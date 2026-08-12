import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API / Supabase request logging (debug console).
bool resolveSupabaseApiLoggingEnabled() {
  const fromDefine = String.fromEnvironment('SUPABASE_API_LOG');
  if (fromDefine == 'true' || fromDefine == '1') return true;
  if (fromDefine == 'false' || fromDefine == '0') return false;

  final fromEnv = dotenv.env['SUPABASE_API_LOG'];
  if (fromEnv == 'true' || fromEnv == '1') return true;
  if (fromEnv == 'false' || fromEnv == '0') return false;

  return kDebugMode;
}
