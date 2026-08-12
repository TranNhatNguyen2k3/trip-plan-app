import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/supabase_provider.dart';
import '../../trips/data/trip_scope.dart';
import '../domain/settlement.dart';

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository(ref.watch(supabaseClientProvider));
});

final tripBalancesProvider =
    FutureProvider.autoDispose.family<List<Balance>, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  return ref.watch(settlementRepositoryProvider).getBalances(tripId);
});

final settlementsProvider =
    FutureProvider.autoDispose.family<List<Settlement>, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  return ref.watch(settlementRepositoryProvider).listSettlements(tripId);
});

final settlementSuggestionsProvider =
    FutureProvider.autoDispose.family<List<SettlementSuggestion>, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  final balances = await ref.watch(tripBalancesProvider(tripId).future);
  return calculateSettlements(balances);
});

final homeBalanceSummaryProvider =
    FutureProvider.autoDispose<({int owe, int receive})>((ref) async {
  return ref.watch(settlementRepositoryProvider).getHomeBalanceSummary();
});

class SettlementRepository {
  SettlementRepository(this._client);

  final SupabaseClient _client;

  Future<({int owe, int receive})> getHomeBalanceSummary() async {
    try {
      final result = await _client.rpc('get_user_home_balance_summary');
      final map = Map<String, dynamic>.from(result as Map);
      return (
        owe: (map['owe'] as num?)?.toInt() ?? 0,
        receive: (map['receive'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<List<Balance>> getBalances(String tripId) async {
    try {
      final rows = await _client.rpc('get_trip_balances', params: {'p_trip_id': tripId});
      return (rows as List).map((e) => Balance.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<List<Settlement>> listSettlements(String tripId) async {
    final rows = await _client
        .from('settlements')
        .select(
          '*, from_profile:profiles!settlements_from_user_id_fkey(display_name), to_profile:profiles!settlements_to_user_id_fkey(display_name)',
        )
        .eq('trip_id', tripId)
        .order('settled_at', ascending: false);
    return (rows as List).map((e) => Settlement.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Settlement> markAsPaid({
    required String tripId,
    required String fromUserId,
    required String toUserId,
    required int amount,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AppAuthException('Please sign in.');
    if (fromUserId == toUserId) {
      throw const ValidationException('Cannot settle with yourself.');
    }
    final row = await _client
        .from('settlements')
        .insert({
          'trip_id': tripId,
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'amount': amount,
          'note': note,
          'status': 'completed',
          'created_by': userId,
        })
        .select(
          '*, from_profile:profiles!settlements_from_user_id_fkey(display_name), to_profile:profiles!settlements_to_user_id_fkey(display_name)',
        )
        .single();
    return Settlement.fromJson(row);
  }
}
