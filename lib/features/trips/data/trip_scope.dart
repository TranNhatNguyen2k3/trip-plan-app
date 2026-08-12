import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps trip-scoped autoDispose providers alive while [TripShell] is mounted.
final tripScopeProvider = Provider.autoDispose.family<void, String>((ref, tripId) {
  ref.keepAlive();
});

void bindTripScope(WidgetRef ref, String tripId) {
  ref.watch(tripScopeProvider(tripId));
}

void bindTripScopeRef(Ref ref, String tripId) {
  ref.watch(tripScopeProvider(tripId));
}
