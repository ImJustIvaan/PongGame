import 'package:shared_preferences/shared_preferences.dart';
import '../game/game_theme.dart';
import '../game/pong_engine.dart';

class StorageService {
  String? getSavedEmail() => _prefs?.getString('auth_email');
  String? getSavedPassword() => _prefs?.getString('auth_password');

  Future<void> saveLocalAccount({
    required String username,
    required String email,
    required String password,
  }) async {
    await _prefs?.setString('player_username', username.trim());
    await _prefs?.setString('auth_email', email.trim().toLowerCase());
    await _prefs?.setString('auth_password', password);
    await setLoggedIn(true);
  }

  bool validateLocalCredentials({
    required String email,
    required String password,
  }) {
    final savedEmail = getSavedEmail();
    final savedPassword = getSavedPassword();
    if (savedEmail == null || savedPassword == null) return false;
    return savedEmail.toLowerCase() == email.trim().toLowerCase() && savedPassword == password;
  }
  bool isLoggedIn() => _prefs?.getBool('is_logged_in') ?? false;

  Future<void> setLoggedIn(bool value) async {
    await _prefs?.setBool('is_logged_in', value);
  }

  Future<void> updateLocalPassword(String newPassword) async {
    await _prefs?.setString('auth_password', newPassword);
  }

  Future<void> logout() async {
    await _prefs?.setBool('is_logged_in', false);
  }

  String? getUsername() => _prefs?.getString('player_username');
  Future<void> saveUsername(String name) async {
    await _prefs?.setString('player_username', name.trim());
  }

  static final StorageService instance = StorageService._();
  StorageService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  int getHighScore() => _prefs?.getInt('high_score') ?? 0;
  Future<void> saveHighScore(int score) async {
    final current = getHighScore();
    if (score > current) {
      await _prefs?.setInt('high_score', score);
    }
  }

  int getBestRally() => _prefs?.getInt('best_rally') ?? 0;
  Future<void> saveBestRally(int rally) async {
    final current = getBestRally();
    if (rally > current) {
      await _prefs?.setInt('best_rally', rally);
    }
  }

  PongThemeType getTheme() {
    final index = _prefs?.getInt('theme_index') ?? PongThemeType.cyberNeon.index;
    return PongThemeType.values[index.clamp(0, PongThemeType.values.length - 1)];
  }

  Future<void> saveTheme(PongThemeType theme) async {
    await _prefs?.setInt('theme_index', theme.index);
  }

  AiDifficulty getDifficulty() {
    final index = _prefs?.getInt('ai_difficulty') ?? AiDifficulty.medium.index;
    return AiDifficulty.values[index.clamp(0, AiDifficulty.values.length - 1)];
  }

  Future<void> saveDifficulty(AiDifficulty difficulty) async {
    await _prefs?.setInt('ai_difficulty', difficulty.index);
  }

  int getTargetScore() => _prefs?.getInt('target_score') ?? 7;
  Future<void> saveTargetScore(int target) async {
    await _prefs?.setInt('target_score', target);
  }

  bool getSoundEnabled() => _prefs?.getBool('sound_enabled') ?? true;
  Future<void> saveSoundEnabled(bool enabled) async {
    await _prefs?.setBool('sound_enabled', enabled);
  }
}
