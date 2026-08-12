class TripStatistics {
  const TripStatistics({
    required this.totalSpent,
    required this.byCategory,
    required this.byMember,
    required this.byDate,
  });

  final int totalSpent;
  final List<CategorySpend> byCategory;
  final List<MemberSpend> byMember;
  final List<DailySpend> byDate;

  factory TripStatistics.fromJson(Map<String, dynamic> json) {
    return TripStatistics(
      totalSpent: (json['total_spent'] as num?)?.toInt() ?? 0,
      byCategory: (json['by_category'] as List<dynamic>? ?? [])
          .map((e) => CategorySpend.fromJson(e as Map<String, dynamic>))
          .toList(),
      byMember: (json['by_member'] as List<dynamic>? ?? [])
          .map((e) => MemberSpend.fromJson(e as Map<String, dynamic>))
          .toList(),
      byDate: (json['by_date'] as List<dynamic>? ?? [])
          .map((e) => DailySpend.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategorySpend {
  const CategorySpend({required this.category, required this.amount});

  final String category;
  final int amount;

  factory CategorySpend.fromJson(Map<String, dynamic> json) {
    return CategorySpend(
      category: json['category'] as String,
      amount: (json['amount'] as num).toInt(),
    );
  }
}

class MemberSpend {
  const MemberSpend({
    required this.userId,
    required this.amount,
    this.displayName,
  });

  final String userId;
  final int amount;
  final String? displayName;

  factory MemberSpend.fromJson(Map<String, dynamic> json) {
    return MemberSpend(
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toInt(),
      displayName: json['display_name'] as String?,
    );
  }
}

class DailySpend {
  const DailySpend({required this.date, required this.amount});

  final DateTime date;
  final int amount;

  factory DailySpend.fromJson(Map<String, dynamic> json) {
    return DailySpend(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toInt(),
    );
  }
}
