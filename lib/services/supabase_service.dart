import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final int level;
  final int coins;

  PlayerStats({
    required this.username,
    required this.highScore,
    required this.bestRally,
    required this.gamesPlayed,
    required this.wins,
    this.level = 1,
    this.coins = 0,
  });

  int get losses => (gamesPlayed - wins).clamp(0, gamesPlayed);
  double get winRate => gamesPlayed > 0 ? (wins / gamesPlayed) * 100 : 0.0;

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    final wins = (map['wins'] as num?)?.toInt() ?? 0;
    final level = (map['level'] as num?)?.toInt() ?? (1 + wins);
    final coins = (map['coins'] as num?)?.toInt() ?? (wins * 50);
    return PlayerStats(
      username: map['username'] as String? ?? 'Player',
      highScore: (map['high_score'] as num?)?.toInt() ?? 0,
      bestRally: (map['best_rally'] as num?)?.toInt() ?? 0,
      gamesPlayed: (map['games_played'] as num?)?.toInt() ?? 0,
      wins: wins,
      level: level,
      coins: coins,
    );
  }
}

class BanRecord {
  final String username;
  final DateTime? bannedUntil; // null = Permanent Ban
  final String bannedBy;
  final String reason;
  final DateTime createdAt;

  BanRecord({
    required this.username,
    required this.bannedUntil,
    required this.bannedBy,
    required this.reason,
    required this.createdAt,
  });

  bool get isPermanent => bannedUntil == null;
  bool get isExpired => bannedUntil != null && DateTime.now().isAfter(bannedUntil!);
  bool get isActive => !isExpired;

  String get durationLabel {
    if (isPermanent) return 'Permanent Ban';
    if (isExpired) return 'Expired';
    final diff = bannedUntil!.difference(DateTime.now());
    if (diff.inDays >= 360) return '1 Year (${diff.inDays}d left)';
    if (diff.inDays >= 28) return '1 Month (${diff.inDays}d left)';
    if (diff.inDays >= 7) return '7 Days (${diff.inDays}d left)';
    if (diff.inDays >= 3) return '3 Days (${diff.inDays}d left)';
    if (diff.inDays >= 1) return '1 Day (${diff.inHours}h left)';
    if (diff.inHours > 0) return '${diff.inHours} hours left';
    return '${diff.inMinutes} mins left';
  }

