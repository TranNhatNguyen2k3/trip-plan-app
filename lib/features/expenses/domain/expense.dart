enum ExpenseCategory {
  food,
  hotel,
  transport,
  activity,
  shopping,
  tickets,
  fuel,
  other;

  String get label => switch (this) {
        ExpenseCategory.food => 'Food',
        ExpenseCategory.hotel => 'Hotel',
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.activity => 'Activity',
        ExpenseCategory.shopping => 'Shopping',
        ExpenseCategory.tickets => 'Tickets',
        ExpenseCategory.fuel => 'Fuel',
        ExpenseCategory.other => 'Other',
      };

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.description,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.expenseDate,
    this.note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.participants = const [],
    this.payerName,
  });

  final String id;
  final String tripId;
  final String description;
  final int amount;
  final ExpenseCategory category;
  final String paidBy;
  final DateTime expenseDate;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ExpenseParticipant> participants;
  final String? payerName;

  factory Expense.fromJson(Map<String, dynamic> json) {
    final parts = (json['expense_participants'] as List<dynamic>?)
            ?.map((e) => ExpenseParticipant.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    String? payerName;
    final payer = json['payer'];
    if (payer is Map<String, dynamic>) {
      payerName = payer['display_name'] as String?;
    }
    return Expense(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toInt(),
      category: ExpenseCategory.fromString(json['category'] as String? ?? 'other'),
      paidBy: json['paid_by'] as String,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      note: json['note'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      participants: parts,
      payerName: payerName,
    );
  }
}

class ExpenseParticipant {
  const ExpenseParticipant({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.shareAmount,
    this.displayName,
  });

  final String id;
  final String expenseId;
  final String userId;
  final int shareAmount;
  final String? displayName;

  factory ExpenseParticipant.fromJson(Map<String, dynamic> json) {
    String? name;
    final profile = json['profiles'];
    if (profile is Map<String, dynamic>) {
      name = profile['display_name'] as String?;
    }
    return ExpenseParticipant(
      id: json['id'] as String? ?? '',
      expenseId: json['expense_id'] as String? ?? '',
      userId: json['user_id'] as String,
      shareAmount: (json['share_amount'] as num).toInt(),
      displayName: name,
    );
  }
}

class ExpenseShare {
  const ExpenseShare({required this.userId, required this.shareAmount});

  final String userId;
  final int shareAmount;
}
