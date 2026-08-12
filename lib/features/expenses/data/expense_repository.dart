import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/supabase_provider.dart';
import '../../trips/data/trip_scope.dart';
import '../domain/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(supabaseClientProvider));
});

final expensesProvider =
    FutureProvider.autoDispose.family<List<Expense>, String>((ref, tripId) async {
  bindTripScopeRef(ref, tripId);
  return ref.watch(expenseRepositoryProvider).listExpenses(tripId);
});

final expenseProvider =
    FutureProvider.autoDispose.family<Expense, ({String tripId, String expenseId})>(
  (ref, ids) async {
    return ref.watch(expenseRepositoryProvider).getExpense(ids.expenseId);
  },
);

class ExpenseRepository {
  ExpenseRepository(this._client);

  final SupabaseClient _client;

  Future<List<Expense>> listExpenses(String tripId, {int page = 0}) async {
    final from = page * AppConstants.pageSize;
    final to = from + AppConstants.pageSize - 1;
    final rows = await _client
        .from('expenses')
        .select(
          '*, expense_participants(*, profiles(display_name)), payer:profiles!expenses_paid_by_fkey(display_name)',
        )
        .eq('trip_id', tripId)
        .order('expense_date', ascending: false)
        .range(from, to);
    return (rows as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Expense> getExpense(String expenseId) async {
    final row = await _client
        .from('expenses')
        .select(
          '*, expense_participants(*, profiles(display_name)), payer:profiles!expenses_paid_by_fkey(display_name)',
        )
        .eq('id', expenseId)
        .single();
    return Expense.fromJson(row);
  }

  Future<String> createExpense({
    required String tripId,
    required String description,
    required int amount,
    required ExpenseCategory category,
    required String paidBy,
    required DateTime expenseDate,
    String? note,
    required List<ExpenseShare> participants,
  }) async {
    if (!participants.every((p) => p.shareAmount >= 0) ||
        participants.fold<int>(0, (s, p) => s + p.shareAmount) != amount) {
      throw const ValidationException('Shares must sum to the expense amount.');
    }

    try {
      final id = await _client.rpc(
        'create_expense',
        params: {
          'p_trip_id': tripId,
          'p_description': description,
          'p_amount': amount,
          'p_category': category.name,
          'p_paid_by': paidBy,
          'p_expense_date': expenseDate.toIso8601String(),
          'p_note': note,
          'p_participants': participants
              .map((p) => {'user_id': p.userId, 'share_amount': p.shareAmount})
              .toList(),
        },
      );
      return id as String;
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<void> updateExpense({
    required String expenseId,
    required String description,
    required int amount,
    required ExpenseCategory category,
    required String paidBy,
    required DateTime expenseDate,
    String? note,
    required List<ExpenseShare> participants,
  }) async {
    if (participants.fold<int>(0, (s, p) => s + p.shareAmount) != amount) {
      throw const ValidationException('Shares must sum to the expense amount.');
    }

    await _client.from('expenses').update({
      'description': description,
      'amount': amount,
      'category': category.name,
      'paid_by': paidBy,
      'expense_date': expenseDate.toIso8601String(),
      'note': note,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', expenseId);

    await _client.from('expense_participants').delete().eq('expense_id', expenseId);
    await _client.from('expense_participants').insert(
          participants
              .map((p) => {
                    'expense_id': expenseId,
                    'user_id': p.userId,
                    'share_amount': p.shareAmount,
                  })
              .toList(),
        );
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }
}
