import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../game/game_theme.dart';
import '../game/pong_engine.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/pong_canvas.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final AiDifficulty difficulty;
  final int targetScore;
  final PongTheme theme;

  const GameScreen({
    super.key,
    required this.mode,
    required this.difficulty,
    required this.targetScore,
    required this.theme,
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

  @override
  void initState() {
    super.initState();
    _engine = PongEngine(
      mode: widget.mode,
      difficulty: widget.difficulty,
      targetScore: widget.targetScore,
    );

    _engine.onPaddleHit = () => SoundService.instance.playPaddleHit();
    _engine.onWallBounce = () => SoundService.instance.playWallBounce();
    _engine.onScore = () => SoundService.instance.playScore();
    _engine.onGameOver = () {
      SoundService.instance.playGameOver();
      _saveRecords();
    };

    _ticker = createTicker(_onTick)..start();
  }

  void _saveRecords() {
    if (widget.mode == GameMode.practice) {
      StorageService.instance.saveBestRally(_engine.maxRally);
      SupabaseService.instance.saveGameResult(
        won: false,
        score: 0,
        rally: _engine.maxRally,
      );
    } else {
      final isWinner = _engine.winner == 1;
      if (isWinner) {
        StorageService.instance.saveHighScore(_engine.score1);
      }
      SupabaseService.instance.saveGameResult(
        won: isWinner,
        score: _engine.score1,
        rally: _engine.maxRally,
      );
    }
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

    _handleKeyboardMovement(safeDt);
    _engine.update(safeDt);

    if (mounted) {
      setState(() {});
    }
  }

  void _handleKeyboardMovement(double dt) {
    const keySpeed = 1.0;
    // Player 1 controls: W / S or Up / Down (in 1P mode)
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        (widget.mode == GameMode.singlePlayer && _pressedKeys.contains(LogicalKeyboardKey.arrowUp))) {
      _engine.movePaddleDelta(1, -keySpeed * dt);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        (widget.mode == GameMode.singlePlayer && _pressedKeys.contains(LogicalKeyboardKey.arrowDown))) {
      _engine.movePaddleDelta(1, keySpeed * dt);
    }

    // Player 2 controls: Up / Down (in 2P mode)
    if (widget.mode == GameMode.twoPlayer) {
      if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
        _engine.movePaddleDelta(2, -keySpeed * dt);
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
        _engine.movePaddleDelta(2, keySpeed * dt);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPos, Size screenSize) {
    final normalizedX = localPos.dx / screenSize.width;
    final normalizedY = localPos.dy / screenSize.height;

    if (widget.mode == GameMode.twoPlayer) {
      if (normalizedX < 0.5) {
        _engine.movePaddle(1, normalizedY);
      } else {
        _engine.movePaddle(2, normalizedY);
      }
    } else {
      // 1P or Practice: touching anywhere or left half controls paddle 1
      _engine.movePaddle(1, normalizedY);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
              ),

              // HUD & Scores
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      // Top Row: Back, Rally/Scores, Pause
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          _buildScoreHeader(),
                          IconButton(
                            icon: Icon(
                              _engine.state == GameState.paused ? Icons.play_arrow : Icons.pause,
                              color: Colors.white70,
                            ),
                            onPressed: () => _engine.togglePause(),
                          ),
                        ],
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
              if (_engine.state == GameState.ready)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.theme.paddle1Color.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      'TAP SCREEN OR PRESS SPACE TO SERVE',
                      style: TextStyle(
                        color: widget.theme.paddle1Color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              // Pause Overlay
              if (_engine.state == GameState.paused)
                _buildOverlay(
                  title: 'GAME PAUSED',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: _buttonStyle(widget.theme.paddle1Color),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('RESUME'),
                        onPressed: () => _engine.togglePause(),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: _outlineButtonStyle(),
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
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.home, color: Colors.white70),
                        label: const Text('EXIT TO MENU', style: TextStyle(color: Colors.white70)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

              // Game Over Overlay
              if (_engine.state == GameState.gameOver)
                _buildOverlay(
                  title: _engine.winner == 1 ? 'PLAYER 1 WINS!' : (widget.mode == GameMode.singlePlayer ? 'AI WINS!' : 'PLAYER 2 WINS!'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_engine.score1}  -  ${_engine.score2}',
                        style: TextStyle(
                          color: widget.theme.ballColor,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Max Rally: ${_engine.maxRally}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: _buttonStyle(widget.theme.paddle1Color),
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
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: _outlineButtonStyle(),
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

  Widget _buildScoreHeader() {
    if (widget.mode == GameMode.practice) {
      return Row(
        children: [
          Text(
            'SCORE: ${_engine.currentRally}',
            style: TextStyle(
              color: widget.theme.ballColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'BEST: ${_engine.maxRally}',
            style: TextStyle(
              color: widget.theme.paddle1Color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          '${_engine.score1}',
          style: TextStyle(
            color: widget.theme.paddle1Color,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            ':',
            style: TextStyle(
              color: widget.theme.tableLineColor.withValues(alpha: 0.8),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '${_engine.score2}',
          style: TextStyle(
            color: widget.theme.paddle2Color,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay({required String title, required Widget child}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: widget.theme.backgroundColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.theme.paddle1Color.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.theme.paddle1Color.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
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
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.black,
      minimumSize: const Size(220, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  ButtonStyle _outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(220, 48),
      side: const BorderSide(color: Colors.white38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
