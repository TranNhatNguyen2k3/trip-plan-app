import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../trips/data/trip_repository.dart';
import '../data/budget_repository.dart';
import '../domain/trip_budget.dart';
import 'budget_card.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(TripBudgetSummary? current) async {
    final raw = _controller.text.replaceAll(RegExp(r'[^\d]'), '');
    final value = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && (value == null || value <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid budget amount.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).setBudget(widget.tripId, value);
      ref.invalidate(tripProvider(widget.tripId));
      ref.invalidate(tripBudgetSummaryProvider(widget.tripId));
      ref.invalidate(tripsProvider);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tripBudgetSummaryProvider(widget.tripId));
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final currency = tripAsync.asData?.value.currency ?? 'VND';

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Budget')),
      body: summaryAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(tripBudgetSummaryProvider(widget.tripId)),
        ),
        data: (summary) {
          if (_controller.text.isEmpty && summary.budgetAmount != null) {
            _controller.text = summary.budgetAmount.toString();
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              if (!summary.hasBudget)
                AppEmptyState(
                  title: 'No trip budget yet',
                  message: 'Set an optional total budget to track spending.',
                  icon: Icons.account_balance_wallet_outlined,
                  actionLabel: null,
                  onAction: null,
                )
              else
                BudgetCard(
                  summary: summary,
                  currency: currency,
                  onTap: null,
                ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _controller,
                label: 'Trip Budget',
                hint: '5,000,000 (optional)',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Optional. Leave empty to clear the budget.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save Budget',
                isLoading: _saving,
                onPressed: () => _save(summary),
              ),
              if (summary.hasBudget && summary.byCategory.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('By category', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                for (final c in summary.byCategory)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.category[0].toUpperCase() + c.category.substring(1),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(formatCurrency(c.amount, currency: currency)),
                      ],
                    ),
                  ),
              ],
              if (summary.insights.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Insights', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                for (final tip in summary.insights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Text(tip, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ),
              ],
              if (summary.dailyBudget != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily target', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      AppCurrencyText(summary.dailyBudget!, fontSize: 22),
                      if (summary.averageDailySpend != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Average daily spend: ${formatCurrency(summary.averageDailySpend!, currency: currency)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (summary.averageDailySpend! <= summary.dailyBudget!)
                          Text(
                            "You're on track",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to overview'),
              ),
            ],
          );
        },
      ),
    );
  }
}
