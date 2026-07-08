import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// A read-only route map for a single daily trip assignment: draws the ORS
/// route line, the ordered collection points (collected vs remaining), and the
/// vehicle's last known position. Backed by:
///   • GET  daily-trip-collection-points/tracking/?trip_assignment_id=…
///   • POST daily-trip-collection-points/optimize-route/  {trip_assignment_id}
class SupervisorTripMapScreen extends StatefulWidget {
  const SupervisorTripMapScreen({
    super.key,
    required this.assignmentId,
    this.title = 'Trip route',
    this.driverName = '',
    this.vehicleNo = '',
    this.tripDate,
  });

  final String assignmentId;
  final String title;
  final String driverName;
  final String vehicleNo;
  final DateTime? tripDate;

  @override
  State<SupervisorTripMapScreen> createState() =>
      _SupervisorTripMapScreenState();
}

class _TripStop {
  _TripStop({
    required this.point,
    required this.name,
    required this.sequence,
    required this.collected,
  });
  final LatLng point;
  final String name;
  final int sequence;
  final bool collected;
}

class _SupervisorTripMapScreenState extends State<SupervisorTripMapScreen> {
  final MapController _map = MapController();

  bool _loading = true;
  String? _error;
  List<_TripStop> _stops = [];
  List<LatLng> _route = [];
  LatLng? _vehicle;
  int _total = 0;
  int _completed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = await authorizedDio();

      // Preferred: tracking-overview (GET) returns the ORS route geometry +
      // ordered stops + vehicle start for each trip — a read-only call that
      // works within the supervisor's view-only permissions.
      var matched = false;
      try {
        final overview = await dio.get(
          '${ApiConfig.desktopBase}schedule-masters/daily-trip-collection-points/tracking-overview/',
          queryParameters: {
            if (widget.tripDate != null) 'date': _fmtDate(widget.tripDate!),
          },
        );
        matched = _parseOverview(overview.data);
      } catch (_) {}

