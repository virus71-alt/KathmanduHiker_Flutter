import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/logger.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

/// App entrypoint. Per ULTIMATE.md §3.3, every uncaught error is routed
/// to Crashlytics from the very first frame:
///   - `FlutterError.onError`             — synchronous framework errors
///   - `PlatformDispatcher.instance.onError` — asynchronous & isolate errors
///   - `runZonedGuarded`                  — zone-level fallback for anything
///                                          that escapes the above two
///
/// Crashlytics is disabled in debug builds so test runs don't pollute the
/// production dashboard. Re-enable manually by flipping
/// `kCrashlyticsEnabledInDebug` to true while debugging the integration.
const bool kCrashlyticsEnabledInDebug = false;

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Crashlytics collection toggle. In release builds we always collect;
      // in debug we respect [kCrashlyticsEnabledInDebug].
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        kReleaseMode || kCrashlyticsEnabledInDebug,
      );

      // Route Flutter framework errors → Crashlytics (and pretty-print in
      // debug so they're easy to spot).
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Route uncaught async / isolate errors → Crashlytics.
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      await ThemeController.instance.load();

      AppLog.i('app.boot.complete');
      runApp(const KathmanduHikerApp());
    },
    (error, stack) {
      // Last-resort net: zone-level errors. These are the ones the two
      // handlers above somehow missed (rare, but worth catching).
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
