import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../trips/data/trip_repository.dart';
import '../data/journal_repository.dart';
import '../domain/journal_entry.dart';
import '../../../core/storage/signed_url_service.dart';

class JournalDetailScreen extends ConsumerWidget {
  const JournalDetailScreen({
    super.key,
    required this.tripId,
    required this.entryId,
  });

  final String tripId;
  final String entryId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete memory?'),
        content: const Text(
          'Photos and this entry will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(journalRepositoryProvider).deleteEntry(entryId);
      ref.invalidate(journalEntriesProvider(tripId));
      ref.invalidate(journalSummaryProvider(tripId));
      HapticFeedback.lightImpact();
      if (context.mounted) context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    }
  }

  Future<void> _setCover(
    BuildContext context,
    WidgetRef ref,
    JournalPhoto photo,
  ) async {
    try {
      await ref.read(tripRepositoryProvider).setCoverPhoto(
            tripId,
            photo.storagePath,
          );
      ref.invalidate(tripProvider(tripId));
      HapticFeedback.lightImpact();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover photo updated')),
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
    final entryAsync = ref.watch(journalEntryProvider(entryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/trips/$tripId/journal/$entryId/edit'),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: entryAsync.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () => ref.invalidate(journalEntryProvider(entryId)),
        ),
        data: (entry) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              if (entry.photos.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entry.photos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final photo = entry.photos[index];
                      return _JournalDetailPhotoThumb(
                        tripId: tripId,
                        entryId: entryId,
                        photo: photo,
                        index: index,
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.photo_outlined, size: 48),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                entry.title?.isNotEmpty == true
                    ? entry.title!
                    : (entry.locationName ?? 'Memory'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                [
                  if (entry.locationName != null &&
                      entry.locationName!.isNotEmpty)
                    entry.locationName!,
                  formatDate(entry.visitedAt),
                  if (entry.authorName != null) entry.authorName!,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (entry.description != null &&
                  entry.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  entry.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (entry.photos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Set as trip cover',
                  icon: Icons.image_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _setCover(context, ref, entry.photos.first),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.tertiary,
                onPressed: () =>
                    context.push('/trips/$tripId/journal/$entryId/edit'),
              ),
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.destructive,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JournalDetailPhotoThumb extends ConsumerWidget {
  const _JournalDetailPhotoThumb({
    required this.tripId,
    required this.entryId,
    required this.photo,
    required this.index,
  });

  final String tripId;
  final String entryId;
  final JournalPhoto photo;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(signedStorageUrlProvider(photo.storagePath));
    return urlAsync.when(
      loading: () => const SizedBox(
        width: 280,
        height: 240,
        child: AppLoading(),
      ),
      error: (_, _) => SizedBox(
        width: 280,
        height: 240,
        child: AppImage(url: null, height: 240, width: 280),
      ),
      data: (url) => GestureDetector(
        onTap: () => context.push(
          '/trips/$tripId/journal/$entryId/photos?i=$index',
        ),
        child: SizedBox(
          width: 280,
          child: AppImage(
            url: url,
            cacheKey: photo.storagePath,
            height: 240,
            width: 280,
            heroTag: 'journal-photo-${photo.id}',
            memCacheWidth: 800,
          ),
        ),
      ),
    );
  }
}
