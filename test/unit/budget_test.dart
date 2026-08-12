import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/features/budget/domain/trip_budget.dart';

void main() {
  group('tripDayCount', () {
    test('missing dates', () {
      expect(tripDayCount(null, DateTime(2026, 1, 1)), isNull);
      expect(tripDayCount(DateTime(2026, 1, 1), null), isNull);
    });

    test('one-day trip', () {
      final d = DateTime(2026, 8, 20);
      expect(tripDayCount(d, d), 1);
    });

    test('multi-day inclusive', () {
      expect(
        tripDayCount(DateTime(2026, 8, 20), DateTime(2026, 8, 23)),
        4,
      );
    });
  });

  group('TripBudgetSummary', () {
    test('no budget', () {
      final s = buildBudgetSummary(budgetAmount: null, spent: 100);
      expect(s.hasBudget, isFalse);
      expect(s.progressClamped, 0);
      expect(s.insights, isEmpty);
    });

    test('under budget', () {
      final s = buildBudgetSummary(
        budgetAmount: 5000000,
        spent: 3850000,
        startDate: DateTime(2026, 8, 20),
        endDate: DateTime(2026, 8, 23),
      );
      expect(s.remaining, 1150000);
      expect(s.percentSpent, 77);
      expect(s.progressClamped, closeTo(0.77, 0.01));
      expect(s.dailyBudget, 1250000);
      expect(s.isOverBudget, isFalse);
    });

    test('budget equals spent', () {
      final s = buildBudgetSummary(budgetAmount: 1000, spent: 1000);
      expect(s.remaining, 0);
      expect(s.percentSpent, 100);
      expect(s.progressClamped, 1.0);
    });

    test('over budget', () {
      final s = buildBudgetSummary(budgetAmount: 5000000, spent: 6200000);
      expect(s.isOverBudget, isTrue);
      expect(s.overAmount, 1200000);
      expect(s.progressClamped, 1.0);
      expect(s.percentSpent, 124);
    });

    test('zero expenses', () {
      final s = buildBudgetSummary(budgetAmount: 1000, spent: 0);
      expect(s.remaining, 1000);
      expect(s.percentSpent, 0);
    });
  });
}
