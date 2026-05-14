import 'package:flutter/services.dart';

/// Haptics + system click sound helper. Mirrors the Android Feedback util.
class AppFeedback {
  static Future<void> tap() async {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  static Future<void> light() async {
    HapticFeedback.lightImpact();
  }

  static Future<void> success() async {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static Future<void> warning() async {
    HapticFeedback.heavyImpact();
  }

  static Future<void> toggle() async {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }
}
