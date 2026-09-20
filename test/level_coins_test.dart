import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pong_game/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerStats Level & Coins Tests', () {
    test('PlayerStats initializes with default level and coins from map', () {
      final stats = PlayerStats.fromMap({
        'username': 'cyber_pro',
        'high_score': 15,
        'best_rally': 22,
        'games_played': 10,
        'wins': 6,
      });

      expect(stats.username, 'cyber_pro');
      expect(stats.wins, 6);
      // Fallback calculation: level = 1 + wins = 7, coins = wins * 50 = 300
      expect(stats.level, 7);
      expect(stats.coins, 300);
    });

    test('PlayerStats reads explicit level and coins if provided in map', () {
      final stats = PlayerStats.fromMap({
        'username': 'champion',
        'high_score': 20,
        'best_rally': 30,
        'games_played': 25,
        'wins': 18,
        'level': 24,
        'coins': 1250,
      });

      expect(stats.level, 24);
      expect(stats.coins, 1250);
    });
  });

  group('StorageService Level and Coins Progression', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'player_level': 1,
        'player_coins': 0,
      });
      await StorageService.instance.init();
    });

    test('Level starts at 1 and increments properly', () async {
      expect(StorageService.instance.getLevel(), 1);

      final next = await StorageService.instance.incrementLevel();
      expect(next, 2);
      expect(StorageService.instance.getLevel(), 2);

      await StorageService.instance.incrementLevel(3);
      expect(StorageService.instance.getLevel(), 5);
    });

    test('Coins start at 0 and award amounts properly', () async {
      expect(StorageService.instance.getCoins(), 0);

      final nextCoins = await StorageService.instance.addCoins(50);
      expect(nextCoins, 50);
      expect(StorageService.instance.getCoins(), 50);

      await StorageService.instance.addCoins(100);
      expect(StorageService.instance.getCoins(), 150);
    });

    test('Kills and Wins track and increment properly', () async {
      expect(StorageService.instance.getKills(), 0);
      expect(StorageService.instance.getWins(), 0);

      await StorageService.instance.addKills(7);
      expect(StorageService.instance.getKills(), 7);

      await StorageService.instance.addWins(1);
      expect(StorageService.instance.getWins(), 1);
    });

    test('addPlayerStats validates user existence and updates stats for valid accounts', () async {
      // 1. Rejects non-existent user
      final notFoundErr = await SupabaseService.instance.addPlayerStats(
        username: 'non_existent_ghost',
        coins: 100,
        levels: 2,
        kills: 10,
        wins: 1,
      );
      expect(notFoundErr, isNotNull);
      expect(notFoundErr, contains('does not exist'));

      // 2. Rejects when all stats are zero or negative
      await StorageService.instance.addKnownUsername('real_player');
      final zeroErr = await SupabaseService.instance.addPlayerStats(
        username: 'real_player',
        coins: 0,
        levels: 0,
        kills: 0,
        wins: 0,
      );
      expect(zeroErr, isNotNull);
      expect(zeroErr, contains('at least one stat amount'));

      // 3. Successfully boosts stats for known user
      final successErr = await SupabaseService.instance.addPlayerStats(
        username: 'real_player',
        coins: 500,
        levels: 5,
        kills: 25,
        wins: 3,
      );
      expect(successErr, isNull);

      final localStats = StorageService.instance.getLocalUserStats('real_player');
      expect(localStats['coins'], 500);
      expect(localStats['level'], 6); // default 1 + 5
      expect(localStats['kills'], 25);
      expect(localStats['wins'], 3);
    });

    test('addPlayerStats directly updates active local player if target is current player', () async {
      await StorageService.instance.saveUsername('ImJustIvaan');
      final initialCoins = StorageService.instance.getCoins();
      final initialLevel = StorageService.instance.getLevel();

      final err = await SupabaseService.instance.addPlayerStats(
        username: 'ImJustIvaan',
        coins: 1000,
        levels: 10,
        kills: 50,
        wins: 5,
      );
      expect(err, isNull);
      expect(StorageService.instance.getCoins(), initialCoins + 1000);
      expect(StorageService.instance.getLevel(), initialLevel + 10);
      expect(StorageService.instance.getKills(), greaterThanOrEqualTo(50));
      expect(StorageService.instance.getWins(), greaterThanOrEqualTo(5));
    });
  });
}
