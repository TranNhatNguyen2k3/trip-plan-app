import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/journal_repository.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.tripId,
    required this.entryId,
    this.initialIndex = 0,
  });

  final String tripId;
  final String entryId;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _index;
  Map<String, String> _urls = {};
  bool _loadingUrls = true;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadUrls();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUrls() async {
    try {
      final entry =
          await ref.read(journalRepositoryProvider).getEntry(widget.entryId);
      final paths = entry.photos.map((p) => p.storagePath).toList();
      final urls =
          await ref.read(journalRepositoryProvider).signedUrls(paths);
      if (!mounted) return;
      setState(() {
        _urls = urls;
        _loadingUrls = false;
        if (_index >= entry.photos.length) {
          _index = entry.photos.isEmpty ? 0 : entry.photos.length - 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _urlError = e.toString();
        _loadingUrls = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(journalEntryProvider(widget.entryId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: entryAsync.maybeWhen(
          data: (entry) {
            final total = entry.photos.length;
            if (total == 0) return const Text('Photos');
            return Text('${_index + 1} / $total');
          },
          orElse: () => const Text('Photos'),
        ),
      ),
      body: entryAsync.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () =>
              ref.invalidate(journalEntryProvider(widget.entryId)),
        ),
        data: (entry) {
          if (entry.photos.isEmpty) {
            return const Center(
              child: Text(
                'No photos',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          if (_loadingUrls) {
            return const AppLoading(message: 'Loading photos…');
          }
          if (_urlError != null) {
            return AppErrorState(
              error: _urlError!,
              onRetry: () {
                setState(() {
                  _loadingUrls = true;
                  _urlError = null;
                });
                _loadUrls();
              },
            );
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: entry.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final photo = entry.photos[index];
              final url = _urls[photo.storagePath];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Hero(
                    tag: 'journal-photo-${photo.id}',
                    child: url == null || url.isEmpty
                        ? const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            placeholder: (_, _) => const Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
