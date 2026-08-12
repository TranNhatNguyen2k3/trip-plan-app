import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/supabase_provider.dart';
import '../../expenses/data/expense_repository.dart';
import '../../settlements/data/settlement_repository.dart';

/// Realtime for the currently open trip only.
final tripRealtimeProvider =
    Provider.autoDispose.family<void, String>((ref, tripId) {
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('trip-$tripId');

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
        callback: (_) {
          ref.invalidate(expensesProvider(tripId));
          ref.invalidate(tripBalancesProvider(tripId));
        },
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
        callback: (_) {
          ref.invalidate(settlementsProvider(tripId));
          ref.invalidate(tripBalancesProvider(tripId));
          ref.invalidate(settlementSuggestionsProvider(tripId));
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
