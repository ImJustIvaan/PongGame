import 'dart:math';
import 'package:flutter/foundation.dart';

enum GameMode {
  singlePlayer,     // Player vs AI
  twoPlayer,        // Local 2P
  practice,         // Wall bounce rally
  attractMode,      // AI vs AI menu background
  onlineMultiplayer // 1v1 Online Realtime match
}

enum AiDifficulty {
  easy,
  medium,
  hard,
  cyberPro,
}

enum GameState {
  ready,
  playing,
  paused,
  goalScored,
  gameOver,
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life; // 1.0 down to 0.0
  final double maxLife;
  final double size;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.maxLife,
    required this.size,
  }) : life = maxLife;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    life -= dt;
  }

  bool get isDead => life <= 0;
}

class BallTrailPoint {
  final double x;
  final double y;
  BallTrailPoint(this.x, this.y);
}

class PongEngine {
  final GameMode mode;
  final AiDifficulty difficulty;
  final int targetScore;

  // Normalized bounds [0.0, 1.0]
  double ballX = 0.5;
  double ballY = 0.5;
  double ballVx = 0.0;
  double ballVy = 0.0;
  final double ballRadius = 0.016;

  // Paddles
  final double paddleWidth = 0.022;
  final double paddleHeight = 0.18;
  final double paddle1X = 0.035;
  late final double paddle2X;

  double paddle1Y = 0.5;
  double paddle2Y = 0.5;

  // Speeds & limits
  final double baseSpeed = 0.70;
  double speedMultiplier = 1.0;
  final double maxSpeedMultiplier = 1.9;
  final double maxPaddleSpeed = 1.25;

  // Scoring & Stats
  int score1 = 0;
  int score2 = 0;
  int currentRally = 0;
  int maxRally = 0;
  int? winner; // 1 or 2

  GameState state = GameState.ready;
  double serveDelayTimer = 0.0;
  double screenShakeIntensity = 0.0;

  // Owner Auto-Play (auto serve & block for verified owner ImJustIvaan)
  bool ownerAutoPlay = false;

  // Particles & Visuals
  final List<Particle> particles = [];
  final List<BallTrailPoint> ballTrail = [];
  final int maxTrailPoints = 6;

  // Callbacks for sound and haptics
  VoidCallback? onPaddleHit;
  VoidCallback? onWallBounce;
  VoidCallback? onScore;
  VoidCallback? onGameOver;

  final Random _rng = Random();

  PongEngine({
    this.mode = GameMode.singlePlayer,
    this.difficulty = AiDifficulty.medium,
    this.targetScore = 7,
  }) {
    paddle2X = mode == GameMode.practice ? 0.98 : 0.965;
    resetServe(servingToPlayer: 1);
  }

  void resetServe({required int servingToPlayer}) {
    ballX = 0.5;
    ballY = 0.5;
    speedMultiplier = 1.0;
    ballTrail.clear();

    final angleOffset = (_rng.nextDouble() - 0.5) * (pi / 4); // +/- 22.5 deg
    final dir = servingToPlayer == 1 ? -1.0 : 1.0;
    ballVx = dir * baseSpeed * cos(angleOffset);
    ballVy = baseSpeed * sin(angleOffset);

    serveDelayTimer = 0.7; // Brief pause before ball moves
    if (state != GameState.gameOver) {
      state = GameState.ready;
    }
  }

  void startOrServe() {
    if (state == GameState.ready) {
      state = GameState.playing;
    }
  }

  void togglePause() {
    if (state == GameState.playing) {
      state = GameState.paused;
    } else if (state == GameState.paused) {
      state = GameState.playing;
    }
  }

