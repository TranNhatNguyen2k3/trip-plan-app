import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/community_repository.dart';
import 'plan_card.dart';

class SavedPlansScreen extends ConsumerWidget {
  const SavedPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedAsync = ref.watch(savedPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved plans',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
      ),
      body: savedAsync.when(
        loading: () => const AppLoading(message: 'Loading saved plans…'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(savedPlansProvider),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return AppEmptyState(
              title: "You haven't saved any plans yet",
              message: 'Find a trip that inspires you.',
              icon: Icons.bookmark_border_rounded,
              actionLabel: 'Explore',
              onAction: () => context.go('/explore'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(savedPlansProvider);
              await ref.read(savedPlansProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                AppSpacing.xxxl,
              ),
              itemCount: plans.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.xl),
              itemBuilder: (context, index) {
                final plan = plans[index];
                return PlanCard(
                  plan: plan,
                  onTap: () => context.push('/explore/plans/${plan.tripId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
