import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/features/community/domain/public_trip_plan.dart';

void main() {
  group('ranking scores', () {
    test('popular prefers saves and clones', () {
      final likesOnly = popularScore(likes: 2, saves: 0, clones: 0); // 4
      final saves = popularScore(likes: 0, saves: 2, clones: 0); // 6
      final clones = popularScore(likes: 0, saves: 0, clones: 2); // 8
      expect(saves, greaterThan(likesOnly));
      expect(clones, greaterThan(saves));
    });

    test('trending weights views', () {
      final cold = trendingScore(likes: 1, saves: 1, views: 0, clones: 0);
      final hot = trendingScore(likes: 1, saves: 1, views: 100, clones: 0);
      expect(hot, greaterThan(cold));
    });
  });

  group('PublicTripPlan parsing', () {
    test('fromJson sanitized card', () {
      final plan = PublicTripPlan.fromJson({
        'trip_id': 't1',
        'title': 'Da Lat 3N2D',
        'destination': 'Da Lat',
        'creator_id': 'u1',
        'creator_display_name': 'Nguyen',
        'like_count': 3,
        'save_count': 2,
        'view_count': 10,
        'clone_count': 1,
        'place_count': 5,
        'memory_count': 8,
        'currency': 'VND',
      });
      expect(plan.title, 'Da Lat 3N2D');
      expect(plan.destination, 'Da Lat');
      expect(plan.likeCount, 3);
      expect(plan.cloneCount, 1);
    });
  });

  group('PublicPlanDetail privacy shape', () {
    test('parses itinerary and photos without private fields', () {
      final detail = PublicPlanDetail.fromJson({
        'trip_id': 't1',
        'title': 'Trip',
        'creator_id': 'u1',
        'liked_by_me': true,
        'saved_by_me': false,
        'itinerary': [
          {
            'id': 'j1',
            'title': 'Waterfall',
            'location_name': 'Datanla',
            'description': 'Cold water',
            'visited_at': '2026-08-20T10:00:00Z',
          },
        ],
        'photos': [
          {'storage_path': 'a/b.jpg', 'display_order': 0},
        ],
      });
      expect(detail.likedByMe, isTrue);
      expect(detail.itinerary.length, 1);
      expect(detail.photoPaths, ['a/b.jpg']);
      expect(detail.itinerary.first.locationName, 'Datanla');
    });
  });
}
