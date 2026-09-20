import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SkinType {
  solid,
  pattern,
  exclusive,
}

enum PatternType {
  none,
  hazardStripes,
  neonChevrons,
  matrixGrid,
  rainbowWave,
  carbonFiber,
  cosmicStars,
  verifiedLegend,
}

class PaddleSkin {
  final String id;
  final String name;
  final String description;
  final SkinType type;
  final PatternType patternType;
  final int price; // in coins, 0 for starter or exclusive
  final Color primaryColor;
  final Color? secondaryColor;
  final Color? glowColor;
  final bool isVerifiedOnly;

  const PaddleSkin({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.patternType = PatternType.none,
    required this.price,
    required this.primaryColor,
    this.secondaryColor,
    this.glowColor,
    this.isVerifiedOnly = false,
  });

  Color get effectiveGlowColor => glowColor ?? primaryColor;

  /// Paints the paddle with its skin texture inside the given [rrect].
  void paintPaddle(
    Canvas canvas,
    RRect rrect, {
    bool isAutoPilot = false,
    bool hasGlow = true,
  }) {
    final rect = rrect.outerRect;

    // 1. Ambient / Outer Glow
    if (isAutoPilot) {
      final autoGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawRRect(rrect.inflate(4), autoGlow);
    } else if (hasGlow) {
      final glowPaint = Paint()
        ..color = effectiveGlowColor.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(rrect, glowPaint);
    }

    // 2. Base Fill & Pattern Clipping
    canvas.save();
    canvas.clipRRect(rrect);

    // Render by pattern type
    switch (patternType) {
      case PatternType.none:
        _paintSolid(canvas, rect);
        break;
      case PatternType.hazardStripes:
        _paintHazardStripes(canvas, rect);
        break;
      case PatternType.neonChevrons:
        _paintNeonChevrons(canvas, rect);
        break;
      case PatternType.matrixGrid:
        _paintMatrixGrid(canvas, rect);
        break;
      case PatternType.rainbowWave:
        _paintRainbowWave(canvas, rect);
        break;
      case PatternType.carbonFiber:
        _paintCarbonFiber(canvas, rect);
        break;
      case PatternType.cosmicStars:
        _paintCosmicStars(canvas, rect);
        break;
      case PatternType.verifiedLegend:
        _paintVerifiedLegend(canvas, rect);
        break;
    }

    canvas.restore();

    // 3. Border Outlines & Highlights
    final borderPaint = Paint()
      ..color = (isAutoPilot ? const Color(0xFF00E5FF) : (secondaryColor ?? primaryColor)).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAutoPilot ? 2.0 : 1.2;
    canvas.drawRRect(rrect, borderPaint);

    // Inner bevel gloss highlight
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect.deflate(1.0), glossPaint);
  }

  void _paintSolid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.9),
          primaryColor,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintHazardStripes(Canvas canvas, Rect rect) {
    // Dark cyber background
    final bgPaint = Paint()..color = const Color(0xFF101216);
    canvas.drawRect(rect, bgPaint);

    final stripePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    const stripeWidth = 9.0;
    const stripeGap = 9.0;
    final totalH = rect.height + rect.width;

    for (double y = -rect.width; y < totalH; y += (stripeWidth + stripeGap)) {
      final path = Path()
        ..moveTo(rect.left, rect.top + y)
        ..lineTo(rect.right, rect.top + y + rect.width)
        ..lineTo(rect.right, rect.top + y + rect.width + stripeWidth)
        ..lineTo(rect.left, rect.top + y + stripeWidth)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
  }

  void _paintNeonChevrons(Canvas canvas, Rect rect) {
    final bgPaint = Paint()..color = const Color(0xFF060914);
    canvas.drawRect(rect, bgPaint);

    final chevronPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const stepY = 16.0;
    final midX = rect.left + rect.width * 0.5;

    for (double y = rect.top + 8; y < rect.bottom; y += stepY) {
      final path = Path()
        ..moveTo(rect.left + 3, y - 4)
        ..lineTo(midX, y + 4)
        ..lineTo(rect.right - 3, y - 4);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, chevronPaint);
    }
  }

  void _paintMatrixGrid(Canvas canvas, Rect rect) {
    final bgPaint = Paint()..color = const Color(0xFF021208);
    canvas.drawRect(rect, bgPaint);

    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    const dotSize = 2.2;
    const spacing = 7.0;

    for (double y = rect.top + 4; y < rect.bottom; y += spacing) {
      for (double x = rect.left + 3; x < rect.right; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize / 2, dotPaint);
      }
    }

    // High tech center scan line
    final centerLinePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(rect.left, rect.top + rect.height * 0.5),
      Offset(rect.right, rect.top + rect.height * 0.5),
      centerLinePaint,
    );
  }

  void _paintRainbowWave(Canvas canvas, Rect rect) {
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFFF0055),
        Color(0xFFFF8800),
        Color(0xFFFFFF00),
        Color(0xFF00FF66),
        Color(0xFF00F0FF),
        Color(0xFF7000FF),
        Color(0xFFFF00AA),
      ],
    );

    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintCarbonFiber(Canvas canvas, Rect rect) {
    final bgPaint = Paint()..color = const Color(0xFF141519);
    canvas.drawRect(rect, bgPaint);

    final weave1 = Paint()..color = const Color(0xFF282C35);
    final weave2 = Paint()..color = primaryColor.withValues(alpha: 0.7);

    const cellSize = 5.0;
    int row = 0;
    for (double y = rect.top; y < rect.bottom; y += cellSize) {
      int col = 0;
      for (double x = rect.left; x < rect.right; x += cellSize) {
        if ((row + col) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), weave1);
        } else if ((row + col) % 4 == 1) {
          canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), weave2);
        }
        col++;
      }
      row++;
    }
  }

  void _paintCosmicStars(Canvas canvas, Rect rect) {
    // Deep galactic gradient
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF0D0221),
        Color(0xFF19053B),
        Color(0xFF2E0854),
        Color(0xFF0F051D),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = bgGradient.createShader(rect));

    // Nebula glow cloud
    final nebulaPaint = Paint()
      ..color = const Color(0xFFFF007F).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(rect.center.dx, rect.top + rect.height * 0.35), rect.width * 0.8, nebulaPaint);

    // Sparkling stars
    final starPaint = Paint()..color = Colors.white;
    final rng = math.Random(42); // deterministic seed so stars don't flicker
    for (int i = 0; i < 22; i++) {
      final sx = rect.left + rng.nextDouble() * rect.width;
      final sy = rect.top + rng.nextDouble() * rect.height;
      final r = (rng.nextDouble() * 1.5) + 0.5;
      canvas.drawCircle(Offset(sx, sy), r, starPaint);
    }
  }

  void _paintVerifiedLegend(Canvas canvas, Rect rect) {
    // 24K Gold & Royal Sapphire dual-metallic gradient
    final goldGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFFFFDF00),
        Color(0xFFFFA500),
        Color(0xFFFF8C00),
        Color(0xFFFFD700),
        Color(0xFF00E5FF),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = goldGradient.createShader(rect));

    // Center verified badge symbol
    final badgeCenter = Offset(rect.center.dx, rect.center.dy);
    final badgeRadius = (rect.width * 0.38).clamp(5.0, 10.0);

    // Blue badge base
    final basePaint = Paint()
      ..color = const Color(0xFF0072FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, basePaint);

    final goldRingPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(badgeCenter, badgeRadius, goldRingPaint);

    // Clean checkmark path in center
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(badgeCenter.dx - badgeRadius * 0.45, badgeCenter.dy)
      ..lineTo(badgeCenter.dx - badgeRadius * 0.1, badgeCenter.dy + badgeRadius * 0.35)
      ..lineTo(badgeCenter.dx + badgeRadius * 0.45, badgeCenter.dy - badgeRadius * 0.35);
    canvas.drawPath(checkPath, checkPaint);
  }
}

