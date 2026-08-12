class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.tripId,
    this.title,
    this.locationName,
    this.latitude,
    this.longitude,
    this.description,
    required this.visitedAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.photos = const [],
    this.authorName,
  });

  final String id;
  final String tripId;
  final String? title;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? description;
  final DateTime visitedAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<JournalPhoto> photos;
  final String? authorName;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final photos = (json['journal_photos'] as List<dynamic>?)
            ?.map((e) => JournalPhoto.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    photos.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    String? author;
    final creator = json['profiles'];
    if (creator is Map<String, dynamic>) {
      author = creator['display_name'] as String?;
    }
    return JournalEntry(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      title: json['title'] as String?,
      locationName: json['location_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description'] as String?,
      visitedAt: DateTime.parse(json['visited_at'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      photos: photos,
      authorName: author,
    );
  }
}

class JournalPhoto {
  const JournalPhoto({
    required this.id,
    required this.journalEntryId,
    required this.storagePath,
    required this.displayOrder,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String journalEntryId;
  final String storagePath;
  final int displayOrder;
  final String? caption;
  final DateTime createdAt;

  factory JournalPhoto.fromJson(Map<String, dynamic> json) {
    return JournalPhoto(
      id: json['id'] as String,
      journalEntryId: json['journal_entry_id'] as String,
      storagePath: json['storage_path'] as String,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class JournalSummary {
  const JournalSummary({
    required this.memoryCount,
    required this.placeCount,
    required this.dayCount,
  });

  final int memoryCount;
  final int placeCount;
  final int dayCount;

  factory JournalSummary.fromJson(Map<String, dynamic> json) {
    return JournalSummary(
      memoryCount: (json['memory_count'] as num?)?.toInt() ?? 0,
      placeCount: (json['place_count'] as num?)?.toInt() ?? 0,
      dayCount: (json['day_count'] as num?)?.toInt() ?? 0,
    );
  }
}
