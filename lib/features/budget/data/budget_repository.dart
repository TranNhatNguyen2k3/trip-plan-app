import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/supabase_provider.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/data/trip_scope.dart';
import '../domain/trip_budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(supabaseClientProvider));
});

final tripBudgetSummaryProvider =
    FutureProvider.autoDispose.family<TripBudgetSummary, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  final trip = await ref.watch(tripProvider(tripId).future);
  final raw = await ref.watch(budgetRepositoryProvider).fetchSummary(tripId);
  return buildBudgetSummary(
    budgetAmount: raw.budgetAmount ?? trip.budgetAmount,
    spent: raw.spent,
    byCategory: raw.byCategory,
    startDate: trip.startDate,
    endDate: trip.endDate,
  );
});

class BudgetRepository {
  BudgetRepository(this._client);

  final SupabaseClient _client;

  Future<({int? budgetAmount, int spent, List<({String category, int amount})> byCategory})>
      fetchSummary(String tripId) async {
    try {
      final result =
          await _client.rpc('get_trip_budget_summary', params: {'p_trip_id': tripId});
      final map = Map<String, dynamic>.from(result as Map);
      final cats = (map['by_category'] as List<dynamic>? ?? [])
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return (
              category: m['category'] as String? ?? 'other',
              amount: (m['amount'] as num).toInt(),
            );
          })
          .toList();
      return (
        budgetAmount: (map['budget_amount'] as num?)?.toInt(),
        spent: (map['spent'] as num?)?.toInt() ?? 0,
        byCategory: cats,
      );
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<void> setBudget(String tripId, int? budgetAmount) async {
    if (budgetAmount != null && budgetAmount <= 0) {
      throw const ValidationException('Budget must be greater than zero.');
    }
    await _client.from('trips').update({
      'budget_amount': budgetAmount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }
}
