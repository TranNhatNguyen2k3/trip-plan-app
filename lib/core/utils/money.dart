import '../constants/app_constants.dart';

/// Equal split that never loses remainder.
/// Example: 100 / 3 => [34, 33, 33]
List<({String userId, int shareAmount})> splitEqually(
  int amount,
  List<String> userIds,
) {
  if (userIds.isEmpty) {
    throw ArgumentError('userIds must not be empty');
  }
  if (amount <= 0) {
    throw ArgumentError('amount must be positive');
  }

  final n = userIds.length;
  final base = amount ~/ n;
  final remainder = amount % n;

  return List.generate(n, (i) {
    final share = base + (i < remainder ? 1 : 0);
    return (userId: userIds[i], shareAmount: share);
  });
}

bool sharesSumToAmount(int amount, Iterable<int> shares) {
  var sum = 0;
  for (final s in shares) {
    if (s < 0) return false;
    sum += s;
  }
  return sum == amount;
}

String journalPhotoPath({
  required String tripId,
  required String entryId,
  required String photoId,
}) {
  return '$tripId/$entryId/$photoId.jpg';
}

String joinLink(String token) => '${AppConstants.joinBaseUrl}/$token';
