import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_loading.dart';
import '../../journal/data/journal_repository.dart';
import '../../statistics/data/statistics_repository.dart';
import '../../statistics/domain/trip_statistics.dart';
import '../../trips/data/trip_repository.dart';
import '../domain/trip_book.dart';

class TripBookScreen extends ConsumerStatefulWidget {
  const TripBookScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripBookScreen> createState() => _TripBookScreenState();
}

class _TripBookScreenState extends ConsumerState<TripBookScreen> {
  var _privacy = const TripBookPrivacy();
  int _page = 0;
  final _urls = <String, String>{};
  final _controller = PageController();
  Object? _urlsLoadedForBook;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUrls(TripBook book) async {
    final repo = ref.read(journalRepositoryProvider);
    for (final page in book.pages) {
      for (final path in page.photoPaths) {
        if (_urls.containsKey(path)) continue;
        final url = await repo.signedUrl(path);
        if (url != null) _urls[path] = url;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _share(String tripName) async {
    final result = await showDialog<TripBookPrivacy>(
      context: context,
      builder: (ctx) {
        var spending = _privacy.includeSpending;
        var names = _privacy.includeMemberNames;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Share Trip Book'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Include spending summary'),
                  value: spending,
                  onChanged: (v) => setD(() => spending = v),
                ),
                SwitchListTile(
                  title: const Text('Include member names'),
                  value: names,
                  onChanged: (v) => setD(() => names = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  TripBookPrivacy(
                    includeSpending: spending,
                    includeMemberNames: names,
                  ),
                ),
                child: const Text('Share'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    setState(() => _privacy = result);

    final trip = await ref.read(tripProvider(widget.tripId).future);
    final entries = await ref.read(journalEntriesProvider(widget.tripId).future);
    final members = await ref.read(tripMembersProvider(widget.tripId).future);
    TripStatistics? stats;
    try {
      stats = await ref.read(tripStatisticsProvider(widget.tripId).future);
    } catch (_) {}
    final regenerated = generateTripBook(
      trip: trip,
      entries: entries,
      memberNames: members.map((m) => m.profile?.displayName ?? 'Traveler').toList(),
      stats: stats,
      privacy: _privacy,
    );
    await SharePlus.instance.share(
      ShareParams(text: shareableBookText(regenerated, trip.name)),
    );
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final journalAsync = ref.watch(journalEntriesProvider(widget.tripId));
    final membersAsync = ref.watch(tripMembersProvider(widget.tripId));
    final statsAsync = ref.watch(tripStatisticsProvider(widget.tripId));

    if (tripAsync.isLoading || journalAsync.isLoading || membersAsync.isLoading) {
      return const Scaffold(body: AppLoading(message: 'Building book…'));
    }
    if (tripAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          error: tripAsync.error!,
          onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
        ),
      );
    }

    final trip = tripAsync.requireValue;
    final entries = journalAsync.asData?.value ?? [];
    if (entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Book')),
        body: const AppEmptyState(
          title: 'Your trip book is waiting',
          message: 'Add memories to start creating it.',
          icon: Icons.menu_book_outlined,
        ),
      );
    }

    final members = membersAsync.asData?.value ?? [];
    final book = generateTripBook(
      trip: trip,
      entries: entries,
      memberNames: members.map((m) => m.profile?.displayName ?? 'Traveler').toList(),
      stats: statsAsync.asData?.value,
      privacy: _privacy,
    );

    if (_urlsLoadedForBook != book) {
      _urlsLoadedForBook = book;
      unawaited(_loadUrls(book));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Page ${_page + 1} / ${book.pages.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => _share(trip.name),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: book.pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _BookPageView(
                page: book.pages[i],
                urls: _urls,
                currency: trip.currency,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                IconButton(
                  onPressed: _page > 0
                      ? () => _controller.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_page + 1} / ${book.pages.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _page < book.pages.length - 1
                      ? () => _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookPageView extends StatelessWidget {
  const _BookPageView({
    required this.page,
    required this.urls,
    required this.currency,
  });

  final TripBookPage page;
  final Map<String, String> urls;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (page.title != null)
            Text(
              page.title!,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
          if (page.subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              page.subtitle!,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (page.photoPaths.isNotEmpty)
            Expanded(
              child: _PhotosLayout(paths: page.photoPaths, urls: urls),
            ),
          if (page.body != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              page.body!,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
          for (final line in page.statsLines)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                line.startsWith('Total spent:')
                    ? 'Total spent: ${formatCurrency(int.tryParse(line.split(':').last.trim()) ?? 0, currency: currency)}'
                    : line,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotosLayout extends StatelessWidget {
  const _PhotosLayout({required this.paths, required this.urls});

  final List<String> paths;
  final Map<String, String> urls;

  @override
  Widget build(BuildContext context) {
    Widget img(String path) {
      final url = urls[path];
      if (url == null) return const AppSkeleton(height: 180);
      return AppImage(url: url, cacheKey: path, memCacheWidth: 900);
    }

    if (paths.length == 1) return img(paths.first);
    if (paths.length == 2) {
      return Row(
        children: [
          Expanded(child: img(paths[0])),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: img(paths[1])),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: img(paths[0])),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: Row(
            children: [
              Expanded(child: img(paths[1])),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: img(paths.length > 2 ? paths[2] : paths[1])),
            ],
          ),
        ),
      ],
    );
  }
}
