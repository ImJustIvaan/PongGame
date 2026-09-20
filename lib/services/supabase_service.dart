import 'storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class PlayerStats {
  final String username;
  final int highScore;
  final int bestRally;
  final int gamesPlayed;
  final int wins;

  PlayerStats({
    required this.username,
    required this.highScore,
    required this.bestRally,
    required this.gamesPlayed,
    required this.wins,
  });

  int get losses => (gamesPlayed - wins).clamp(0, gamesPlayed);
  double get winRate => gamesPlayed > 0 ? (wins / gamesPlayed) * 100 : 0.0;

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      username: map['username'] as String? ?? 'Player',
      highScore: (map['high_score'] as num?)?.toInt() ?? 0,
      bestRally: (map['best_rally'] as num?)?.toInt() ?? 0,
      gamesPlayed: (map['games_played'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;
  bool get isConfigured => SupabaseConfig.isConfigured;

  SupabaseClient? get client => _initialized ? Supabase.instance.client : null;
  User? get currentUser => client?.auth.currentUser;
  bool get isLoggedIn => (currentUser != null) || StorageService.instance.isLoggedIn();

  String get currentUsername {
    if (!isLoggedIn) {
      final local = StorageService.instance.getUsername();
      if (local != null && local.trim().isNotEmpty) {
        return local.trim();
      }
      return 'Guest';
    }
    final metadata = currentUser?.userMetadata;
    return metadata?['username'] as String? ??
        currentUser?.email?.split('@').first ??
        'Player';
  }

  Future<bool> initialize() async {
    await SupabaseConfig.load();
    if (!SupabaseConfig.isConfigured) {
      debugPrint('Supabase credentials not configured yet. Running in offline/guest mode.');
      return false;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
      );
      _initialized = true;
      debugPrint('Supabase initialized successfully!');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
      _initialized = false;
      return false;
    }
  }

  // Auth: Sign Up
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    if (!isConfigured) return 'Supabase credentials are not configured.';
    if (!_initialized) await initialize();
    if (!_initialized) return 'Could not connect to Supabase.';

    try {
      final res = await client!.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username.trim()},
      );
      if (res.user == null) {
        return 'Signup failed. Please check your details.';
      }
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  // Auth: Sign In
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return 'Supabase credentials are not configured.';
    if (!_initialized) await initialize();
    if (!_initialized) return 'Could not connect to Supabase.';

    try {
      final res = await client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) {
        return 'Sign in failed.';
      }
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  // Auth: Sign Out
  Future<void> signOut() async {
    try {
      await client?.auth.signOut();
    } catch (_) {}
    await StorageService.instance.logout();
  }

  // Save game result and sync high scores
  Future<void> saveGameResult({
    required bool won,
    required int score,
    required int rally,
  }) async {
    if (!isLoggedIn) return;

    try {
      final userId = currentUser!.id;
      final currentStats = await fetchMyStats();

      final newGamesPlayed = (currentStats?.gamesPlayed ?? 0) + 1;
      final newWins = (currentStats?.wins ?? 0) + (won ? 1 : 0);
      final newHighScore = [currentStats?.highScore ?? 0, score].reduce((a, b) => a > b ? a : b);
      final newBestRally = [currentStats?.bestRally ?? 0, rally].reduce((a, b) => a > b ? a : b);

      await client!.from('game_stats').upsert({
        'user_id': userId,
        'username': currentUsername,
        'high_score': newHighScore,
        'best_rally': newBestRally,
        'games_played': newGamesPlayed,
        'wins': newWins,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Error syncing game result to Supabase: $e');
    }
  }

  // Sync local records on login
  Future<void> syncLocalRecords(int localHighScore, int localBestRally) async {
    if (!isLoggedIn) return;

    try {
      final currentStats = await fetchMyStats();
      final mergedHighScore = [currentStats?.highScore ?? 0, localHighScore].reduce((a, b) => a > b ? a : b);
      final mergedBestRally = [currentStats?.bestRally ?? 0, localBestRally].reduce((a, b) => a > b ? a : b);

      await client!.from('game_stats').upsert({
        'user_id': currentUser!.id,
        'username': currentUsername,
        'high_score': mergedHighScore,
        'best_rally': mergedBestRally,
        'games_played': currentStats?.gamesPlayed ?? 0,
        'wins': currentStats?.wins ?? 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Error syncing local records: $e');
    }
  }

  // Fetch logged-in user stats
  Future<PlayerStats?> fetchMyStats() async {
    if (!isLoggedIn) return null;

    try {
      final data = await client!
          .from('game_stats')
          .select()
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      if (data != null) {
        return PlayerStats.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
    return null;
  }

  // Fetch Top 10 Global Leaderboard
  Future<List<PlayerStats>> fetchLeaderboard({String orderBy = 'high_score', int limit = 10}) async {
    if (!_initialized) return [];

    try {
      final data = await client!
          .from('game_stats')
          .select()
          .order(orderBy, ascending: false)
          .limit(limit);

      return (data as List).map((row) => PlayerStats.fromMap(row as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }
}
