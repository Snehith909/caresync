import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class CareSyncSupabase {
  static SupabaseClient get client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY '
        'with --dart-define.',
      );
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );
  }
}
