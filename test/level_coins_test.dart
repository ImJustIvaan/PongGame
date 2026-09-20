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
  });
}
