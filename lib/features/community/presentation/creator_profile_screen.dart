import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/community_repository.dart';
import 'plan_card.dart';

class CreatorProfileScreen extends ConsumerWidget {
  const CreatorProfileScreen({super.key, required this.creatorId});

  final String creatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(creatorProfileProvider(creatorId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Creator',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () => const AppLoading(message: 'Loading profile…'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(creatorProfileProvider(creatorId)),
        ),
        data: (profile) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creatorProfileProvider(creatorId));
              await ref.read(creatorProfileProvider(creatorId).future);
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
                      children: [
                        AppAvatar(
                          url: profile.avatarUrl,
                          name: profile.displayName,
                          size: 88,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          profile.displayName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.primaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: _Metric(
                                value: '${profile.publicPlanCount}',
                                label: 'Trips',
                              ),
                            ),
                            Expanded(
                              child: _Metric(
                                value: _compact(profile.totalLikes),
                                label: 'Likes',
                              ),
                            ),
                            Expanded(
                              child: _Metric(
                                value: _compact(profile.totalClones),
                                label: 'Clones',
                              ),
                            ),
                            Expanded(
                              child: _Metric(
                                value: _compact(profile.totalViews),
                                label: 'Views',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Published trips',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (profile.plans.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      title: 'No public trips yet',
                      message: 'This traveler has not published a plan.',
                      icon: Icons.public_off_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      0,
                      AppSpacing.screenPadding,
                      AppSpacing.xxxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: profile.plans.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xl),
                      itemBuilder: (context, index) {
                        final plan = profile.plans[index];
                        return PlanCard(
                          plan: plan,
                          onTap: () =>
                              context.push('/explore/plans/${plan.tripId}'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}K'
          : '${k.toStringAsFixed(1)}K';
    }
    return '$n';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
