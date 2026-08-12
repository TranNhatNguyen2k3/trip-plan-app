import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../domain/trip_budget.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.summary,
    required this.currency,
    this.onTap,
  });

  final TripBudgetSummary summary;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!summary.hasBudget) {
      return AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trip Budget', style: theme.textTheme.titleMedium),
                  Text('No budget set', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
    }

    final over = summary.isOverBudget;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trip Budget', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCurrencyText(summary.budgetAmount!, fontSize: 24),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent', style: theme.textTheme.bodySmall),
                    Text(
                      formatCurrency(summary.spent, currency: currency),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(over ? 'Over by' : 'Remaining', style: theme.textTheme.bodySmall),
                    Text(
                      formatCurrency(
                        over ? summary.overAmount : summary.remaining,
                        currency: currency,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: over ? theme.colorScheme.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.progressClamped,
              minHeight: 10,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
              color: over ? theme.colorScheme.error : AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            over ? 'Budget exceeded' : '${summary.percentSpent}%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: over ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
