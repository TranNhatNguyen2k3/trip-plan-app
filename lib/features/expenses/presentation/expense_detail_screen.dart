import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../settlements/data/settlement_repository.dart';
import '../../statistics/data/statistics_repository.dart';
import '../data/expense_repository.dart';
import 'expenses_screen.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.tripId,
    required this.expenseId,
  });

  final String tripId;
  final String expenseId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(expenseId);
      ref.invalidate(expensesProvider(tripId));
      ref.invalidate(tripBalancesProvider(tripId));
      ref.invalidate(tripStatisticsProvider(tripId));
      HapticFeedback.lightImpact();
      if (context.mounted) context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(
      expenseProvider((tripId: tripId, expenseId: expenseId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/trips/$tripId/expenses/$expenseId/edit'),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: expenseAsync.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () => ref.invalidate(
            expenseProvider((tripId: tripId, expenseId: expenseId)),
          ),
        ),
        data: (expense) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          child: Text(
                            expense.description,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCurrencyText(expense.amount, fontSize: 32),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(
                      label: 'Category',
                      value: expense.category.label,
                    ),
                    _DetailRow(
                      label: 'Paid by',
                      value: expense.payerName ?? 'Someone',
                    ),
                    _DetailRow(
                      label: 'Date',
                      value: formatDate(expense.expenseDate),
                    ),
                    if (expense.note != null && expense.note!.isNotEmpty)
                      _DetailRow(label: 'Note', value: expense.note!),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Split', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < expense.participants.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: AppAvatar(
                          name: expense.participants[i].displayName,
                        ),
                        title: Text(
                          expense.participants[i].displayName ?? 'Traveler',
                        ),
                        trailing: AppCurrencyText(
                          expense.participants[i].shareAmount,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Edit expense',
                icon: Icons.edit_outlined,
                onPressed: () =>
                    context.push('/trips/$tripId/expenses/$expenseId/edit'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Delete',
                variant: AppButtonVariant.destructive,
                icon: Icons.delete_outline,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
