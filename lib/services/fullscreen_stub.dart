class FullscreenPlatform {
  static bool get isFullscreen => false;
  static Future<void> init() async {}
  static Future<void> toggle() async {}
  static void listenChanges(void Function(bool) callback) {}
}
