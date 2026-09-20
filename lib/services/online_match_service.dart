import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

enum OnlineRole {
  host,
  guest,
}

enum OnlineConnectionState {
  idle,
  connecting,
  waitingForGuest,
  connected,
  inGame,
  disconnected,
  error,
}

class OnlineMatchService {
  static final OnlineMatchService instance = OnlineMatchService._();
  OnlineMatchService._();

  RealtimeChannel? _channel;
  String? _currentGameId;
  OnlineRole? _currentRole;
  OnlineConnectionState _state = OnlineConnectionState.idle;
  String? _opponentUsername;
  String? _errorMessage;

  // Callbacks
  void Function(OnlineConnectionState state)? onStateChanged;
  void Function(Map<String, dynamic> data)? onGameStateReceived;
  void Function(double paddleY)? onPaddleMoveReceived;
  void Function(String opponentName)? onOpponentJoined;
  void Function(int winner)? onGameOverReceived;
  void Function()? onOpponentDisconnected;

  OnlineConnectionState get state => _state;
  String? get currentGameId => _currentGameId;
  OnlineRole? get currentRole => _currentRole;
  String? get opponentUsername => _opponentUsername;
  String? get errorMessage => _errorMessage;
  bool get isHost => _currentRole == OnlineRole.host;

  /// Generates a clean, readable 6-character random game ID
  static String generateGameId() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Builds the required shareable URL: `https://pong.ivaan.cc/join/<game-id>`
  static String buildShareLink(String gameId) {
    return 'https://pong.ivaan.cc/join/$gameId';
  }

  /// Extracts game ID from a full join URL or raw code
  static String extractGameId(String input) {
    var trimmed = input.trim();
    if (trimmed.contains('pong.ivaan.cc/join/')) {
      trimmed = trimmed.split('pong.ivaan.cc/join/').last;
    } else if (trimmed.contains('/join/')) {
      trimmed = trimmed.split('/join/').last;
    }
    // Remove query params or trailing slashes
    trimmed = trimmed.split('?').first.split('#').first.replaceAll('/', '').trim();
    return trimmed.toLowerCase();
  }

  void _setState(OnlineConnectionState newState) {
    _state = newState;
    onStateChanged?.call(_state);
  }