class PaddleSkinCatalog {
  // Default starter skin
  static const String defaultSkinId = 'classic_cyan';

  // --- Solid Colors (Cheaper: 0 - 250 coins) ---
  static const PaddleSkin classicCyan = PaddleSkin(
    id: 'classic_cyan',
    name: 'Classic Cyan',
    description: 'The iconic glowing electric cyan paddle.',
    type: SkinType.solid,
    price: 0, // Free / Starter
    primaryColor: Color(0xFF00F0FF),
    glowColor: Color(0xFF00F0FF),
  );

  static const PaddleSkin neonPink = PaddleSkin(
    id: 'neon_pink',
    name: 'Neon Pink',
    description: 'Hot cyber synthwave magenta.',
    type: SkinType.solid,
    price: 150,
    primaryColor: Color(0xFFFF007F),
    glowColor: Color(0xFFFF007F),
  );

  static const PaddleSkin electricLime = PaddleSkin(
    id: 'electric_lime',
    name: 'Electric Lime',
    description: 'Radioactive high-visibility neon green.',
    type: SkinType.solid,
    price: 150,
    primaryColor: Color(0xFF39FF14),
    glowColor: Color(0xFF39FF14),
  );

  static const PaddleSkin blazingAmber = PaddleSkin(
    id: 'blazing_amber',
    name: 'Blazing Amber',
    description: 'Molten plasma orange with radiant heat.',
    type: SkinType.solid,
    price: 200,
    primaryColor: Color(0xFFFF9100),
    glowColor: Color(0xFFFF9100),
  );

