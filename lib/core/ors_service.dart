import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:iwms_citizen_app/core/api_config.dart';

class ORSService {
  static String get _key => ApiConfig.orsApiKey;

  // ---------------------------------------------------------------------------
  // SINGLE ROUTE (A → B) - CORE METHOD
  // ---------------------------------------------------------------------------
  static Future<List<LatLng>> fetchRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car',
    );

    final body = jsonEncode({
      "coordinates": [
        [origin.longitude, origin.latitude],
        [destination.longitude, destination.latitude],
      ]
    });

    try {
      final resp = await http.post(
        url,
        headers: {
          'Authorization': _key,
          'Content-Type': 'application/json',
          'Accept': 'application/json, application/geo+json',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      debugPrint('ORS ROUTE STATUS: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        debugPrint('ORS ROUTE ERROR ${resp.statusCode}: ${resp.body}');
        return [origin, destination];
      }

      // Print the actual response to see structure
      debugPrint('ORS RESPONSE BODY: ${resp.body.substring(0, math.min(500, resp.body.length))}...');

      final decoded = jsonDecode(resp.body);
      final extracted = _extractDirectionsGeometry(decoded);
      
      debugPrint('ORS ROUTE EXTRACTED POINTS: ${extracted.length}');
      
      if (extracted.isEmpty) {
        debugPrint('ORS ROUTE GEOMETRY EMPTY - using fallback');
        return [origin, destination];
      }

      return extracted;
    } catch (e, stackTrace) {
      debugPrint('ORS ROUTE EXCEPTION: $e');
      debugPrint('STACK: $stackTrace');
      return [origin, destination];
    }
  }

  // ---------------------------------------------------------------------------
  // MULTI-STOP WRAPPER (for backward compatibility)
  // ---------------------------------------------------------------------------
  static Future<List<LatLng>> fetchMultiRoute(
    List<List<double>> coords,
  ) async {
    if (coords.length < 2) {
      debugPrint('ORS MULTI: Not enough coordinates');
      return [];
    }

    final driver = LatLng(coords.first[1], coords.first[0]);
    final stops = coords
        .skip(1)
        .map((c) => LatLng(c[1], c[0]))
        .toList();

    debugPrint('ORS MULTI: Driver at $driver, ${stops.length} stops');

    return fetchOptimizedMultiRoute(
      driver: driver,
      stops: stops,
    );
  }

  // ---------------------------------------------------------------------------
  // OPTIMIZED MULTI-STOP ROUTING
  // ---------------------------------------------------------------------------
  static Future<List<LatLng>> fetchOptimizedMultiRoute({
    required LatLng driver,
    required List<LatLng> stops,
  }) async {
    if (stops.isEmpty) {
      debugPrint('ORS OPT: No stops provided');
      return [];
    }

    debugPrint('ORS OPT: Starting with ${stops.length} stops');

    // Try optimization API first
    final optimizedOrder = await _tryOptimization(driver, stops);
    
    if (optimizedOrder != null && optimizedOrder.isNotEmpty) {
      debugPrint('ORS OPT: Got optimized order, building polyline...');
      return _buildPolyline([driver, ...optimizedOrder]);
    }

    // Fallback: use original order
    debugPrint('ORS OPT: Optimization failed, using original order');
    return _buildPolyline([driver, ...stops]);
  }

  // ---------------------------------------------------------------------------
  // ROAD ROUTE FOR ORDERED STOPS (NO RE-SEQUENCING)
  // ---------------------------------------------------------------------------
  static Future<List<LatLng>> fetchRoadRoute({
    required LatLng driver,
    required List<LatLng> stops,
  }) async {
    if (stops.isEmpty) return [];

    final coords = [
      [driver.longitude, driver.latitude],
      ...stops.map((s) => [s.longitude, s.latitude]),
    ];

    try {
      final resp = await http
          .post(
            Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
            headers: {
              'Authorization': _key,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({"coordinates": coords}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        debugPrint('ORS ROAD ROUTE ERROR ${resp.statusCode}: ${resp.body}');
        return [];
      }

      final data = jsonDecode(resp.body);
      final features = data is Map ? data['features'] : null;
      if (features is! List || features.isEmpty) return [];

      final geometry = features[0]?['geometry']?['coordinates'];
      if (geometry is! List || geometry.isEmpty) return [];

      return geometry
          .map<LatLng>(
            (c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('ORS ROAD ROUTE EXCEPTION: $e');
      return [];
    }
  }

  static Future<List<LatLng>?> _tryOptimization(
    LatLng driver,
    List<LatLng> stops,
  ) async {
    final url = Uri.parse('https://api.openrouteservice.org/optimization');

    final jobs = <Map<String, dynamic>>[];
    for (int i = 0; i < stops.length; i++) {
      jobs.add({
        "id": i + 1,
        "location": [stops[i].longitude, stops[i].latitude],
      });
    }

    final body = jsonEncode({
      "vehicles": [
        {
          "id": 1,
          "profile": "driving-car",
          "start": [driver.longitude, driver.latitude],
          "end": [driver.longitude, driver.latitude],
        }
      ],
      "jobs": jobs,
    });

    try {
      final resp = await http.post(
        url,
        headers: {
          'Authorization': _key,
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

      debugPrint('ORS OPT STATUS: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        debugPrint('ORS OPT ERROR ${resp.statusCode}: ${resp.body}');
        return null;
      }

      final json = jsonDecode(resp.body);
      final steps = json['routes']?[0]?['steps'];

      if (steps is! List || steps.isEmpty) {
        debugPrint('ORS OPT: Invalid or empty steps');
        return null;
      }

      final ordered = <LatLng>[];
      for (final s in steps) {
        if (s['type'] == 'job') {
          final loc = s['location'];
          if (loc is List && loc.length == 2) {
            ordered.add(LatLng(
              (loc[1] as num).toDouble(),
              (loc[0] as num).toDouble(),
            ));
          }
        }
      }

      debugPrint('ORS OPT: Extracted ${ordered.length} ordered stops');
      return ordered.isEmpty ? null : ordered;
    } catch (e) {
      debugPrint('ORS OPT EXCEPTION: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD POLYLINE FROM WAYPOINTS
  // ---------------------------------------------------------------------------
  static Future<List<LatLng>> _buildPolyline(List<LatLng> points) async {
    if (points.length < 2) {
      debugPrint('POLYLINE: Not enough points');
      return points;
    }

    debugPrint('POLYLINE: Building route through ${points.length} waypoints');
    final out = <LatLng>[];

    for (int i = 0; i < points.length - 1; i++) {
      debugPrint('POLYLINE: Segment $i -> ${i + 1}');
      final seg = await fetchRoute(points[i], points[i + 1]);
      
      if (seg.isNotEmpty) {
        // Avoid duplicating connection points
        if (out.isNotEmpty && seg.isNotEmpty) {
          seg.removeAt(0);
        }
        out.addAll(seg);
      } else {
        debugPrint('POLYLINE: Segment $i failed, skipping');
      }
    }

    debugPrint('POLYLINE: Final route has ${out.length} points');
    return out;
  }

  // ---------------------------------------------------------------------------
  // EXTRACT GEOMETRY FROM ORS RESPONSE - FIXED VERSION
  // ---------------------------------------------------------------------------
  static List<LatLng> _extractDirectionsGeometry(dynamic json) {
    try {
      debugPrint('GEOMETRY PARSING: Checking response structure...');
      
      // ORS v2 API returns: { features: [...], routes: [...] }
      // We need to check both possible structures
      
      // Try GeoJSON format first (features)
      if (json['features'] != null && json['features'] is List) {
        final features = json['features'] as List;
        debugPrint('GEOMETRY: Found features array with ${features.length} items');
        
        if (features.isNotEmpty) {
          final firstFeature = features[0];
          final coords = firstFeature['geometry']?['coordinates'];
          
          if (coords is List && coords.isNotEmpty) {
            debugPrint('GEOMETRY: Extracting from features[0].geometry.coordinates');
            return coords
                .map((c) => LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    ))
                .toList();
          }
        }
      }
      
      // Try routes format (alternative structure)
      if (json['routes'] != null && json['routes'] is List) {
        final routes = json['routes'] as List;
        debugPrint('GEOMETRY: Found routes array with ${routes.length} items');
        
        if (routes.isNotEmpty) {
          final firstRoute = routes[0];
          
          // Check for encoded polyline
          if (firstRoute['geometry'] is String) {
            debugPrint('GEOMETRY: Found encoded polyline string');
            final encoded = firstRoute['geometry'] as String;
            return decodePolyline(encoded);
          }
          
          // Check for geometry object
          if (firstRoute['geometry'] is Map) {
            final coords = firstRoute['geometry']['coordinates'];
            if (coords is List && coords.isNotEmpty) {
              debugPrint('GEOMETRY: Extracting from routes[0].geometry.coordinates');
              return coords
                  .map((c) => LatLng(
                        (c[1] as num).toDouble(),
                        (c[0] as num).toDouble(),
                      ))
                  .toList();
            }
          }
        }
      }
      
      debugPrint('GEOMETRY: No valid coordinates found in response');
      debugPrint('GEOMETRY: Available keys: ${json.keys.toList()}');
      return [];
      
    } catch (e, stackTrace) {
      debugPrint('GEOMETRY PARSE ERROR: $e');
      debugPrint('STACK: $stackTrace');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // POLYLINE DECODER (for encoded geometry strings)
  // ---------------------------------------------------------------------------
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    debugPrint('POLYLINE DECODED: ${points.length} points');
    return points;
  }

  // ---------------------------------------------------------------------------
  // BEARING CALCULATION
  // ---------------------------------------------------------------------------
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lat2 = _degToRad(to.latitude);
    final dLon = _degToRad(to.longitude - from.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return (_radToDeg(math.atan2(y, x)) + 360) % 360;
  }

  static double _degToRad(double d) => d * math.pi / 180;
  static double _radToDeg(double r) => r * 180 / math.pi;
}
