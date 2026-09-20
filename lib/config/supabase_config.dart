import 'package:shared_preferences/shared_preferences.dart';

class SupabaseConfig {
  // Default project credentials (can be overridden here or in the in-game settings)
  static const String defaultUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String defaultAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  static String _url = defaultUrl;
  static String _anonKey = defaultAnonKey;

  static String get url => _url;
  static String get anonKey => _anonKey;

  static bool get isConfigured {
    return _url.isNotEmpty &&
        _anonKey.isNotEmpty &&
        !_url.contains('YOUR_PROJECT_ID') &&
        !_anonKey.contains('YOUR_SUPABASE_ANON_KEY');
  }

  static Future<void> loadCustomConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('custom_supabase_url');
    final savedKey = prefs.getString('custom_supabase_key');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _url = savedUrl;
    }
    if (savedKey != null && savedKey.isNotEmpty) {
      _anonKey = savedKey;
    }
  }

  static Future<void> saveCustomConfig(String url, String key) async {
    final prefs = await SharedPreferences.getInstance();
    _url = url.trim();
    _anonKey = key.trim();
    await prefs.setString('custom_supabase_url', _url);
    await prefs.setString('custom_supabase_key', _anonKey);
  }
}
