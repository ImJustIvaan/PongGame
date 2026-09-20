import 'package:flutter/foundation.dart';
import 'fullscreen_stub.dart'
    if (dart.library.html) 'fullscreen_web.dart'
    if (dart.library.io) 'fullscreen_desktop.dart';

class FullscreenService {
  static final FullscreenService instance = FullscreenService._();
  FullscreenService._();

  final ValueNotifier<bool> isFullScreen = ValueNotifier<bool>(false);

  Future<void> init() async {
    try {
      await FullscreenPlatform.init();
      isFullScreen.value = FullscreenPlatform.isFullscreen;
      FullscreenPlatform.listenChanges((fs) {
        isFullScreen.value = fs;
      });
    } catch (_) {}
  }

  Future<void> toggle() async {
    try {
      await FullscreenPlatform.toggle();
      isFullScreen.value = FullscreenPlatform.isFullscreen;
    } catch (_) {}
  }
}
