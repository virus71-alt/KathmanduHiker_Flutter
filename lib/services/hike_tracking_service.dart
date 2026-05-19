import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../domain/entities/trail.dart';

enum TrackingStatus {
  idle,
  tracking,
  pausedForSpeed,
  pausedOffTrail,
  pausedLowAccuracy,
}

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
  static const double _maxTrailDistanceMeters = 30000.0; // 30 km radius

  StreamSubscription<Position>? _sub;
  Position? _last;
  DateTime? _lastAt;

  final _isTracking = StreamController<bool>.broadcast();
  final _distance = StreamController<double>.broadcast();
  final _activeTrailId = StreamController<String?>.broadcast();
  final _trackingStatus = StreamController<TrackingStatus>.broadcast();

  bool _tracking = false;
  double _distanceMeters = 0;
  Trail? _activeTrail;

  Stream<bool> get isTracking => _isTracking.stream;
  Stream<double> get distanceTraveled => _distance.stream;
  Stream<String?> get activeTrailId => _activeTrailId.stream;
  Stream<TrackingStatus> get trackingStatus => _trackingStatus.stream;

  bool get currentlyTracking => _tracking;
  double get currentDistance => _distanceMeters;
  String? get currentTrailId => _activeTrail?.id;

  Future<bool> start(Trail trail) async {
    if (_tracking) return false;
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return false;

    _tracking = true;
    _activeTrail = trail;
    _distanceMeters = 0;
    _last = null;
    _lastAt = null;

    _isTracking.add(true);
    _distance.add(0);
    _activeTrailId.add(trail.id);
    _trackingStatus.add(TrackingStatus.tracking);

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final now = DateTime.now();

      // 1. Accuracy Validation
      if (!pos.accuracy.isFinite || pos.accuracy > _minAccuracyMeters) {
        _trackingStatus.add(TrackingStatus.pausedLowAccuracy);
        // Do NOT update _last. Ignore noisy points entirely to avoid phantom jumps.
        return;
      }

      // 2. Trail Proximity Validation
      if (_activeTrail != null) {
        final distanceFromStart = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, _activeTrail!.latitude, _activeTrail!.longitude);
        if (distanceFromStart > _maxTrailDistanceMeters) {
          _trackingStatus.add(TrackingStatus.pausedOffTrail);
          // Break the segment anchor so we don't count distance from here when they return
          _last = null;
          _lastAt = null;
          return;
        }
      }

      final prev = _last;
      final prevAt = _lastAt;

      if (prev != null && prevAt != null) {
        final delta = Geolocator.distanceBetween(
          prev.latitude, prev.longitude, pos.latitude, pos.longitude,
        );
        final dtSec = now.difference(prevAt).inMilliseconds / 1000.0;
        
        final reported = pos.speed.isFinite && pos.speed > 0 ? pos.speed : 0.0;
        final derived = dtSec > 0 ? delta / dtSec : 0.0;
        final speed = reported > derived ? reported : derived;
        
        // 3. Speed Validation
        if (speed > _maxHikingSpeedMps) {
          _trackingStatus.add(TrackingStatus.pausedForSpeed);
          // Auto-pause and break the segment. Discards the massive jump from a car ride.
          _last = null;
          _lastAt = null;
          return;
        }

        // 4. Minimum Movement Validation
        final sensibleMove = delta >= _minMoveMeters && delta <= _maxJumpMeters;
        if (sensibleMove) {
          _distanceMeters += delta;
          _distance.add(_distanceMeters);
        }
      }

      // Valid point, update anchor and unpause
      _trackingStatus.add(TrackingStatus.tracking);
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
    _activeTrail = null;
    _isTracking.add(false);
    _activeTrailId.add(null);
    _trackingStatus.add(TrackingStatus.idle);
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
