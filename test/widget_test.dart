import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/core/utils/money.dart';

void main() {
  test('splitEqually smoke', () {
    final shares = splitEqually(100, ['a', 'b', 'c']);
    expect(shares.fold<int>(0, (a, b) => a + b.shareAmount), 100);
  });
}
