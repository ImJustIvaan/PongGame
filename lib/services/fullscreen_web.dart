// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

class FullscreenPlatform {
  static bool get isFullscreen {
    try {
      return html.document.fullscreenElement != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> init() async {}

  static Future<void> toggle() async {
    try {
      if (html.document.fullscreenElement != null) {
        html.document.exitFullscreen();
      } else {
        html.document.documentElement?.requestFullscreen();
      }
    } catch (_) {}
  }

  static void listenChanges(void Function(bool) callback) {
    try {
      html.document.onFullscreenChange.listen((_) {
        callback(isFullscreen);
      });
    } catch (_) {}
  }
}
