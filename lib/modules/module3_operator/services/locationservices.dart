import 'package:geolocator/geolocator.dart';

class LocationService {
  static double? _latitude;
  static double? _longitude;

  /// Request permission and fetch current position quickly with fallback to
  /// last known location. We intentionally keep a short timeout to avoid
  /// blocking the UI while scanning QR codes.
  static Future<void> initLocation({Duration timeout = const Duration(seconds: 2)}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // Try to hydrate quickly from last known
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _latitude = last.latitude;
        _longitude = last.longitude;
      }
    } catch (_) {}

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: timeout,
      );
      _latitude = pos.latitude;
      _longitude = pos.longitude;
    } catch (_) {
      // Swallow timeouts/errors; we keep any last-known value.
    }
  }

  /// Return latitude or 0.0 if not available
  static double get latitude => _latitude ?? 0.0;
  /// Return longitude or 0.0 if not available
  static double get longitude => _longitude ?? 0.0;

  /// Refresh coordinates manually (for updates)
  static Future<void> refresh({Duration timeout = const Duration(seconds: 2)}) async =>
      await initLocation(timeout: timeout);
}
