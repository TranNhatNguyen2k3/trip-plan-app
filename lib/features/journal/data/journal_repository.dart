import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/supabase_provider.dart';
import '../domain/journal_entry.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(ref.watch(supabaseClientProvider));
});

final journalEntriesProvider =
    FutureProvider.autoDispose.family<List<JournalEntry>, String>((ref, tripId) async {
  return ref.watch(journalRepositoryProvider).listEntries(tripId);
});

final journalEntryProvider =
    FutureProvider.autoDispose.family<JournalEntry, String>((ref, entryId) async {
  return ref.watch(journalRepositoryProvider).getEntry(entryId);
});

final journalSummaryProvider =
    FutureProvider.autoDispose.family<JournalSummary, String>((ref, tripId) async {
  return ref.watch(journalRepositoryProvider).getSummary(tripId);
});

enum PhotoUploadStatus { waiting, uploading, done, failed }

class PhotoUploadItem {
  PhotoUploadItem({
    required this.localPath,
    required this.status,
    this.error,
  });

  final String localPath;
  PhotoUploadStatus status;
  String? error;
}

class JournalRepository {
  JournalRepository(this._client);

  final SupabaseClient _client;
  final _uuid = const Uuid();

  Future<List<JournalEntry>> listEntries(String tripId, {int page = 0}) async {
    final from = page * AppConstants.pageSize;
    final to = from + AppConstants.pageSize - 1;
    final rows = await _client
        .from('journal_entries')
        .select('*, journal_photos(*), profiles(display_name)')
        .eq('trip_id', tripId)
        .order('visited_at', ascending: false)
        .range(from, to);
    return (rows as List)
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JournalEntry> getEntry(String entryId) async {
    final row = await _client
        .from('journal_entries')
        .select('*, journal_photos(*), profiles(display_name)')
        .eq('id', entryId)
        .single();
    return JournalEntry.fromJson(row);
  }

  Future<JournalSummary> getSummary(String tripId) async {
    final result = await _client.rpc('get_journal_summary', params: {'p_trip_id': tripId});
    if (result is List && result.isNotEmpty) {
      return JournalSummary.fromJson(result.first as Map<String, dynamic>);
    }
    if (result is Map<String, dynamic>) {
      return JournalSummary.fromJson(result);
    }
    return const JournalSummary(memoryCount: 0, placeCount: 0, dayCount: 0);
  }

  Future<JournalEntry> createEntry({
    required String tripId,
    String? title,
    String? locationName,
    double? latitude,
    double? longitude,
    String? description,
    required DateTime visitedAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AppAuthException('Please sign in.');

    final row = await _client
        .from('journal_entries')
        .insert({
          'trip_id': tripId,
          'title': title,
          'location_name': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'description': description,
          'visited_at': visitedAt.toIso8601String(),
          'created_by': userId,
        })
        .select('*, journal_photos(*), profiles(display_name)')
        .single();
    return JournalEntry.fromJson(row);
  }

  Future<JournalEntry> updateEntry({
    required String entryId,
    String? title,
    String? locationName,
    double? latitude,
    double? longitude,
    String? description,
    required DateTime visitedAt,
  }) async {
    final row = await _client
        .from('journal_entries')
        .update({
          'title': title,
          'location_name': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'description': description,
          'visited_at': visitedAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', entryId)
        .select('*, journal_photos(*), profiles(display_name)')
        .single();
    return JournalEntry.fromJson(row);
  }

  Future<Uint8List> compressImage(String path) async {
    final result = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: AppConstants.imageMaxDimension,
      minHeight: AppConstants.imageMaxDimension,
      quality: AppConstants.imageJpegQuality,
      format: CompressFormat.jpeg,
    );
    if (result == null) throw const AppException('Unable to compress image.');
    if (result.lengthInBytes > AppConstants.imageMaxBytes) {
      throw const ValidationException('Image is still too large after compression.');
    }
    return result;
  }

  Future<JournalPhoto> uploadPhoto({
    required String tripId,
    required String entryId,
    required String localPath,
    required int displayOrder,
  }) async {
    final bytes = await compressImage(localPath);
    final photoId = _uuid.v4();
    final path = journalPhotoPath(tripId: tripId, entryId: entryId, photoId: photoId);

    await _client.storage.from(AppConstants.storageBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );

    final row = await _client
        .from('journal_photos')
        .insert({
          'journal_entry_id': entryId,
          'storage_path': path,
          'display_order': displayOrder,
        })
        .select()
        .single();
    return JournalPhoto.fromJson(row);
  }

  /// Uploads with max 2 concurrent. Updates [items] statuses in place.
  Future<void> uploadPhotos({
    required String tripId,
    required String entryId,
    required List<PhotoUploadItem> items,
    void Function()? onProgress,
  }) async {
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= items.length) return;
        final item = items[index];
        item.status = PhotoUploadStatus.uploading;
        onProgress?.call();
        try {
          await uploadPhoto(
            tripId: tripId,
            entryId: entryId,
            localPath: item.localPath,
            displayOrder: index,
          );
          item.status = PhotoUploadStatus.done;
        } catch (e) {
          item.status = PhotoUploadStatus.failed;
          item.error = mapErrorToMessage(e);
        }
        onProgress?.call();
      }
    }

    final workers = List.generate(
      AppConstants.maxConcurrentUploads.clamp(1, items.length),
      (_) => worker(),
    );
    await Future.wait(workers);
  }

  Future<void> deleteEntry(String entryId) async {
    final entry = await getEntry(entryId);
    final paths = entry.photos.map((p) => p.storagePath).toList();
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(AppConstants.storageBucket).remove(paths);
      } catch (e) {
        throw AppException(
          'Unable to delete photos from storage. Memory was not deleted.',
        );
      }
    }
    await _client.from('journal_entries').delete().eq('id', entryId);
  }

  Future<String?> signedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    return _client.storage
        .from(AppConstants.storageBucket)
        .createSignedUrl(path, 60 * 60);
  }

  Future<Map<String, String>> signedUrls(List<String> paths) async {
    final map = <String, String>{};
    for (final path in paths) {
      final url = await signedUrl(path);
      if (url != null) map[path] = url;
    }
    return map;
  }

  bool fileExists(String path) => File(path).existsSync();
}
