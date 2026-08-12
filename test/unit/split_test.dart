import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/core/utils/money.dart';

void main() {
  group('splitEqually', () {
    test('100 / 3 keeps remainder', () {
      final shares = splitEqually(100, ['a', 'b', 'c']);
      expect(shares.map((s) => s.shareAmount).toList(), [34, 33, 33]);
      expect(shares.fold<int>(0, (a, b) => a + b.shareAmount), 100);
    });

    test('1000 / 3', () {
      final shares = splitEqually(1000, ['a', 'b', 'c']);
      expect(shares.fold<int>(0, (a, b) => a + b.shareAmount), 1000);
      expect(shares.map((s) => s.shareAmount).toList(), [334, 333, 333]);
    });

    test('1000 / 4', () {
      final shares = splitEqually(1000, ['a', 'b', 'c', 'd']);
      expect(shares.every((s) => s.shareAmount == 250), isTrue);
    });

    test('rejects empty users', () {
      expect(() => splitEqually(100, []), throwsArgumentError);
    });

    test('rejects non-positive amount', () {
      expect(() => splitEqually(0, ['a']), throwsArgumentError);
    });
  });

  group('sharesSumToAmount', () {
    test('valid custom', () {
      expect(sharesSumToAmount(1000000, [500000, 300000, 200000]), isTrue);
    });

    test('invalid', () {
      expect(sharesSumToAmount(1000, [400, 400]), isFalse);
    });

    test('negative invalid', () {
      expect(sharesSumToAmount(100, [150, -50]), isFalse);
    });

    test('zero shares ok if sum matches', () {
      expect(sharesSumToAmount(100, [100, 0]), isTrue);
    });
  });
}
