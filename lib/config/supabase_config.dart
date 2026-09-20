import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Reads from:
  // 1. .env file via flutter_dotenv
  // 2. Or compile-time --dart-define=SUPABASE_URL=...
  // 3. Or empty string fallback
  static String get url {
    final fromDotenv = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
    if (fromDotenv.isNotEmpty) return fromDotenv;

    const fromDefine = String.fromEnvironment('SUPABASE_URL');
    return fromDefine.trim();
  }

  static String get anonKey {
    final fromDotenv = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
    if (fromDotenv.isNotEmpty) return fromDotenv;

    const fromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    return fromDefine.trim();
  }

  static bool get isConfigured {
    final u = url;
    final k = anonKey;
    return u.isNotEmpty &&
        k.isNotEmpty &&
        !u.contains('your-project-id') &&
        !u.contains('YOUR_PROJECT_ID') &&
        !k.contains('your-anon') &&
        !k.contains('YOUR_SUPABASE_ANON_KEY');
  }

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      if (isConfigured) {
        debugPrint('Loaded Supabase credentials from .env');
      }
    } catch (_) {
      // .env missing or in test/CI - falls back gracefully
    }
  }
}
