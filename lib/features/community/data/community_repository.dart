import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/signed_url_service.dart';
import '../../../core/utils/supabase_provider.dart';
import '../domain/public_trip_plan.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(signedUrlCacheProvider),
  );
});

final publicPlansProvider = FutureProvider.autoDispose
    .family<List<PublicTripPlan>, ({String? destination, String? tripType, String sort})>(
  (ref, q) async {
    ref.keepAlive();
    return ref.watch(communityRepositoryProvider).listPlans(
          destination: q.destination,
          tripType: q.tripType,
          sort: q.sort,
        );
  },
);

final popularDestinationsProvider =
    FutureProvider.autoDispose<List<({String destination, int planCount})>>((ref) async {
  return ref.watch(communityRepositoryProvider).popularDestinations();
});

final publicPlanDetailProvider =
    FutureProvider.autoDispose.family<PublicPlanDetail, String>((ref, tripId) async {
  return ref.watch(communityRepositoryProvider).getPlan(tripId);
});

final savedPlansProvider = FutureProvider.autoDispose<List<PublicTripPlan>>((ref) async {
  return ref.watch(communityRepositoryProvider).listSaved();
});

final creatorProfileProvider =
    FutureProvider.autoDispose.family<CreatorProfile, String>((ref, userId) async {
  return ref.watch(communityRepositoryProvider).getCreator(userId);
});

class CommunityRepository {
  CommunityRepository(this._client, this._urlCache);

  final SupabaseClient _client;
  final SignedUrlCache _urlCache;

  List<PublicTripPlan> _parseList(dynamic result) {
    final list = result as List<dynamic>? ?? [];
    return list
        .map((e) => PublicTripPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PublicTripPlan>> listPlans({
    String? destination,
    String? tripType,
    String sort = 'popular',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'list_public_trip_plans',
        params: {
          'p_destination': destination,
          'p_trip_type': tripType,
          'p_sort': sort,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return _parseList(result);
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<PublicPlanDetail> getPlan(String tripId) async {
    try {
      final result =
          await _client.rpc('get_public_trip_plan', params: {'p_trip_id': tripId});
      return PublicPlanDetail.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<void> publish({
    required String tripId,
    String? tripType,
    int? estimatedBudget,
    List<String> photoPaths = const [],
  }) async {
    try {
      await _client.rpc(
        'publish_trip_plan',
        params: {
          'p_trip_id': tripId,
          'p_trip_type': tripType,
          'p_estimated_budget': estimatedBudget,
          'p_photo_paths': photoPaths,
        },
      );
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<void> unpublish(String tripId) async {
    try {
      await _client.rpc('unpublish_trip_plan', params: {'p_trip_id': tripId});
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<bool> toggleLike(String tripId) async {
    final result =
        await _client.rpc('toggle_trip_plan_like', params: {'p_trip_id': tripId});
    return (result as Map)['liked'] as bool? ?? false;
  }

  Future<bool> toggleSave(String tripId) async {
    final result =
        await _client.rpc('toggle_trip_plan_save', params: {'p_trip_id': tripId});
    return (result as Map)['saved'] as bool? ?? false;
  }

  Future<void> recordView(String tripId) async {
    try {
      await _client.rpc('record_plan_view', params: {'p_trip_id': tripId});
    } catch (_) {}
  }

  Future<List<PublicTripPlan>> listSaved({int limit = 20, int offset = 0}) async {
    final result = await _client.rpc(
      'list_saved_trip_plans',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    return _parseList(result);
  }

  Future<String> clonePlan(String tripId) async {
    try {
      final id = await _client.rpc('clone_trip_plan', params: {'p_trip_id': tripId});
      return id as String;
    } catch (e) {
      throw AppException(mapErrorToMessage(e));
    }
  }

  Future<CreatorProfile> getCreator(String userId) async {
    final result = await _client.rpc(
      'get_creator_public_profile',
      params: {'p_user_id': userId},
    );
    return CreatorProfile.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<List<({String destination, int planCount})>> popularDestinations() async {
    final result = await _client.rpc('list_popular_destinations', params: {'p_limit': 8});
    final list = result as List<dynamic>? ?? [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return (
        destination: m['destination'] as String,
        planCount: (m['plan_count'] as num).toInt(),
      );
    }).toList();
  }

  Future<String?> signedPlanPhotoUrl(String? path) async {
    return _urlCache.getSignedUrl(path);
  }
}
