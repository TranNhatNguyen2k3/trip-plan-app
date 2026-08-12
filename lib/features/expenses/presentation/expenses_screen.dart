import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

IconData categoryIcon(ExpenseCategory category) {
  return switch (category) {
    ExpenseCategory.food => Icons.restaurant_outlined,
    ExpenseCategory.hotel => Icons.hotel_outlined,
    ExpenseCategory.transport => Icons.directions_car_outlined,
    ExpenseCategory.activity => Icons.hiking_outlined,
    ExpenseCategory.shopping => Icons.shopping_bag_outlined,
    ExpenseCategory.tickets => Icons.confirmation_number_outlined,
    ExpenseCategory.fuel => Icons.local_gas_station_outlined,
    ExpenseCategory.other => Icons.payments_outlined,
  };
}

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Add expense',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/trips/$tripId/expenses/create'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/trips/$tripId/expenses/create'),
        child: const Icon(Icons.add),
      ),
      body: expensesAsync.when(
        loading: () => const AppLoading(message: 'Loading expenses…'),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () => ref.invalidate(expensesProvider(tripId)),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return AppEmptyState(
              title: 'No expenses yet',
              message: 'Add your first shared cost to start tracking.',
              icon: Icons.receipt_long_outlined,
              actionLabel: 'Add expense',
              onAction: () => context.push('/trips/$tripId/expenses/create'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(expensesProvider(tripId)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                88,
              ),
              itemCount: expenses.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return AppCard(
                  onTap: () => context.push('/trips/$tripId/expenses/${expense.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        child: Icon(
                          categoryIcon(expense.category),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.description,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${expense.category.label} · ${expense.payerName ?? 'Someone'}'
                              ' · ${formatDate(expense.expenseDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppCurrencyText(expense.amount, fontSize: 16),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
