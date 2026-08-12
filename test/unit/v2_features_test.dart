import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/features/book/domain/trip_book.dart';
import 'package:tripmate/features/journal/domain/journal_entry.dart';
import 'package:tripmate/features/map/domain/trip_map_point.dart';
import 'package:tripmate/features/recap/domain/trip_recap.dart';
import 'package:tripmate/features/trips/domain/trip.dart';

void main() {
  final trip = Trip(
    id: 't1',
    name: 'Da Lat 2026',
    destination: 'Da Lat',
    startDate: DateTime(2026, 8, 20),
    endDate: DateTime(2026, 8, 23),
    currency: 'VND',
    createdBy: 'u1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  JournalEntry entry({
    required String id,
    required DateTime visited,
    String? location,
    List<JournalPhoto> photos = const [],
    String? description,
  }) {
    return JournalEntry(
      id: id,
      tripId: 't1',
      title: 'Title $id',
      locationName: location,
      description: description,
      visitedAt: visited,
      createdBy: 'u1',
      createdAt: visited,
      updatedAt: visited,
      photos: photos,
    );
  }

  group('map points', () {
    test('valid coordinates and journey order', () {
      expect(TripMapPoint.isValidCoordinate(11.9, 108.4), isTrue);
      expect(TripMapPoint.isValidCoordinate(100, 0), isFalse);
      final points = sortJourney([
        TripMapPoint(
          id: '2',
          latitude: 1,
          longitude: 1,
          visitedAt: DateTime(2026, 8, 21),
          createdAt: DateTime(2026, 8, 21),
        ),
        TripMapPoint(
          id: '1',
          latitude: 1,
          longitude: 2,
          visitedAt: DateTime(2026, 8, 20),
          createdAt: DateTime(2026, 8, 20),
        ),
      ]);
      expect(points.map((p) => p.id).toList(), ['1', '2']);
    });

    test('clustering nearby', () {
      final clusters = clusterMapPoints([
        TripMapPoint(
          id: 'a',
          latitude: 11.94,
          longitude: 108.44,
          visitedAt: DateTime(2026, 8, 20),
          createdAt: DateTime(2026, 8, 20),
        ),
        TripMapPoint(
          id: 'b',
          latitude: 11.941,
          longitude: 108.441,
          visitedAt: DateTime(2026, 8, 20),
          createdAt: DateTime(2026, 8, 20),
        ),
        TripMapPoint(
          id: 'c',
          latitude: 12.5,
          longitude: 109.0,
          visitedAt: DateTime(2026, 8, 21),
          createdAt: DateTime(2026, 8, 21),
        ),
      ]);
      expect(clusters.length, lessThan(3));
    });
  });

  group('recap', () {
    test('orders entries and limits photos', () {
      final photos = List.generate(
        8,
        (i) => JournalPhoto(
          id: '$i',
          journalEntryId: 'e',
          storagePath: 'p$i.jpg',
          displayOrder: i,
          createdAt: DateTime(2026, 8, 20),
        ),
      );
      expect(selectPhotosForRecap(photos).length, 5);
      final ordered = orderEntriesForRecap([
        entry(id: 'b', visited: DateTime(2026, 8, 21)),
        entry(id: 'a', visited: DateTime(2026, 8, 20)),
      ]);
      expect(ordered.first.id, 'a');
    });

    test('builds slides', () {
      final recap = buildTripRecap(
        trip: trip,
        entries: [
          entry(
            id: '1',
            visited: DateTime(2026, 8, 20),
            location: 'Datanla',
            description: 'Nice',
            photos: [
              JournalPhoto(
                id: 'p',
                journalEntryId: '1',
                storagePath: 'x.jpg',
                displayOrder: 0,
                createdAt: DateTime(2026, 8, 20),
              ),
            ],
          ),
        ],
        stats: null,
        memberCount: 4,
      );
      expect(recap.slides.first.type, RecapSlideType.cover);
      expect(recap.slides.last.type, RecapSlideType.finale);
      expect(recap.insights['memories'], '1');
    });
  });

  group('trip book privacy', () {
    test('excludes spending by default', () {
      final book = generateTripBook(
        trip: trip,
        entries: [
          entry(
            id: '1',
            visited: DateTime(2026, 8, 20),
            location: 'Lake',
            description: 'Calm water',
          ),
        ],
        memberNames: ['Nguyen', 'Minh'],
        privacy: const TripBookPrivacy(),
      );
      final statsPage = book.pages.firstWhere(
        (p) => p.template == BookPageTemplate.statistics,
      );
      expect(statsPage.statsLines.any((l) => l.contains('Total spent')), isFalse);
      expect(book.pages.first.subtitle?.contains('2 friends'), isTrue);
    });

    test('hides member names when disabled', () {
      final book = generateTripBook(
        trip: trip,
        entries: [entry(id: '1', visited: DateTime(2026, 8, 20))],
        memberNames: ['Nguyen'],
        privacy: const TripBookPrivacy(includeMemberNames: false),
      );
      final intro = book.pages.firstWhere(
        (p) => p.template == BookPageTemplate.introduction,
      );
      expect(intro.subtitle, isNull);
    });
  });
}
