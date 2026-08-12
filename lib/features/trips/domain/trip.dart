class Trip {
  const Trip({
    required this.id,
    required this.name,
    this.description,
    this.destination,
    this.startDate,
    this.endDate,
    required this.currency,
    this.coverPhotoPath,
    this.budgetAmount,
    this.visibility = 'private',
    this.tripType,
    this.estimatedBudget,
    this.publishedAt,
    this.clonedFromTripId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String currency;
  final String? coverPhotoPath;
  final int? budgetAmount;
  final String visibility;
  final String? tripType;
  final int? estimatedBudget;
  final DateTime? publishedAt;
  final String? clonedFromTripId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublic => visibility == 'public';

  factory Trip.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.parse(v as String);
    }

    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      destination: json['destination'] as String?,
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      currency: json['currency'] as String? ?? 'VND',
      coverPhotoPath: json['cover_photo_path'] as String?,
      budgetAmount: (json['budget_amount'] as num?)?.toInt(),
      visibility: json['visibility'] as String? ?? 'private',
      tripType: json['trip_type'] as String?,
      estimatedBudget: (json['estimated_budget'] as num?)?.toInt(),
      publishedAt: parseDate(json['published_at']),
      clonedFromTripId: json['cloned_from_trip_id'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'destination': destination,
        'start_date': startDate?.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'currency': currency,
        'cover_photo_path': coverPhotoPath,
        'budget_amount': budgetAmount,
        'created_by': createdBy,
      };

  Trip copyWith({
    String? name,
    String? description,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    String? coverPhotoPath,
    int? budgetAmount,
    bool clearBudget = false,
    String? visibility,
    String? tripType,
    int? estimatedBudget,
    String? clonedFromTripId,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currency: currency ?? this.currency,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      budgetAmount: clearBudget ? null : (budgetAmount ?? this.budgetAmount),
      visibility: visibility ?? this.visibility,
      tripType: tripType ?? this.tripType,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      publishedAt: publishedAt,
      clonedFromTripId: clonedFromTripId ?? this.clonedFromTripId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

enum TripMemberRole { owner, member }

class TripMember {
  const TripMember({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.profile,
  });

  final String id;
  final String tripId;
  final String userId;
  final TripMemberRole role;
  final DateTime joinedAt;
  final ProfileLite? profile;

  factory TripMember.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'member';
    return TripMember(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      userId: json['user_id'] as String,
      role: roleStr == 'owner' ? TripMemberRole.owner : TripMemberRole.member,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      profile: json['profiles'] != null
          ? ProfileLite.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ProfileLite {
  const ProfileLite({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  factory ProfileLite.fromJson(Map<String, dynamic> json) {
    return ProfileLite(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Traveler',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class TripInvitation {
  const TripInvitation({
    required this.id,
    required this.tripId,
    required this.token,
    required this.invitedBy,
    this.expiresAt,
    this.acceptedAt,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String token;
  final String invitedBy;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  factory TripInvitation.fromJson(Map<String, dynamic> json) {
    return TripInvitation(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      token: json['token'] as String,
      invitedBy: json['invited_by'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
