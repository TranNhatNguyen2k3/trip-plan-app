class TripMapPoint {
  const TripMapPoint({
    required this.id,
    this.title,
    this.locationName,
    required this.latitude,
    required this.longitude,
    required this.visitedAt,
    required this.createdAt,
    this.photoPath,
  });

  final String id;
  final String? title;
  final String? locationName;
  final double latitude;
  final double longitude;
  final DateTime visitedAt;
  final DateTime createdAt;
  final String? photoPath;

  String get displayTitle =>
      (title != null && title!.isNotEmpty)
          ? title!
          : (locationName != null && locationName!.isNotEmpty)
              ? locationName!
              : 'Memory';

  factory TripMapPoint.fromJson(Map<String, dynamic> json) {
    return TripMapPoint(
      id: json['id'] as String,
      title: json['title'] as String?,
      locationName: json['location_name'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      visitedAt: DateTime.parse(json['visited_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      photoPath: json['photo_path'] as String?,
    );
  }

  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}

/// Cluster nearby points by rounding to [precision] decimal places.
List<List<TripMapPoint>> clusterMapPoints(
  List<TripMapPoint> points, {
  double precision = 0.01,
}) {
  final map = <String, List<TripMapPoint>>{};
  for (final p in points) {
    final key =
        '${(p.latitude / precision).round()}_${(p.longitude / precision).round()}';
    map.putIfAbsent(key, () => []).add(p);
  }
  return map.values.toList();
}

List<TripMapPoint> sortJourney(List<TripMapPoint> points) {
  final sorted = [...points];
  sorted.sort((a, b) {
    final c = a.visitedAt.compareTo(b.visitedAt);
    if (c != 0) return c;
    return a.createdAt.compareTo(b.createdAt);
  });
  return sorted;
}
