import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_repository.dart';
import '../../settlements/data/settlement_repository.dart';
import '../data/trip_repository.dart';
import '../domain/trip.dart';
import 'trip_cover_fallback.dart';

final _coverUrlProvider =
    FutureProvider.autoDispose.family<String?, String?>((ref, path) {
  return ref.watch(tripRepositoryProvider).createSignedUrl(path);
});

/// Aggregates the signed-in user's net balance across all trips.
final homeBalanceSummaryProvider =
    FutureProvider.autoDispose<({int owe, int receive})>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return (owe: 0, receive: 0);

  final trips = await ref.watch(tripsProvider.future);
  final repo = ref.watch(settlementRepositoryProvider);

  final results = await Future.wait(trips.map((trip) async {
    try {
      final balances = await repo.getBalances(trip.id);
      var owe = 0;
      var receive = 0;
      for (final b in balances) {
        if (b.userId != userId) continue;
        if (b.netBalance < 0) owe += -b.netBalance;
        if (b.netBalance > 0) receive += b.netBalance;
      }
      return (owe: owe, receive: receive);
    } catch (_) {
      // Skip trips that fail balance fetch; home still renders.
      return (owe: 0, receive: 0);
    }
  }));

  var owe = 0;
  var receive = 0;
  for (final r in results) {
    owe += r.owe;
    receive += r.receive;
  }
  return (owe: owe, receive: receive);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final tripsAsync = ref.watch(tripsProvider);
    final balancesAsync = ref.watch(homeBalanceSummaryProvider);
    final greeting = greetingForNow();
    final name = profile?.displayName.split(' ').first ?? 'traveler';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tripsProvider);
            ref.invalidate(homeBalanceSummaryProvider);
            await ref.read(tripsProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.xl,
                    AppSpacing.screenPadding,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        name,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      balancesAsync.when(
                        loading: () => const AppSkeleton(height: 112),
                        error: (_, _) => _BalanceSummaryCard(owe: 0, receive: 0),
                        data: (s) => _BalanceSummaryCard(
                          owe: s.owe,
                          receive: s.receive,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent Trips',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/trips'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              tripsAsync.when(
                loading: () => const SliverFillRemaining(
                  child: AppLoading(message: 'Loading trips…'),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: AppErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(tripsProvider),
                  ),
                ),
                data: (trips) {
                  if (trips.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        title: 'No trips yet',
                        message: 'Plan your next adventure and invite friends.',
                        icon: Icons.luggage_outlined,
                        actionLabel: 'Create trip',
                        onAction: () => context.push('/trips/create'),
                      ),
                    );
                  }
                  final recent = trips.take(6).toList();
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      0,
                      AppSpacing.screenPadding,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: recent.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) {
                        return _HomeTripCard(trip: recent[index]);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({required this.owe, required this.receive});

  final int owe;
  final int receive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.travelAccent.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.surface,
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You owe', style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatCurrency(owe),
                  style: AppTypography.money(
                    color: AppColors.warning,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You receive', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatCurrency(receive),
                    style: AppTypography.money(
                      color: AppColors.success,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTripCard extends ConsumerWidget {
  const _HomeTripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverAsync = ref.watch(_coverUrlProvider(trip.coverPhotoPath));
    final dateLabel = formatDateRange(trip.startDate, trip.endDate);

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/trips/${trip.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Hero(
            tag: 'trip-cover-${trip.id}',
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusMd),
              ),
              child: coverAsync.when(
                loading: () => const AppSkeleton(height: 148),
                error: (_, _) => const TripCoverFallback(height: 148),
                data: (url) {
                  if (url == null || url.isEmpty) {
                    return const TripCoverFallback(height: 148);
                  }
                  return AppImage(
                    url: url,
                    height: 148,
                    width: double.infinity,
                    borderRadius: BorderRadius.zero,
                    memCacheWidth: 800,
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.name, style: theme.textTheme.titleMedium),
                if (trip.destination != null && trip.destination!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          trip.destination!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(dateLabel, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
