import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/services/location_service.dart';

class PickedLocation {
  const PickedLocation({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

/// Full-screen map to pick a shop/branch pin anywhere (OpenStreetMap).
class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.geofenceRadiusMeters = 200,
    this.title = 'Select shop location',
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final double geofenceRadiusMeters;
  final String title;

  static Future<PickedLocation?> open(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    double geofenceRadiusMeters = 200,
    String title = 'Select shop location',
  }) {
    return Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          geofenceRadiusMeters: geofenceRadiusMeters,
          title: title,
        ),
      ),
    );
  }

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  late final MapController _map = MapController();
  LatLng? _pin;
  bool _loadingGps = false;
  bool _userChosePin = false;

  static const _fallbackCenter = LatLng(31.5204, 74.3587);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _pin = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _userChosePin = true;
    }
  }

  Future<void> _useCurrent() async {
    setState(() => _loadingGps = true);
    final loc = await LocationService().currentPosition(precise: true);
    if (!mounted) return;
    setState(() => _loadingGps = false);
    if (loc.hasPoint) {
      final point = LatLng(loc.point!.latitude, loc.point!.longitude);
      setState(() {
        _pin = point;
        _userChosePin = true;
      });
      _map.move(point, 17);
    } else {
      showToast(context, loc.error ?? 'Location unavailable', error: true);
    }
  }

  void _confirm() {
    if (!_userChosePin || _pin == null) {
      showToast(context, 'Tap the map or use current GPS first', error: true);
      return;
    }
    Navigator.pop(
      context,
      PickedLocation(latitude: _pin!.latitude, longitude: _pin!.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.geofenceRadiusMeters.clamp(20, 5000).toDouble();
    final center = _pin ?? _fallbackCenter;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _userChosePin ? _confirm : null,
            child: const Text('Use pin', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _pin == null ? 12 : 15,
              onTap: (_, point) => setState(() {
                _pin = point;
                _userChosePin = true;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.staffpro.app',
              ),
              if (_pin != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _pin!,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (_pin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pin!,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.location_on, color: AppColors.danger, size: 48),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: AppCard(
              child: Text(
                _userChosePin
                    ? 'Blue circle ≈ ${radius.round()}m attendance range. Move the pin by tapping elsewhere.'
                    : 'Tap the map to place the shop pin, or use your current GPS. Confirm is disabled until you choose.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pin != null)
                  AppCard(
                    child: Text(
                      '${_pin!.latitude.toStringAsFixed(6)}, ${_pin!.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (_pin != null) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: _loadingGps ? 'Locating…' : 'My current location',
                        outlined: true,
                        icon: Icons.my_location,
                        onPressed: _loadingGps ? null : _useCurrent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'Confirm pin',
                        icon: Icons.check,
                        onPressed: _userChosePin ? _confirm : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
