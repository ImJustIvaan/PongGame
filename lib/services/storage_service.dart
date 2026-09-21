import 'package:flutter/material.dart';
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
    await addKnownUsername(username);
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
    await addKnownUsername(name);
  }

  static final StorageService instance = StorageService._();
  StorageService._();

  SharedPreferences? _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    themeModeNotifier.value = getThemeMode();
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

  ThemeMode getThemeMode() {
    final val = _prefs?.getString('theme_mode') ?? 'system';
    switch (val) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final val = mode == ThemeMode.light
        ? 'light'
        : (mode == ThemeMode.dark ? 'dark' : 'system');
    await _prefs?.setString('theme_mode', val);
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

  bool getOwnerAutoPlay() => _prefs?.getBool('owner_auto_play') ?? false;
  Future<void> saveOwnerAutoPlay(bool enabled) async {
    await _prefs?.setBool('owner_auto_play', enabled);
  }

  List<String> getLocalBannedUsersJson() => _prefs?.getStringList('local_banned_users') ?? [];
  Future<void> saveLocalBannedUsersJson(List<String> list) async {
    await _prefs?.setStringList('local_banned_users', list);
  }

  // Level & Coin Progression System
  int getLevel() => _prefs?.getInt('player_level') ?? 1;
  Future<void> saveLevel(int level) async {
    await _prefs?.setInt('player_level', level.clamp(1, 99999));
  }

  Future<int> incrementLevel([int by = 1]) async {
    final next = getLevel() + by;
    await saveLevel(next);
    return next;
  }

  int getCoins() => _prefs?.getInt('player_coins') ?? 0;
  Future<void> saveCoins(int coins) async {
    await _prefs?.setInt('player_coins', coins.clamp(0, 9999999));
  }

  Future<int> addCoins(int amount) async {
    final next = getCoins() + amount;
    await saveCoins(next);
    return next;
  }

  int getKills() => _prefs?.getInt('player_kills') ?? getHighScore();
  Future<void> saveKills(int kills) async {
    await _prefs?.setInt('player_kills', kills.clamp(0, 9999999));
  }

  Future<int> addKills(int amount) async {
    final next = getKills() + amount;
    await saveKills(next);
    if (next > getHighScore()) {
      await saveHighScore(next);
    }
    return next;
  }

  int getWins() => _prefs?.getInt('player_wins') ?? 0;
  Future<void> saveWins(int wins) async {
    await _prefs?.setInt('player_wins', wins.clamp(0, 9999999));
  }

  Future<int> addWins(int amount) async {
    final next = getWins() + amount;
    await saveWins(next);
    return next;
  }

  Future<void> syncFromRemoteStats({
    required int level,
    required int coins,
    required int kills,
    required int wins,
    required int highScore,
    required int bestRally,
  }) async {
    if (level > getLevel()) {
      await saveLevel(level);
    }
    if (coins > getCoins() || (getCoins() == 0 && coins > 0)) {
      await saveCoins(coins);
    }
    if (kills > getKills()) {
      await saveKills(kills);
    }
    if (wins > getWins()) {
      await saveWins(wins);
    }
    if (highScore > getHighScore()) {
      await saveHighScore(highScore);
    }
    if (bestRally > getBestRally()) {
      await saveBestRally(bestRally);
    }
  }

  // --- Paddle Skins & Wardrobe ---
  String getEquippedSkin() => _prefs?.getString('equipped_skin') ?? 'classic_cyan';
  Future<void> saveEquippedSkin(String skinId) async {
    await _prefs?.setString('equipped_skin', skinId);
  }

  List<String> getOwnedSkins() {
    final list = _prefs?.getStringList('owned_skins');
    if (list == null || list.isEmpty) {
      return ['classic_cyan'];
    }
    if (!list.contains('classic_cyan')) {
      list.add('classic_cyan');
    }
    return list;
  }

  Future<void> saveOwnedSkins(List<String> list) async {
    final unique = list.toSet().toList();
    if (!unique.contains('classic_cyan')) {
      unique.add('classic_cyan');
    }
    await _prefs?.setStringList('owned_skins', unique);
  }

  Future<void> addOwnedSkin(String skinId) async {
    final current = getOwnedSkins();
    if (!current.contains(skinId)) {
      current.add(skinId);
      await saveOwnedSkins(current);
    }
  }

  bool isSkinOwned(String skinId) {
    if (skinId == 'classic_cyan') return true;
    return getOwnedSkins().contains(skinId);
  }

  // --- Verified Users Cache ---
  List<String> getLocalVerifiedUsers() => _prefs?.getStringList('local_verified_users') ?? ['imjustivaan'];
  Future<void> saveLocalVerifiedUsers(List<String> list) async {
    final clean = list.map((u) => u.trim().toLowerCase()).toSet().toList();
    if (!clean.contains('imjustivaan')) {
      clean.add('imjustivaan');
    }
    await _prefs?.setStringList('local_verified_users', clean);
  }

  bool isLocalVerified(String username) {
    final clean = username.trim().toLowerCase();
    if (clean == 'imjustivaan') return true;
    return getLocalVerifiedUsers().contains(clean);
  }

  // --- Locally Granted Skins Map ---
  List<String> getLocalGrantedSkins(String username) {
    final clean = username.trim().toLowerCase();
    return _prefs?.getStringList('granted_skins_$clean') ?? [];
  }

  Future<void> saveLocalGrantedSkin(String username, String skinId) async {
    final clean = username.trim().toLowerCase();
    final list = getLocalGrantedSkins(clean);
    if (!list.contains(skinId)) {
      list.add(skinId);
      await _prefs?.setStringList('granted_skins_$clean', list);
    }
  }

  // --- Known Accounts & Usernames ---
  List<String> getKnownUsernames() {
    final list = _prefs?.getStringList('known_usernames') ?? [];
    final set = list.map((u) => u.trim().toLowerCase()).toSet();
    set.add('imjustivaan');
    final current = getUsername();
    if (current != null && current.trim().isNotEmpty) {
      set.add(current.trim().toLowerCase());
    }
    return set.toList();
  }

  Future<void> addKnownUsername(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return;
    final current = getKnownUsernames().toSet();
    if (!current.contains(clean)) {
      current.add(clean);
      await _prefs?.setStringList('known_usernames', current.toList());
    }
  }

  bool isKnownUser(String username) {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return false;
    return getKnownUsernames().contains(clean);
  }

  // --- Local User Custom Stats Adjustments ---
  Map<String, int> getLocalUserStats(String username) {
    final clean = username.trim().toLowerCase();
    return {
      'coins': _prefs?.getInt('user_coins_$clean') ?? 0,
      'level': _prefs?.getInt('user_level_$clean') ?? 1,
      'kills': _prefs?.getInt('user_kills_$clean') ?? 0,
      'wins': _prefs?.getInt('user_wins_$clean') ?? 0,
    };
  }

  Future<void> addLocalUserStats(
    String username, {
    int coins = 0,
    int levels = 0,
    int kills = 0,
    int wins = 0,
  }) async {
    final clean = username.trim().toLowerCase();
    final cur = getLocalUserStats(clean);
    final nextCoins = (cur['coins']! + coins).clamp(0, 9999999);
    final nextLevel = (cur['level']! + levels).clamp(1, 99999);
    final nextKills = (cur['kills']! + kills).clamp(0, 9999999);
    final nextWins = (cur['wins']! + wins).clamp(0, 9999999);

    await _prefs?.setInt('user_coins_$clean', nextCoins);
    await _prefs?.setInt('user_level_$clean', nextLevel);
    await _prefs?.setInt('user_kills_$clean', nextKills);
    await _prefs?.setInt('user_wins_$clean', nextWins);
  }
}

