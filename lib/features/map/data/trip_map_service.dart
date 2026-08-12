import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/supabase_provider.dart';
import '../../trips/data/trip_scope.dart';
import '../domain/trip_map_point.dart';

abstract class TripMapService {
  Future<List<TripMapPoint>> loadPoints(String tripId);
}

final tripMapServiceProvider = Provider<TripMapService>((ref) {
  return SupabaseTripMapService(ref.watch(supabaseClientProvider));
});

final tripMapPointsProvider =
    FutureProvider.autoDispose.family<List<TripMapPoint>, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  return ref.watch(tripMapServiceProvider).loadPoints(tripId);
});

class SupabaseTripMapService implements TripMapService {
  SupabaseTripMapService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TripMapPoint>> loadPoints(String tripId) async {
    try {
      final result =
          await _client.rpc('get_trip_map_points', params: {'p_trip_id': tripId});
      final list = (result as List<dynamic>)
          .map((e) => TripMapPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((p) => TripMapPoint.isValidCoordinate(p.latitude, p.longitude))
          .toList();
      return sortJourney(list);
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }
}
