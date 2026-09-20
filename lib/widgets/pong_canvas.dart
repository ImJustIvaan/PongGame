import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../game/paddle_skin.dart';
import '../game/pong_engine.dart';

class PongCanvas extends StatelessWidget {
  final PongEngine engine;
  final PongTheme theme;
  final PaddleSkin? skin1;
  final PaddleSkin? skin2;

  const PongCanvas({
    super.key,
    required this.engine,
    required this.theme,
    this.skin1,
    this.skin2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PongPainter(
        engine: engine,
        theme: theme,
        skin1: skin1,
        skin2: skin2,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PongPainter extends CustomPainter {
  final PongEngine engine;
  final PongTheme theme;
  final PaddleSkin? skin1;
  final PaddleSkin? skin2;

  _PongPainter({
    required this.engine,
    required this.theme,
    this.skin1,
    this.skin2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Screen shake offset
    if (engine.screenShakeIntensity > 0) {
      final dx = (engine.screenShakeIntensity * (size.width * 0.05)) *
          (DateTime.now().millisecond % 2 == 0 ? 1 : -1);
      final dy = (engine.screenShakeIntensity * (size.height * 0.05)) *
          (DateTime.now().microsecond % 2 == 0 ? 1 : -1);
      canvas.translate(dx, dy);
    }

    // Background
    final bgPaint = Paint()..color = theme.backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Center Dashed Net
    final netPaint = Paint()
      ..color = theme.tableLineColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final dashHeight = size.height / 35;
    final dashGap = dashHeight * 0.7;
    double currentY = 0;
    while (currentY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, currentY),
        Offset(size.width / 2, currentY + dashHeight),
        netPaint,
      );
      currentY += dashHeight + dashGap;
    }

    // Top & Bottom Court Boundaries
    final boundaryPaint = Paint()
      ..color = theme.tableLineColor.withValues(alpha: 0.45)
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(0, 1.5), Offset(size.width, 1.5), boundaryPaint);
    canvas.drawLine(Offset(0, size.height - 1.5), Offset(size.width, size.height - 1.5), boundaryPaint);

    // Wall bounce barrier in practice mode
    if (engine.mode == GameMode.practice) {
      final wallPaint = Paint()
        ..color = theme.paddle2Color.withValues(alpha: 0.8)
        ..strokeWidth = 4.0;
      canvas.drawLine(
        Offset(engine.paddle2X * size.width, 0),
        Offset(engine.paddle2X * size.width, size.height),
        wallPaint,
      );
    }

    // Ball Motion Trail
    for (var i = 0; i < engine.ballTrail.length; i++) {
      final point = engine.ballTrail[i];
      final trailOpacity = (1.0 - (i / engine.ballTrail.length)) * 0.35;
      final trailRadius = (engine.ballRadius * size.height) * (1.0 - (i / engine.ballTrail.length) * 0.4);
      final trailPaint = Paint()
        ..color = theme.ballColor.withValues(alpha: trailOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        trailRadius,
        trailPaint,
      );
    }

    // Ball
    final ballCenter = Offset(engine.ballX * size.width, engine.ballY * size.height);
    final ballPxRadius = engine.ballRadius * size.height;

    if (theme.hasGlow) {
      final glowPaint = Paint()
        ..color = theme.ballColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(ballCenter, ballPxRadius * 1.5, glowPaint);
    }

    final ballPaint = Paint()
      ..color = theme.ballColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ballCenter, ballPxRadius, ballPaint);

    // Paddle 1 (Left)
    _drawPaddle(
      canvas,
      size,
      x: engine.paddle1X,
      y: engine.paddle1Y,
      color: theme.paddle1Color,
      skin: skin1,
      isAutoPilot: engine.ownerAutoPlay,
    );

    // Paddle 2 (Right, non-practice)
    if (engine.mode != GameMode.practice) {
      _drawPaddle(
        canvas,
        size,
        x: engine.paddle2X,
        y: engine.paddle2Y,
        color: theme.paddle2Color,
        skin: skin2,
      );
    }

    // Collision Particles
    for (final p in engine.particles) {
      final particleOpacity = (p.life / p.maxLife).clamp(0.0, 1.0);
      final particlePaint = Paint()
        ..color = theme.particleColor.withValues(alpha: particleOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * (size.height / 600),
        particlePaint,
      );
    }

    // Optional Retro CRT Scanlines
    if (theme.hasScanlines) {
      final scanlinePaint = Paint()
        ..color = const Color(0x15000000)
        ..strokeWidth = 1.5;
      for (double y = 0; y < size.height; y += 4) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
      }
    }
  }

  void _drawPaddle(
    Canvas canvas,
    Size size, {
    required double x,
    required double y,
    required Color color,
    PaddleSkin? skin,
    bool isAutoPilot = false,
  }) {
    final pw = engine.paddleWidth * size.width;
    final ph = engine.paddleHeight * size.height;
    final px = x * size.width - pw / 2;
    final py = y * size.height - ph / 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(px, py, pw, ph),
      Radius.circular(pw / 2),
    );

    if (skin != null) {
      skin.paintPaddle(
        canvas,
        rrect,
        isAutoPilot: isAutoPilot,
        hasGlow: theme.hasGlow,
      );
      return;
    }

    if (isAutoPilot) {
      final autoGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawRRect(rrect.inflate(4), autoGlow);
    } else if (theme.hasGlow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(rrect, glowPaint);
    }

    final paddlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paddlePaint);

    if (isAutoPilot) {
      final borderPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PongPainter oldDelegate) => true;
}
