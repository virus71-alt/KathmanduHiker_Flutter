import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/analytics.dart';
import 'core/logger.dart';
import 'firebase_options.dart';
import 'services/remote_config_service.dart';
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

      final bootTrace = FirebasePerformance.instance.newTrace('app_boot');
      await bootTrace.start();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        kReleaseMode || kCrashlyticsEnabledInDebug,
      );
      await FirebasePerformance.instance
          .setPerformanceCollectionEnabled(kReleaseMode);

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      await ThemeController.instance.load();
      await AppConfig.instance.init();
      await Analytics.appOpen();

      await bootTrace.stop();
      AppLog.i('app.boot.complete');
      runApp(const ProviderScope(child: KathmanduHikerApp()));
    },
    (error, stack) {
      // Last-resort net: zone-level errors. These are the ones the two
      // handlers above somehow missed (rare, but worth catching).
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
