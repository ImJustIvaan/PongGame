import 'package:shared_preferences/shared_preferences.dart';
import '../game/game_theme.dart';
import '../game/pong_engine.dart';

class StorageService {
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
