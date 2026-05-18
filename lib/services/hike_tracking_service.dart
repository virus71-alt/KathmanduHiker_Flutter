import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Simple foreground GPS tracker. Distance is summed from successive locations.
/// For full background (locked screen) tracking on Android you can extend this
/// with `flutter_background_service` — see README. The tracker is exposed as a
/// global singleton so any screen can read live distance via streams.
class HikeTrackingService {
  HikeTrackingService._();
  static final HikeTrackingService instance = HikeTrackingService._();

  // 8 km/h ≈ 2.22 m/s. Anything above this is treated as vehicle travel and
  // dropped from the hike total. We pick the lower end of the 8–10 km/h band
  // so brisk hiking still counts but slow stop-and-go traffic does not.
  static const double _maxHikingSpeedMps = 2.22;
  // Drop points with poor fix quality — they cause phantom jumps that the
  // speed filter alone can't catch when several bad samples line up.
  static const double _minAccuracyMeters = 30;
  // Two thresholds for the per-sample distance delta: too small (GPS noise)
  // or too large (a jump that the speed filter should have caught but
  // didn't — e.g. when the previous sample was very old).
  static const double _minMoveMeters = 2.0;
  static const double _maxJumpMeters = 80.0;

  StreamSubscription<Position>? _sub;
  Position? _last;
  DateTime? _lastAt;

  final _isTracking = StreamController<bool>.broadcast();
  final _distance = StreamController<double>.broadcast();
  final _activeTrailId = StreamController<String?>.broadcast();

  bool _tracking = false;
  double _distanceMeters = 0;
  String? _trailId;

  Stream<bool> get isTracking => _isTracking.stream;
  Stream<double> get distanceTraveled => _distance.stream;
  Stream<String?> get activeTrailId => _activeTrailId.stream;

  bool get currentlyTracking => _tracking;
  double get currentDistance => _distanceMeters;
  String? get currentTrailId => _trailId;

  Future<bool> start(String trailId) async {
    if (_tracking) return false;
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return false;

    _tracking = true;
    _trailId = trailId;
    _distanceMeters = 0;
    _last = null;
    _lastAt = null;

    _isTracking.add(true);
    _distance.add(0);
    _activeTrailId.add(trailId);

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final now = DateTime.now();
      // Reject low-quality fixes outright — they cause phantom drift even
      // when the user is standing still or moving slowly.
      if (pos.accuracy.isFinite && pos.accuracy > _minAccuracyMeters) {
        _last = pos;
        _lastAt = now;
        return;
      }
      // Local-capture pattern (ULTIMATE.md §19.8): copy the nullable
      // class fields into locals so Dart's flow analysis knows they stay
      // non-null for the rest of the block. A bang on `_last!` would
      // technically work here but the lint rightly flags it.
      final prev = _last;
      final prevAt = _lastAt;
      if (prev != null && prevAt != null) {
        final delta = Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          pos.latitude,
          pos.longitude,
        );
        final dtSec = now.difference(prevAt).inMilliseconds / 1000.0;
        // Reported speed is unreliable on some devices, so derive it
        // from the time/distance delta as well and take the larger of the
        // two — being conservative keeps vehicle travel out of the total.
        final reported = pos.speed.isFinite && pos.speed > 0 ? pos.speed : 0.0;
        final derived = dtSec > 0 ? delta / dtSec : 0.0;
        final speed = reported > derived ? reported : derived;
        final withinHikingPace = speed > 0 && speed <= _maxHikingSpeedMps;
        final sensibleMove =
            delta >= _minMoveMeters && delta <= _maxJumpMeters;
        if (sensibleMove && withinHikingPace) {
          _distanceMeters += delta;
          _distance.add(_distanceMeters);
        }
      }
      _last = pos;
      _lastAt = now;
    });
    return true;
  }

  Future<double> stop() async {
    if (!_tracking) return _distanceMeters;
    await _sub?.cancel();
    _sub = null;
    final finalDistance = _distanceMeters;
    _tracking = false;
    _trailId = null;
    _isTracking.add(false);
    _activeTrailId.add(null);
    return finalDistance;
  }

  Future<bool> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }
}
