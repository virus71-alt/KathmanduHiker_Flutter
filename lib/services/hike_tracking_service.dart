import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Simple foreground GPS tracker. Distance is summed from successive locations.
/// For full background (locked screen) tracking on Android you can extend this
/// with `flutter_background_service` — see README. The tracker is exposed as a
/// global singleton so any screen can read live distance via streams.
class HikeTrackingService {
  HikeTrackingService._();
  static final HikeTrackingService instance = HikeTrackingService._();

  StreamSubscription<Position>? _sub;
  Position? _last;

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

    _isTracking.add(true);
    _distance.add(0);
    _activeTrailId.add(trailId);

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (_last != null) {
        final delta = Geolocator.distanceBetween(
          _last!.latitude,
          _last!.longitude,
          pos.latitude,
          pos.longitude,
        );
        // Ignore GPS noise (jumps < 1.5m) to keep the total realistic.
        if (delta > 1.5) {
          _distanceMeters += delta;
          _distance.add(_distanceMeters);
        }
      }
      _last = pos;
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