  /// Host creates and hosts a match
  Future<bool> hostMatch({
    required String gameId,
    required String hostUsername,
    required int targetScore,
  }) async {
    await leaveMatch();
    _currentGameId = gameId.toLowerCase().trim();
    _currentRole = OnlineRole.host;
    _opponentUsername = null;
    _errorMessage = null;
    _setState(OnlineConnectionState.connecting);

    final client = SupabaseService.instance.client;
    if (client == null) {
      _errorMessage = 'Online service unavailable. Check network.';
      _setState(OnlineConnectionState.error);
      return false;
    }

    try {
      final channelName = 'pong_room_$_currentGameId';
      _channel = client.channel(
        channelName,
        opts: const RealtimeChannelConfig(ack: false),
      );

      _channel!.onBroadcast(
        event: 'guest_join',
        callback: (payload) {
          final guestName = payload['username'] as String? ?? 'Player 2';
          _opponentUsername = guestName;
          _setState(OnlineConnectionState.connected);
          onOpponentJoined?.call(guestName);

          // Respond to guest with match info
          sendHostReady(hostUsername: hostUsername, targetScore: targetScore);
        },
      );

      _channel!.onBroadcast(
        event: 'paddle2_move',
        callback: (payload) {
          final y = (payload['y'] as num?)?.toDouble();
          if (y != null) {
            onPaddleMoveReceived?.call(y);
          }
        },
      );

      _channel!.onBroadcast(
        event: 'player_disconnect',
        callback: (_) {
          onOpponentDisconnected?.call();
          _setState(OnlineConnectionState.disconnected);
        },
      );

      _channel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _setState(OnlineConnectionState.waitingForGuest);
        } else if (status == RealtimeSubscribeStatus.timedOut || status == RealtimeSubscribeStatus.channelError) {
          _errorMessage = error?.toString() ?? 'Failed to connect to matchmaking server.';
          _setState(OnlineConnectionState.error);
        }
      });

      return true;
    } catch (e) {
      _errorMessage = 'Failed to create room: $e';
      _setState(OnlineConnectionState.error);
      return false;
    }
  }

  /// Guest joins an existing match
  Future<bool> joinMatch({
    required String gameId,
    required String guestUsername,
    required void Function(int targetScore) onMatchReady,
  }) async {
    await leaveMatch();
    _currentGameId = extractGameId(gameId);
    _currentRole = OnlineRole.guest;
    _opponentUsername = null;
    _errorMessage = null;
    _setState(OnlineConnectionState.connecting);

    final client = SupabaseService.instance.client;
    if (client == null) {
      _errorMessage = 'Online service unavailable. Check network.';
      _setState(OnlineConnectionState.error);
      return false;
    }

    try {
      final channelName = 'pong_room_$_currentGameId';
      _channel = client.channel(
        channelName,
        opts: const RealtimeChannelConfig(ack: false),
      );

      _channel!.onBroadcast(
        event: 'host_ready',
        callback: (payload) {
          final hostName = payload['username'] as String? ?? 'Host';
          final target = (payload['targetScore'] as num?)?.toInt() ?? 10;
          _opponentUsername = hostName;
          _setState(OnlineConnectionState.connected);
          onMatchReady(target);
        },
      );

      _channel!.onBroadcast(
        event: 'game_state_sync',
        callback: (payload) {
          onGameStateReceived?.call(payload);
        },
      );

      _channel!.onBroadcast(
        event: 'game_over_sync',
        callback: (payload) {
          final winner = (payload['winner'] as num?)?.toInt() ?? 1;
          onGameOverReceived?.call(winner);
        },
      );

      _channel!.onBroadcast(
        event: 'player_disconnect',
        callback: (_) {
          onOpponentDisconnected?.call();
          _setState(OnlineConnectionState.disconnected);
        },
      );

      _channel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          // Announce guest arrival to host
          _channel!.sendBroadcastMessage(
            event: 'guest_join',
            payload: {'username': guestUsername},
          );
        } else if (status == RealtimeSubscribeStatus.timedOut || status == RealtimeSubscribeStatus.channelError) {
          _errorMessage = error?.toString() ?? 'Matchroom not found or server error.';
          _setState(OnlineConnectionState.error);
        }
      });

      return true;
    } catch (e) {
      _errorMessage = 'Failed to join match: $e';
      _setState(OnlineConnectionState.error);
      return false;
    }
  }

  /// Host sends host_ready signal to guest
  void sendHostReady({required String hostUsername, required int targetScore}) {
    if (_channel == null) return;
    _channel!.sendBroadcastMessage(
      event: 'host_ready',
      payload: {
        'username': hostUsername,
        'targetScore': targetScore,
      },
    );
  }

  /// Host broadcasts authoritative physics state (ball, paddle1, scores)
  void broadcastGameState({
    required double ballX,
    required double ballY,
    required double ballVx,
    required double ballVy,
    required double paddle1Y,
    required int score1,
    required int score2,
    required int currentRally,
    required String gameState,
  }) {
    if (_channel == null || _currentRole != OnlineRole.host) return;
    _channel!.sendBroadcastMessage(
      event: 'game_state_sync',
      payload: {
        'bx': ballX,
        'by': ballY,
        'bvx': ballVx,
        'bvy': ballVy,
        'p1y': paddle1Y,
        's1': score1,
        's2': score2,
        'rally': currentRally,
        'st': gameState,
      },
    );
  }

  /// Guest sends paddle 2 position updates to host
  void sendGuestPaddleMove(double paddle2Y) {
    if (_channel == null || _currentRole != OnlineRole.guest) return;
    _channel!.sendBroadcastMessage(
      event: 'paddle2_move',
      payload: {'y': paddle2Y},
    );
  }

  /// Host broadcasts match completion
  void broadcastGameOver(int winner) {
    if (_channel == null || _currentRole != OnlineRole.host) return;
    _channel!.sendBroadcastMessage(
      event: 'game_over_sync',
      payload: {'winner': winner},
    );
  }

  /// Disconnect and clean up
  Future<void> leaveMatch() async {
    try {
      if (_channel != null) {
        try {
          await _channel!.sendBroadcastMessage(
            event: 'player_disconnect',
            payload: {'role': _currentRole?.name},
          );
        } catch (_) {}

        final client = SupabaseService.instance.client;
        if (client != null) {
          await client.removeChannel(_channel!);
        }
      }
    } catch (e) {
      debugPrint('Error leaving match: $e');
    } finally {
      _channel = null;
      _currentGameId = null;
      _currentRole = null;
      _opponentUsername = null;
      _errorMessage = null;
      _setState(OnlineConnectionState.idle);
    }
  }
}
