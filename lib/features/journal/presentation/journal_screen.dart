import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/storage/signed_url_service.dart';
import '../data/journal_repository.dart';
import '../domain/journal_entry.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(journalEntriesProvider(tripId));
    final summaryAsync = ref.watch(journalSummaryProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          IconButton(
            tooltip: 'New memory',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/trips/$tripId/journal/create'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/trips/$tripId/journal/create'),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(journalEntriesProvider(tripId));
          ref.invalidate(journalSummaryProvider(tripId));
        },
        child: entriesAsync.when(
          loading: () => const AppLoading(message: 'Loading memories…'),
          error: (error, _) => AppErrorState(
            error: error,
            onRetry: () => ref.invalidate(journalEntriesProvider(tripId)),
          ),
          data: (entries) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.sm,
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                    ),
                    child: summaryAsync.when(
                      loading: () => const AppSkeleton(height: 88),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (summary) => _SummaryBar(summary: summary),
                    ),
                  ),
                ),
                if (entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      title: 'No memories yet',
                      message: 'Capture places and moments from this trip.',
                      icon: Icons.photo_album_outlined,
                      actionLabel: 'Add memory',
                      onAction: () =>
                          context.push('/trips/$tripId/journal/create'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      0,
                      AppSpacing.screenPadding,
                      88,
                    ),
                    sliver: SliverList.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _JournalTimelineCard(
                          tripId: tripId,
                          entry: entry,
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary});

  final JournalSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          _SummaryStat(
            label: '📸 memories',
            value: '${summary.memoryCount}',
          ),
          _SummaryStat(
            label: 'places',
            value: '${summary.placeCount}',
          ),
          _SummaryStat(
            label: 'days',
            value: '${summary.dayCount}',
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _JournalTimelineCard extends ConsumerWidget {
  const _JournalTimelineCard({
    required this.tripId,
    required this.entry,
  });

  final String tripId;
  final JournalEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPhoto = entry.photos.isNotEmpty ? entry.photos.first : null;

    return AppCard(
      onTap: () => context.push('/trips/$tripId/journal/${entry.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (firstPhoto != null)
            ref.watch(signedStorageUrlProvider(firstPhoto.storagePath)).when(
              loading: () => const AppSkeleton(height: 180),
              error: (_, _) => const AppSkeleton(height: 180),
              data: (url) => AppImage(
                url: url,
                cacheKey: firstPhoto.storagePath,
                height: 180,
                width: double.infinity,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusMd),
                ),
                heroTag: 'journal-photo-${firstPhoto.id}',
                memCacheWidth: 800,
              ),
            )
          else
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: Icon(
                Icons.landscape_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title?.isNotEmpty == true
                      ? entry.title!
                      : (entry.locationName ?? 'Memory'),
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    if (entry.locationName != null && entry.locationName!.isNotEmpty)
                      entry.locationName!,
                    formatDate(entry.visitedAt),
                    if (entry.photos.isNotEmpty) '${entry.photos.length} photos',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (entry.description != null && entry.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    entry.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
