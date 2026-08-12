import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/supabase_provider.dart';
import '../../trips/data/trip_scope.dart';
import '../domain/trip_statistics.dart';

final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository(ref.watch(supabaseClientProvider));
});

final tripStatisticsProvider =
    FutureProvider.autoDispose.family<TripStatistics, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  return ref.watch(statisticsRepositoryProvider).getStatistics(tripId);
});

class StatisticsRepository {
  StatisticsRepository(this._client);

  final SupabaseClient _client;

  Future<TripStatistics> getStatistics(String tripId) async {
    try {
      final result = await _client.rpc('get_trip_statistics', params: {'p_trip_id': tripId});
      final map = Map<String, dynamic>.from(result as Map);
      return TripStatistics.fromJson(map);
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }
}
