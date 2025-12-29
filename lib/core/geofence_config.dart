import 'package:latlong2/latlong.dart';

/// Centralised configuration for static geofences used inside the app.
class GammaGeofenceConfig {
  const GammaGeofenceConfig._();
  static const String name = 'Gamma 1';
  /// Approximate centre point (used for map camera defaults).
  static final LatLng center = _polygon.fold<LatLng>(
    const LatLng(0, 0),
    (previousValue, point) => LatLng(
      previousValue.latitude + point.latitude / _polygon.length,
      previousValue.longitude + point.longitude / _polygon.length,
    ),
  );

  /// Lowercase hint taken from the provider address field for resilience.
  static const String addressHint =
      'blue planet integrated waste management facility';

  /// Polygon describing the Gamma 1 perimeter (clockwise order).
  static List<LatLng> get polygon => List.unmodifiable(_polygon);

  static const List<LatLng> _polygon = [
    // GAMMA 1 vertices from viewSiteV2 API (userId=BLUEPLANET)
    LatLng(28.488876, 77.50349395599494),
    LatLng(28.48923800793327, 77.50413414293003),
    LatLng(28.490354381034557, 77.50361561557074),
    LatLng(28.491033306194158, 77.50131255819706),
    LatLng(28.49027894463618, 77.49890221246272),
    LatLng(28.48967924612614, 77.4979303669922),
    LatLng(28.488664638341163, 77.4970872675544),
    LatLng(28.486409076190427, 77.49507920359704),
    LatLng(28.483255762046685, 77.49739308895748),
    LatLng(28.48394232621382, 77.49845165092357),
    LatLng(28.484572305555172, 77.49959604357812),
    LatLng(28.4831276593093, 77.49983921400369),
    LatLng(28.47991007809596, 77.50192774423152),
    LatLng(28.48206963574756, 77.50288969709781),
    LatLng(28.484134848261156, 77.5035727002265),
    LatLng(28.48539088110138, 77.50448642290579),
    LatLng(28.486345142487355, 77.50595804506015),
    LatLng(28.487704876699937, 77.5050264079372),
    LatLng(28.489176830945848, 77.50410997826121),
  ];

  static final Distance _distance = Distance();

  /// Checks whether [point] lies inside the Gamma 1 polygon using a
  /// ray-casting algorithm.
  static bool contains(LatLng point) {
    final double x = point.longitude;
    final double y = point.latitude;
    bool inside = false;

    for (int i = 0, j = _polygon.length - 1; i < _polygon.length; j = i++) {
      final double xi = _polygon[i].longitude;
      final double yi = _polygon[i].latitude;
      final double xj = _polygon[j].longitude;
      final double yj = _polygon[j].latitude;

      final bool intersectY = ((yi > y) != (yj > y));
      if (!intersectY) continue;

      final double slope =
          (yj - yi).abs() < 1e-9 ? double.infinity : (xj - xi) / (yj - yi);
      final double xIntersection =
          slope.isInfinite ? xi : slope * (y - yi) + xi;

      if (x < xIntersection) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Returns true when [point] is within [toleranceMeters] of the polygon
  /// centre—used as a graceful fallback when API metadata only flags the
  /// facility without precise vertices.
  static bool isNear(LatLng point, {double toleranceMeters = 120}) {
    return _distance(point, center) <= toleranceMeters;
  }
}