  static const PaddleSkin ultraViolet = PaddleSkin(
    id: 'ultra_violet',
    name: 'Ultra Violet',
    description: 'Deep ultraviolet neon pulse.',
    type: SkinType.solid,
    price: 200,
    primaryColor: Color(0xFFD500F9),
    glowColor: Color(0xFFD500F9),
  );

  static const PaddleSkin arcticWhite = PaddleSkin(
    id: 'arctic_white',
    name: 'Arctic White',
    description: 'Piercing sub-zero pure white luminescence.',
    type: SkinType.solid,
    price: 250,
    primaryColor: Color(0xFFFFFFFF),
    glowColor: Color(0xFFB0E0E6),
  );

  static const PaddleSkin crimsonRed = PaddleSkin(
    id: 'crimson_red',
    name: 'Crimson Red',
    description: 'Aggressive laser red for competitive champions.',
    type: SkinType.solid,
    price: 250,
    primaryColor: Color(0xFFFF1744),
    glowColor: Color(0xFFFF1744),
  );

  // --- Patterns (Premium: 500 - 1250 coins) ---
  static const PaddleSkin hazardStripes = PaddleSkin(
    id: 'hazard_stripes',
    name: 'Hazard Stripes',
    description: 'High-contrast angled industrial caution stripes.',
    type: SkinType.pattern,
    patternType: PatternType.hazardStripes,
    price: 500,
    primaryColor: Color(0xFFFFD600),
    secondaryColor: Color(0xFF212121),
    glowColor: Color(0xFFFFD600),
  );

  static const PaddleSkin neonChevrons = PaddleSkin(
    id: 'neon_chevrons',
    name: 'Neon Chevrons',
    description: 'Directional cyber arrows pulsing along the paddle.',
    type: SkinType.pattern,
    patternType: PatternType.neonChevrons,
    price: 650,
    primaryColor: Color(0xFF00E5FF),
    secondaryColor: Color(0xFF0072FF),
    glowColor: Color(0xFF00E5FF),
  );

  static const PaddleSkin matrixGrid = PaddleSkin(
    id: 'matrix_grid',
    name: 'Matrix Grid',
    description: 'Digital cyber grid with glowing emerald tech nodes.',
    type: SkinType.pattern,
    patternType: PatternType.matrixGrid,
    price: 800,
    primaryColor: Color(0xFF00E676),
    secondaryColor: Color(0xFF004D40),
    glowColor: Color(0xFF00E676),
  );

  static const PaddleSkin rainbowWave = PaddleSkin(
    id: 'rainbow_wave',
    name: 'Rainbow Wave',
    description: 'Spectral chromatic gradient flowing across the field.',
    type: SkinType.pattern,
    patternType: PatternType.rainbowWave,
    price: 1000,
    primaryColor: Color(0xFFFF007F),
    secondaryColor: Color(0xFF00F0FF),
    glowColor: Color(0xFFFFD700),
  );

  static const PaddleSkin carbonFiber = PaddleSkin(
    id: 'carbon_fiber',
    name: 'Carbon Fiber',
    description: 'Ultralight interwoven composite weave texture.',
    type: SkinType.pattern,
    patternType: PatternType.carbonFiber,
    price: 1100,
    primaryColor: Color(0xFF00F0FF),
    secondaryColor: Color(0xFF424242),
    glowColor: Color(0xFF00F0FF),
  );

  static const PaddleSkin cosmicStars = PaddleSkin(
    id: 'cosmic_stars',
    name: 'Cosmic Stars',
    description: 'Deep galaxy nebula filled with sparkling astral stars.',
    type: SkinType.pattern,
    patternType: PatternType.cosmicStars,
    price: 1250,
    primaryColor: Color(0xFF7C4DFF),
    secondaryColor: Color(0xFFFF007F),
    glowColor: Color(0xFFB388FF),
  );

  // --- Exclusive / Verified Skin ---
  static const PaddleSkin verifiedLegend = PaddleSkin(
    id: 'verified_legend',
    name: 'Verified Legend',
    description: 'Exclusive 24K Royal Gold paddle etched with the Verified Badge. Awarded only to verified players.',
    type: SkinType.exclusive,
    patternType: PatternType.verifiedLegend,
    price: 0,
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFF00E5FF),
    glowColor: Color(0xFFFFD700),
    isVerifiedOnly: true,
  );

  static const List<PaddleSkin> allSkins = [
    classicCyan,
    neonPink,
    electricLime,
    blazingAmber,
    ultraViolet,
    arcticWhite,
    crimsonRed,
    hazardStripes,
    neonChevrons,
    matrixGrid,
    rainbowWave,
    carbonFiber,
    cosmicStars,
    verifiedLegend,
  ];

  static PaddleSkin get defaultSkin => classicCyan;

  static PaddleSkin byId(String? id) {
    if (id == null) return defaultSkin;
    return allSkins.firstWhere(
      (s) => s.id == id,
      orElse: () => defaultSkin,
    );
  }
}
