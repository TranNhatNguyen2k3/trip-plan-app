import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/trip_repository.dart';
import '../domain/trip.dart';
import 'shell_scaffold.dart';

final _tripCoverUrlProvider =
    FutureProvider.autoDispose.family<String?, String?>((ref, path) {
  return ref.watch(tripRepositoryProvider).createSignedUrl(path);
});

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your trips',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/create'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New trip'),
      ),
      body: tripsAsync.when(
        loading: () => const AppLoading(message: 'Loading trips…'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(tripsProvider),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return AppEmptyState(
              title: 'Ready for an adventure?',
              message: 'Create a trip, invite friends, and start tracking.',
              icon: Icons.explore_outlined,
              actionLabel: 'Create trip',
              onAction: () => context.push('/trips/create'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tripsProvider);
              await ref.read(tripsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                100,
              ),
              itemCount: trips.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
              itemBuilder: (context, index) => _TripCoverCard(trip: trips[index]),
            ),
          );
        },
      ),
    );
  }
}

class _TripCoverCard extends ConsumerWidget {
  const _TripCoverCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverAsync = ref.watch(_tripCoverUrlProvider(trip.coverPhotoPath));
    final dateLabel = formatDateRange(trip.startDate, trip.endDate);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => context.push('/trips/${trip.id}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'trip-cover-${trip.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg),
                  ),
                  child: Stack(
                    children: [
                      coverAsync.when(
                        loading: () => const AppSkeleton(height: 200),
                        error: (_, _) => const TripCoverFallback(height: 200),
                        data: (url) {
                          if (url == null || url.isEmpty) {
                            return const TripCoverFallback(height: 200);
                          }
                          return AppImage(
                            url: url,
                            height: 200,
                            width: double.infinity,
                            borderRadius: BorderRadius.zero,
                            memCacheWidth: 1000,
                          );
                        },
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.overlay.withValues(alpha: 0),
                                AppColors.overlay,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        bottom: AppSpacing.lg,
                        child: Text(
                          trip.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trip.destination != null &&
                        trip.destination!.isNotEmpty)
                      Text(
                        trip.destination!,
                        style: theme.textTheme.bodyLarge,
                      ),
                    if (dateLabel.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(dateLabel, style: theme.textTheme.bodyMedium),
                    ],
                    if (trip.description != null &&
                        trip.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        trip.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
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
