import 'dart:async';

import 'package:flutter/services.dart';

/// Soft haptic feedback — modeled on modern social apps (Instagram, Threads).
/// One subtle pulse per intentional action. SystemSound is intentionally
/// omitted because Material InkWells already play it; combining the two
/// caused the previous "double tap" feel.
///
/// These methods are deliberately void-returning fire-and-forget. The
/// underlying `HapticFeedback` calls are Future<void>, but waiting on them
/// would force every UI callback to be async, and a missed pulse is
/// strictly cosmetic. We `unawaited` the future at the source to keep the
/// ULTIMATE.md §3.1.1 lint (unawaited_futures) happy without polluting
/// every callsite.
class AppFeedback {
  /// Light selection tick. Use for routine taps inside custom GestureDetectors
  /// (Material widgets fire their own haptic via `enableFeedback`).
  static void tap() {
    unawaited(HapticFeedback.selectionClick());
  }

  /// Very light pulse for non-button surface affordances (drag, hover).
  static void light() {
    unawaited(HapticFeedback.selectionClick());
  }

  /// Toggle / chip change — same softness as tap.
  static void toggle() {
    unawaited(HapticFeedback.selectionClick());
  }

  /// Affirmative confirmation (send, submit). Slightly stronger.
  static void success() {
    unawaited(HapticFeedback.lightImpact());
  }

  /// Destructive or attention-grabbing action.
  static void warning() {
    unawaited(HapticFeedback.mediumImpact());
  }
}
