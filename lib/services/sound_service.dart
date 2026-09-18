import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundService {
  static final SoundService instance = SoundService._();
  SoundService._();

  bool isMuted = false;

  void playPaddleHit() {
    if (isMuted) return;
    try {
      if (!kIsWeb) {
        HapticFeedback.lightImpact();
      }
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void playWallBounce() {
    if (isMuted) return;
    try {
      if (!kIsWeb) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  void playScore() {
    if (isMuted) return;
    try {
      if (!kIsWeb) {
        HapticFeedback.mediumImpact();
      }
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  void playGameOver() {
    if (isMuted) return;
    try {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
