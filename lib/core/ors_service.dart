import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:iwms_citizen_app/core/api_config.dart';

class ORSService {
  static String get _key => ApiConfig.orsApiKey;

  // ---------------------------------------------------------------------------
  // 1) Fetch Route (Single Origin → Destination)
  // ---------------------------------------------------------------------------
  static Future<List<LatLng>> fetchRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    if (!_isValid(origin) || !_isValid(destination)) {
      print("ORS ERROR → Invalid LatLng");
      return [];
    }

    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/driving-car",
    );

    final body = jsonEncode({
      "coordinates": [
        [origin.longitude, origin.latitude],
        [destination.longitude, destination.latitude],
      ],
      "instructions": false,
      "preference": "fastest",
      "units": "m",
      "geometry": true,
      "geometry_simplify": false,
      "geometry_format": "geojson",
    });

    try {
      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Authorization": _key,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print("ORS HTTP ERROR: ${response.statusCode}");
        print(response.body);
        return [];
      }

      final json = jsonDecode(response.body);

      final coordsList = _extractCoords(json);
      return coordsList;
    } catch (e, s) {
      print("ORS EXCEPTION: $e");
      print("STACK: $s");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 2) Fetch Optimized Multi-Stop Route
  // ---------------------------------------------------------------------------
  static Future<List<LatLng>> fetchMultiRoute(List<List<double>> coords) async {
    if (coords.length < 2) {
      print("ORS MULTI ERROR → need minimum 2 coords");
      return [];
    }

    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/driving-car/optimized",
    );

    final body = jsonEncode({
      "coordinates": coords,
      "instructions": false,
      "units": "m",
      "geometry": true,
      "geometry_format": "geojson",
      "geometry_simplify": false,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Authorization": _key},
        body: body,
      );

      if (response.statusCode != 200) {
        print("ORS MULTI HTTP ERROR: ${response.statusCode}");
        print(response.body);
        return [];
      }

      final json = jsonDecode(response.body);

      final coordsList = _extractCoords(json);
      return coordsList;
    } catch (e, s) {
      print("ORS MULTI EXCEPTION: $e");
      print("STACK: $s");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Extract coordinates safely — Shared logic
  // ---------------------------------------------------------------------------
  static List<LatLng> _extractCoords(dynamic json) {
    try {
      List<dynamic>? raw;

      // Optimized routes → json["routes"][0]["geometry"]["coordinates"]
      if (json is Map &&
          json["routes"] is List &&
          json["routes"].isNotEmpty &&
          json["routes"][0]["geometry"] != null &&
          json["routes"][0]["geometry"]["coordinates"] != null) {
        raw = json["routes"][0]["geometry"]["coordinates"] as List<dynamic>;
      }

      // Normal route → json["features"][0]["geometry"]["coordinates"]
      if (raw == null &&
          json is Map &&
          json["features"] is List &&
          json["features"].isNotEmpty &&
          json["features"][0]["geometry"] != null &&
          json["features"][0]["geometry"]["coordinates"] != null) {
        raw = json["features"][0]["geometry"]["coordinates"] as List<dynamic>;
      }

      if (raw == null) {
        print("ORS ERROR → geometry missing");
        return [];
      }

      final List<LatLng> out = [];

      for (final item in raw) {
        if (item is List && item.length >= 2) {
          final lon = item[0];
          final lat = item[1];
          if (lon is num && lat is num) {
            out.add(LatLng(lat.toDouble(), lon.toDouble()));
          }
        }
      }

      return out;
    } catch (e) {
      print("ORS COORD PARSE ERROR: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Bearing Calculation
  // ---------------------------------------------------------------------------
  static double calculateBearing(LatLng from, LatLng to) {
    try {
      final lat1 = _degToRad(from.latitude);
      final lat2 = _degToRad(to.latitude);
      final dLon = _degToRad(to.longitude - from.longitude);

      final y = math.sin(dLon) * math.cos(lat2);
      final x =
          math.cos(lat1) * math.sin(lat2) -
          math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

      double bearing = math.atan2(y, x);
      bearing = _radToDeg(bearing);
      return (bearing + 360) % 360;
    } catch (_) {
      return 0.0;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static bool _isValid(LatLng? p) {
    if (p == null) return false;
    return !(p.latitude.isNaN ||
        p.longitude.isNaN ||
        (p.latitude == 0.0 && p.longitude == 0.0));
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
  static double _radToDeg(double rad) => rad * 180 / math.pi;
}
