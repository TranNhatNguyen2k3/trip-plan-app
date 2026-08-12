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
import '../domain/trip_recap.dart';

final tripRecapProvider =
    FutureProvider.autoDispose.family<TripRecap, String>((ref, tripId) async {
  final trip = await ref.watch(tripProvider(tripId).future);
  final entries = await ref.watch(journalEntriesProvider(tripId).future);
  final members = await ref.watch(tripMembersProvider(tripId).future);
  TripStatistics? stats;
  try {
    stats = await ref.watch(tripStatisticsProvider(tripId).future);
  } catch (_) {}
  return buildTripRecap(
    trip: trip,
    entries: entries,
    stats: stats,
    memberCount: members.length,
  );
});

class TripRecapScreen extends ConsumerStatefulWidget {
  const TripRecapScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripRecapScreen> createState() => _TripRecapScreenState();
}

class _TripRecapScreenState extends ConsumerState<TripRecapScreen> {
  int _index = 0;
  bool _paused = false;
  Timer? _timer;
  final _urls = <String, String>{};

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _armTimer(int slideCount) {
    _timer?.cancel();
    if (_paused || slideCount == 0) return;
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _paused) return;
      if (_index < slideCount - 1) {
        setState(() => _index++);
        _armTimer(slideCount);
      }
    });
  }

  Future<void> _ensureUrls(List<String> paths) async {
    final repo = ref.read(journalRepositoryProvider);
    for (final path in paths) {
      if (_urls.containsKey(path)) continue;
      final url = await repo.signedUrl(path);
      if (url != null) _urls[path] = url;
    }
    if (mounted) setState(() {});
  }

  Future<void> _share(TripRecap recap) async {
    final i = recap.insights;
    await SharePlus.instance.share(
      ShareParams(
        text: [
          '${recap.trip.name} — Trip Recap',
          '${i['days']} days · ${i['friends']} friends · ${i['memories']} memories',
          if (i['places'] != null) '${i['places']} places',
          'Shared from TripMate',
        ].join('\n'),
      ),
    );
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripRecapProvider(widget.tripId));

    return async.when(
      loading: () => const Scaffold(body: AppLoading(message: 'Creating recap…')),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          error: e,
          onRetry: () => ref.invalidate(tripRecapProvider(widget.tripId)),
        ),
      ),
      data: (recap) {
        if (recap.slides.length <= 2 &&
            recap.insights['memories'] == '0') {
          return Scaffold(
            appBar: AppBar(title: const Text('Trip Recap')),
            body: const AppEmptyState(
              title: 'Your story is still being written',
              message: 'Add some memories first.',
              icon: Icons.movie_filter_outlined,
            ),
          );
        }

        final slides = recap.slides;
        final slide = slides[_index.clamp(0, slides.length - 1)];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureUrls(slide.photoPaths);
          _armTimer(slides.length);
        });

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTapUp: (d) {
              final w = MediaQuery.sizeOf(context).width;
              if (d.localPosition.dx < w / 3) {
                setState(() => _index = (_index - 1).clamp(0, slides.length - 1));
              } else {
                setState(() => _index = (_index + 1).clamp(0, slides.length - 1));
              }
              _armTimer(slides.length);
            },
            onLongPressStart: (_) {
              setState(() => _paused = true);
              _timer?.cancel();
            },
            onLongPressEnd: (_) {
              setState(() => _paused = false);
              _armTimer(slides.length);
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -200) {
                setState(() => _index = (_index + 1).clamp(0, slides.length - 1));
                _armTimer(slides.length);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _SlideView(
                    key: ValueKey(_index),
                    slide: slide,
                    urls: _urls,
                    currency: recap.trip.currency,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < slides.length; i++)
                              Expanded(
                                child: Container(
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: i <= _index
                                        ? Colors.white
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _share(recap),
                              icon: const Icon(Icons.ios_share, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    super.key,
    required this.slide,
    required this.urls,
    required this.currency,
  });

  final RecapSlide slide;
  final Map<String, String> urls;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final photoUrl =
        slide.photoPaths.isNotEmpty ? urls[slide.photoPaths.first] : null;

    return Container(
      key: key,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photoUrl != null)
            AnimatedScale(
              scale: 1.05,
              duration: const Duration(milliseconds: 450),
              child: AppImage(
                url: photoUrl,
                borderRadius: BorderRadius.zero,
                memCacheWidth: 1200,
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                if (slide.title != null)
                  Text(
                    slide.title!,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 36,
                        ),
                  ),
                if (slide.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    slide.subtitle!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
                if (slide.caption != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    slide.caption!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
                if (slide.stats != null) ...[
                  const SizedBox(height: 16),
                  for (final e in slide.stats!.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        e.value.isEmpty
                            ? e.key
                            : '${e.key}: ${e.key.contains('spent') ? formatCurrency(int.tryParse(e.value) ?? 0, currency: currency) : e.value}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                      ),
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