  void applyOnlineSync({
    required double bx,
    required double by,
    required double bvx,
    required double bvy,
    required double p1y,
    required int s1,
    required int s2,
    required int rally,
    required String st,
  }) {
    ballX = bx;
    ballY = by;
    ballVx = bvx;
    ballVy = bvy;
    paddle1Y = p1y;
    score1 = s1;
    score2 = s2;
    currentRally = rally;
    if (rally > maxRally) maxRally = rally;
    ballTrail.insert(0, BallTrailPoint(ballX, ballY));
    if (ballTrail.length > maxTrailPoints) {
      ballTrail.removeLast();
    }
  }

  void update(double dt) {
    if (screenShakeIntensity > 0) {
      screenShakeIntensity = max(0.0, screenShakeIntensity - dt * 5.0);
    }

    _updateParticles(dt);

    if (state == GameState.paused || state == GameState.gameOver) {
      return;
    }

    if (state == GameState.ready || state == GameState.goalScored) {
      if (ownerAutoPlay) {
        if (serveDelayTimer > 0.25) {
          serveDelayTimer = 0.25;
        }
        serveDelayTimer -= dt * 2.0;
        if (serveDelayTimer <= 0) {
          state = GameState.playing;
        }
        return;
      }
      serveDelayTimer -= dt;
      if (serveDelayTimer <= 0) {
        state = GameState.playing;
      }
      return;
    }

    // AI Logic
    _updateAi(dt);

    // Ball movement
    final effectiveVx = ballVx * speedMultiplier;
    final effectiveVy = ballVy * speedMultiplier;

    ballX += effectiveVx * dt;
    ballY += effectiveVy * dt;

    // Ball trail
    ballTrail.insert(0, BallTrailPoint(ballX, ballY));
    if (ballTrail.length > maxTrailPoints) {
      ballTrail.removeLast();
    }

    // Top & Bottom wall collision
    if (ballY - ballRadius <= 0.0) {
      ballY = ballRadius;
      ballVy = ballVy.abs();
      _spawnWallSparks(ballX, 0.0);
      onWallBounce?.call();
    } else if (ballY + ballRadius >= 1.0) {
      ballY = 1.0 - ballRadius;
      ballVy = -ballVy.abs();
      _spawnWallSparks(ballX, 1.0);
      onWallBounce?.call();
    }

    // Practice Mode: Right wall bounce
    if (mode == GameMode.practice && ballX + ballRadius >= paddle2X) {
      ballX = paddle2X - ballRadius;
      ballVx = -ballVx.abs();
      speedMultiplier = min(maxSpeedMultiplier, speedMultiplier + 0.04);
      currentRally++;
      if (currentRally > maxRally) maxRally = currentRally;
      _spawnPaddleSparks(paddle2X, ballY, -1.0);
      screenShakeIntensity = 0.015;
      onPaddleHit?.call();
    }

    // Paddle 1 Collision (Left side)
    if (ballVx < 0) {
      final p1Left = paddle1X - paddleWidth / 2;
      final p1Right = paddle1X + paddleWidth / 2;
      final p1Top = paddle1Y - paddleHeight / 2;
      final p1Bottom = paddle1Y + paddleHeight / 2;

      if (ballX - ballRadius <= p1Right && ballX + ballRadius >= p1Left) {
        if (ballY + ballRadius >= p1Top && ballY - ballRadius <= p1Bottom) {
          _reflectFromPaddle(paddle1Y, 1.0);
          ballX = p1Right + ballRadius;
          currentRally++;
          if (currentRally > maxRally) maxRally = currentRally;
          _spawnPaddleSparks(p1Right, ballY, 1.0);
          screenShakeIntensity = 0.02;
          onPaddleHit?.call();
        }
      }
    }

    // Paddle 2 Collision (Right side, non-practice)
    if (mode != GameMode.practice && ballVx > 0) {
      final p2Left = paddle2X - paddleWidth / 2;
      final p2Right = paddle2X + paddleWidth / 2;
      final p2Top = paddle2Y - paddleHeight / 2;
      final p2Bottom = paddle2Y + paddleHeight / 2;

      if (ballX + ballRadius >= p2Left && ballX - ballRadius <= p2Right) {
        if (ballY + ballRadius >= p2Top && ballY - ballRadius <= p2Bottom) {
          _reflectFromPaddle(paddle2Y, -1.0);
          ballX = p2Left - ballRadius;
          currentRally++;
          if (currentRally > maxRally) maxRally = currentRally;
          _spawnPaddleSparks(p2Left, ballY, -1.0);
          screenShakeIntensity = 0.02;
          onPaddleHit?.call();
        }
      }
    }

    // Goals / Scoring
    if (ballX < -0.05) {
      // Player 2 scores
      score2++;
      currentRally = 0;
      _spawnGoalExplosion(0.0, ballY);
      screenShakeIntensity = 0.04;
      onScore?.call();
      _checkGameOverOrServe(servingTo: 1);
    } else if (ballX > 1.05) {
      // Player 1 scores
      score1++;
      currentRally = 0;
      _spawnGoalExplosion(1.0, ballY);
      screenShakeIntensity = 0.04;
      onScore?.call();
      _checkGameOverOrServe(servingTo: 2);
    }
  }