  Map<String, dynamic> toMap() => {
    'username': username.toLowerCase().trim(),
    'banned_until': bannedUntil?.toUtc().toIso8601String(),
    'banned_by': bannedBy,
    'reason': reason,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory BanRecord.fromMap(Map<String, dynamic> map) {
    return BanRecord(
      username: map['username'] as String? ?? '',
      bannedUntil: map['banned_until'] != null ? DateTime.tryParse(map['banned_until'] as String)?.toLocal() : null,
      bannedBy: map['banned_by'] as String? ?? 'Admin',
      reason: map['reason'] as String? ?? 'Violation of Terms',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;
  bool get isConfigured => SupabaseConfig.isConfigured;

  SupabaseClient? get client {
    if (_initialized) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    try {
      final c = Supabase.instance.client;
      _initialized = true;
      return c;
    } catch (_) {
      return null;
    }
  }

  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;
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
    final metaName = metadata?['username'] as String?;
    if (metaName != null && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }
    final local = StorageService.instance.getUsername();
    if (local != null && local.trim().isNotEmpty) {
      return local.trim();
    }
    return currentUser?.email?.split('@').first ?? 'Player';
  }

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      final _ = Supabase.instance.client;
      _initialized = true;
      return true;
    } catch (_) {}

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
      try {
        final _ = Supabase.instance.client;
        _initialized = true;
        return true;
      } catch (_) {}
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
    if (!_initialized || client == null) return 'Could not connect to Supabase.';

    try {
      final res = await client!.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username.trim()},
      ).timeout(const Duration(seconds: 8));
      if (res.user == null) {
        return 'Signup failed. Please check your details.';
      }
      return null; // Success
    } on TimeoutException {
      return 'Connection timed out. Please check your internet connection.';
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
    if (!_initialized || client == null) return 'Could not connect to Supabase.';

    try {
      final res = await client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ).timeout(const Duration(seconds: 8));
      if (res.user == null) {
        return 'Sign in failed. Check your credentials.';
      }
      return null; // Success
    } on TimeoutException {
      return 'Connection timed out. Please check your internet connection.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  // Auth: Reset Password
  Future<String?> resetPassword(String email) async {
    if (!isConfigured) return 'Supabase credentials are not configured.';
    if (!_initialized) await initialize();
    if (!_initialized || client == null) return 'Could not connect to authentication service.';

    try {
      await client!.auth.resetPasswordForEmail(email.trim()).timeout(const Duration(seconds: 8));
      return null;
    } on TimeoutException {
      return 'Connection timed out. Please check your internet connection.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  // Auth: Update Password
  Future<String?> updatePassword(String newPassword) async {
    if (!isConfigured) return 'Supabase credentials are not configured.';
    if (!_initialized) await initialize();
    if (!_initialized || client == null) return 'Could not connect to authentication service.';

    try {
      await client!.auth.updateUser(UserAttributes(password: newPassword.trim())).timeout(const Duration(seconds: 8));
      return null;
    } on TimeoutException {
      return 'Connection timed out. Please check your internet connection.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  // Auth: Sign Out
  Future<void> signOut() async {
    try {
      await client?.auth.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}
    await StorageService.instance.logout();
  }

  // Save game result and sync high scores, levels, and coins
  Future<void> saveGameResult({
    required bool won,
    required int score,
    required int rally,
    int? level,
    int? coins,
  }) async {
    final user = currentUser;
    if (user == null || client == null) return;

    try {
      final userId = user.id;
      final currentStats = await fetchMyStats();

      final newGamesPlayed = (currentStats?.gamesPlayed ?? 0) + 1;
      final newWins = (currentStats?.wins ?? 0) + (won ? 1 : 0);
      final newHighScore = [currentStats?.highScore ?? 0, score].reduce((a, b) => a > b ? a : b);
      final newBestRally = [currentStats?.bestRally ?? 0, rally].reduce((a, b) => a > b ? a : b);
      final newLevel = level ?? (currentStats?.level ?? (1 + newWins));
      final newCoins = coins ?? (currentStats?.coins ?? (newWins * 50));

      final payload = {
        'user_id': userId,
        'username': currentUsername,
        'high_score': newHighScore,
        'best_rally': newBestRally,
        'games_played': newGamesPlayed,
        'wins': newWins,
        'level': newLevel,
        'coins': newCoins,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await client!.from('game_stats').upsert(payload, onConflict: 'user_id').timeout(const Duration(seconds: 6));
      } catch (_) {
        payload.remove('level');
        payload.remove('coins');
        await client!.from('game_stats').upsert(payload, onConflict: 'user_id').timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      debugPrint('Error syncing game result to Supabase: $e');
    }
  }

  // Sync local records on login
  Future<void> syncLocalRecords(int localHighScore, int localBestRally, {int? localLevel, int? localCoins}) async {
    final user = currentUser;
    if (user == null || client == null) return;

    try {
      final currentStats = await fetchMyStats();
      final mergedHighScore = [currentStats?.highScore ?? 0, localHighScore].reduce((a, b) => a > b ? a : b);
      final mergedBestRally = [currentStats?.bestRally ?? 0, localBestRally].reduce((a, b) => a > b ? a : b);
      final mergedLevel = [currentStats?.level ?? 1, localLevel ?? 1].reduce((a, b) => a > b ? a : b);
      final mergedCoins = [currentStats?.coins ?? 0, localCoins ?? 0].reduce((a, b) => a > b ? a : b);

      final payload = {
        'user_id': user.id,
        'username': currentUsername,
        'high_score': mergedHighScore,
        'best_rally': mergedBestRally,
        'games_played': currentStats?.gamesPlayed ?? 0,
        'wins': currentStats?.wins ?? 0,
        'level': mergedLevel,
        'coins': mergedCoins,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await client!.from('game_stats').upsert(payload, onConflict: 'user_id').timeout(const Duration(seconds: 6));
      } catch (_) {
        payload.remove('level');
        payload.remove('coins');
        await client!.from('game_stats').upsert(payload, onConflict: 'user_id').timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      debugPrint('Error syncing local records: $e');
    }
  }

  // Fetch logged-in user stats
  Future<PlayerStats?> fetchMyStats() async {
    final user = currentUser;
    if (user == null || client == null) return null;

    try {
      final data = await client!
          .from('game_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

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
    if (!isConfigured) return [];

    // 1. Try Supabase Client SDK with timeout
    try {
      if (!_initialized) {
        await initialize().timeout(const Duration(seconds: 4));
      }
      if (_initialized && client != null) {
        final data = await client!
            .from('game_stats')
            .select()
            .order(orderBy, ascending: false)
            .limit(limit)
            .timeout(const Duration(seconds: 5));

        final list = (data as List).map((row) => PlayerStats.fromMap(row as Map<String, dynamic>)).toList();
        for (final item in list) {
          StorageService.instance.addKnownUsername(item.username);
        }
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Supabase client SDK fetch notice: $e');
    }

    // 2. Direct REST Fallback (reliable across Windows Desktop, Web, Android, iOS)
    try {
      final uri = Uri.parse(
        '${SupabaseConfig.url}/rest/v1/game_stats?select=*&order=$orderBy.desc&limit=$limit',
      );
      final res = await http.get(
        uri,
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          final list = decoded.map((row) => PlayerStats.fromMap(row as Map<String, dynamic>)).toList();
          for (final item in list) {
            StorageService.instance.addKnownUsername(item.username);
          }
          return list;
        }
      }
    } catch (e) {
      debugPrint('Direct REST fetchLeaderboard fallback error: $e');
    }

    return [];
  }

  // Ban Management (Admin / Owner)
  Future<List<BanRecord>> fetchBannedUsers() async {
    final localList = _loadLocalBans();

    if (!isConfigured) return localList;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        final data = await client!
            .from('banned_users')
            .select()
            .order('created_at', ascending: false);
        final list = data.map((e) => BanRecord.fromMap(e)).toList();
        for (final b in list) {
          StorageService.instance.addKnownUsername(b.username);
        }
        _saveLocalBans(list);
        return list;
      }
    } catch (e) {
      debugPrint('Error fetching banned users via SDK: $e');
    }

    return localList;
  }

  Future<BanRecord?> checkBanStatus(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // 1. Check local cache first for instant feedback
    final localBans = _loadLocalBans();
    final localMatch = localBans.where((b) => b.username.toLowerCase() == clean && b.isActive).toList();
    if (localMatch.isNotEmpty) return localMatch.first;

    if (!isConfigured) return null;

    // 2. Query Supabase
    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        final data = await client!
            .from('banned_users')
            .select()
            .eq('username', clean)
            .maybeSingle()
            .timeout(const Duration(seconds: 6));
        if (data != null) {
          final record = BanRecord.fromMap(data);
          if (record.isActive) {
            final updated = localBans.where((b) => b.username.toLowerCase() != clean).toList()..add(record);
            _saveLocalBans(updated);
            return record;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking ban status: $e');
    }

    return null;
  }

  // --- User Existence Verification ---
  Future<bool> userExists(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return false;

    // 1. Owner & Current user always exist
    if (clean == 'imjustivaan') return true;
    if (clean == currentUsername.toLowerCase()) return true;

    // 2. Check local known accounts & cache
    if (StorageService.instance.isKnownUser(clean)) return true;

    if (!isConfigured) return false;

    // 3. Query Supabase via client SDK
    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        final res = await client!
            .from('game_stats')
            .select('username')
            .ilike('username', clean)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (res != null) {
          await StorageService.instance.addKnownUsername(clean);
          return true;
        }

        final verifiedRes = await client!
            .from('verified_users')
            .select('username')
            .ilike('username', clean)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));
        if (verifiedRes != null) {
          await StorageService.instance.addKnownUsername(clean);
          return true;
        }

        final bannedRes = await client!
            .from('banned_users')
            .select('username')
            .ilike('username', clean)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));
        if (bannedRes != null) {
          await StorageService.instance.addKnownUsername(clean);
          return true;
        }
      }
    } catch (e) {
      debugPrint('SDK notice in userExists: $e');
    }

    // 4. Direct REST fallback
    try {
      final encoded = Uri.encodeComponent(clean);
      final uri = Uri.parse(
        '${SupabaseConfig.url}/rest/v1/game_stats?select=username&username=ilike.$encoded&limit=1',
      );
      final res = await http.get(
        uri,
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty) {
          await StorageService.instance.addKnownUsername(clean);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Direct REST userExists fallback notice: $e');
    }

    return false;
  }

  Future<String?> banUser({
    required String username,
    required Duration? duration,
    required String reason,
    required String bannedBy,
  }) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return 'Username cannot be empty';

    if (clean == 'imjustivaan') {
      return 'Cannot ban the owner of the game!';
    }

    final exists = await userExists(clean);
    if (!exists) {
      return 'User "@$username" does not exist! Cannot ban a non-existent account.';
    }

    final now = DateTime.now();
    final bannedUntil = duration != null ? now.add(duration) : null;
    final record = BanRecord(
      username: clean,
      bannedUntil: bannedUntil,
      bannedBy: bannedBy,
      reason: reason.trim().isEmpty ? 'Violation of Terms' : reason.trim(),
      createdAt: now,
    );

    // Save locally
    final currentBans = _loadLocalBans().where((b) => b.username.toLowerCase() != clean).toList();
    currentBans.insert(0, record);
    _saveLocalBans(currentBans);

    if (!isConfigured) return null;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        await client!.from('banned_users').upsert(record.toMap(), onConflict: 'username').timeout(const Duration(seconds: 8));
        return null;
      }
    } catch (e) {
      debugPrint('Notice saving ban to Supabase: $e');
    }

    return null;
  }

  Future<String?> unbanUser(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return 'Invalid username';

    // Remove locally
    final currentBans = _loadLocalBans().where((b) => b.username.toLowerCase() != clean).toList();
    _saveLocalBans(currentBans);

    if (!isConfigured) return null;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        await client!.from('banned_users').delete().eq('username', clean).timeout(const Duration(seconds: 6));
        return null;
      }
    } catch (e) {
      debugPrint('Notice deleting ban from Supabase: $e');
    }
    return null;
  }

  List<BanRecord> _loadLocalBans() {
    try {
      final jsonList = StorageService.instance.getLocalBannedUsersJson();
      return jsonList.map((str) => BanRecord.fromMap(jsonDecode(str) as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  void _saveLocalBans(List<BanRecord> list) {
    try {
      final jsonList = list.map((b) => jsonEncode(b.toMap())).toList();
      StorageService.instance.saveLocalBannedUsersJson(jsonList);
    } catch (_) {}
  }

  // --- Verified Users Management ---
  Future<List<String>> fetchVerifiedUsers() async {
    final local = StorageService.instance.getLocalVerifiedUsers();
    if (!isConfigured) return local;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        final data = await client!
            .from('verified_users')
            .select('username')
            .timeout(const Duration(seconds: 6));
        final list = (data as List)
            .map((e) => (e['username'] as String? ?? '').toLowerCase().trim())
            .where((u) => u.isNotEmpty)
            .toList();
        if (!list.contains('imjustivaan')) list.add('imjustivaan');
        for (final u in list) {
          StorageService.instance.addKnownUsername(u);
        }
        await StorageService.instance.saveLocalVerifiedUsers(list);
        return list;
      }
    } catch (e) {
      debugPrint('Notice fetching verified users from Supabase: $e');
    }
    return local;
  }

  Future<bool> checkVerifiedStatus(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean == 'imjustivaan') return true;
    if (StorageService.instance.isLocalVerified(clean)) return true;

    if (!isConfigured) return false;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        final data = await client!
            .from('verified_users')
            .select('username')
            .eq('username', clean)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        if (data != null) {
          final current = StorageService.instance.getLocalVerifiedUsers();
          if (!current.contains(clean)) {
            current.add(clean);
            await StorageService.instance.saveLocalVerifiedUsers(current);
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('Notice checking verified status: $e');
    }
    return false;
  }

  Future<String?> setVerifiedStatus({
    required String username,
    required bool isVerified,
    String? setBy,
  }) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return 'Username cannot be empty';

    if (isVerified) {
      final exists = await userExists(clean);
      if (!exists) {
        return 'User "@$username" does not exist! Cannot verify a non-existent account.';
      }

      final local = StorageService.instance.getLocalVerifiedUsers();
      if (!local.contains(clean)) {
        local.add(clean);
        await StorageService.instance.saveLocalVerifiedUsers(local);
      }
      // Also automatically award them the exclusive Verified Legend skin!
      await grantSkinToUser(
        username: clean,
        skinId: 'verified_legend',
        grantedBy: setBy ?? 'Admin',
      );
    } else {
      if (clean == 'imjustivaan') {
        return 'Cannot unverify the system owner!';
      }
      final local = StorageService.instance.getLocalVerifiedUsers();
      local.remove(clean);
      await StorageService.instance.saveLocalVerifiedUsers(local);
    }

    if (!isConfigured) return null;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        if (isVerified) {
          await client!.from('verified_users').upsert({
            'username': clean,
            'verified_at': DateTime.now().toUtc().toIso8601String(),
            'verified_by': setBy ?? 'ImJustIvaan',
          }, onConflict: 'username').timeout(const Duration(seconds: 6));
        } else {
          await client!.from('verified_users').delete().eq('username', clean).timeout(const Duration(seconds: 6));
        }
      }
    } catch (e) {
      debugPrint('Notice updating verified user in Supabase: $e');
    }
    return null;
  }

  // --- Admin Granted Skins Management ---
  Future<List<String>> fetchGrantedSkins(String username) async {
    final clean = username.trim().toLowerCase();
    final local = StorageService.instance.getLocalGrantedSkins(clean);
    if (!isConfigured) return local;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        final data = await client!
            .from('granted_skins')
            .select('skin_id')
            .eq('username', clean)
            .timeout(const Duration(seconds: 6));
        final list = (data as List)
            .map((e) => (e['skin_id'] as String? ?? '').trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
        for (final s in list) {
          await StorageService.instance.saveLocalGrantedSkin(clean, s);
          if (clean == currentUsername.toLowerCase()) {
            await StorageService.instance.addOwnedSkin(s);
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('Notice fetching granted skins: $e');
    }
    return local;
  }

  Future<String?> grantSkinToUser({
    required String username,
    required String skinId,
    required String grantedBy,
  }) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return 'Username cannot be empty';
    if (skinId.isEmpty) return 'Skin ID cannot be empty';

    final exists = await userExists(clean);
    if (!exists) {
      return 'User "@$username" does not exist! Please check the spelling.';
    }

    // Update local cache
    await StorageService.instance.saveLocalGrantedSkin(clean, skinId);
    if (clean == currentUsername.toLowerCase()) {
      await StorageService.instance.addOwnedSkin(skinId);
    }

    if (!isConfigured) return null;

    try {
      if (!_initialized) await initialize().timeout(const Duration(seconds: 4));
      if (_initialized && client != null) {
        await client!.from('granted_skins').upsert({
          'username': clean,
          'skin_id': skinId,
          'granted_by': grantedBy,
          'granted_at': DateTime.now().toUtc().toIso8601String(),
        }).timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      debugPrint('Notice saving granted skin to Supabase: $e');
    }
    return null;
  }
}

