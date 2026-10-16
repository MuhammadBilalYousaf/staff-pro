import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class LocationResult {
  const LocationResult({
    this.point,
    this.accuracyMeters,
    this.permissionDenied = false,
    this.error,
  });

  final GeoPoint? point;
  final double? accuracyMeters;
  final bool permissionDenied;
  final String? error;

  bool get hasPoint => point != null;
}

class LocationService {
  /// Request location access early (app open) without requiring a fix.
  Future<bool> ensurePermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) return false;
    final enabled = await Geolocator.isLocationServiceEnabled();
    return enabled;
  }

  Future<LocationResult> currentPosition({bool precise = true}) async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return const LocationResult(
        permissionDenied: true,
        error: 'Location permission is required for attendance and shop location.',
      );
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return const LocationResult(
        error: 'Turn on location services to capture a precise GPS position.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: precise ? LocationAccuracy.best : LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
      return LocationResult(
        point: GeoPoint(pos.latitude, pos.longitude),
        accuracyMeters: pos.accuracy,
      );
    } catch (e) {
      return LocationResult(error: 'Unable to read GPS location. $e');
    }
  }

  static double distanceMeters(GeoPoint a, GeoPoint b) {
    const earth = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earth * asin(min(1, sqrt(h)));
  }

  static double _rad(double deg) => deg * pi / 180;
}
