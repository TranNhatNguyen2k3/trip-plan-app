import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../trips/presentation/trip_cover_fallback.dart';
import '../data/community_repository.dart';
import '../domain/public_trip_plan.dart';

final planPhotoUrlProvider =
    FutureProvider.autoDispose.family<String?, String?>((ref, path) {
  return ref.watch(communityRepositoryProvider).signedPlanPhotoUrl(path);
});

String tripTypeLabel(String type) {
  if (type.isEmpty) return type;
  return '${type[0].toUpperCase()}${type.substring(1)}';
}

class PlanCard extends ConsumerWidget {
  const PlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.compact = false,
  });

  final PublicTripPlan plan;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverAsync = ref.watch(planPhotoUrlProvider(plan.coverImage));
    final coverHeight = compact ? 140.0 : 180.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap ?? () => context.push('/explore/plans/${plan.tripId}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusLg),
                ),
                child: Stack(
                  children: [
                    coverAsync.when(
                      loading: () => AppSkeleton(height: coverHeight),
                      error: (_, _) => TripCoverFallback(height: coverHeight),
                      data: (url) {
                        if (url == null || url.isEmpty) {
                          return TripCoverFallback(height: coverHeight);
                        }
                        return AppImage(
                          url: url,
                          height: coverHeight,
                          width: double.infinity,
                          borderRadius: BorderRadius.zero,
                          memCacheWidth: 900,
                          heroTag: 'plan-cover-${plan.tripId}',
                        );
                      },
                    ),
                    if (plan.tripType != null && plan.tripType!.isNotEmpty)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.overlay.withValues(alpha: 0.55),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            tripTypeLabel(plan.tripType!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (plan.destination != null &&
                        plan.destination!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              plan.destination!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (plan.estimatedBudget != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '~${formatCompactCurrency(plan.estimatedBudget!, currency: plan.currency)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.travelAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        AppAvatar(
                          url: plan.creatorAvatar,
                          name: plan.creatorDisplayName,
                          size: 28,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            plan.creatorDisplayName ?? 'Traveler',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        _StatChip(
                          icon: Icons.favorite_rounded,
                          value: plan.likeCount,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatChip(
                          icon: Icons.content_copy_rounded,
                          value: plan.cloneCount,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 2),
        Text(
          _compact(value),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
        ),
      ],
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
