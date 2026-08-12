import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../statistics/data/statistics_repository.dart';
import '../data/settlement_repository.dart';
import '../domain/settlement.dart';

class SettlementsScreen extends ConsumerWidget {
  const SettlementsScreen({super.key, required this.tripId});

  final String tripId;

  Future<void> _confirmAndMarkPaid(
    BuildContext context,
    WidgetRef ref,
    SettlementSuggestion suggestion,
  ) async {
    final from = suggestion.fromName ?? 'Someone';
    final to = suggestion.toName ?? 'Someone';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark payment as completed?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$from → $to', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCurrencyText(suggestion.amount, fontSize: 22),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(settlementRepositoryProvider).markAsPaid(
            tripId: tripId,
            fromUserId: suggestion.fromUserId,
            toUserId: suggestion.toUserId,
            amount: suggestion.amount,
          );
      ref.invalidate(tripBalancesProvider(tripId));
      ref.invalidate(settlementsProvider(tripId));
      ref.invalidate(settlementSuggestionsProvider(tripId));
      ref.invalidate(tripStatisticsProvider(tripId));
      HapticFeedback.lightImpact();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as paid')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(settlementSuggestionsProvider(tripId));
    final historyAsync = ref.watch(settlementsProvider(tripId));
    final balancesAsync = ref.watch(tripBalancesProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tripBalancesProvider(tripId));
          ref.invalidate(settlementsProvider(tripId));
          ref.invalidate(settlementSuggestionsProvider(tripId));
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text('Balances', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            balancesAsync.when(
              loading: () => const AppSkeleton(height: 72),
              error: (e, _) => AppErrorState(
                error: e,
                onRetry: () => ref.invalidate(tripBalancesProvider(tripId)),
              ),
              data: (balances) {
                if (balances.isEmpty) {
                  return const Text('No balances yet.');
                }
                return Column(
                  children: [
                    for (final b in balances)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            AppAvatar(name: b.displayName),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                b.displayName ?? 'Traveler',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            AppCurrencyText(
                              b.netBalance,
                              signed: true,
                              fontSize: 16,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Settlement', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            suggestionsAsync.when(
              loading: () => const AppSkeleton(height: 100),
              error: (e, _) => AppErrorState(
                error: e,
                onRetry: () =>
                    ref.invalidate(settlementSuggestionsProvider(tripId)),
              ),
              data: (suggestions) {
                if (suggestions.isEmpty) {
                  return AppCard(
                    child: Row(
                      children: [
                        Icon(
                          Icons.celebration_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Everyone is settled up.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final n = suggestions.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$n payment${n == 1 ? '' : 's'} needed',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final s in suggestions)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      style: Theme.of(context).textTheme.bodyLarge,
                                      children: [
                                        TextSpan(
                                          text: s.fromName ?? 'Someone',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const TextSpan(text: ' pays '),
                                        TextSpan(
                                          text: s.toName ?? 'Someone',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                AppCurrencyText(s.amount, fontSize: 16),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              label: 'Mark as Paid',
                              icon: Icons.check,
                              expand: false,
                              onPressed: () =>
                                  _confirmAndMarkPaid(context, ref, s),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('History', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            historyAsync.when(
              loading: () => const AppSkeleton(height: 80),
              error: (e, _) => AppErrorState(
                error: e,
                onRetry: () => ref.invalidate(settlementsProvider(tripId)),
              ),
              data: (history) {
                if (history.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'No settlements recorded yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final item in history)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.swap_horiz,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.fromName ?? 'Someone'} → ${item.toName ?? 'Someone'}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    formatDate(item.settledAt),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            AppCurrencyText(item.amount, fontSize: 15),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
