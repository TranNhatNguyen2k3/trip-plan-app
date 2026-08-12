class PublicTripPlan {
  const PublicTripPlan({
    required this.tripId,
    required this.title,
    this.destination,
    this.description,
    this.coverImage,
    this.startDate,
    this.endDate,
    this.durationDays,
    this.tripType,
    this.estimatedBudget,
    this.currency = 'VND',
    this.publishedAt,
    required this.creatorId,
    this.creatorDisplayName,
    this.creatorAvatar,
    this.likeCount = 0,
    this.saveCount = 0,
    this.viewCount = 0,
    this.cloneCount = 0,
    this.placeCount = 0,
    this.memoryCount = 0,
  });

  final String tripId;
  final String title;
  final String? destination;
  final String? description;
  final String? coverImage;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? durationDays;
  final String? tripType;
  final int? estimatedBudget;
  final String currency;
  final DateTime? publishedAt;
  final String creatorId;
  final String? creatorDisplayName;
  final String? creatorAvatar;
  final int likeCount;
  final int saveCount;
  final int viewCount;
  final int cloneCount;
  final int placeCount;
  final int memoryCount;

  factory PublicTripPlan.fromJson(Map<String, dynamic> json) {
    DateTime? d(dynamic v) => v == null ? null : DateTime.tryParse(v as String);
    return PublicTripPlan(
      tripId: json['trip_id'] as String,
      title: json['title'] as String? ?? 'Trip',
      destination: json['destination'] as String?,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      startDate: d(json['start_date']),
      endDate: d(json['end_date']),
      durationDays: (json['duration_days'] as num?)?.toInt(),
      tripType: json['trip_type'] as String?,
      estimatedBudget: (json['estimated_budget'] as num?)?.toInt(),
      currency: json['currency'] as String? ?? 'VND',
      publishedAt: d(json['published_at']),
      creatorId: json['creator_id'] as String,
      creatorDisplayName: json['creator_display_name'] as String?,
      creatorAvatar: json['creator_avatar'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      saveCount: (json['save_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      cloneCount: (json['clone_count'] as num?)?.toInt() ?? 0,
      placeCount: (json['place_count'] as num?)?.toInt() ?? 0,
      memoryCount: (json['memory_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PublicPlanItineraryItem {
  const PublicPlanItineraryItem({
    required this.id,
    this.title,
    this.locationName,
    this.description,
    required this.visitedAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? title;
  final String? locationName;
  final String? description;
  final DateTime visitedAt;
  final double? latitude;
  final double? longitude;

  factory PublicPlanItineraryItem.fromJson(Map<String, dynamic> json) {
    return PublicPlanItineraryItem(
      id: json['id'] as String,
      title: json['title'] as String?,
      locationName: json['location_name'] as String?,
      description: json['description'] as String?,
      visitedAt: DateTime.parse(json['visited_at'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class PublicPlanDetail {
  const PublicPlanDetail({
    required this.plan,
    this.itinerary = const [],
    this.photoPaths = const [],
    this.likedByMe = false,
    this.savedByMe = false,
  });

  final PublicTripPlan plan;
  final List<PublicPlanItineraryItem> itinerary;
  final List<String> photoPaths;
  final bool likedByMe;
  final bool savedByMe;

  factory PublicPlanDetail.fromJson(Map<String, dynamic> json) {
    final photos = (json['photos'] as List<dynamic>? ?? [])
        .map((e) => (e as Map)['storage_path'] as String)
        .toList();
    final itinerary = (json['itinerary'] as List<dynamic>? ?? [])
        .map((e) => PublicPlanItineraryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return PublicPlanDetail(
      plan: PublicTripPlan.fromJson(json),
      itinerary: itinerary,
      photoPaths: photos,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      savedByMe: json['saved_by_me'] as bool? ?? false,
    );
  }
}

class CreatorProfile {
  const CreatorProfile({
    required this.creatorId,
    required this.displayName,
    this.avatarUrl,
    this.publicPlanCount = 0,
    this.totalLikes = 0,
    this.totalClones = 0,
    this.totalViews = 0,
    this.plans = const [],
  });

  final String creatorId;
  final String displayName;
  final String? avatarUrl;
  final int publicPlanCount;
  final int totalLikes;
  final int totalClones;
  final int totalViews;
  final List<PublicTripPlan> plans;

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    return CreatorProfile(
      creatorId: json['creator_id'] as String,
      displayName: json['display_name'] as String? ?? 'Traveler',
      avatarUrl: json['avatar_url'] as String?,
      publicPlanCount: (json['public_plan_count'] as num?)?.toInt() ?? 0,
      totalLikes: (json['total_likes'] as num?)?.toInt() ?? 0,
      totalClones: (json['total_clones'] as num?)?.toInt() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      plans: (json['plans'] as List<dynamic>? ?? [])
          .map((e) => PublicTripPlan.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

/// Popular score for ranking tests / client-side sort helpers.
int popularScore({
  required int likes,
  required int saves,
  required int clones,
  int views = 0,
}) {
  return likes * 2 + saves * 3 + clones * 4 + views;
}

int trendingScore({
  required int likes,
  required int saves,
  required int views,
  required int clones,
}) {
  return likes * 3 + saves * 2 + views + clones * 4;
}

const tripTypeOptions = [
  'weekend',
  'budget',
  'friends',
  'family',
  'couple',
  'adventure',
  'relax',
];
