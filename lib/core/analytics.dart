import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// All analytics calls go through here so we have one place to enforce
/// the no-PII rule. Events use the `feature_action` naming from the
/// spec; properties are limited to primitives, never raw identifiers.
class Analytics {
  Analytics._();

  static FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver navObserver() =>
      FirebaseAnalyticsObserver(analytics: _fa);

  static Future<void> setUser(String? uid) async {
    if (uid == null || uid.isEmpty) {
      await _fa.setUserId(id: null);
      return;
    }
    final digest = sha256.convert(utf8.encode(uid)).toString().substring(0, 16);
    await _fa.setUserId(id: digest);
  }

  static Future<void> log(String event,
      [Map<String, Object>? params]) async {
    await _fa.logEvent(name: event, parameters: params);
  }

  // Convenience for the handful of events we already know we want.
  static Future<void> appOpen() => log('app_open');
  static Future<void> login(String method) =>
      log('login', {'method': method});
  static Future<void> trailView(String trailId) =>
      log('trail_view', {'trail_id': trailId});
  static Future<void> hikeStarted(String trailId) =>
      log('hike_started', {'trail_id': trailId});
  static Future<void> hikeCompleted(String trailId, double km) =>
      log('hike_completed', {'trail_id': trailId, 'km': km});
  static Future<void> trailSubmitted() => log('trail_submitted');
  static Future<void> accountDeleted() => log('account_deleted');
}
