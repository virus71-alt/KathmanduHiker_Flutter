import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as pkg;

/// Single structured logger for the whole app.
///
/// Per ULTIMATE.md §9.2:
///   - No raw `print()` / `debugPrint()` in shipped code paths.
///   - Logs are stripped from release builds (we only emit to `pkg.Logger`
///     in debug; in release we forward errors to Crashlytics non-fatals
///     and otherwise stay silent).
///   - PII is NEVER logged. Pass user IDs hashed, never raw emails,
///     phone numbers, names, tokens, or payloads.
///
/// Usage:
///
/// ```dart
/// AppLog.i('home.loaded', data: {'trailCount': trails.length});
/// AppLog.w('weather.fetch.fallback', error: e);
/// AppLog.e('hike.tracking.fail', error: e, stack: s, fatal: false);
/// ```
///
/// In release the `i`/`d` calls become no-ops. `w` and `e` always go to
/// Crashlytics so non-fatal regressions are visible in production.
class AppLog {
  AppLog._();

  static final pkg.Logger _logger = pkg.Logger(
    // Pretty output for dev, silenced in release (see [_shouldLog]).
    printer: pkg.PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: pkg.DateTimeFormat.onlyTimeAndSinceStart,
    ),
    // In release we want a Logger with the most permissive level (errors
    // still reach Crashlytics) but the printer above never fires because
    // [_shouldLog] short-circuits the debug calls.
    level: kReleaseMode ? pkg.Level.warning : pkg.Level.trace,
  );

  static bool get _shouldLog => !kReleaseMode;

  /// Debug — verbose dev tracing. Stripped in release.
  static void d(String event, {Map<String, Object?>? data}) {
    if (!_shouldLog) return;
    _logger.d(_format(event, data));
  }

  /// Info — significant lifecycle events (login, navigation milestones).
  /// Stripped in release.
  static void i(String event, {Map<String, Object?>? data}) {
    if (!_shouldLog) return;
    _logger.i(_format(event, data));
  }

  /// Warning — recoverable issue or retry. Sent to Crashlytics as a
  /// non-fatal in release; printed locally in debug.
  static void w(
    String event, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? data,
  }) {
    if (_shouldLog) {
      _logger.w(_format(event, data), error: error, stackTrace: stack);
    }
    _reportNonFatal(event, error: error, stack: stack, data: data);
  }

  /// Error — user-affecting failure. Always reported to Crashlytics. If
  /// [fatal] is true the entry is recorded as a fatal exception.
  static void e(
    String event, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? data,
    bool fatal = false,
  }) {
    if (_shouldLog) {
      _logger.e(_format(event, data), error: error, stackTrace: stack);
    }
    _reportNonFatal(
      event,
      error: error,
      stack: stack,
      data: data,
      fatal: fatal,
    );
  }

  /// Adds a breadcrumb-style log to Crashlytics so it shows up in the
  /// session timeline if a crash follows. Per ULTIMATE.md §3.3.
  static void breadcrumb(String event, {Map<String, Object?>? data}) {
    if (_shouldLog) _logger.t(_format(event, data));
    try {
      FirebaseCrashlytics.instance.log(_format(event, data));
    } catch (_) {
      // Crashlytics may not be initialised yet during very early startup.
    }
  }

  /// Sets the hashed user id on Crashlytics for crash attribution.
  /// NEVER pass the raw uid if it can be reversed to a real user identity
  /// outside of Firebase Auth — but Firebase uids are already opaque so
  /// passing them through is acceptable per their docs.
  static Future<void> setUser(String? uid) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
    } catch (_) {}
  }

  // ── Internals ──────────────────────────────────────────────────────

  static String _format(String event, Map<String, Object?>? data) {
    if (data == null || data.isEmpty) return event;
    final pairs = data.entries.map((e) => '${e.key}=${e.value}').join(' ');
    return '$event  $pairs';
  }

  static void _reportNonFatal(
    String event, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? data,
    bool fatal = false,
  }) {
    if (error == null) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack ?? StackTrace.current,
        reason: _format(event, data),
        fatal: fatal,
      );
    } catch (_) {
      // If Crashlytics isn't initialised yet (very early startup), drop
      // the report silently — better than crashing the error reporter.
    }
  }
}
