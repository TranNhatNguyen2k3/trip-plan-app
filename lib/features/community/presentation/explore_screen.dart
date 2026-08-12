import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/community_repository.dart';
import 'plan_card.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  static const _trendingQuery = (destination: null, tripType: null, sort: 'trending');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.communityTripPlans) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explore')),
        body: const AppEmptyState(
          title: 'Coming soon',
          message: 'Community trip plans are not available yet.',
          icon: Icons.explore_outlined,
        ),
      );
    }

    final theme = Theme.of(context);
    final destinationsAsync = ref.watch(popularDestinationsProvider);
    final plansAsync = ref.watch(publicPlansProvider(_trendingQuery));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(popularDestinationsProvider);
            ref.invalidate(publicPlansProvider(_trendingQuery));
            await Future.wait([
              ref.read(popularDestinationsProvider.future),
              ref.read(publicPlansProvider(_trendingQuery).future),
            ]);
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
                        'Explore',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Bạn muốn đi đâu?',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Material(
                        color: theme.colorScheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          onTap: () => context.push('/explore/search'),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: AppSpacing.touchTarget,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Đà Lạt, Phú Quốc, Đà Nẵng…',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Popular Destinations',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      destinationsAsync.when(
                        loading: () => const SizedBox(
                          height: AppSpacing.touchTarget,
                          child: AppSkeleton(height: 44, width: 200),
                        ),
                        error: (e, _) => Text(
                          'Unable to load destinations',
                          style: theme.textTheme.bodySmall,
                        ),
                        data: (destinations) {
                          if (destinations.isEmpty) {
                            return Text(
                              'No popular destinations yet',
                              style: theme.textTheme.bodyMedium,
                            );
                          }
                          return SizedBox(
                            height: AppSpacing.touchTarget + 4,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: destinations.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final d = destinations[index];
                                return AppChip(
                                  label: d.destination,
                                  icon: Icons.place_outlined,
                                  onTap: () => context.push(
                                    '/explore/search?q=${Uri.encodeComponent(d.destination)}',
                                    extra: d.destination,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Trending Plans',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/explore/search'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              plansAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppLoading(message: 'Loading plans…'),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorState(
                    error: e,
                    onRetry: () =>
                        ref.invalidate(publicPlansProvider(_trendingQuery)),
                  ),
                ),
                data: (plans) {
                  if (plans.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        title: 'No trip plans yet',
                        message: 'Be the first to share a trip!',
                        icon: Icons.explore_outlined,
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      0,
                      AppSpacing.screenPadding,
                      AppSpacing.xxxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: plans.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xl),
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        return PlanCard(
                          plan: plan,
                          onTap: () =>
                              context.push('/explore/plans/${plan.tripId}'),
                        );
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
