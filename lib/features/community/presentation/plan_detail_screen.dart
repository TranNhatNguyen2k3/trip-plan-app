import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_currency_text.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../trips/presentation/trip_cover_fallback.dart';
import '../../../core/storage/signed_url_service.dart';
import '../data/community_repository.dart';
import '../domain/public_trip_plan.dart';

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  bool _viewRecorded = false;
  bool _cloning = false;
  bool _liking = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewRecorded) return;
    _viewRecorded = true;
    ref.read(communityRepositoryProvider).recordView(widget.tripId);
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      await ref.read(communityRepositoryProvider).toggleLike(widget.tripId);
      HapticFeedback.lightImpact();
      ref.invalidate(publicPlanDetailProvider(widget.tripId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(communityRepositoryProvider).toggleSave(widget.tripId);
      HapticFeedback.lightImpact();
      ref.invalidate(publicPlanDetailProvider(widget.tripId));
      ref.invalidate(savedPlansProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clonePlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use this plan?'),
        content: const Text(
          'A new private trip will be created from this public plan. '
          'You can edit it freely afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Use This Plan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cloning = true);
    try {
      final newId =
          await ref.read(communityRepositoryProvider).clonePlan(widget.tripId);
      HapticFeedback.mediumImpact();
      ref.invalidate(publicPlanDetailProvider(widget.tripId));
      if (!mounted) return;
      context.go('/trips/$newId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _cloning = false);
    }
  }

  Map<DateTime, List<PublicPlanItineraryItem>> _groupByDay(
    List<PublicPlanItineraryItem> items,
  ) {
    final map = <DateTime, List<PublicPlanItineraryItem>>{};
    for (final item in items) {
      final day = DateTime(
        item.visitedAt.year,
        item.visitedAt.month,
        item.visitedAt.day,
      );
      map.putIfAbsent(day, () => []).add(item);
    }
    final keys = map.keys.toList()..sort();
    return {for (final k in keys) k: map[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(publicPlanDetailProvider(widget.tripId));

    return Scaffold(
      appBar: detailAsync.hasError || detailAsync.isLoading
          ? AppBar()
          : null,
      body: detailAsync.when(
        loading: () => const AppLoading(message: 'Loading plan…'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () =>
              ref.invalidate(publicPlanDetailProvider(widget.tripId)),
        ),
        data: (detail) {
          final plan = detail.plan;
          final coverAsync = ref.watch(signedStorageUrlProvider(plan.coverImage));
          final byDay = _groupByDay(detail.itinerary);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                actions: [
                  IconButton(
                    tooltip: detail.likedByMe ? 'Unlike' : 'Like',
                    onPressed: _liking ? null : _toggleLike,
                    icon: Icon(
                      detail.likedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: detail.likedByMe
                          ? AppColors.error
                          : AppColors.textOnPrimary,
                    ),
                  ),
                  IconButton(
                    tooltip: detail.savedByMe ? 'Unsave' : 'Save',
                    onPressed: _saving ? null : _toggleSave,
                    icon: Icon(
                      detail.savedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      coverAsync.when(
                        loading: () => const TripCoverFallback(height: 260),
                        error: (_, _) =>
                            const TripCoverFallback(height: 260),
                        data: (url) {
                          if (url == null || url.isEmpty) {
                            return const TripCoverFallback(height: 260);
                          }
                          return AppImage(
                            url: url,
                            height: 260,
                            width: double.infinity,
                            borderRadius: BorderRadius.zero,
                            memCacheWidth: 1200,
                            heroTag: 'plan-cover-${plan.tripId}',
                          );
                        },
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66000000),
                              Color(0x00000000),
                              Color(0x99000000),
                            ],
                            stops: [0, 0.4, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        bottom: AppSpacing.lg,
                        child: Text(
                          plan.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plan.destination != null &&
                          plan.destination!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                plan.destination!,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      if (plan.durationDays != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${plan.durationDays} day${plan.durationDays == 1 ? '' : 's'}'
                          '${formatDateRange(plan.startDate, plan.endDate).isEmpty ? '' : ' · ${formatDateRange(plan.startDate, plan.endDate)}'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          _Counter(
                            icon: Icons.favorite_rounded,
                            label: '${plan.likeCount}',
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          _Counter(
                            icon: Icons.bookmark_rounded,
                            label: '${plan.saveCount}',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          _Counter(
                            icon: Icons.visibility_outlined,
                            label: '${plan.viewCount}',
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          _Counter(
                            icon: Icons.content_copy_rounded,
                            label: '${plan.cloneCount}',
                            color: AppColors.travelAccent,
                          ),
                        ],
                      ),
                      if (plan.estimatedBudget != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text('Budget estimate', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        AppCurrencyText(
                          plan.estimatedBudget!,
                          currency: plan.currency,
                          fontSize: 24,
                          color: AppColors.primaryDark,
                        ),
                      ],
                      if (plan.description != null &&
                          plan.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text('Overview', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(plan.description!, style: theme.textTheme.bodyLarge),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      InkWell(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        onTap: () => context.push(
                          '/explore/creators/${plan.creatorId}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              AppAvatar(
                                url: plan.creatorAvatar,
                                name: plan.creatorDisplayName,
                                size: 48,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Created by',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Text(
                                      plan.creatorDisplayName ?? 'Traveler',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Itinerary', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      if (byDay.isEmpty)
                        Text(
                          'No itinerary shared for this plan.',
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        ...byDay.entries.map((entry) {
                          final dayLabel =
                              DateFormat('EEE, MMM d').format(entry.key);
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dayLabel,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ...entry.value.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title ??
                                                    item.locationName ??
                                                    'Stop',
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                              if (item.locationName != null &&
                                                  item.title != null)
                                                Text(
                                                  item.locationName!,
                                                  style: theme
                                                      .textTheme.bodySmall,
                                                ),
                                              if (item.description != null &&
                                                  item.description!.isNotEmpty)
                                                Text(
                                                  item.description!,
                                                  style: theme
                                                      .textTheme.bodyMedium,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      if (detail.photoPaths.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Photos', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: detail.photoPaths.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final path = detail.photoPaths[index];
                              final urlAsync =
                                  ref.watch(signedStorageUrlProvider(path));
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                child: SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: urlAsync.when(
                                    loading: () =>
                                        const AppSkeleton(height: 120),
                                    error: (_, _) => Container(
                                      color: AppColors.surfaceMuted,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                                    data: (url) => AppImage(
                                      url: url,
                                      width: 120,
                                      height: 120,
                                      borderRadius: BorderRadius.zero,
                                      memCacheWidth: 360,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: detailAsync.maybeWhen(
        data: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: AppButton(
              label: 'Use This Plan',
              icon: Icons.content_copy_rounded,
              isLoading: _cloning,
              onPressed: _cloning ? null : _clonePlan,
            ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}
