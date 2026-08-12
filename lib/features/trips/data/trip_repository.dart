import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/signed_url_service.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/supabase_provider.dart';
import '../domain/trip.dart';
import 'trip_scope.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(signedUrlCacheProvider),
  );
});

final tripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  ref.keepAlive();
  return ref.watch(tripRepositoryProvider).listTrips();
});

final tripProvider = FutureProvider.autoDispose.family<Trip, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  return ref.watch(tripRepositoryProvider).getTrip(tripId);
});

final tripMembersProvider =
    FutureProvider.autoDispose.family<List<TripMember>, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  return ref.watch(tripRepositoryProvider).listMembers(tripId);
});

class TripRepository {
  TripRepository(this._client, this._urlCache);

  final SupabaseClient _client;
  final SignedUrlCache _urlCache;
  final _uuid = const Uuid();

  Future<List<Trip>> listTrips() async {
    final rows = await _client
        .from('trips')
        .select()
        .order('updated_at', ascending: false);
    return (rows as List).map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Trip> getTrip(String tripId) async {
    final row = await _client.from('trips').select().eq('id', tripId).single();
    return Trip.fromJson(row);
  }

  Future<Trip> createTrip({
    required String name,
    String? description,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String currency = AppConstants.defaultCurrency,
    int? budgetAmount,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AppAuthException('Please sign in.');

    final row = await _client
        .from('trips')
        .insert({
          'name': name,
          'description': description,
          'destination': destination,
          'start_date': startDate?.toIso8601String().split('T').first,
          'end_date': endDate?.toIso8601String().split('T').first,
          'currency': currency,
          'budget_amount': budgetAmount,
          'created_by': userId,
        })
        .select()
        .single();
    return Trip.fromJson(row);
  }

  Future<Trip> updateTrip(Trip trip) async {
    final row = await _client
        .from('trips')
        .update({
          'name': trip.name,
          'description': trip.description,
          'destination': trip.destination,
          'start_date': trip.startDate?.toIso8601String().split('T').first,
          'end_date': trip.endDate?.toIso8601String().split('T').first,
          'currency': trip.currency,
          'cover_photo_path': trip.coverPhotoPath,
          'budget_amount': trip.budgetAmount,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', trip.id)
        .select()
        .single();
    return Trip.fromJson(row);
  }

  Future<void> deleteTrip(String tripId) async {
    await _client.from('trips').delete().eq('id', tripId);
  }

  Future<List<TripMember>> listMembers(String tripId) async {
    final rows = await _client
        .from('trip_members')
        .select('*, profiles(id, display_name, avatar_url)')
        .eq('trip_id', tripId)
        .order('joined_at');
    return (rows as List)
        .map((e) => TripMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TripInvitation> createInvitation(String tripId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AppAuthException('Please sign in.');
    final token = _uuid.v4();
    final row = await _client
        .from('trip_invitations')
        .insert({
          'trip_id': tripId,
          'token': token,
          'invited_by': userId,
          'expires_at': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
        })
        .select()
        .single();
    return TripInvitation.fromJson(row);
  }

  Future<void> shareInvitation(TripInvitation invitation, String tripName) async {
    final link = joinLink(invitation.token);
    await SharePlus.instance.share(
      ShareParams(text: 'Join "$tripName" on TripMate:\n$link'),
    );
  }

  Future<String> acceptInvitation(String token) async {
    final result = await _client.rpc('accept_trip_invitation', params: {'p_token': token});
    return result as String;
  }

  Future<void> setCoverPhoto(String tripId, String storagePath) async {
    await _client.from('trips').update({
      'cover_photo_path': storagePath,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }

  Future<String?> createSignedUrl(String? path) async {
    return _urlCache.getSignedUrl(path);
  }
}