      // Fallback: per-assignment tracking (stops + live vehicle; route is drawn
      // by connecting stops in order when no ORS geometry is available).
      if (!matched) {
        final tracking = await dio.get(
          '${ApiConfig.desktopBase}schedule-masters/daily-trip-collection-points/tracking/',
          queryParameters: {'trip_assignment_id': widget.assignmentId},
        );
        _parseTracking(tracking.data);
        if (_route.isEmpty && _stops.isNotEmpty) {
          _route = _stops.map((s) => s.point).toList();
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load trip route';
        _loading = false;
      });
    }
  }

  void _parseTracking(dynamic data) {
    if (data is! Map) return;

    final results = data['route_results'];
    final stops = <_TripStop>[];
    if (results is List) {
      for (final r in results) {
        if (r is! Map) continue;
        final cp = r['collection_point'];
        final lat = _toD(cp is Map ? cp['latitude'] : null);
        final lng = _toD(cp is Map ? cp['longitude'] : null);
        if (lat == null || lng == null) continue;
        stops.add(_TripStop(
          point: LatLng(lat, lng),
          name: (cp is Map ? cp['cp_name'] : null)?.toString() ?? 'Stop',
          sequence: (r['sequence'] is num) ? (r['sequence'] as num).toInt() : 0,
          collected: r['is_collected'] == true ||
              (r['status']?.toString().toUpperCase() == 'COLLECTED'),
        ));
      }
    }
    stops.sort((a, b) => a.sequence.compareTo(b.sequence));

    final summary = data['summary'];
    final vt = data['vehicle_tracking'];
    final loc = vt is Map ? vt['current_location'] : null;
    LatLng? vehicle;
    if (loc is Map) {
      final lat = _toD(loc['latitude']);
      final lng = _toD(loc['longitude']);
      if (lat != null && lng != null) vehicle = LatLng(lat, lng);
    }

    _stops = stops;
    _vehicle = vehicle;
    _total = (summary is Map && summary['total'] is num)
        ? (summary['total'] as num).toInt()
        : stops.length;
    _completed = (summary is Map && summary['completed'] is num)
        ? (summary['completed'] as num).toInt()
        : stops.where((s) => s.collected).length;
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Parses tracking-overview: finds this assignment's trip and pulls its
  /// ORS route geometry, ordered stops, vehicle start and progress. Returns
  /// true when the assignment was found in the payload.
  bool _parseOverview(dynamic data) {
    if (data is! Map) return false;
    final trips = data['trips'];
    if (trips is! List) return false;

    Map? trip;
    for (final t in trips) {
      if (t is Map && t['assignment_id']?.toString() == widget.assignmentId) {
        trip = t;
        break;
      }
    }
    if (trip == null) return false;

    // Stops from `collection_points` (same nested shape as tracking rows).
    final cps = trip['collection_points'];
    final stops = <_TripStop>[];
    if (cps is List) {
      for (final r in cps) {
        if (r is! Map) continue;
        final cp = r['collection_point'];
        final lat = _toD(cp is Map ? cp['latitude'] : null);
        final lng = _toD(cp is Map ? cp['longitude'] : null);
        if (lat == null || lng == null) continue;
        stops.add(_TripStop(
          point: LatLng(lat, lng),
          name: (cp is Map ? cp['cp_name'] : null)?.toString() ?? 'Stop',
          sequence: (r['sequence'] is num) ? (r['sequence'] as num).toInt() : 0,
          collected: r['is_collected'] == true ||
              (r['status']?.toString().toUpperCase() == 'COLLECTED'),
        ));
      }
    }
    stops.sort((a, b) => a.sequence.compareTo(b.sequence));

    final vs = trip['vehicle_start'];
    if (vs is List && vs.length >= 2) {
      final lng = _toD(vs[0]);
      final lat = _toD(vs[1]);
      if (lat != null && lng != null) _vehicle = LatLng(lat, lng);
    }

    final coords = _extractLineCoords(trip['route_geojson']);

    final summary = trip['summary'];
    _stops = stops;
    _route = coords.isNotEmpty ? coords : stops.map((s) => s.point).toList();
    _total = (summary is Map && summary['total'] is num)
        ? (summary['total'] as num).toInt()
        : stops.length;
    _completed = (summary is Map && summary['completed'] is num)
        ? (summary['completed'] as num).toInt()
        : stops.where((s) => s.collected).length;
    return stops.isNotEmpty || coords.isNotEmpty;
  }

  /// GeoJSON coords are [lng, lat]; handle LineString, Feature, and
  /// FeatureCollection shapes.
  List<LatLng> _extractLineCoords(dynamic geojson) {
    dynamic geometry = geojson;
    if (geojson is Map && geojson['type'] == 'FeatureCollection') {
      final features = geojson['features'];
      if (features is List && features.isNotEmpty && features.first is Map) {
        geometry = (features.first as Map)['geometry'];
      }
    } else if (geojson is Map && geojson['type'] == 'Feature') {
      geometry = geojson['geometry'];
    }
    if (geometry is! Map) return const [];
    final coords = geometry['coordinates'];
    final out = <LatLng>[];
    if (coords is List) {
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lng = _toD(c[0]);
          final lat = _toD(c[1]);
          if (lat != null && lng != null) out.add(LatLng(lat, lng));
        }
      }
    }
    return out;
  }

  void _fit() {
    final pts = <LatLng>[
      ..._stops.map((s) => s.point),
      ..._route,
      if (_vehicle != null) _vehicle!,
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _map.move(pts.first, 15);
      return;
    }
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 140),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupervisorTheme.background,
      appBar: AppBar(
        backgroundColor: SupervisorTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SupervisorTheme.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: SupervisorTheme.danger, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: SupervisorTheme.mutedText)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: SupervisorTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final center = _stops.isNotEmpty
        ? _stops.first.point
        : (_vehicle ?? const LatLng(11.0, 78.0));

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            minZoom: 6,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.iwms.citizen.app',
            ),
            if (_route.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route,
                    color: SupervisorTheme.accent,
                    strokeWidth: 4.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final s in _stops)
                  Marker(
                    point: s.point,
                    width: 34,
                    height: 34,
                    child: _StopPin(
                      sequence: s.sequence,
                      collected: s.collected,
                    ),
                  ),
                if (_vehicle != null)
                  Marker(
                    point: _vehicle!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SupervisorTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: SupervisorTheme.softShadow,
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _ProgressHeader(
            driverName: widget.driverName,
            vehicleNo: widget.vehicleNo,
            completed: _completed,
            total: _total,
            remaining: (_total - _completed).clamp(0, _total),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 24,
          child: FloatingActionButton.small(
            heroTag: 'sup_trip_recenter',
            backgroundColor: Colors.white,
            foregroundColor: SupervisorTheme.accent,
            onPressed: _fit,
            child: const Icon(Icons.center_focus_strong_rounded),
          ),
        ),
      ],
    );
  }
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.sequence, required this.collected});

  final int sequence;
  final bool collected;

  @override
  Widget build(BuildContext context) {
    final color = collected ? SupervisorTheme.success : SupervisorTheme.warning;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: collected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text(
              '$sequence',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.driverName,
    required this.vehicleNo,
    required this.completed,
    required this.total,
    required this.remaining,
  });

  final String driverName;
  final String vehicleNo;
  final int completed;
  final int total;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (driverName.isNotEmpty) driverName,
      if (vehicleNo.isNotEmpty) vehicleNo,
    ].join('  •  ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: SupervisorTheme.softShadow,
        border: Border.all(color: SupervisorTheme.hairline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: SupervisorTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route_rounded,
                color: SupervisorTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed / $total stops collected',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SupervisorTheme.strongText,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: SupervisorTheme.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SupervisorTheme.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$remaining left',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: SupervisorTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
