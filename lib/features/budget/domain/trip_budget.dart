class TripBudgetSummary {
  const TripBudgetSummary({
    this.budgetAmount,
    required this.spent,
    this.byCategory = const [],
    this.tripDays,
  });

  final int? budgetAmount;
  final int spent;
  final List<({String category, int amount})> byCategory;
  final int? tripDays;

  bool get hasBudget => budgetAmount != null && budgetAmount! > 0;

  int get remaining {
    if (!hasBudget) return 0;
    return budgetAmount! - spent;
  }

  bool get isOverBudget => hasBudget && spent > budgetAmount!;

  int get overAmount => isOverBudget ? spent - budgetAmount! : 0;

  /// Progress for UI, clamped 0.0–1.0.
  double get progressClamped {
    if (!hasBudget) return 0;
    final p = spent / budgetAmount!;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  /// Integer percent of budget spent (can exceed 100 when over).
  int get percentSpent {
    if (!hasBudget) return 0;
    return (spent * 100) ~/ budgetAmount!;
  }

  int? get dailyBudget {
    if (!hasBudget || tripDays == null || tripDays! <= 0) return null;
    return budgetAmount! ~/ tripDays!;
  }

  int? get averageDailySpend {
    if (tripDays == null || tripDays! <= 0) return null;
    return spent ~/ tripDays!;
  }

  List<String> get insights {
    if (!hasBudget) return const [];
    final out = <String>[];
    if (isOverBudget) {
      out.add('Budget exceeded.');
      return out;
    }
    final daily = dailyBudget;
    final avg = averageDailySpend;
    if (daily != null && avg != null) {
      if (avg <= daily) {
        out.add("You're below your daily spending target.");
      } else {
        out.add('At the current pace, you may exceed the budget.');
      }
    }
    if (percentSpent >= 80 && !isOverBudget) {
      out.add('$percentSpent% of the budget has been used.');
    }
    return out;
  }
}

/// Trip day count inclusive; null when dates missing or invalid.
int? tripDayCount(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  if (e.isBefore(s)) return null;
  return e.difference(s).inDays + 1;
}

TripBudgetSummary buildBudgetSummary({
  required int? budgetAmount,
  required int spent,
  List<({String category, int amount})> byCategory = const [],
  DateTime? startDate,
  DateTime? endDate,
}) {
  return TripBudgetSummary(
    budgetAmount: budgetAmount,
    spent: spent,
    byCategory: byCategory,
    tripDays: tripDayCount(startDate, endDate),
  );
}
