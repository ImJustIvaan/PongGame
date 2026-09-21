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
  final bool isLight;

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
    this.isLight = false,
  });

  // Dark variants
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
    isLight: false,
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
    isLight: false,
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
    isLight: false,
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
    isLight: false,
  );

  // Light variants for each theme
  static const PongTheme cyberNeonLight = PongTheme(
    type: PongThemeType.cyberNeon,
    name: 'Cyber Neon',
    backgroundColor: Color(0xFFF1F5F9),
    tableLineColor: Color(0x330066FF),
    paddle1Color: Color(0xFF0066FF),
    paddle2Color: Color(0xFFFF007F),
    ballColor: Color(0xFF0F172A),
    scoreColor: Color(0x280066FF),
    particleColor: Color(0xFF0066FF),
    hasGlow: false,
    hasScanlines: false,
    isLight: true,
  );

  static const PongTheme retro1972Light = PongTheme(
    type: PongThemeType.retro1972,
    name: 'Retro CRT',
    backgroundColor: Color(0xFFE8F4E8),
    tableLineColor: Color(0x441B5E20),
    paddle1Color: Color(0xFF1B5E20),
    paddle2Color: Color(0xFF1B5E20),
    ballColor: Color(0xFF0D3810),
    scoreColor: Color(0x331B5E20),
    particleColor: Color(0xFF1B5E20),
    hasGlow: false,
    hasScanlines: true,
    isLight: true,
  );

  static const PongTheme synthwaveLight = PongTheme(
    type: PongThemeType.synthwave,
    name: 'Synthwave',
    backgroundColor: Color(0xFFFAF0F8),
    tableLineColor: Color(0x33B5179E),
    paddle1Color: Color(0xFFB5179E),
    paddle2Color: Color(0xFF0077B6),
    ballColor: Color(0xFF3A0CA3),
    scoreColor: Color(0x28B5179E),
    particleColor: Color(0xFFB5179E),
    hasGlow: false,
    hasScanlines: false,
    isLight: true,
  );

  static const PongTheme minimalLight = PongTheme(
    type: PongThemeType.minimal,
    name: 'Monochrome',
    backgroundColor: Color(0xFFFAFAFA),
    tableLineColor: Color(0x22000000),
    paddle1Color: Color(0xFF111111),
    paddle2Color: Color(0xFF111111),
    ballColor: Color(0xFF111111),
    scoreColor: Color(0x22000000),
    particleColor: Color(0xFF555555),
    hasGlow: false,
    hasScanlines: false,
    isLight: true,
  );

  static PongTheme fromType(PongThemeType type, {bool isLight = false}) {
    if (isLight) {
      switch (type) {
        case PongThemeType.cyberNeon:
          return cyberNeonLight;
        case PongThemeType.retro1972:
          return retro1972Light;
        case PongThemeType.synthwave:
          return synthwaveLight;
        case PongThemeType.minimal:
          return minimalLight;
      }
    } else {
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
}
