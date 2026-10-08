import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String _envValue(String key) {
    final compileTimeValue = String.fromEnvironment(key, defaultValue: '');
    if (compileTimeValue.trim().isNotEmpty) {
      return compileTimeValue.trim();
    }
    return (dotenv.env[key] ?? '').trim();
  }

  static String get url => _envValue('SUPABASE_URL');
  static String get anonKey => _envValue('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