  void _reflectFromPaddle(double paddleY, double xDirection) {
    // Relative hit point between -1.0 (top edge) and +1.0 (bottom edge)
    final hitOffset = (ballY - paddleY) / (paddleHeight / 2);
    final clampedOffset = hitOffset.clamp(-1.0, 1.0);

    // Max deflection angle ~55 degrees
    final maxAngle = 55.0 * (pi / 180.0);
    final bounceAngle = clampedOffset * maxAngle;

    final currentSpeed = sqrt(ballVx * ballVx + ballVy * ballVy);
    ballVx = xDirection * currentSpeed * cos(bounceAngle);
    ballVy = currentSpeed * sin(bounceAngle);

    // Accelerate ball
    speedMultiplier = min(maxSpeedMultiplier, speedMultiplier + 0.05);
  }

  void _checkGameOverOrServe({required int servingTo}) {
    if (mode != GameMode.practice && (score1 >= targetScore || score2 >= targetScore)) {
      state = GameState.gameOver;
      winner = score1 >= targetScore ? 1 : 2;
      onGameOver?.call();
    } else {
      state = GameState.goalScored;
      resetServe(servingToPlayer: servingTo);
    }
  }

  void _updateAi(double dt) {
    // Attract mode: both paddles controlled by AI
    if (mode == GameMode.attractMode) {
      _steerPaddleTowards(1, ballY, 0.9, dt);
      _steerPaddleTowards(2, ballY, 0.9, dt);
      return;
    }

    // Owner Auto-Play: auto-intercept and block incoming balls for Paddle 1
    if (ownerAutoPlay) {
      if (ballVx < 0) {
        final predictedY = _predictInterceptY(paddle1X);
        final dist = (predictedY - paddle1Y).abs();
        final timeToIntercept = (ballX - paddle1X) / (ballVx.abs() * speedMultiplier);
        double speed = 2.0;
        if (timeToIntercept > 0.005 && (dist / timeToIntercept) > maxPaddleSpeed * speed) {
          speed = (dist / timeToIntercept) / maxPaddleSpeed + 0.6;
        }
        _steerPaddleTowards(1, predictedY, speed, dt);
      } else {
        _steerPaddleTowards(1, 0.5, 0.8, dt);
      }
    }

    if (mode != GameMode.singlePlayer) {
      return;
    }

    // AI controls Paddle 2
    double targetY = 0.5;

    switch (difficulty) {
      case AiDifficulty.easy:
        // Slow reaction, only tracks when ball heads towards it
        if (ballVx > 0) {
          targetY = ballY + sin(ballX * 10) * 0.06;
          _steerPaddleTowards(2, targetY, 0.45, dt);
        }
        break;

      case AiDifficulty.medium:
        if (ballVx > 0) {
          targetY = ballY + (_rng.nextDouble() - 0.5) * 0.04;
          _steerPaddleTowards(2, targetY, 0.72, dt);
        } else {
          _steerPaddleTowards(2, 0.5, 0.3, dt);
        }
        break;

      case AiDifficulty.hard:
        if (ballVx > 0) {
          final predictedY = _predictInterceptY(paddle2X);
          _steerPaddleTowards(2, predictedY, 0.95, dt);
        } else {
          _steerPaddleTowards(2, 0.5, 0.4, dt);
        }
        break;

      case AiDifficulty.cyberPro:
        final predictedY = ballVx > 0 ? _predictInterceptY(paddle2X) : 0.5;
        _steerPaddleTowards(2, predictedY, 1.2, dt);
        break;
    }
  }

