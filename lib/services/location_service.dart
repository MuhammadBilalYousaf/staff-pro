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
    this.permissionDenied = false,
    this.error,
  });

  final GeoPoint? point;
  final bool permissionDenied;
  final String? error;

  bool get hasPoint => point != null;
}

class LocationService {
  Future<LocationResult> currentPosition() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return const LocationResult(
        permissionDenied: true,
        error: 'Location permission is required to verify attendance.',
      );
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return const LocationResult(
        error: 'Turn on location services to capture attendance location.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LocationResult(point: GeoPoint(pos.latitude, pos.longitude));
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
