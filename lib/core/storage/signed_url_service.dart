import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/trips/data/trip_repository.dart';
import '../constants/app_constants.dart';
import '../utils/supabase_provider.dart';

/// Cached signed URLs for private storage paths (TTL ~50 min for 1h Supabase tokens).
class SignedUrlCache {
  SignedUrlCache(this._client);

  final SupabaseClient _client;
  final _cache = <String, _CachedUrl>{};
  final _inFlight = <String, Future<String?>>{};

  static const _ttl = Duration(minutes: 50);

  Future<String?> getSignedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;

    final cached = _cache[path];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.url;
    }

    final pending = _inFlight[path];
    if (pending != null) return pending;

    final future = _fetch(path);
    _inFlight[path] = future;
    try {
      final url = await future;
      if (url != null) {
        _cache[path] = _CachedUrl(url, DateTime.now().add(_ttl));
      }
      return url;
    } finally {
      _inFlight.remove(path);
    }
  }

  Future<String?> _fetch(String path) async {
    try {
      return await _client.storage
          .from(AppConstants.storageBucket)
          .createSignedUrl(path, 60 * 60);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> signPaths(List<String> paths) async {
    final unique = paths.where((p) => p.isNotEmpty).toSet();
    final entries = await Future.wait(
      unique.map((p) async {
        final url = await getSignedUrl(p);
        return (p, url);
      }),
    );
    return {
      for (final e in entries)
        if (e.$2 != null) e.$1: e.$2!,
    };
  }
}

class _CachedUrl {
  _CachedUrl(this.url, this.expiresAt);

  final String url;
  final DateTime expiresAt;
}

final signedUrlCacheProvider = Provider<SignedUrlCache>((ref) {
  return SignedUrlCache(ref.watch(supabaseClientProvider));
});

/// Shared signed URL provider for storage paths (trip-journal bucket).
final signedStorageUrlProvider =
    FutureProvider.autoDispose.family<String?, String?>((ref, path) async {
  if (path == null || path.isEmpty) return null;
  return ref.watch(signedUrlCacheProvider).getSignedUrl(path);
});

/// Prefetch cover URLs after trips load (batch, cached).
final homeTripCoverUrlsProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final trips = await ref.watch(tripsProvider.future);
  final paths = trips
      .map((t) => t.coverPhotoPath)
      .whereType<String>()
      .where((p) => p.isNotEmpty)
      .toList();
  return ref.watch(signedUrlCacheProvider).signPaths(paths);
});
