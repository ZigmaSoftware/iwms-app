import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:iwms_citizen_app/modules/module1_citizen/citizen/theme/citizen_theme.dart';
import '../../../core/di.dart';
import '../../../core/geofence_config.dart';
import '../../../data/models/site_polygon.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/site_repository.dart';
import '../../../logic/vehicle_tracking/vehicle_bloc.dart';
import '../../../router/app_router.dart';

class CitizenPersonalMapScreen extends StatefulWidget {
  const CitizenPersonalMapScreen({
    super.key,
    this.vehicleId,
    this.vehicleNumber,
    this.siteName,
  });

  final String? vehicleId;
  final String? vehicleNumber;
  final String? siteName;

  @override
  State<CitizenPersonalMapScreen> createState() =>
      _CitizenPersonalMapScreenState();
}

class _CitizenPersonalMapScreenState extends State<CitizenPersonalMapScreen> {
  final MapController _mapController = MapController();
  List<SitePolygon> _sites = const [];
  bool _loadingSites = true;
  LatLng? _lastCameraTarget;
  VehicleModel? _selectedVehicle;
  bool _showVehicleDetails = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    try {
      final repo = getIt<SiteRepository>();
      final data = await repo.fetchSites();
      if (!mounted) return;
      setState(() {
        _sites = data;
        _loadingSites = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSites = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<VehicleBloc>(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: CitizenColors.primary,
          title: const Text(
            'My Vehicle Map',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              } else {
                router.go(AppRoutePaths.citizenHome);
              }
            },
          ),
        ),
        body: BlocBuilder<VehicleBloc, VehicleState>(
          builder: (context, state) {
            final allVehicles = state is VehicleLoaded
                ? state.vehicles
                : const <VehicleModel>[];
            final filteredVehicles = _visibleVehicles(allVehicles);
            final selectedSite =
                _resolveSite(filteredVehicles, allVehicles, widget.siteName);
            final cameraTarget =
                _resolveCameraTarget(filteredVehicles, selectedSite);

            _moveCameraOnce(cameraTarget);

            // Keep the selection in sync with the latest data.
            if (_selectedVehicle != null) {
              final stillPresent = filteredVehicles.any(
                (v) => v.id == _selectedVehicle!.id,
              );
              if (!stillPresent && _showVehicleDetails) {
                _selectedVehicle = null;
                _showVehicleDetails = false;
              }
            }

            final showLoader = _loadingSites ||
                state is VehicleLoading ||
                state is VehicleInitial;
            final showEmptyState =
                state is VehicleLoaded && filteredVehicles.isEmpty;

            return Stack(
              children: [
                Positioned.fill(
                  child: _buildMap(
                    context,
                    filteredVehicles,
                    selectedSite,
                    cameraTarget,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _GeofenceBanner(
                    siteName: selectedSite?.name ??
                        widget.siteName ??
                        GammaGeofenceConfig.name,
                  ),
                ),
                if (showEmptyState) _buildEmptyState(context),
                if (_showVehicleDetails && _selectedVehicle != null)
                  _buildVehicleInfo(context, _selectedVehicle!),
                if (showLoader)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (state is VehicleError) _buildErrorState(state.message),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    List<VehicleModel> vehicles,
    SitePolygon? site,
    LatLng cameraTarget,
  ) {
    final theme = Theme.of(context);
    final polygons = <Polygon>[
      Polygon(
        points: site?.points ?? GammaGeofenceConfig.polygon,
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderColor: theme.colorScheme.primary,
        borderStrokeWidth: 2.2,
      ),
    ];
    final markers = vehicles
        .map(
          (vehicle) => Marker(
            width: 70,
            height: 70,
            point: LatLng(vehicle.latitude, vehicle.longitude),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedVehicle = vehicle;
                  _showVehicleDetails = true;
                });
              },
              child: _PersonalVehicleMarker(
                vehicle: vehicle,
                statusColor:
                    context.read<VehicleBloc>().getStatusColor(vehicle.status),
              ),
            ),
          ),
        )
        .toList(growable: false);

    final bounds = _boundsFor(site);

    final cameraConstraint = bounds != null
        ? CameraConstraint.containCenter(bounds: bounds)
        : const CameraConstraint.unconstrained();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: cameraTarget,
        initialZoom: 15,
        minZoom: 10,
        maxZoom: 18,
        cameraConstraint: cameraConstraint,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, __) {
          setState(() {
            _showVehicleDetails = false;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.zigma.iwmsapp',
        ),
        PolygonLayer(polygons: polygons),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: const [
            TextSourceAttribution('© OpenStreetMap, © CARTO'),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleInfo(BuildContext context, VehicleModel vehicle) {
    final theme = Theme.of(context);
    final statusColor =
        context.read<VehicleBloc>().getStatusColor(vehicle.status);
    return Positioned(
      bottom: 14,
      left: 16,
      right: 16,
      child: Material(
        elevation: 14,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.registrationNumber ?? 'Unknown vehicle',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (vehicle.status ?? 'N/A').toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if ((vehicle.driverName ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vehicle.driverName!,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if ((vehicle.address ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined,
                        color: theme.colorScheme.secondary, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vehicle.address!,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: 'Load',
                    value:
                        '${(vehicle.wasteCapacityKg ?? 0).toStringAsFixed(1)} kg',
                  ),
                  _InfoChip(
                    label: 'Last update',
                    value: vehicle.lastUpdated ?? 'N/A',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      bottom: 30,
      left: 16,
      right: 16,
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline,
                  color: theme.colorScheme.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                'No assigned vehicle is active inside your geofence right now.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Positioned(
      bottom: 30,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade800),
          ),
        ),
      ),
    );
  }

  void _moveCameraOnce(LatLng target) {
    final previous = _lastCameraTarget;
    final isSame = previous != null &&
        (target.latitude - previous.latitude).abs() < 0.0001 &&
        (target.longitude - previous.longitude).abs() < 0.0001;
    if (isSame) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentZoom = _mapController.camera.zoom;
      final targetZoom = currentZoom < 15 ? 15.0 : currentZoom;
      _mapController.move(target, targetZoom);
      _lastCameraTarget = target;
    });
  }

  List<VehicleModel> _visibleVehicles(List<VehicleModel> vehicles) {
    if (vehicles.isEmpty) return const [];

    final vehicleId = widget.vehicleId?.toLowerCase();
    if (vehicleId != null && vehicleId.isNotEmpty) {
      final byId = vehicles
          .where((v) => v.id.toLowerCase() == vehicleId)
          .toList(growable: false);
      if (byId.isNotEmpty) return byId;
    }

    final regNumber = widget.vehicleNumber?.toLowerCase();
    if (regNumber != null && regNumber.isNotEmpty) {
      final byNumber = vehicles
          .where((v) => (v.registrationNumber ?? '').toLowerCase() == regNumber)
          .toList(growable: false);
      if (byNumber.isNotEmpty) return byNumber;
    }

    final explicitSite = _findSiteByName(widget.siteName);
    if (explicitSite != null) {
      return _filterVehiclesBySite(vehicles, explicitSite);
    }

    if (_sites.isNotEmpty) {
      final inferredSite = _siteContainingVehicleList(vehicles);
      if (inferredSite != null) {
        return _filterVehiclesBySite(vehicles, inferredSite);
      }
    }

    final fallback = vehicles
        .where((vehicle) =>
            GammaGeofenceConfig.contains(
              LatLng(vehicle.latitude, vehicle.longitude),
            ) ||
            vehicle.isInsideGeofence)
        .toList(growable: false);
    return fallback;
  }

  SitePolygon? _resolveSite(
    List<VehicleModel> filtered,
    List<VehicleModel> allVehicles,
    String? desiredSite,
  ) {
    final byName = _findSiteByName(desiredSite);
    if (byName != null) return byName;
    if (_sites.isEmpty) return null;

    final source = filtered.isNotEmpty ? filtered : allVehicles;
    for (final vehicle in source) {
      final match = _findSiteContainingVehicle(vehicle);
      if (match != null) return match;
    }
    return null;
  }

  SitePolygon? _findSiteByName(String? name) {
    if (name == null || name.isEmpty || _sites.isEmpty) return null;
    final target = name.toLowerCase();
    for (final site in _sites) {
      if (site.name.toLowerCase() == target) {
        return site;
      }
    }
    return null;
  }

  SitePolygon? _siteContainingVehicleList(List<VehicleModel> vehicles) {
    for (final vehicle in vehicles) {
      final match = _findSiteContainingVehicle(vehicle);
      if (match != null) return match;
    }
    return null;
  }

  SitePolygon? _findSiteContainingVehicle(VehicleModel vehicle) {
    if (_sites.isEmpty) return null;
    final point = LatLng(vehicle.latitude, vehicle.longitude);
    for (final site in _sites) {
      if (_pointInPolygon(point, site.points)) {
        return site;
      }
    }
    return null;
  }

  List<VehicleModel> _filterVehiclesBySite(
    List<VehicleModel> vehicles,
    SitePolygon site,
  ) {
    return vehicles
        .where(
          (vehicle) => _pointInPolygon(
            LatLng(vehicle.latitude, vehicle.longitude),
            site.points,
          ),
        )
        .toList(growable: false);
  }

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    final double x = point.longitude;
    final double y = point.latitude;
    bool inside = false;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

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

  LatLng _resolveCameraTarget(List<VehicleModel> vehicles, SitePolygon? site) {
    if (vehicles.isNotEmpty) {
      final vehicle = vehicles.first;
      return LatLng(vehicle.latitude, vehicle.longitude);
    }
    if (site != null && site.points.isNotEmpty) {
      return _polygonCentroid(site.points);
    }
    return GammaGeofenceConfig.center;
  }

  LatLng _polygonCentroid(List<LatLng> points) {
    if (points.isEmpty) return GammaGeofenceConfig.center;
    double lat = 0;
    double lng = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  LatLngBounds? _boundsFor(SitePolygon? site) {
    final points = site?.points ?? GammaGeofenceConfig.polygon;
    if (points.length < 2) return null;
    return LatLngBounds.fromPoints(points);
  }
}

class _GeofenceBanner extends StatelessWidget {
  const _GeofenceBanner({required this.siteName});

  final String siteName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.shield_moon_outlined,
              color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vehicles limited to $siteName geofence',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalVehicleMarker extends StatelessWidget {
  const _PersonalVehicleMarker({
    required this.vehicle,
    required this.statusColor,
  });

  final VehicleModel vehicle;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/marker.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
