import 'package:flutter/material.dart';

enum PongThemeType {
  cyberNeon,
  retro1972,
  synthwave,
  minimal,
}

class PongTheme {
  final PongThemeType type;
  final String name;
  final Color backgroundColor;
  final Color tableLineColor;
  final Color paddle1Color;
  final Color paddle2Color;
  final Color ballColor;
  final Color scoreColor;
  final Color particleColor;
  final bool hasGlow;
  final bool hasScanlines;

  const PongTheme({
    required this.type,
    required this.name,
    required this.backgroundColor,
    required this.tableLineColor,
    required this.paddle1Color,
    required this.paddle2Color,
    required this.ballColor,
    required this.scoreColor,
    required this.particleColor,
    this.hasGlow = true,
    this.hasScanlines = false,
  });

  static const PongTheme cyberNeon = PongTheme(
    type: PongThemeType.cyberNeon,
    name: 'Cyber Neon',
    backgroundColor: Color(0xFF090A15),
    tableLineColor: Color(0x3300F0FF),
    paddle1Color: Color(0xFF00F0FF),
    paddle2Color: Color(0xFFFF007F),
    ballColor: Color(0xFFFFFFFF),
    scoreColor: Color(0x6600F0FF),
    particleColor: Color(0xFF00F0FF),
    hasGlow: true,
    hasScanlines: false,
  );

  static const PongTheme retro1972 = PongTheme(
    type: PongThemeType.retro1972,
    name: 'Retro CRT',
    backgroundColor: Color(0xFF0C100C),
    tableLineColor: Color(0x4433FF33),
    paddle1Color: Color(0xFF33FF33),
    paddle2Color: Color(0xFF33FF33),
    ballColor: Color(0xFF33FF33),
    scoreColor: Color(0x5533FF33),
    particleColor: Color(0xFF33FF33),
    hasGlow: false,
    hasScanlines: true,
  );

  static const PongTheme synthwave = PongTheme(
    type: PongThemeType.synthwave,
    name: 'Synthwave',
    backgroundColor: Color(0xFF1B053A),
    tableLineColor: Color(0x33FF71CE),
    paddle1Color: Color(0xFFFF71CE),
    paddle2Color: Color(0xFF01CDFE),
    ballColor: Color(0xFFFFF44F),
    scoreColor: Color(0x66FF71CE),
    particleColor: Color(0xFFFF71CE),
    hasGlow: true,
    hasScanlines: false,
  );

  static const PongTheme minimal = PongTheme(
    type: PongThemeType.minimal,
    name: 'Monochrome',
    backgroundColor: Color(0xFF0A0A0A),
    tableLineColor: Color(0x22FFFFFF),
    paddle1Color: Color(0xFFFFFFFF),
    paddle2Color: Color(0xFFFFFFFF),
    ballColor: Color(0xFFFFFFFF),
    scoreColor: Color(0x44FFFFFF),
    particleColor: Color(0xFFDDDDDD),
    hasGlow: false,
    hasScanlines: false,
  );

  static PongTheme fromType(PongThemeType type) {
    switch (type) {
      case PongThemeType.cyberNeon:
        return cyberNeon;
      case PongThemeType.retro1972:
        return retro1972;
      case PongThemeType.synthwave:
        return synthwave;
      case PongThemeType.minimal:
        return minimal;
    }
  }
}