  double _predictInterceptY(double targetX) {
    if (ballVx.abs() < 0.001) return ballY;
    final time = (targetX - ballX) / (ballVx * speedMultiplier);
    if (time <= 0) return ballY;

    double projectedY = ballY + (ballVy * speedMultiplier) * time;

    // Simulate wall bounces in normalized coordinates [0, 1]
    while (projectedY < 0.0 || projectedY > 1.0) {
      if (projectedY < 0.0) {
        projectedY = -projectedY;
      } else if (projectedY > 1.0) {
        projectedY = 2.0 - projectedY;
      }
    }
    return projectedY;
  }

  void _steerPaddleTowards(int player, double targetY, double speedFactor, double dt) {
    final currentY = player == 1 ? paddle1Y : paddle2Y;
    final diff = targetY - currentY;
    final maxStep = maxPaddleSpeed * speedFactor * dt;

    final newY = (currentY + diff.clamp(-maxStep, maxStep)).clamp(
      paddleHeight / 2,
      1.0 - paddleHeight / 2,
    );

    if (player == 1) {
      paddle1Y = newY;
    } else {
      paddle2Y = newY;
    }
  }

  void movePaddle(int player, double normalizedY) {
    final clamped = normalizedY.clamp(paddleHeight / 2, 1.0 - paddleHeight / 2);
    if (player == 1) {
      paddle1Y = clamped;
    } else {
      paddle2Y = clamped;
    }
  }

  void movePaddleDelta(int player, double deltaY) {
    if (player == 1) {
      paddle1Y = (paddle1Y + deltaY).clamp(paddleHeight / 2, 1.0 - paddleHeight / 2);
    } else {
      paddle2Y = (paddle2Y + deltaY).clamp(paddleHeight / 2, 1.0 - paddleHeight / 2);
    }
  }

  void _updateParticles(double dt) {
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.update(dt);
      if (p.isDead) {
        particles.removeAt(i);
      }
    }
  }

  void _spawnPaddleSparks(double x, double y, double xDir) {
    for (var i = 0; i < 14; i++) {
      final angle = (xDir > 0 ? 0 : pi) + (_rng.nextDouble() - 0.5) * (pi / 2);
      final speed = 0.2 + _rng.nextDouble() * 0.5;
      particles.add(Particle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        maxLife: 0.25 + _rng.nextDouble() * 0.2,
        size: 2.0 + _rng.nextDouble() * 3.0,
      ));
    }
  }

  void _spawnWallSparks(double x, double y) {
    for (var i = 0; i < 8; i++) {
      final vy = (y < 0.5 ? 1.0 : -1.0) * (0.1 + _rng.nextDouble() * 0.3);
      final vx = (_rng.nextDouble() - 0.5) * 0.3;
      particles.add(Particle(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        maxLife: 0.2 + _rng.nextDouble() * 0.15,
        size: 1.5 + _rng.nextDouble() * 2.0,
      ));
    }
  }

  void _spawnGoalExplosion(double x, double y) {
    for (var i = 0; i < 35; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.2 + _rng.nextDouble() * 0.7;
      particles.add(Particle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        maxLife: 0.4 + _rng.nextDouble() * 0.3,
        size: 2.5 + _rng.nextDouble() * 4.0,
      ));
    }
  }
}
