class Balance {
  const Balance({
    required this.userId,
    required this.amountPaid,
    required this.amountOwed,
    required this.netBalance,
    this.displayName,
  });

  final String userId;
  final int amountPaid;
  final int amountOwed;
  final int netBalance;
  final String? displayName;

  factory Balance.fromJson(Map<String, dynamic> json) {
    return Balance(
      userId: json['user_id'] as String,
      amountPaid: (json['amount_paid'] as num).toInt(),
      amountOwed: (json['amount_owed'] as num).toInt(),
      netBalance: (json['net_balance'] as num).toInt(),
      displayName: json['display_name'] as String?,
    );
  }
}

class SettlementSuggestion {
  const SettlementSuggestion({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.fromName,
    this.toName,
  });

  final String fromUserId;
  final String toUserId;
  final int amount;
  final String? fromName;
  final String? toName;
}

class Settlement {
  const Settlement({
    required this.id,
    required this.tripId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.note,
    required this.status,
    required this.settledAt,
    required this.createdBy,
    required this.createdAt,
    this.fromName,
    this.toName,
  });

  final String id;
  final String tripId;
  final String fromUserId;
  final String toUserId;
  final int amount;
  final String? note;
  final String status;
  final DateTime settledAt;
  final String createdBy;
  final DateTime createdAt;
  final String? fromName;
  final String? toName;

  factory Settlement.fromJson(Map<String, dynamic> json) {
    String? fromName;
    String? toName;
    final from = json['from_profile'];
    final to = json['to_profile'];
    if (from is Map<String, dynamic>) fromName = from['display_name'] as String?;
    if (to is Map<String, dynamic>) toName = to['display_name'] as String?;
    return Settlement(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      amount: (json['amount'] as num).toInt(),
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'completed',
      settledAt: DateTime.parse(json['settled_at'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      fromName: fromName,
      toName: toName,
    );
  }
}

/// Deterministic settlement suggestions that minimize transfers where practical.
List<SettlementSuggestion> calculateSettlements(List<Balance> balances) {
  final debtors = <({String id, String? name, int amount})>[];
  final creditors = <({String id, String? name, int amount})>[];

  final sorted = [...balances]..sort((a, b) => a.userId.compareTo(b.userId));
  for (final b in sorted) {
    if (b.netBalance < 0) {
      debtors.add((id: b.userId, name: b.displayName, amount: -b.netBalance));
    } else if (b.netBalance > 0) {
      creditors.add((id: b.userId, name: b.displayName, amount: b.netBalance));
    }
  }

  debtors.sort((a, b) {
    final c = b.amount.compareTo(a.amount);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  creditors.sort((a, b) {
    final c = b.amount.compareTo(a.amount);
    return c != 0 ? c : a.id.compareTo(b.id);
  });

  final suggestions = <SettlementSuggestion>[];
  var i = 0;
  var j = 0;
  final dAmt = List<int>.generate(debtors.length, (k) => debtors[k].amount);
  final cAmt = List<int>.generate(creditors.length, (k) => creditors[k].amount);

  while (i < debtors.length && j < creditors.length) {
    final pay = dAmt[i] < cAmt[j] ? dAmt[i] : cAmt[j];
    if (pay > 0 && debtors[i].id != creditors[j].id) {
      suggestions.add(
        SettlementSuggestion(
          fromUserId: debtors[i].id,
          toUserId: creditors[j].id,
          amount: pay,
          fromName: debtors[i].name,
          toName: creditors[j].name,
        ),
      );
    }
    dAmt[i] -= pay;
    cAmt[j] -= pay;
    if (dAmt[i] == 0) i++;
    if (cAmt[j] == 0) j++;
  }

  return suggestions;
}

/// Local balance calculation from expenses + settlements (for tests / offline checks).
List<Balance> calculateBalancesFromLedger({
  required List<String> memberIds,
  required Map<String, String?> names,
  required List<({String paidBy, int amount, List<({String userId, int share})> shares})> expenses,
  required List<({String from, String to, int amount})> settlements,
}) {
  final paid = {for (final id in memberIds) id: 0};
  final owed = {for (final id in memberIds) id: 0};

  for (final e in expenses) {
    paid[e.paidBy] = (paid[e.paidBy] ?? 0) + e.amount;
    for (final s in e.shares) {
      owed[s.userId] = (owed[s.userId] ?? 0) + s.share;
    }
  }

  for (final s in settlements) {
    // Settlement: from pays to → from's debt decreases, to's credit decreases
    owed[s.from] = (owed[s.from] ?? 0) - s.amount;
    paid[s.to] = (paid[s.to] ?? 0) - s.amount;
  }

  return memberIds.map((id) {
    final p = paid[id] ?? 0;
    final o = owed[id] ?? 0;
    return Balance(
      userId: id,
      amountPaid: p,
      amountOwed: o,
      netBalance: p - o,
      displayName: names[id],
    );
  }).toList();
}
