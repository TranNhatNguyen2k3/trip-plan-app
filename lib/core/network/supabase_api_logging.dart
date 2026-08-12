import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

StreamSubscription<LogRecord>? _subscription;

/// Prints Supabase SDK logs. HTTP requests are logged by [LoggingHttpClient].
void configureSupabaseApiLogging({required bool enabled}) {
  _subscription?.cancel();
  _subscription = null;

  if (!enabled) return;

  // Only adjust root logger — never set level on child loggers (avoids crash).
  Logger.root.level = Level.ALL;

  _subscription = Logger.root.onRecord.listen((record) {
    final name = record.loggerName;
    final isSupabaseFamily = name.startsWith('supabase') || name == 'gotrue';
    if (!isSupabaseFamily) return;
    if (record.level == Level.CONFIG) return;
    // Token refresh ticks — very noisy in debug.
    if (record.level.value <= Level.FINER.value && name.contains('auth')) {
      return;
    }

    debugPrint(
      '[Supabase] ${record.level.name} $name: ${record.message}'
      '${record.error != null ? ' | ${record.error}' : ''}',
    );
  });
}

void disposeSupabaseApiLogging() {
  _subscription?.cancel();
  _subscription = null;
}
