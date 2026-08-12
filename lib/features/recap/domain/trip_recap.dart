import '../../journal/domain/journal_entry.dart';
import '../../statistics/domain/trip_statistics.dart';
import '../../trips/domain/trip.dart';

enum RecapSlideType { cover, dayPhotos, stats, finale }

class RecapSlide {
  const RecapSlide({
    required this.type,
    this.title,
    this.subtitle,
    this.caption,
    this.photoPaths = const [],
    this.stats,
  });

  final RecapSlideType type;
  final String? title;
  final String? subtitle;
  final String? caption;
  final List<String> photoPaths;
  final Map<String, String>? stats;
}

class TripRecap {
  const TripRecap({
    required this.trip,
    required this.slides,
    required this.insights,
  });

  final Trip trip;
  final List<RecapSlide> slides;
  final Map<String, String> insights;
}

List<String> selectPhotosForRecap(List<JournalPhoto> photos, {int max = 5}) {
  final sorted = [...photos]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return sorted.take(max).map((p) => p.storagePath).toList();
}

List<JournalEntry> orderEntriesForRecap(List<JournalEntry> entries) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final c = a.visitedAt.compareTo(b.visitedAt);
    if (c != 0) return c;
    return a.createdAt.compareTo(b.createdAt);
  });
  return sorted;
}

TripRecap buildTripRecap({
  required Trip trip,
  required List<JournalEntry> entries,
  required TripStatistics? stats,
  required int memberCount,
}) {
  final ordered = orderEntriesForRecap(entries);
  final slides = <RecapSlide>[];
  final places = ordered
      .map((e) => e.locationName)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet();
  final photoCount = ordered.fold<int>(0, (s, e) => s + e.photos.length);
  final days = <String>{};
  for (final e in ordered) {
    days.add('${e.visitedAt.year}-${e.visitedAt.month}-${e.visitedAt.day}');
  }

  slides.add(
    RecapSlide(
      type: RecapSlideType.cover,
      title: trip.name,
      subtitle: [
        if (trip.destination != null) trip.destination!,
        if (trip.startDate != null && trip.endDate != null)
          '${trip.startDate!.month}/${trip.startDate!.day} – ${trip.endDate!.month}/${trip.endDate!.day}',
      ].join('\n'),
      photoPaths: trip.coverPhotoPath != null
          ? [trip.coverPhotoPath!]
          : (ordered.isNotEmpty ? selectPhotosForRecap(ordered.first.photos, max: 1) : const []),
    ),
  );

  String? lastDayKey;
  for (final entry in ordered) {
    final dayKey = '${entry.visitedAt.year}-${entry.visitedAt.month}-${entry.visitedAt.day}';
    final photos = selectPhotosForRecap(entry.photos);
    if (photos.isEmpty && (entry.description == null || entry.description!.isEmpty)) {
      continue;
    }
    slides.add(
      RecapSlide(
        type: RecapSlideType.dayPhotos,
        title: lastDayKey != dayKey ? 'Day ${days.toList().indexOf(dayKey) + 1}' : null,
        subtitle: entry.title ?? entry.locationName,
        caption: entry.description,
        photoPaths: photos,
      ),
    );
    lastDayKey = dayKey;
  }

  final insights = <String, String>{
    'days': '${days.isEmpty ? 1 : days.length}',
    'friends': '$memberCount',
    'places': '${places.length}',
    'memories': '${ordered.length}',
    'photos': '$photoCount',
    if (stats != null) 'spent': '${stats.totalSpent}',
  };

  if (stats != null && stats.byCategory.isNotEmpty) {
    final top = stats.byCategory.first;
    insights['largest_category'] = top.category;
  }

  slides.add(
    RecapSlide(
      type: RecapSlideType.stats,
      title: 'Trip Stats',
      stats: {
        '📸 ${insights['memories']} memories': '',
        '📍 ${insights['places']} places': '',
        '👥 ${insights['friends']} friends': '',
        if (stats != null) '💰 spent': '${stats.totalSpent}',
      },
    ),
  );

  slides.add(
    const RecapSlide(
      type: RecapSlideType.finale,
      title: 'Until next adventure',
      caption: 'Thanks for traveling together.',
    ),
  );

  return TripRecap(trip: trip, slides: slides, insights: insights);
}
