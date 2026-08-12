import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/network/api_log_config.dart';
import 'core/network/logging_http_client.dart';
import 'core/network/supabase_api_logging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional when using --dart-define
    if (kDebugMode) {
      debugPrint('No .env loaded; using --dart-define or defaults.');
    }
  }

  const defineUrl = String.fromEnvironment('SUPABASE_URL');
  const defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final supabaseUrl = defineUrl.isNotEmpty
      ? defineUrl
      : (dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co');
  final supabaseAnonKey = defineKey.isNotEmpty
      ? defineKey
      : (dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholder-anon-key');

  final apiLog = resolveSupabaseApiLoggingEnabled();
  configureSupabaseApiLogging(enabled: apiLog);

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    debug: apiLog,
    httpClient: apiLog ? LoggingHttpClient() : null,
  );

  if (apiLog && kDebugMode) {
    debugPrint('[API] Supabase API logging enabled');
  }

  runApp(const ProviderScope(child: TripMateApp()));
}
