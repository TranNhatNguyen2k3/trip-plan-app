import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/domain/journal_entry.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip.dart';
import '../data/community_repository.dart';
import '../domain/public_trip_plan.dart';
import '../../../core/storage/signed_url_service.dart';
import 'plan_card.dart' show tripTypeLabel;

class PublishPlanScreen extends ConsumerStatefulWidget {
  const PublishPlanScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PublishPlanScreen> createState() => _PublishPlanScreenState();
}

class _PublishPlanScreenState extends ConsumerState<PublishPlanScreen> {
  final _budgetController = TextEditingController();
  String? _tripType;
  final Set<String> _selectedPhotos = {};
  bool _seeded = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  void _seedFromTrip(Trip trip) {
    if (_seeded) return;
    setState(() {
      _seeded = true;
      _tripType = trip.tripType;
      if (trip.estimatedBudget != null) {
        _budgetController.text = trip.estimatedBudget.toString();
      } else if (trip.budgetAmount != null) {
        _budgetController.text = trip.budgetAmount.toString();
      }
    });
  }

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = _budgetController.text.replaceAll(RegExp(r'[^\d]'), '');
      final budget = raw.isEmpty ? null : int.tryParse(raw);
      await ref.read(communityRepositoryProvider).publish(
            tripId: widget.tripId,
            tripType: _tripType,
            estimatedBudget: budget,
            photoPaths: _selectedPhotos.toList(),
          );
      HapticFeedback.mediumImpact();
      ref.invalidate(tripProvider(widget.tripId));
      ref.invalidate(publicPlansProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan published to Explore')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mapErrorToMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpublish this plan?'),
        content: const Text(
          'Your plan will leave Explore. Existing likes and saves stay, '
          'and trips already cloned by others are not deleted.',
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
            child: const Text('Unpublish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(communityRepositoryProvider).unpublish(widget.tripId);
      HapticFeedback.lightImpact();
      ref.invalidate(tripProvider(widget.tripId));
      ref.invalidate(publicPlansProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan unpublished')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mapErrorToMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<JournalPhoto> _allPhotos(List<JournalEntry> entries) {
    final photos = <JournalPhoto>[];
    for (final entry in entries) {
      photos.addAll(entry.photos);
    }
    return photos;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final journalAsync = ref.watch(journalEntriesProvider(widget.tripId));

    ref.listen(tripProvider(widget.tripId), (previous, next) {
      next.whenData(_seedFromTrip);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Publish plan',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
      ),
      body: tripAsync.when(
        loading: () => const AppLoading(message: 'Loading trip…'),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
        ),
        data: (trip) {
          final photos = journalAsync.asData?.value == null
              ? const <JournalPhoto>[]
              : _allPhotos(journalAsync.asData!.value);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Text(
                trip.isPublic ? 'Public preview' : 'What becomes public',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Only title, destination, itinerary places, selected photos, '
                'and budget estimate are shared — never expenses or members.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name, style: theme.textTheme.titleLarge),
                    if (trip.destination != null &&
                        trip.destination!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            trip.destination!,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ],
                    if (formatDateRange(trip.startDate, trip.endDate)
                        .isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatDateRange(trip.startDate, trip.endDate),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (trip.description != null &&
                        trip.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        trip.description!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Trip type', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: tripTypeOptions.map((type) {
                  return AppChip(
                    label: tripTypeLabel(type),
                    selected: _tripType == type,
                    onTap: () => setState(() {
                      _tripType = _tripType == type ? null : type;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _budgetController,
                label: 'Estimated budget',
                hint: 'e.g. 2500000',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Photos to publish', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose memories to show on the public plan.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              journalAsync.when(
                loading: () => const AppSkeleton(height: 96),
                error: (_, _) => Text(
                  'Unable to load photos',
                  style: theme.textTheme.bodyMedium,
                ),
                data: (_) {
                  if (photos.isEmpty) {
                    return Text(
                      'No journal photos yet. You can still publish without photos.',
                      style: theme.textTheme.bodyMedium,
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: photos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                    ),
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      final selected =
                          _selectedPhotos.contains(photo.storagePath);
                      final urlAsync =
                          ref.watch(signedStorageUrlProvider(photo.storagePath));
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedPhotos.remove(photo.storagePath);
                            } else {
                              _selectedPhotos.add(photo.storagePath);
                            }
                          });
                        },
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            urlAsync.when(
                              loading: () => const AppSkeleton(height: 96),
                              error: (_, _) => Container(
                                color: AppColors.surfaceMuted,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                              data: (url) => AppImage(
                                url: url,
                                cacheKey: photo.storagePath,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                memCacheWidth: 300,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textOnPrimary,
                                shadows: const [
                                  Shadow(blurRadius: 4, color: Colors.black45),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              if (trip.isPublic) ...[
                AppButton(
                  label: 'Update & republish',
                  icon: Icons.public_rounded,
                  isLoading: _busy,
                  onPressed: _busy ? null : _publish,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Unpublish',
                  variant: AppButtonVariant.destructive,
                  icon: Icons.public_off_rounded,
                  isLoading: _busy,
                  onPressed: _busy ? null : _unpublish,
                ),
              ] else
                AppButton(
                  label: 'Publish to Explore',
                  icon: Icons.public_rounded,
                  isLoading: _busy,
                  onPressed: _busy ? null : _publish,
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}
