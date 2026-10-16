import 'package:staffpro/services/location_service.dart';

/// Deterministic GPS for QA (Lahore — matches default QA branch pin).
class QaLocationService extends LocationService {
  QaLocationService({
    this.latitude = 31.5204,
    this.longitude = 74.3587,
    this.accuracyMeters = 8,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<LocationResult> currentPosition({bool precise = true}) async {
    return LocationResult(
      point: GeoPoint(latitude, longitude),
      accuracyMeters: accuracyMeters,
    );
  }
}
