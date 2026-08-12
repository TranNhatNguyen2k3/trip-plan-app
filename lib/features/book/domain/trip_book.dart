import '../../journal/domain/journal_entry.dart';
import '../../statistics/domain/trip_statistics.dart';
import '../../trips/domain/trip.dart';

enum BookPageTemplate {
  cover,
  introduction,
  fullImage,
  imageText,
  twoImages,
  threeImages,
  quote,
  statistics,
  finale,
}

class TripBookPage {
  const TripBookPage({
    required this.template,
    this.title,
    this.subtitle,
    this.body,
    this.photoPaths = const [],
    this.statsLines = const [],
  });

  final BookPageTemplate template;
  final String? title;
  final String? subtitle;
  final String? body;
  final List<String> photoPaths;
  final List<String> statsLines;
}

class TripBookPrivacy {
  const TripBookPrivacy({
    this.includeSpending = false,
    this.includeMemberNames = true,
  });

  final bool includeSpending;
  final bool includeMemberNames;
}

class TripBook {
  const TripBook({
    required this.pages,
    required this.privacy,
  });

  final List<TripBookPage> pages;
  final TripBookPrivacy privacy;
}

List<JournalEntry> _ordered(List<JournalEntry> entries) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final c = a.visitedAt.compareTo(b.visitedAt);
    if (c != 0) return c;
    return a.createdAt.compareTo(b.createdAt);
  });
  return sorted;
}

List<String> _paths(List<JournalPhoto> photos, int max) {
  final sorted = [...photos]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return sorted.take(max).map((p) => p.storagePath).toList();
}

/// Sanitized book: never includes balances, debts, settlements, or expense detail.
TripBook generateTripBook({
  required Trip trip,
  required List<JournalEntry> entries,
  required List<String> memberNames,
  TripStatistics? stats,
  TripBookPrivacy privacy = const TripBookPrivacy(),
}) {
  final ordered = _ordered(entries);
  final pages = <TripBookPage>[];

  pages.add(
    TripBookPage(
      template: BookPageTemplate.cover,
      title: trip.name,
      subtitle: [
        if (trip.destination != null) trip.destination!,
        if (trip.startDate != null && trip.endDate != null)
          '${trip.startDate!.toIso8601String().split('T').first} – ${trip.endDate!.toIso8601String().split('T').first}',
        if (privacy.includeMemberNames && memberNames.isNotEmpty)
          '${memberNames.length} friends',
      ].join('\n'),
      photoPaths: trip.coverPhotoPath != null
          ? [trip.coverPhotoPath!]
          : (ordered.isNotEmpty ? _paths(ordered.first.photos, 1) : const []),
    ),
  );

  pages.add(
    TripBookPage(
      template: BookPageTemplate.introduction,
      title: 'Introduction',
      body: trip.description?.isNotEmpty == true
          ? trip.description
          : 'A trip remembered in photos and places.',
      subtitle: privacy.includeMemberNames ? memberNames.join(', ') : null,
    ),
  );

  final dayBuckets = <String, List<JournalEntry>>{};
  for (final e in ordered) {
    final key = '${e.visitedAt.year}-${e.visitedAt.month}-${e.visitedAt.day}';
    dayBuckets.putIfAbsent(key, () => []).add(e);
  }

  var dayIndex = 1;
  for (final dayEntries in dayBuckets.values) {
    for (final entry in dayEntries) {
      final paths = _paths(entry.photos, 5);
      final template = switch (paths.length) {
        0 => BookPageTemplate.quote,
        1 => entry.description?.isNotEmpty == true
            ? BookPageTemplate.imageText
            : BookPageTemplate.fullImage,
        2 => BookPageTemplate.twoImages,
        _ => BookPageTemplate.threeImages,
      };
      pages.add(
        TripBookPage(
          template: template,
          title: 'Day $dayIndex',
          subtitle: entry.title ?? entry.locationName,
          body: entry.description,
          photoPaths: paths.take(3).toList(),
        ),
      );
    }
    dayIndex++;
  }

  final statsLines = <String>[
    '${ordered.length} memories',
    '${dayBuckets.length} days',
  ];
  if (privacy.includeSpending && stats != null) {
    statsLines.add('Total spent: ${stats.totalSpent}');
  }
  pages.add(
    TripBookPage(
      template: BookPageTemplate.statistics,
      title: 'Trip Statistics',
      statsLines: statsLines,
    ),
  );

  pages.add(
    const TripBookPage(
      template: BookPageTemplate.finale,
      title: 'Final Memory',
      body: 'Until the next road.',
    ),
  );

  return TripBook(pages: pages, privacy: privacy);
}

String shareableBookText(TripBook book, String tripName) {
  final buffer = StringBuffer('Trip Book: $tripName\n\n');
  for (final page in book.pages) {
    if (page.title != null) buffer.writeln(page.title);
    if (page.subtitle != null) buffer.writeln(page.subtitle);
    if (page.body != null) buffer.writeln(page.body);
    for (final line in page.statsLines) {
      buffer.writeln(line);
    }
    buffer.writeln();
  }
  buffer.writeln('Shared from TripMate');
  return buffer.toString();
}
