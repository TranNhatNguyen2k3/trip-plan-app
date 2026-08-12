import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/features/settlements/domain/settlement.dart';

void main() {
  group('calculateSettlements', () {
    test('1 creditor / many debtors', () {
      final balances = [
        const Balance(userId: 'nguyen', amountPaid: 900, amountOwed: 0, netBalance: 900, displayName: 'Nguyen'),
        const Balance(userId: 'minh', amountPaid: 0, amountOwed: 300, netBalance: -300, displayName: 'Minh'),
        const Balance(userId: 'an', amountPaid: 0, amountOwed: 300, netBalance: -300, displayName: 'An'),
        const Balance(userId: 'tuan', amountPaid: 0, amountOwed: 300, netBalance: -300, displayName: 'Tuan'),
      ];
      final suggestions = calculateSettlements(balances);
      expect(suggestions.length, 3);
      expect(suggestions.every((s) => s.toUserId == 'nguyen'), isTrue);
      expect(suggestions.every((s) => s.amount == 300), isTrue);
      expect(suggestions.fold<int>(0, (a, b) => a + b.amount), 900);
    });

    test('1 creditor / 1 debtor', () {
      final balances = [
        const Balance(userId: 'a', amountPaid: 50, amountOwed: 0, netBalance: 50),
        const Balance(userId: 'b', amountPaid: 0, amountOwed: 50, netBalance: -50),
      ];
      final suggestions = calculateSettlements(balances);
      expect(suggestions.length, 1);
      expect(suggestions.first.fromUserId, 'b');
      expect(suggestions.first.toUserId, 'a');
      expect(suggestions.any((s) => s.fromUserId == s.toUserId), isFalse);
    });

    test('many creditors / many debtors', () {
      final balances = [
        const Balance(userId: 'a', amountPaid: 500, amountOwed: 0, netBalance: 500),
        const Balance(userId: 'b', amountPaid: 200, amountOwed: 0, netBalance: 200),
        const Balance(userId: 'c', amountPaid: 0, amountOwed: 400, netBalance: -400),
        const Balance(userId: 'd', amountPaid: 0, amountOwed: 300, netBalance: -300),
      ];
      expect(balances.fold<int>(0, (s, b) => s + b.netBalance), 0);
      final suggestions = calculateSettlements(balances);
      final paid = suggestions.fold<int>(0, (a, b) => a + b.amount);
      expect(paid, 700);
      expect(suggestions.every((s) => s.fromUserId != s.toUserId), isTrue);
      expect(suggestions.isNotEmpty, isTrue);
    });

    test('many creditors / 1 debtor', () {
      final balances = [
        const Balance(userId: 'a', amountPaid: 300, amountOwed: 0, netBalance: 300),
        const Balance(userId: 'b', amountPaid: 200, amountOwed: 0, netBalance: 200),
        const Balance(userId: 'c', amountPaid: 0, amountOwed: 500, netBalance: -500),
      ];
      final suggestions = calculateSettlements(balances);
      expect(suggestions.fold<int>(0, (a, b) => a + b.amount), 500);
      expect(suggestions.every((s) => s.fromUserId == 'c'), isTrue);
    });

    test('already balanced and zero', () {
      expect(calculateSettlements(const []), isEmpty);
      expect(
        calculateSettlements([
          const Balance(userId: 'a', amountPaid: 10, amountOwed: 10, netBalance: 0),
          const Balance(userId: 'b', amountPaid: 5, amountOwed: 5, netBalance: 0),
        ]),
        isEmpty,
      );
    });

    test('uneven large amounts', () {
      final balances = [
        const Balance(userId: 'a', amountPaid: 1000000000, amountOwed: 0, netBalance: 1000000000),
        const Balance(userId: 'b', amountPaid: 0, amountOwed: 600000000, netBalance: -600000000),
        const Balance(userId: 'c', amountPaid: 0, amountOwed: 400000000, netBalance: -400000000),
      ];
      final suggestions = calculateSettlements(balances);
      expect(suggestions.fold<int>(0, (a, b) => a + b.amount), 1000000000);
    });
  });

  group('balance invariants', () {
    test('sum of balances is zero', () {
      final balances = calculateBalancesFromLedger(
        memberIds: ['n', 'm', 'a', 't'],
        names: {'n': 'Nguyen', 'm': 'Minh', 'a': 'An', 't': 'Tuan'},
        expenses: [
          (
            paidBy: 'n',
            amount: 1000000,
            shares: [
              (userId: 'n', share: 250000),
              (userId: 'm', share: 250000),
              (userId: 'a', share: 250000),
              (userId: 't', share: 250000),
            ],
          ),
        ],
        settlements: const [],
      );
      expect(balances.fold<int>(0, (s, b) => s + b.netBalance), 0);
      expect(balances.firstWhere((b) => b.userId == 'n').netBalance, 750000);
      expect(balances.firstWhere((b) => b.userId == 'm').netBalance, -250000);
    });

    test('settlement restores balances toward zero', () {
      final after = calculateBalancesFromLedger(
        memberIds: ['n', 'm'],
        names: const {},
        expenses: [
          (
            paidBy: 'n',
            amount: 100,
            shares: [
              (userId: 'n', share: 50),
              (userId: 'm', share: 50),
            ],
          ),
        ],
        settlements: [
          (from: 'm', to: 'n', amount: 50),
        ],
      );
      expect(after.fold<int>(0, (s, b) => s + b.netBalance), 0);
      expect(after.every((b) => b.netBalance == 0), isTrue);
    });
  });
}
