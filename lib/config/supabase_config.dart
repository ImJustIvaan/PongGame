import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const String _defaultUrl = 'https://dhliamsdosprwojlnczh.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRobGlhbXNkb3NwcndvamxuY3poIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4NzczMTgsImV4cCI6MjEwNTQ1MzMxOH0.1L03hBPG4tIz8OtfsuURSI99G2WtlaBeQIVCvIvMcAI';

  // Reads from:
  // 1. .env file via flutter_dotenv
  // 2. Or compile-time --dart-define=SUPABASE_URL=...
  // 3. Or project default credentials
  static String get url {
    String fromDotenv = '';
    try {
      if (dotenv.isInitialized) {
        fromDotenv = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
      }
    } catch (_) {}
    if (fromDotenv.isNotEmpty && !fromDotenv.contains('your-project-id') && !fromDotenv.contains('YOUR_PROJECT_ID')) {
      return fromDotenv;
    }

    const fromDefine = String.fromEnvironment('SUPABASE_URL');
    if (fromDefine.isNotEmpty && !fromDefine.contains('your-project-id') && !fromDefine.contains('YOUR_PROJECT_ID')) {
      return fromDefine.trim();
    }

    return _defaultUrl;
  }

  static String get anonKey {
    String fromDotenv = '';
    try {
      if (dotenv.isInitialized) {
        fromDotenv = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
      }
    } catch (_) {}
    if (fromDotenv.isNotEmpty && !fromDotenv.contains('your-anon') && !fromDotenv.contains('YOUR_SUPABASE_ANON_KEY')) {
      return fromDotenv;
    }

    const fromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromDefine.isNotEmpty && !fromDefine.contains('your-anon') && !fromDefine.contains('YOUR_SUPABASE_ANON_KEY')) {
      return fromDefine.trim();
    }

    return _defaultAnonKey;
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
      // .env missing or in test/CI - falls back gracefully to project defaults
    }
  }
}
