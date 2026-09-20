import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../game/game_theme.dart';
import '../game/paddle_skin.dart';
import '../game/pong_engine.dart';
import '../services/fullscreen_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/online_match_service.dart';
import '../utils/user_utils.dart';
import '../widgets/pong_canvas.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final AiDifficulty difficulty;
  final int targetScore;
  final PongTheme theme;
  final bool isOnlineHost;
  final String? onlineRoomId;
  final String? opponentUsername;

  const GameScreen({
    super.key,
    required this.mode,
    this.difficulty = AiDifficulty.medium,
    required this.targetScore,
    required this.theme,
    this.isOnlineHost = false,
    this.onlineRoomId,
    this.opponentUsername,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final PongEngine _engine;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Keyboard control states
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final FocusNode _focusNode = FocusNode();

  bool _opponentDisconnected = false;
  double _lastBroadcastTime = 0.0;
  double _elapsedTime = 0.0;

  int? _earnedCoins;
  int? _earnedLevel;
  int _totalCoins = 0;

  bool get _isOwner => UserUtils.isOwner(SupabaseService.instance.currentUsername);

  @override
  void initState() {
    super.initState();
    _totalCoins = StorageService.instance.getCoins();
    _engine = PongEngine(
      mode: widget.mode,
      difficulty: widget.difficulty,
      targetScore: widget.targetScore,
    );

    if (_isOwner) {
      _engine.ownerAutoPlay = StorageService.instance.getOwnerAutoPlay();
    }

    _engine.onPaddleHit = () => SoundService.instance.playPaddleHit();
    _engine.onWallBounce = () => SoundService.instance.playWallBounce();
    _engine.onScore = () => SoundService.instance.playScore();
    _engine.onGameOver = () {
      SoundService.instance.playGameOver();
      _saveRecords();
    };

    if (widget.mode == GameMode.onlineMultiplayer) {
      if (widget.isOnlineHost) {
        OnlineMatchService.instance.onPaddleMoveReceived = (y) {
          _engine.paddle2Y = y;
        };
      } else {
        OnlineMatchService.instance.onGameStateReceived = (data) {
          _engine.applyOnlineSync(
            bx: (data['bx'] as num).toDouble(),
            by: (data['by'] as num).toDouble(),
            bvx: (data['bvx'] as num).toDouble(),
            bvy: (data['bvy'] as num).toDouble(),
            p1y: (data['p1y'] as num).toDouble(),
            s1: (data['s1'] as num).toInt(),
            s2: (data['s2'] as num).toInt(),
            rally: (data['rally'] as num).toInt(),
            st: data['st'] as String? ?? 'playing',
          );
        };
        OnlineMatchService.instance.onGameOverReceived = (winner) {
          _engine.winner = winner;
          _engine.state = GameState.gameOver;
          SoundService.instance.playGameOver();
          _saveRecords();
        };
      }

      OnlineMatchService.instance.onOpponentDisconnected = () {
        if (mounted) {
          setState(() {
            _opponentDisconnected = true;
          });
        }
      };
    }

    _ticker = createTicker(_onTick)..start();
  }

  void _toggleOwnerAutoPlay() {
    if (!_isOwner) return;
    setState(() {
      _engine.ownerAutoPlay = !_engine.ownerAutoPlay;
      StorageService.instance.saveOwnerAutoPlay(_engine.ownerAutoPlay);
    });
  }

  void _saveRecords() async {
    if (widget.mode == GameMode.practice) {
      StorageService.instance.saveBestRally(_engine.maxRally);
      SupabaseService.instance.saveGameResult(
        won: false,
        score: 0,
        rally: _engine.maxRally,
      );
      return;
    } 
    
    if (widget.mode == GameMode.twoPlayer) {
      // Unranked Casual Local 2-Player: strictly do not record wins, scores, levels, or coins
      return;
    }

    final bool won;
    final int myScore;

    if (widget.mode == GameMode.onlineMultiplayer) {
      // Ranked Online 1v1 PvP
      won = widget.isOnlineHost ? (_engine.winner == 1) : (_engine.winner == 2);
      myScore = widget.isOnlineHost ? _engine.score1 : _engine.score2;
    } else {
      // Single Player vs AI
      won = _engine.winner == 1;
      myScore = _engine.score1;
    }

    int? newLevel;
    int? newCoins;

    if (won) {
      StorageService.instance.saveHighScore(myScore);
      await StorageService.instance.addKills(myScore);
      await StorageService.instance.addWins(1);
      newLevel = await StorageService.instance.incrementLevel();
      const reward = 50;
      newCoins = await StorageService.instance.addCoins(reward);
      if (mounted) {
        setState(() {
          _earnedLevel = newLevel;
          _earnedCoins = reward;
          _totalCoins = newCoins!;
        });
      }
    } else {
      _totalCoins = StorageService.instance.getCoins();
      if (myScore > 0) {
        await StorageService.instance.addKills(myScore);
      }
    }

    SupabaseService.instance.saveGameResult(
      won: won,
      score: myScore,
      rally: _engine.maxRally,
      level: newLevel ?? StorageService.instance.getLevel(),
      coins: newCoins ?? StorageService.instance.getCoins(),
      kills: StorageService.instance.getKills(),
      wins: StorageService.instance.getWins(),
    );
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    // Safety clamp dt to avoid physics leaps on lag
    final safeDt = dt.clamp(0.0, 0.04);
    _elapsedTime += safeDt;

    _handleKeyboardMovement(safeDt);

    if (widget.mode == GameMode.onlineMultiplayer) {
      if (widget.isOnlineHost) {
        _engine.update(safeDt);
        if (_elapsedTime - _lastBroadcastTime >= 0.033) {
          _lastBroadcastTime = _elapsedTime;
          OnlineMatchService.instance.broadcastGameState(
            ballX: _engine.ballX,
            ballY: _engine.ballY,
            ballVx: _engine.ballVx,
            ballVy: _engine.ballVy,
            paddle1Y: _engine.paddle1Y,
            score1: _engine.score1,
            score2: _engine.score2,
            currentRally: _engine.currentRally,
            gameState: _engine.state.name,
          );
        }
        if (_engine.state == GameState.gameOver) {
          OnlineMatchService.instance.broadcastGameOver(_engine.winner ?? 1);
        }
      } else {
        // Guest mode: update visual screen shake
        if (_engine.screenShakeIntensity > 0) {
          _engine.screenShakeIntensity = (_engine.screenShakeIntensity - safeDt * 5.0).clamp(0.0, 1.0);
        }
      }
    } else {
      _engine.update(safeDt);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleKeyboardMovement(double dt) {
    if (_engine.ownerAutoPlay) {
      // In Owner Auto-Play mode, Paddle 1 is automatically piloted
      if (widget.mode == GameMode.twoPlayer) {
        const keySpeed = 1.0;
        if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
          _engine.movePaddleDelta(2, -keySpeed * dt);
        }
        if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
          _engine.movePaddleDelta(2, keySpeed * dt);
        }
      }
      return;
    }

    const keySpeed = 1.0;
    // Player 1 controls: W / S or Up / Down (in 1P mode or if online Host)
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        ((widget.mode == GameMode.singlePlayer || (widget.mode == GameMode.onlineMultiplayer && widget.isOnlineHost)) &&
            _pressedKeys.contains(LogicalKeyboardKey.arrowUp))) {
      _engine.movePaddleDelta(1, -keySpeed * dt);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        ((widget.mode == GameMode.singlePlayer || (widget.mode == GameMode.onlineMultiplayer && widget.isOnlineHost)) &&
            _pressedKeys.contains(LogicalKeyboardKey.arrowDown))) {
      _engine.movePaddleDelta(1, keySpeed * dt);
    }

    // Player 2 controls: Up / Down (in 2P mode or if online Guest)
    if (widget.mode == GameMode.twoPlayer) {
      if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
        _engine.movePaddleDelta(2, -keySpeed * dt);
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
        _engine.movePaddleDelta(2, keySpeed * dt);
      }
    } else if (widget.mode == GameMode.onlineMultiplayer && !widget.isOnlineHost) {
      if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp) || _pressedKeys.contains(LogicalKeyboardKey.keyW)) {
        _engine.movePaddleDelta(2, -keySpeed * dt);
        OnlineMatchService.instance.sendGuestPaddleMove(_engine.paddle2Y);
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown) || _pressedKeys.contains(LogicalKeyboardKey.keyS)) {
        _engine.movePaddleDelta(2, keySpeed * dt);
        OnlineMatchService.instance.sendGuestPaddleMove(_engine.paddle2Y);
      }
    }
  }

  @override
  void dispose() {
    if (widget.mode == GameMode.onlineMultiplayer) {
      OnlineMatchService.instance.leaveMatch();
    }
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPos, Size screenSize) {
    if (_engine.ownerAutoPlay && widget.mode != GameMode.twoPlayer) {
      // In Owner Auto-Play, paddle 1 is locked to auto-pilot
      return;
    }

    final normalizedX = localPos.dx / screenSize.width;
    final normalizedY = localPos.dy / screenSize.height;

    if (widget.mode == GameMode.twoPlayer) {
      if (normalizedX < 0.5) {
        if (!_engine.ownerAutoPlay) {
          _engine.movePaddle(1, normalizedY);
        }
      } else {
        _engine.movePaddle(2, normalizedY);
      }
    } else if (widget.mode == GameMode.onlineMultiplayer) {
      if (widget.isOnlineHost) {
        _engine.movePaddle(1, normalizedY);
      } else {
        _engine.movePaddle(2, normalizedY);
        OnlineMatchService.instance.sendGuestPaddleMove(_engine.paddle2Y);
      }
    } else {
      // 1P or Practice: touching anywhere or left half controls paddle 1
      _engine.movePaddle(1, normalizedY);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 640;
    final double scale = isMobile
        ? (screenSize.width / 400.0).clamp(0.75, 0.95)
        : (screenSize.height / 680.0).clamp(0.9, 1.55);

    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            _pressedKeys.add(event.logicalKey);
            if (event.logicalKey == LogicalKeyboardKey.space) {
              if (_engine.state == GameState.ready) {
                _engine.startOrServe();
              } else {
                _engine.togglePause();
              }
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
            } else if (event.logicalKey == LogicalKeyboardKey.keyA ||
                       event.logicalKey == LogicalKeyboardKey.keyO) {
              if (_isOwner) {
                _toggleOwnerAutoPlay();
              }
            } else if (event.logicalKey == LogicalKeyboardKey.f11) {
              FullscreenService.instance.toggle();
            }
          } else if (event is KeyUpEvent) {
            _pressedKeys.remove(event.logicalKey);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (_engine.state == GameState.ready) {
              _engine.startOrServe();
            }
            _handleTouch(details.localPosition, screenSize);
          },
          onPanUpdate: (details) {
            _handleTouch(details.localPosition, screenSize);
          },
          child: Stack(
            children: [
              // Canvas
              PongCanvas(
                engine: _engine,
                theme: widget.theme,
                skin1: PaddleSkinCatalog.byId(StorageService.instance.getEquippedSkin()),
              ),

              // HUD & Scores
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : (20 * scale.clamp(1.0, 1.3)).roundToDouble(),
                    vertical: isMobile ? 6 : (12 * scale.clamp(1.0, 1.3)).roundToDouble(),
                  ),
                  child: Column(
                    children: [
                      // Top Row: Back, Rally/Scores, Auto-Play Toggle & Pause
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: isMobile ? 18 : 22),
                            padding: EdgeInsets.all(isMobile ? 4 : 8),
                            constraints: isMobile ? const BoxConstraints() : null,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          _buildScoreHeader(scale, isMobile),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isOwner)
                                GestureDetector(
                                  onTap: _toggleOwnerAutoPlay,
                                  child: Container(
                                    margin: EdgeInsets.only(right: isMobile ? 4 : 8),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 6 : 10,
                                      vertical: isMobile ? 4 : 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _engine.ownerAutoPlay
                                          ? const Color(0xFF00E5FF).withValues(alpha: 0.22)
                                          : Colors.black54,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _engine.ownerAutoPlay
                                            ? const Color(0xFF00E5FF)
                                            : Colors.white30,
                                        width: 1.2,
                                      ),
                                      boxShadow: _engine.ownerAutoPlay
                                          ? [
                                              const BoxShadow(
                                                color: Color(0x6600E5FF),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt,
                                          size: isMobile ? 14 : 15,
                                          color: _engine.ownerAutoPlay
                                              ? const Color(0xFF00E5FF)
                                              : Colors.white60,
                                        ),
                                        if (!isMobile) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            _engine.ownerAutoPlay ? 'AUTO ON' : 'AUTO OFF',
                                            style: TextStyle(
                                              color: _engine.ownerAutoPlay
                                                  ? const Color(0xFF00E5FF)
                                                  : Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ValueListenableBuilder<bool>(
                                valueListenable: FullscreenService.instance.isFullScreen,
                                builder: (context, isFs, _) {
                                  return IconButton(
                                    tooltip: isFs ? 'Exit Fullscreen' : 'Fullscreen',
                                    padding: EdgeInsets.all(isMobile ? 4 : 8),
                                    constraints: isMobile ? const BoxConstraints() : null,
                                    icon: Icon(
                                      isFs ? Icons.fullscreen_exit : Icons.fullscreen,
                                      color: Colors.white70,
                                      size: isMobile ? 18 : 22,
                                    ),
                                    onPressed: () => FullscreenService.instance.toggle(),
                                  );
                                },
                              ),
                              IconButton(
                                padding: EdgeInsets.all(isMobile ? 4 : 8),
                                constraints: isMobile ? const BoxConstraints() : null,
                                icon: Icon(
                                  _engine.state == GameState.paused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white70,
                                  size: isMobile ? 18 : 22,
                                ),
                                onPressed: () => _engine.togglePause(),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Owner Auto-Play indicator
                      if (_isOwner && _engine.ownerAutoPlay)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: Color(0xFF00E5FF)),
                              SizedBox(width: 5),
                              Text(
                                'OWNER AUTO-PLAY: AUTO SERVE & BLOCK (Press A)',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Spacer(),
                      // Bottom help / rally status
                      if (_engine.currentRally > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: widget.theme.paddle1Color.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'RALLY: ${_engine.currentRally}  (Speed: ${(_engine.speedMultiplier * 100).toInt()}%)',
                            style: TextStyle(
                              color: widget.theme.ballColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Ready to serve prompt
              if (_engine.state == GameState.ready && !(_isOwner && _engine.ownerAutoPlay))
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: (24 * scale).roundToDouble(),
                      vertical: (12 * scale).roundToDouble(),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16 * scale),
                      border: Border.all(color: widget.theme.paddle1Color.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      'TAP SCREEN OR PRESS SPACE TO SERVE',
                      style: TextStyle(
                        color: widget.theme.paddle1Color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5 * scale,
                        fontSize: (14 * scale).roundToDouble(),
                      ),
                    ),
                  ),
                ),

              // Pause Overlay
              if (_engine.state == GameState.paused)
                _buildOverlay(
                  scale: scale,
                  title: 'GAME PAUSED',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: _buttonStyle(widget.theme.paddle1Color, scale),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('RESUME'),
                        onPressed: () => _engine.togglePause(),
                      ),
                      if (_isOwner) ...[
                        SizedBox(height: 12 * scale),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _engine.ownerAutoPlay ? const Color(0xFF00E5FF) : Colors.white70,
                            side: BorderSide(
                              color: _engine.ownerAutoPlay ? const Color(0xFF00E5FF) : Colors.white30,
                              width: 1.5,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: (18 * scale).roundToDouble(),
                              vertical: (12 * scale).roundToDouble(),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
                          ),
                          icon: Icon(
                            Icons.bolt,
                            color: _engine.ownerAutoPlay ? const Color(0xFF00E5FF) : Colors.white70,
                          ),
                          label: Text(
                            'OWNER AUTO-PLAY: ${_engine.ownerAutoPlay ? "ACTIVE" : "DISABLED"}',
                            style: TextStyle(
                              color: _engine.ownerAutoPlay ? const Color(0xFF00E5FF) : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _toggleOwnerAutoPlay,
                        ),
                      ],
                      SizedBox(height: 12 * scale),
                      OutlinedButton.icon(
                        style: _outlineButtonStyle(scale),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('RESTART', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          setState(() {
                            _engine.score1 = 0;
                            _engine.score2 = 0;
                            _engine.currentRally = 0;
                            _engine.state = GameState.ready;
                            _engine.resetServe(servingToPlayer: 1);
                          });
                        },
                      ),
                      SizedBox(height: 12 * scale),
                      ValueListenableBuilder<bool>(
                        valueListenable: FullscreenService.instance.isFullScreen,
                        builder: (context, isFs, _) {
                          return OutlinedButton.icon(
                            style: _outlineButtonStyle(scale),
                            icon: Icon(
                              isFs ? Icons.fullscreen_exit : Icons.fullscreen,
                              color: Colors.white,
                            ),
                            label: Text(
                              isFs ? 'EXIT FULLSCREEN' : 'FULLSCREEN',
                              style: const TextStyle(color: Colors.white),
                            ),
                            onPressed: () => FullscreenService.instance.toggle(),
                          );
                        },
                      ),
                      SizedBox(height: 12 * scale),
                      TextButton.icon(
                        icon: const Icon(Icons.home, color: Colors.white70),
                        label: const Text('EXIT TO MENU', style: TextStyle(color: Colors.white70)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

              // Opponent Disconnected Overlay
              if (_opponentDisconnected)
                _buildOverlay(
                  scale: scale,
                  title: 'OPPONENT DISCONNECTED',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, color: Color(0xFFFF1744), size: 48),
                      const SizedBox(height: 14),
                      const Text(
                        'Your opponent disconnected from the match.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: _buttonStyle(widget.theme.paddle1Color, scale),
                        icon: const Icon(Icons.home),
                        label: const Text('RETURN TO MENU'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

              // Game Over Overlay
              if (_engine.state == GameState.gameOver && !_opponentDisconnected)
                _buildOverlay(
                  scale: scale,
                  title: _getGameOverTitle(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_engine.score1}  -  ${_engine.score2}',
                        style: TextStyle(
                          color: widget.theme.ballColor,
                          fontSize: (38 * scale).roundToDouble(),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4 * scale,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        'Max Rally: ${_engine.maxRally}',
                        style: TextStyle(color: Colors.white70, fontSize: (14 * scale).roundToDouble()),
                      ),
                      if (_earnedLevel != null && _earnedCoins != null) ...[
                        SizedBox(height: 14 * scale),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: (16 * scale).roundToDouble(),
                            vertical: (10 * scale).roundToDouble(),
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0x3300FF88), Color(0x33FFD700)],
                            ),
                            borderRadius: BorderRadius.circular(14 * scale),
                            border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Color(0x44FFD700), blurRadius: 12, spreadRadius: 1),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_circle_up, color: Color(0xFF00FF88), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'LEVEL UP!  LV. $_earnedLevel',
                                    style: TextStyle(
                                      color: const Color(0xFF00FF88),
                                      fontWeight: FontWeight.w900,
                                      fontSize: (13 * scale).roundToDouble(),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+$_earnedCoins COINS!  (Total: $_totalCoins)',
                                    style: TextStyle(
                                      color: const Color(0xFFFFD700),
                                      fontWeight: FontWeight.w900,
                                      fontSize: (12 * scale).roundToDouble(),
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 20 * scale),
                      if (widget.mode != GameMode.onlineMultiplayer) ...[
                        ElevatedButton.icon(
                          style: _buttonStyle(widget.theme.paddle1Color, scale),
                          icon: const Icon(Icons.replay),
                          label: const Text('PLAY AGAIN'),
                          onPressed: () {
                            setState(() {
                              _engine.score1 = 0;
                              _engine.score2 = 0;
                              _engine.currentRally = 0;
                              _engine.winner = null;
                              _engine.state = GameState.ready;
                              _engine.resetServe(servingToPlayer: 1);
                            });
                          },
                        ),
                        SizedBox(height: 12 * scale),
                      ],
                      OutlinedButton.icon(
                        style: _outlineButtonStyle(scale),
                        icon: const Icon(Icons.home, color: Colors.white),
                        label: const Text('MAIN MENU', style: TextStyle(color: Colors.white)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGameOverTitle() {
    if (widget.mode == GameMode.onlineMultiplayer) {
      final isMeWinner = widget.isOnlineHost ? (_engine.winner == 1) : (_engine.winner == 2);
      return isMeWinner ? 'VICTORY! YOU WON!' : 'DEFEAT! OPPONENT WON!';
    }
    if (_engine.winner == 1) return 'PLAYER 1 WINS!';
    if (widget.mode == GameMode.singlePlayer) return 'AI WINS!';
    return 'PLAYER 2 WINS!';
  }

  Widget _buildScoreHeader(double scale, bool isMobile) {
    if (widget.mode == GameMode.practice) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SCORE: ${_engine.currentRally}',
            style: TextStyle(
              color: widget.theme.ballColor,
              fontSize: (isMobile ? 16 : 24 * scale).roundToDouble(),
              fontWeight: FontWeight.bold,
              letterSpacing: isMobile ? 1.0 : 2 * scale,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 14 * scale),
          Text(
            'BEST: ${_engine.maxRally}',
            style: TextStyle(
              color: widget.theme.paddle1Color,
              fontSize: (isMobile ? 12 : 16 * scale).roundToDouble(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (widget.mode == GameMode.onlineMultiplayer) {
      final myName = SupabaseService.instance.currentUsername.isNotEmpty
          ? SupabaseService.instance.currentUsername
          : 'YOU';
      final oppName = widget.opponentUsername ?? 'OPP';
      final p1Name = widget.isOnlineHost ? myName : oppName;
      final p2Name = widget.isOnlineHost ? oppName : myName;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? 52 : 90),
            child: Text(
              p1Name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.theme.paddle1Color,
                fontSize: (isMobile ? 11 : 13 * scale).roundToDouble(),
                fontWeight: FontWeight.bold,
                letterSpacing: isMobile ? 0.5 : 1.0,
              ),
            ),
          ),
          SizedBox(width: isMobile ? 5 : 10),
          Text(
            '${_engine.score1}',
            style: TextStyle(
              color: widget.theme.paddle1Color,
              fontSize: (isMobile ? 22 : 30 * scale).roundToDouble(),
              fontWeight: FontWeight.w900,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : (12 * scale).roundToDouble()),
            child: Text(
              ':',
              style: TextStyle(
                color: widget.theme.tableLineColor.withValues(alpha: 0.8),
                fontSize: (isMobile ? 18 : 26 * scale).roundToDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${_engine.score2}',
            style: TextStyle(
              color: widget.theme.paddle2Color,
              fontSize: (isMobile ? 22 : 30 * scale).roundToDouble(),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: isMobile ? 5 : 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? 52 : 90),
            child: Text(
              p2Name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.theme.paddle2Color,
                fontSize: (isMobile ? 11 : 13 * scale).roundToDouble(),
                fontWeight: FontWeight.bold,
                letterSpacing: isMobile ? 0.5 : 1.0,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_engine.score1}',
          style: TextStyle(
            color: widget.theme.paddle1Color,
            fontSize: (isMobile ? 24 : 34 * scale).roundToDouble(),
            fontWeight: FontWeight.w900,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : (16 * scale).roundToDouble()),
          child: Text(
            ':',
            style: TextStyle(
              color: widget.theme.tableLineColor.withValues(alpha: 0.8),
              fontSize: (isMobile ? 20 : 28 * scale).roundToDouble(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '${_engine.score2}',
          style: TextStyle(
            color: widget.theme.paddle2Color,
            fontSize: (isMobile ? 24 : 34 * scale).roundToDouble(),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay({required double scale, required String title, required Widget child}) {
    final width = (320 * scale).clamp(320.0, 480.0);
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          width: width,
          padding: EdgeInsets.all((28 * scale).roundToDouble()),
          decoration: BoxDecoration(
            color: widget.theme.backgroundColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24 * scale),
            border: Border.all(color: widget.theme.paddle1Color.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.theme.paddle1Color.withValues(alpha: 0.25),
                blurRadius: 20 * scale,
                spreadRadius: 2 * scale,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.theme.ballColor,
                  fontSize: (22 * scale).roundToDouble(),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2 * scale,
                ),
              ),
              SizedBox(height: 20 * scale),
              child,
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color color, [double scale = 1.0]) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.black,
      minimumSize: Size((220 * scale).roundToDouble(), (48 * scale).roundToDouble()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
      textStyle: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontSize: (14 * scale).roundToDouble(),
      ),
    );
  }

  ButtonStyle _outlineButtonStyle([double scale = 1.0]) {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white38),
      minimumSize: Size((220 * scale).roundToDouble(), (48 * scale).roundToDouble()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
      textStyle: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontSize: (14 * scale).roundToDouble(),
      ),
    );
  }
}
