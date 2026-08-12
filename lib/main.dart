import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

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

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const ProviderScope(child: TripMateApp()));
}
