import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../core/logger.dart';

/// Wraps Firebase Remote Config so the rest of the app reads typed
/// values without caring about fetch state.
///
/// Add new flags by:
///   1. Adding a default to [_defaults] below.
///   2. Adding a typed getter.
///   3. Setting the live value in Firebase console.
class AppConfig {
  AppConfig._();
  static final AppConfig instance = AppConfig._();

  static const _defaults = <String, dynamic>{
    'min_build_number': 0,
    'force_update_message':
        'A new version of Kathmandu Hiker is required. Please update from the Play Store.',
    'show_leaderboard': true,
    'show_community_events': true,
  };

  bool _ready = false;

  Future<void> init() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await rc.setDefaults(_defaults);
    try {
      await rc.fetchAndActivate();
    } catch (e) {
      AppLog.w('remoteConfig.fetch.fail', error: e);
    }
    _ready = true;
  }

  bool get _hasRC => _ready;
  RemoteConfigValue _v(String key) =>
      FirebaseRemoteConfig.instance.getValue(key);

  int get minBuildNumber =>
      _hasRC ? _v('min_build_number').asInt() : 0;
  String get forceUpdateMessage =>
      _hasRC ? _v('force_update_message').asString() : '';
  bool get showLeaderboard =>
      _hasRC ? _v('show_leaderboard').asBool() : true;
  bool get showCommunityEvents =>
      _hasRC ? _v('show_community_events').asBool() : true;
}
