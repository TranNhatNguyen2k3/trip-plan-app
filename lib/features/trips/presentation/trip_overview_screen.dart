import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/storage/signed_url_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../budget/data/budget_repository.dart';
import '../../budget/domain/trip_budget.dart';
import '../../budget/presentation/budget_card.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/domain/journal_entry.dart';
import '../../settlements/data/settlement_repository.dart';
import '../../statistics/data/statistics_repository.dart';
import '../data/trip_repository.dart';
import 'trip_cover_fallback.dart';

class TripOverviewScreen extends ConsumerWidget {
  const TripOverviewScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
    final statsAsync = ref.watch(tripStatisticsProvider(tripId));
    final balancesAsync = ref.watch(tripBalancesProvider(tripId));
    final expensesAsync = ref.watch(expensesProvider(tripId));
    final journalAsync = ref.watch(journalEntriesProvider(tripId));
    final userId = ref.watch(currentUserProvider)?.id;

    return tripAsync.when(
      loading: () => const AppLoading(message: 'Loading trip…'),
      error: (e, _) => AppErrorState(
        error: e,
        onRetry: () => ref.invalidate(tripProvider(tripId)),
      ),
      data: (trip) {
        final coverAsync = ref.watch(signedStorageUrlProvider(trip.coverPhotoPath));
        final dateLabel = formatDateRange(trip.startDate, trip.endDate);
        final theme = Theme.of(context);

        int? myNet;
        balancesAsync.whenData((balances) {
          for (final b in balances) {
            if (b.userId == userId) {
              myNet = b.netBalance;
              break;
            }
          }
        });

        final totalSpent = statsAsync.asData?.value.totalSpent;
        final expenses =
            expensesAsync.asData?.value.take(5).toList() ?? const <Expense>[];
        final memories =
            journalAsync.asData?.value.take(4).toList() ?? const <JournalEntry>[];

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tripProvider(tripId));
            ref.invalidate(tripStatisticsProvider(tripId));
            ref.invalidate(tripBalancesProvider(tripId));
            ref.invalidate(expensesProvider(tripId));
            ref.invalidate(journalEntriesProvider(tripId));
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: Hero(
                  tag: 'trip-cover-${trip.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: coverAsync.when(
                      loading: () => const AppSkeleton(height: 220),
                      error: (_, _) => const TripCoverFallback(height: 220),
                      data: (url) {
                        if (url == null || url.isEmpty) {
                          return const TripCoverFallback(height: 220);
                        }
                        return AppImage(
                          url: url,
                          cacheKey: trip.coverPhotoPath,
                          height: 220,
                          width: double.infinity,
                          borderRadius: BorderRadius.zero,
                          memCacheWidth: 1200,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (trip.destination != null &&
                        trip.destination!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            trip.destination!,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ],
                    if (dateLabel.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(dateLabel, style: theme.textTheme.bodyMedium),
                    ],
                    if (trip.clonedFromTripId != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Inspired by a community trip plan',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (FeatureFlags.communityTripPlans && trip.isPublic) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Published to Explore',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _MoneySummary(
                      currency: trip.currency,
                      totalSpent: totalSpent,
                      myNet: myNet,
                      loading: statsAsync.isLoading || balancesAsync.isLoading,
                    ),
                    if (FeatureFlags.tripBudget) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Consumer(
                        builder: (context, ref, _) {
                          final budgetAsync =
                              ref.watch(tripBudgetSummaryProvider(tripId));
                          return budgetAsync.when(
                            loading: () => const AppSkeleton(height: 120),
                            error: (_, _) => BudgetCard(
                              summary: buildBudgetSummary(
                                budgetAmount: trip.budgetAmount,
                                spent: totalSpent ?? 0,
                              ),
                              currency: trip.currency,
                              onTap: () => context.push('/trips/$tripId/budget'),
                            ),
                            data: (summary) => BudgetCard(
                              summary: summary,
                              currency: trip.currency,
                              onTap: () => context.push('/trips/$tripId/budget'),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Text('Explore', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (FeatureFlags.smartTripMap)
                          _ExploreChip(
                            icon: Icons.map_outlined,
                            label: 'Trip Map',
                            onTap: () => context.go('/trips/$tripId/map'),
                          ),
                        _ExploreChip(
                          icon: Icons.handshake_outlined,
                          label: 'Settlement',
                          onTap: () => context.go('/trips/$tripId/settlements'),
                        ),
                        if (FeatureFlags.tripBudget)
                          _ExploreChip(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Budget',
                            onTap: () => context.push('/trips/$tripId/budget'),
                          ),
                        if (FeatureFlags.digitalTripBook)
                          _ExploreChip(
                            icon: Icons.menu_book_outlined,
                            label: 'Trip Book',
                            onTap: () => context.push('/trips/$tripId/book'),
                          ),
                        if (FeatureFlags.autoTripRecap)
                          _ExploreChip(
                            icon: Icons.movie_filter_outlined,
                            label: 'Trip Recap',
                            onTap: () => context.push('/trips/$tripId/recap'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _SectionHeader(
                      title: 'Recent Memories',
                      actionLabel: 'Journal',
                      onAction: () => context.go('/trips/$tripId/journal'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (journalAsync.isLoading)
                      const AppSkeleton(height: 96)
                    else if (memories.isEmpty)
                      AppCard(
                        child: Text(
                          'No memories yet — capture your first moment.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: memories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (context, index) {
                            return _MemoryChip(
                              entry: memories[index],
                              tripId: tripId,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                    _SectionHeader(
                      title: 'Recent Expenses',
                      actionLabel: 'See all',
                      onAction: () => context.go('/trips/$tripId/expenses'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (expensesAsync.isLoading)
                      const AppSkeleton(height: 120)
                    else if (expensesAsync.hasError)
                      AppErrorState(
                        error: expensesAsync.error!,
                        onRetry: () => ref.invalidate(expensesProvider(tripId)),
                      )
                    else if (expenses.isEmpty)
                      const AppEmptyState(
                        title: 'No expenses yet',
                        message: 'Add your first shared cost for this trip.',
                        icon: Icons.receipt_long_outlined,
                      )
                    else
                      ...expenses.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _ExpenseRow(
                            expense: e,
                            currency: trip.currency,
                            onTap: () => context.push(
                              '/trips/$tripId/expenses/${e.id}',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoneySummary extends StatelessWidget {
  const _MoneySummary({
    required this.currency,
    required this.totalSpent,
    required this.myNet,
    required this.loading,
  });

  final String currency;
  final int? totalSpent;
  final int? myNet;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owe = (myNet != null && myNet! < 0) ? -myNet! : 0;
    final receive = (myNet != null && myNet! > 0) ? myNet! : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: loading
          ? const AppSkeleton(height: 88)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total spent', style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                AppCurrencyText(
                  totalSpent ?? 0,
                  currency: currency,
                  fontSize: 30,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You owe', style: theme.textTheme.bodySmall),
                          Text(
                            formatCurrency(owe, currency: currency),
                            style: AppTypography.money(
                              color: AppColors.warning,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You receive', style: theme.textTheme.bodySmall),
                          Text(
                            formatCurrency(receive, currency: currency),
                            style: AppTypography.money(
                              color: AppColors.success,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _MemoryChip extends ConsumerWidget {
  const _MemoryChip({required this.entry, required this.tripId});

  final JournalEntry entry;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstPhoto =
        entry.photos.isNotEmpty ? entry.photos.first.storagePath : null;
    final urlAsync = firstPhoto == null
        ? null
        : ref.watch(signedStorageUrlProvider(firstPhoto));

    return InkWell(
      onTap: () => context.push('/trips/$tripId/journal/${entry.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
          color: theme.colorScheme.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: urlAsync == null
                  ? Container(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.photo_outlined,
                        color: AppColors.primary,
                      ),
                    )
                  : urlAsync.when(
                      loading: () => const AppSkeleton(height: 72),
                      error: (_, _) => Container(
                        color: AppColors.surfaceMuted,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                      data: (url) => AppImage(
                        url: url,
                        cacheKey: firstPhoto,
                        height: 72,
                        borderRadius: BorderRadius.zero,
                        memCacheWidth: 300,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                entry.title?.isNotEmpty == true
                    ? entry.title!
                    : (entry.locationName ?? 'Memory'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.currency,
    required this.onTap,
  });

  final Expense expense;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description, style: theme.textTheme.titleMedium),
                Text(
                  '${expense.category.label} · ${formatDate(expense.expenseDate)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(expense.amount, currency: currency),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ExploreChip extends StatelessWidget {
  const _ExploreChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
