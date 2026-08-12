import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/supabase_provider.dart';
import '../../expenses/data/expense_repository.dart';
import '../../settlements/data/settlement_repository.dart';
import 'trip_scope.dart';

/// Realtime for the currently open trip only (debounced invalidation).
final tripRealtimeProvider =
    Provider.autoDispose.family<void, String>((ref, tripId) {
  bindTripScopeRef(ref, tripId);

  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('trip-$tripId');
  Timer? debounce;

  void invalidateExpenses() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      ref.invalidate(expensesProvider(tripId));
      ref.invalidate(tripBalancesProvider(tripId));
    });
  }

  void invalidateSettlements() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      ref.invalidate(settlementsProvider(tripId));
      ref.invalidate(tripBalancesProvider(tripId));
      ref.invalidate(settlementSuggestionsProvider(tripId));
    });
  }

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expenses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (_) => invalidateExpenses(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'settlements',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (_) => invalidateSettlements(),
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});
