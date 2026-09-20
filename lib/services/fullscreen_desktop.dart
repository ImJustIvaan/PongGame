import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class FullscreenPlatform {
  static bool _isFs = false;

  static bool get isFullscreen => _isFs;

  static Future<void> init() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        await windowManager.ensureInitialized();
        const windowOptions = WindowOptions(
          title: 'The Pong Game!',
          center: true,
          size: Size(1100, 680),
          minimumSize: Size(800, 500),
        );
        windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
        _isFs = await windowManager.isFullScreen();
      } catch (_) {}
    }
  }

  static Future<void> toggle() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final current = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!current);
        _isFs = !current;
      } catch (_) {}
    }
  }

  static void listenChanges(void Function(bool) callback) {
    // State is maintained internally on desktop
  }
}
