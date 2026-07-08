import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

import '../../../core/constants.dart';
import '../../../core/di.dart';
import '../../../core/geofence_config.dart';
import '../../../router/app_router.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/site_polygon.dart';
import '../../../data/repositories/site_repository.dart';
import '../../../logic/vehicle_tracking/vehicle_bloc.dart';
import '../../../logic/vehicle_tracking/vehicle_event.dart';
import '../../../shared/widgets/home_base_marker.dart';
import '../../../shared/widgets/tracking_view_shell.dart';

class MapScreen extends StatefulWidget {
  final String? driverName;
  final String? vehicleNumber;
  final bool showBackButton;

  const MapScreen({
    super.key,
    this.driverName,
    this.vehicleNumber,
    this.showBackButton = true,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

const Color _mapAccent = Color.fromARGB(255, 0, 61, 126);
const Color _mapAccentDeep = Color.fromARGB(255, 31, 91, 231);

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _gammaCenter = GammaGeofenceConfig.center;

  _MapThemeOption _selectedTheme = _MapThemeOption.light;
  String _searchQuery = '';

  // Prevent camera auto-fit repeatedly after user zooms or moves map
  bool _hasInitialFitDone = false;
  LatLngBounds? _previousBounds;

  // Site polygons from API
  List<SitePolygon> _sites = const [];

  static const Map<_MapThemeOption, _MapThemeConfig> _mapThemes = {
    _MapThemeOption.standard: _MapThemeConfig(
      label: 'Standard',
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
      attribution: '© OpenStreetMap contributors',
    ),
    _MapThemeOption.light: _MapThemeConfig(
      label: 'Light',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap, © CARTO',
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    final repo = getIt<SiteRepository>();
    final result = await repo.fetchSites();

    if (!mounted) return;

    setState(() {
      _sites = result;
    });
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom + 0.6).clamp(10.0, 18.0).toDouble();
    _mapController.move(_mapController.camera.center, targetZoom);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom - 0.6).clamp(10.0, 18.0).toDouble();
    _mapController.move(_mapController.camera.center, targetZoom);
  }

  void _recenterOnGamma() {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = currentZoom < 14.0 ? 14.0 : currentZoom;
    _mapController.move(_gammaCenter, targetZoom);
  }

  void _setTheme(_MapThemeOption theme) {
    if (_selectedTheme == theme) return;

    setState(() {
      _selectedTheme = theme;
    });
  }

  bool _isValidLatLng(double lat, double lng) {
    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        lat != 0.0 &&
        lng != 0.0;
  }

  // ---------------------------------------------------------------------------
  // AUTO-FIT LOGIC
  // ---------------------------------------------------------------------------

  void _autoFitVehicles(List<VehicleModel> vehicles) {
    if (!mounted) return;

    final validVehiclePoints = vehicles
        .where((v) => _isValidLatLng(v.latitude, v.longitude))
        .map((v) => LatLng(v.latitude, v.longitude))
        .toList();

    final points = <LatLng>[
      _gammaCenter,
      ...validVehiclePoints,
    ];

    if (points.length == 1) {
      _mapController.move(_gammaCenter, 14.0);
      _previousBounds = null;
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);

    if (_previousBounds != null &&
        _previousBounds!.southWest == bounds.southWest &&
        _previousBounds!.northEast == bounds.northEast) {
      return;
    }

    _previousBounds = bounds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
        maxZoom: 16,
        minZoom: 12,
      );

      _mapController.fitCamera(cameraFit);
    });
  }

  Widget _buildGammaFacilityMarker() {
    return const HomeBaseMarker(
      size: 18,
      gradientColors: [_mapAccent, _mapAccentDeep],
    );
  }

  Iterable<Marker> _buildArcMarkers(LatLng start, LatLng end) sync* {
    final arcPoints = _generateArcPoints(start, end);

    for (var i = 1; i < arcPoints.length - 1; i += 2) {
      final point = arcPoints[i];

      yield Marker(
        width: 8,
        height: 8,
        point: point,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: _mapAccentDeep.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
        ),
      );
    }
  }

  List<LatLng> _generateArcPoints(
    LatLng start,
    LatLng end, {
    int segments = 20,
    double curveStrength = 0.003,
  }) {
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;

    final control = LatLng(
      midLat - dy * curveStrength,
      midLng + dx * curveStrength,
    );

    final pts = <LatLng>[];

    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final invT = 1 - t;

      final lat = invT * invT * start.latitude +
          2 * invT * t * control.latitude +
          t * t * end.latitude;

      final lng = invT * invT * start.longitude +
          2 * invT * t * control.longitude +
          t * t * end.longitude;

      pts.add(LatLng(lat, lng));
    }

    return pts;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<VehicleBloc>(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: SafeArea(
          child: BlocConsumer<VehicleBloc, VehicleState>(
            listenWhen: (prev, curr) => curr is VehicleLoaded,
            listener: (context, state) {
              if (state is VehicleLoaded && !_hasInitialFitDone) {
                _hasInitialFitDone = true;
                _autoFitVehicles(state.vehicles);
              }
            },
            builder: (context, state) {
              final size = MediaQuery.of(context).size;
              final localizations = AppLocalizations.of(context);
              final headerHeight = size.height * 0.20;

              final int totalVehicles =
                  state is VehicleLoaded ? state.vehicles.length : 0;

              final VehicleModel? selectedVehicle =
                  state is VehicleLoaded ? state.selectedVehicle : null;

              final vehicleName = selectedVehicle?.registrationNumber ??
                  localizations.mapUnknownVehicle;

              final headline = selectedVehicle != null
                  ? localizations.mapVehicleHeadline(vehicleName)
                  : localizations.mapLiveHeadline;

              final statusPrimary = selectedVehicle?.lastUpdated ??
                  localizations.mapRefreshingTelemetry;

              final statusSecondary =
                  localizations.vehiclesActive(totalVehicles);

              return Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    width: double.infinity,
                    child: TrackingHeroHeader(
                      contextLabel: widget.vehicleNumber ??
                          localizations.mapGammaCollectionZone,
                      headline: headline,
                      statusPrimary: statusPrimary,
                      statusSecondary: statusSecondary,
                      gradientColors: const [
                        Color.fromARGB(255, 0, 79, 162),
                        Color.fromARGB(255, 0, 50, 119),
                      ],
                      statusContent: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildSearchBar(localizations),
                      ),
                      onBack: widget.showBackButton
                          ? () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(AppRoutePaths.citizenHome);
                              }
                            }
                          : null,
                      onRefresh: () {
                        context.read<VehicleBloc>().add(
                              const VehicleFetchRequested(showLoading: true),
                            );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildHeaderFilterSection(
                      context,
                      state,
                      localizations,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Stack(
                            children: [
                              _buildMap(context, state),
                              _buildMapStyleSelector(state, localizations),
                              _buildZoomControls(state),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: selectedVehicle != null
                                    ? Align(
                                        key: const ValueKey(
                                          'selectedVehicleBubble',
                                        ),
                                        alignment: Alignment.center,
                                        child: TrackingSpeechBubble(
                                          message:
                                              localizations.mapVehicleEnRoute(
                                            selectedVehicle
                                                    .registrationNumber ??
                                                localizations.mapUnknownVehicle,
                                          ),
                                          icon: Icons.local_shipping_rounded,
                                          iconColor: _mapAccentDeep,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (state is VehicleLoading)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              if (state is VehicleError)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      state.message,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              _buildVehicleInfoPanel(
                                context,
                                state,
                                localizations,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAP WIDGET
  // ---------------------------------------------------------------------------

  Widget _buildMap(BuildContext context, VehicleState state) {
    List<VehicleModel> vehiclesToShow = [];
    VehicleModel? selectedVehicle;
    VehicleFilter activeFilter = VehicleFilter.all;

    if (state is VehicleLoaded) {
      activeFilter = state.activeFilter;
      selectedVehicle = state.selectedVehicle;

      vehiclesToShow = state.vehicles.where((vehicle) {
        final status = vehicle.status?.toLowerCase() ?? 'no data';

        switch (activeFilter) {
          case VehicleFilter.all:
            return true;
          case VehicleFilter.running:
            return status == 'running';
          case VehicleFilter.idle:
            return status == 'idle';
          case VehicleFilter.parked:
            return status == 'parked';
          case VehicleFilter.noData:
            return status == 'no data';
        }
      }).toList();

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();

        vehiclesToShow = vehiclesToShow.where((v) {
          final reg = (v.registrationNumber ?? '').toLowerCase();
          final name = (v.driverName ?? '').toLowerCase();
          final addr = (v.address ?? '').toLowerCase();

          return reg.contains(q) || name.contains(q) || addr.contains(q);
        }).toList();
      }

      vehiclesToShow = vehiclesToShow
          .where((v) => _isValidLatLng(v.latitude, v.longitude))
          .toList();
    }

    final List<Marker> arcMarkers = [];

    if (selectedVehicle != null &&
        _isValidLatLng(selectedVehicle.latitude, selectedVehicle.longitude)) {
      final point = LatLng(
        selectedVehicle.latitude,
        selectedVehicle.longitude,
      );

      arcMarkers.addAll(_buildArcMarkers(_gammaCenter, point));
    }

    final markers = <Marker>[
      ...arcMarkers,

      // Vehicle markers
      for (final v in vehiclesToShow)
        Marker(
          width: selectedVehicle?.id == v.id ? 52 : 44,
          height: selectedVehicle?.id == v.id ? 52 : 44,
          point: LatLng(v.latitude, v.longitude),

          // Important fix:
          // Use center alignment so marker stays on exact lat/lng during zoom.
          alignment: Alignment.center,

          child: GestureDetector(
            onTap: () {
              context.read<VehicleBloc>().add(
                    VehicleSelectionUpdated(v.id),
                  );
            },
            child: _VehicleMarker(
              vehicle: v,
              isSelected: selectedVehicle?.id == v.id,
              getVehicleStatusColor: context.read<VehicleBloc>().getStatusColor,
            ),
          ),
        ),

      // Home base marker
      Marker(
        width: 28,
        height: 28,
        point: _gammaCenter,
        alignment: Alignment.center,
        child: _buildGammaFacilityMarker(),
      ),
    ];

    final themeConfig = _mapThemes[_selectedTheme]!;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _gammaCenter,
        initialZoom: 14.5,
        minZoom: 10,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (tapPos, latlng) {
          context.read<VehicleBloc>().add(
                const VehicleSelectionUpdated(null),
              );
        },
      ),
      children: [
        TileLayer(
          urlTemplate: themeConfig.urlTemplate,
          subdomains: themeConfig.subdomains,
          userAgentPackageName: 'com.iwms.citizen.app',
        ),
        if (_sites.isNotEmpty)
          PolygonLayer(
            polygons: _sites
                .map(
                  (s) => Polygon(
                    points: s.points,
                    color: const Color(0xFFF2A93B).withValues(alpha: 0.12),
                    borderColor: const Color(0xFFE08E1D),
                    borderStrokeWidth: 3,
                    pattern: StrokePattern.dashed(segments: const [14, 10]),
                    strokeCap: StrokeCap.round,
                    label: s.name,
                    labelStyle: const TextStyle(
                      color: Color(0xFF8A5A0B),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                )
                .toList(),
          )
        else
          PolygonLayer(
            polygons: [
              Polygon(
                points: GammaGeofenceConfig.polygon,
                color: const Color(0xFFF2A93B).withValues(alpha: 0.12),
                borderColor: const Color(0xFFE08E1D),
                borderStrokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [14, 10]),
                strokeCap: StrokeCap.round,
                label: 'Gamma Collection Zone',
                labelStyle: const TextStyle(
                  color: Color(0xFF8A5A0B),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomRight,
          attributions: [
            TextSourceAttribution(
              themeConfig.attribution,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER FILTER SECTION
  // ---------------------------------------------------------------------------

  Widget _buildHeaderFilterSection(
    BuildContext context,
    VehicleState state,
    AppLocalizations localizations,
  ) {
    final bloc = context.read<VehicleBloc>();
    VehicleFilter activeFilter = VehicleFilter.all;

    if (state is VehicleLoaded) {
      activeFilter = state.activeFilter;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: VehicleFilter.values.map((filter) {
          final isSelected = activeFilter == filter;
          final count = bloc.countVehiclesByFilter(filter);
          final label = '${localizations.vehicleFilterLabel(filter)} ($count)';
          final color = _filterColor(filter);

          final textColor =
              filter == VehicleFilter.all ? Colors.black87 : Colors.white;

          final unselectedTint = filter == VehicleFilter.all
              ? Colors.black26
              : color.withValues(alpha: 0.22);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? textColor : Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: color,
              backgroundColor: isSelected
                  ? color
                  : filter == VehicleFilter.all
                      ? Colors.white.withValues(alpha: 0.95)
                      : color.withValues(alpha: 0.12),
              side: BorderSide(
                color: isSelected ? color : unselectedTint,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(
                horizontal: -2,
                vertical: -2,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              onSelected: (_) {
                bloc.add(VehicleFilterUpdated(filter));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations localizations) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: Colors.black54,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: localizations.mapSearchHint,
                hintStyle: const TextStyle(
                  color: Colors.black45,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) {
                setState(() {
                  _searchQuery = v.trim();
                });
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 18,
                color: Colors.black54,
              ),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAP STYLE SELECTOR
  // ---------------------------------------------------------------------------

  Widget _buildMapStyleSelector(
    VehicleState state,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double bottomOffset = 12.0 + safeBottom;

    return Positioned(
      bottom: bottomOffset,
      left: 10,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Wrap(
            spacing: 4,
            alignment: WrapAlignment.start,
            children: _mapThemes.entries.map((entry) {
              final option = entry.key;
              final bool isSelected = _selectedTheme == option;

              return ChoiceChip(
                label: Text(_mapThemeLabel(option, localizations)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _setTheme(option);
                  }
                },
                selectedColor: _mapAccent,
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -3,
                  vertical: -3,
                ),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _mapThemeLabel(
    _MapThemeOption option,
    AppLocalizations localizations,
  ) {
    switch (option) {
      case _MapThemeOption.standard:
        return localizations.mapThemeStandard;
      case _MapThemeOption.light:
        return localizations.mapThemeLight;
    }
  }

  // ---------------------------------------------------------------------------
  // ZOOM CONTROL BUTTONS
  // ---------------------------------------------------------------------------

  Widget _buildZoomControls(VehicleState state) {
    final hasSelection =
        state is VehicleLoaded && state.selectedVehicle != null;

    final bottomOffset = hasSelection ? 180.0 : 24.0;

    return Positioned(
      bottom: bottomOffset,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapControlButton(
            icon: Icons.add,
            onPressed: _zoomIn,
          ),
          const SizedBox(height: 8),
          _MapControlButton(
            icon: Icons.remove,
            onPressed: _zoomOut,
          ),
          const SizedBox(height: 8),
          _MapControlButton(
            icon: Icons.my_location_outlined,
            onPressed: _recenterOnGamma,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VEHICLE INFO PANEL
  // ---------------------------------------------------------------------------

  Widget _buildVehicleInfoPanel(
    BuildContext context,
    VehicleState state,
    AppLocalizations localizations,
  ) {
    if (state is! VehicleLoaded || state.selectedVehicle == null) {
      return const SizedBox.shrink();
    }

    final vehicle = state.selectedVehicle!;
    final theme = Theme.of(context);
    final statusColor =
        context.read<VehicleBloc>().getStatusColor(vehicle.status);

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(18),
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.registrationNumber ??
                          localizations.mapUnknownVehicle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (vehicle.status ?? localizations.mapNoData).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      context.read<VehicleBloc>().add(
                            const VehicleSelectionUpdated(null),
                          );
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if ((vehicle.address ?? '').isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      color: _mapAccent.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vehicle.address!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _InfoTag(
                    label: localizations.mapEstimatedLoad,
                    value:
                        '${(vehicle.wasteCapacityKg ?? 0).toStringAsFixed(1)} kg',
                  ),
                  _InfoTag(
                    label: localizations.mapLastUpdate,
                    value: vehicle.lastUpdated ?? 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VEHICLE MARKER WIDGET
// -----------------------------------------------------------------------------

class _VehicleMarker extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isSelected;
  final Color Function(String?) getVehicleStatusColor;

  const _VehicleMarker({
    required this.vehicle,
    required this.isSelected,
    required this.getVehicleStatusColor,
  });

  String _vehicleIconByStatus(String? status) {
    final s = status?.toLowerCase().replaceAll(' ', '') ?? 'nodata';

    switch (s) {
      case 'running':
        return 'assets/images/truck_3d.png';
      case 'idle':
        return 'assets/images/truck_3d_orange.png';
      case 'parked':
        return 'assets/images/truck_3d_red.png';
      case 'nodata':
      default:
        return 'assets/images/truck_3d_grey.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 46.0 : 38.0;

    return AnimatedScale(
      scale: isSelected ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          _vehicleIconByStatus(vehicle.status),
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI BUTTON + INFO TAG + MAP THEME CONFIG
// -----------------------------------------------------------------------------

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: _mapAccent,
          ),
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTag({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.60,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MAP THEME ENUM + CONFIG
// -----------------------------------------------------------------------------

enum _MapThemeOption { standard, light }

class _MapThemeConfig {
  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;

  const _MapThemeConfig({
    required this.label,
    required this.urlTemplate,
    required this.subdomains,
    required this.attribution,
  });
}

Color _filterColor(VehicleFilter filter) {
  switch (filter) {
    case VehicleFilter.all:
      return Colors.white;
    case VehicleFilter.running:
      return Colors.green;
    case VehicleFilter.idle:
      return Colors.amber;
    case VehicleFilter.parked:
      return Colors.blue;
    case VehicleFilter.noData:
      return Colors.grey;
  }
}



