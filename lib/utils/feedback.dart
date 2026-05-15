import 'package:flutter/services.dart';

/// Soft haptic feedback — modeled on modern social apps (Instagram, Threads).
/// One subtle pulse per intentional action. SystemSound is intentionally
/// omitted because Material InkWells already play it; combining the two
/// caused the previous "double tap" feel.
class AppFeedback {
  /// Light selection tick. Use for routine taps inside custom GestureDetectors
  /// (Material widgets fire their own haptic via `enableFeedback`).
  static Future<void> tap() async {
    await HapticFeedback.selectionClick();
  }

  /// Very light pulse for non-button surface affordances (drag, hover).
  static Future<void> light() async {
    await HapticFeedback.selectionClick();
  }

  /// Toggle / chip change — same softness as tap.
  static Future<void> toggle() async {
    await HapticFeedback.selectionClick();
  }

  /// Affirmative confirmation (send, submit). Slightly stronger.
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
  }

  /// Destructive or attention-grabbing action.
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact();
  }
}
