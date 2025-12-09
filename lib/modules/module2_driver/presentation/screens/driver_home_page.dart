import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../../../core/di.dart';
import '../../../../core/geofence_config.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';
import '../../../../logic/vehicle_tracking/vehicle_bloc.dart';
import '../../../../logic/vehicle_tracking/vehicle_event.dart';
import '../../../../router/app_router.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/shared/widgets/tracking_view_shell.dart';
import '../../route/driver_route_screen.dart';
import 'package:iwms_citizen_app/core/ors_service.dart';

const Color _driverPrimary = Color(0xFF1B5E20);
const Color _driverAccent = Color(0xFF66BB6A);
const Duration _kHeaderTransitionDuration = Duration(milliseconds: 320);
const Duration _kStartButtonAnimationDuration = Duration(milliseconds: 280);
const double _kBottomNavigationHeight = 10;
const double _kStopMarkerDiameter = 32;

enum _DriverMapThemeOption { light, standard }

class _DriverMapThemeConfig {
  const _DriverMapThemeConfig({
    required this.label,
    required this.urlTemplate,
    required this.subdomains,
    required this.attribution,
  });

  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;
}

const Map<_DriverMapThemeOption, _DriverMapThemeConfig> _driverMapThemes = {
  _DriverMapThemeOption.light: _DriverMapThemeConfig(
    label: 'Light',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    attribution: '© OpenStreetMap, © CARTO',
  ),
  _DriverMapThemeOption.standard: _DriverMapThemeConfig(
    label: 'Standard',
    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    attribution: '© OpenStreetMap contributors',
  ),
};

String _formatMetricValue(double? value, String unit, {int decimals = 1}) {
  if (value == null) return '--';
  return '${value.toStringAsFixed(decimals)} $unit';
}

Widget _tripLiveVehicleSummary(VehicleModel? liveVehicle) {
  if (liveVehicle == null) {
    return const Text(
      'Live telemetry will appear once your truck starts transmitting data.',
      style: TextStyle(color: Colors.black54),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        liveVehicle.registrationNumber ?? 'Live vehicle',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Speed',
              value: _formatMetricValue(liveVehicle.speedKmh, 'km/h'),
              icon: Icons.speed_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Fuel',
              value: _formatMetricValue(
                liveVehicle.fuelLevel,
                'L',
                decimals: 0,
              ),
              icon: Icons.local_gas_station_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Distance',
              value: _formatMetricValue(liveVehicle.distanceKm, 'km'),
              icon: Icons.route_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Last update: ${liveVehicle.lastUpdated ?? 'N/A'}',
        style: const TextStyle(color: Colors.black54),
      ),
    ],
  );
}

enum _DriverTab { home, history, profile }

class _DemoStop {
  final String label;
  final LatLng location;
  final String? detail;

  const _DemoStop({
    required this.label,
    required this.location,
    this.detail,
  });
}

const List<_DemoStop> _demoStops = [
  _DemoStop(
    label: 'Gate 2 Entry',
    detail: 'Gamma 1 driver yard',
    location: LatLng(28.4871, 77.5019),
  ),
  _DemoStop(
    label: 'Sector 4',
    detail: 'Collection lane',
    location: LatLng(28.4879, 77.5031),
  ),
  _DemoStop(
    label: 'Service Loop',
    detail: 'Maintenance access point',
    location: LatLng(28.4892, 77.5044),
  ),
  _DemoStop(
    label: 'Dry Waste Depot',
    detail: 'Holding area',
    location: LatLng(28.4910, 77.5058),
  ),
  _DemoStop(
    label: 'Gamma 2 Facility',
    detail: 'Final delivery',
    location: LatLng(28.4936, 77.5072),
  ),
];

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  _DriverTab _activeTab = _DriverTab.home;
  final MapController _mapController = MapController();
  List<_DriverCustomerStop> _customers = [];
  bool _loadingCustomers = true;
  String? _customerError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerOnDriver(GammaGeofenceConfig.center),
    );
    _loadCustomers();
  }

  VehicleModel? _selectedVehicleFrom(VehicleState state) {
    return state is VehicleLoaded ? state.selectedVehicle : null;
  }

  LatLng _resolveDriverLocation(VehicleModel? vehicle) {
    if (vehicle == null) return GammaGeofenceConfig.center;
    return LatLng(vehicle.latitude, vehicle.longitude);
  }

  VehicleModel _chooseDriverVehicle(List<VehicleModel> vehicles) {
    return vehicles.firstWhere(
      (vehicle) => (vehicle.status ?? '').toLowerCase() == 'running',
      orElse: () => vehicles.first,
    );
  }

  void _centerOnDriver(LatLng target) {
    _mapController.move(target, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<VehicleBloc>(),
      child: BlocListener<VehicleBloc, VehicleState>(
        listener: (context, state) {
          if (state is VehicleLoaded &&
              state.selectedVehicle == null &&
              state.vehicles.isNotEmpty) {
            final defaultVehicle = _chooseDriverVehicle(state.vehicles);
            context
                .read<VehicleBloc>()
                .add(VehicleSelectionUpdated(defaultVehicle.id));
          }
        },
        child: BlocBuilder<VehicleBloc, VehicleState>(
          builder: (context, state) {
            final selectedVehicle = _selectedVehicleFrom(state);
            final driverLocation = _resolveDriverLocation(selectedVehicle);

            return Scaffold(
              backgroundColor: const Color(0xFFF7FBF8),
              body: SafeArea(
                child: Column(
                  children: [
                    _MiniHeader(
                      driverName:
                          selectedVehicle?.registrationNumber ?? 'Driver',
                      onNotification: () {},
                    ),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey<_DriverTab>(_activeTab),
                        child: _buildTab(_activeTab, driverLocation),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: BottomNavigationBar(
                  currentIndex: _tabFromIndexReverse(_activeTab),
                  selectedItemColor: _driverPrimary,
                  unselectedItemColor: Colors.black54,
                  onTap: (index) {
                    final tab = _tabFromIndex(index);
                    if (tab != _activeTab) {
                      setState(() => _activeTab = tab);
                    }
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline_rounded),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _loadingCustomers = true;
      _customerError = null;
    });

    try {
      // 1) Try assignments API
      final assignmentsUri = Uri.parse(ApiConfig.assignments);
      final resp =
          await http.get(assignmentsUri).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final decodedAssignments =
            _decodeCustomerList(resp.body, fromAssignments: true);
        if (decodedAssignments.isNotEmpty) {
          setState(() {
            _customers = decodedAssignments;
            _loadingCustomers = false;
          });
          return;
        }
      }

      // 2) Fallback to raw customer list
      final customersResp = await http
          .get(Uri.parse(ApiConfig.customerList))
          .timeout(const Duration(seconds: 12));

      if (customersResp.statusCode == 200) {
        final decoded = _decodeCustomerList(customersResp.body);
        setState(() {
          _customers = decoded;
          _loadingCustomers = false;
        });
      } else {
        setState(() {
          _loadingCustomers = false;
          _customerError =
              'Failed to load customers (${customersResp.statusCode})';
        });
      }
    } catch (_) {
      setState(() {
        _loadingCustomers = false;
        _customerError = 'Unable to load customers';
      });
    }
  }

  LatLng? _safeLatLng(dynamic latRaw, dynamic lonRaw) {
    if (latRaw == null || lonRaw == null) return null;
    final lat = double.tryParse(latRaw.toString());
    final lon = double.tryParse(lonRaw.toString());
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  List<_DriverCustomerStop> _decodeCustomerList(String body,
      {bool fromAssignments = false}) {
    final List<_DriverCustomerStop> out = [];

    try {
      final decoded = jsonDecode(body);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['results'] is List
              ? decoded['results']
              : []);

      if (list is! List) return out;

      for (final entry in list) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry as Map);

        final id = (map['unique_id'] ?? map['customer_id'] ?? '').toString();
        if (id.trim().isEmpty) continue;

        final latRaw =
            fromAssignments ? map['customer_latitude'] : map['latitude'];
        final lonRaw =
            fromAssignments ? map['customer_longitude'] : map['longitude'];

        final position = _safeLatLng(latRaw, lonRaw);
        if (position == null) continue;

        final name = (map['customer_name'] ??
                map['ward_name'] ??
                map['driver_name'] ??
                'Unknown')
            .toString();

        final addressParts = [
          map['building_no'],
          map['street'],
          map['area'],
          map['pincode'],
        ].whereType<String>().where((v) => v.trim().isNotEmpty).toList();

        out.add(
          _DriverCustomerStop(
            id: id,
            name: name,
            address: addressParts.join(', '),
            location: position,
          ),
        );
      }
    } catch (_) {}

    return out;
  }

  Widget _buildTab(_DriverTab tab, LatLng driverLocation) {
    switch (tab) {
      case _DriverTab.home:
        return _HomeTab(
          mapController: _mapController,
          driverLocation: driverLocation,
          onCenter: () => _centerOnDriver(driverLocation),
          customers: _customers,
          loading: _loadingCustomers,
          error: _customerError,
          onRefresh: _loadCustomers,
          onStatusChanged: _updateCustomerStatus,
        );
      case _DriverTab.history:
        return _HistoryTab(
          customers: _customers,
          loading: _loadingCustomers,
          error: _customerError,
          onRefresh: _loadCustomers,
        );
      case _DriverTab.profile:
        return _ProfileTab(onLogout: () => _logout(context));
    }
  }

  _DriverTab _tabFromIndex(int index) {
    switch (index) {
      case 1:
        return _DriverTab.history;
      case 2:
        return _DriverTab.profile;
      case 0:
      default:
        return _DriverTab.home;
    }
  }

  int _tabFromIndexReverse(_DriverTab tab) {
    switch (tab) {
      case _DriverTab.history:
        return 1;
      case _DriverTab.profile:
        return 2;
      case _DriverTab.home:
      default:
        return 0;
    }
  }

  void _logout(BuildContext context) {
    if (!mounted) return;
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }

  void _updateCustomerStatus(String id, _CustomerStatus status) {
    setState(() {
      _customers = _customers.map((c) {
        if (c.id == id) {
          return _DriverCustomerStop(
            id: c.id,
            name: c.name,
            address: c.address,
            location: c.location,
            status: status,
          );
        }
        return c;
      }).toList();
    });
  }
}

class _MiniHeader extends StatelessWidget {
  const _MiniHeader({
    required this.driverName,
    required this.onNotification,
  });

  final String driverName;
  final VoidCallback onNotification;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _driverPrimary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: _driverPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  driverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNotification,
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white),
            tooltip: 'Notifications',
          ),
        ],
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    required this.title,
    required this.subtitle,
    required this.activeTab,
    required this.routeStops,
    required this.onLogoutTapped,
    this.speed,
    this.fuel,
    this.distance,
  });

  final String title;
  final String subtitle;
  final _DriverTab activeTab;
  final int routeStops;
  final VoidCallback onLogoutTapped;
  final double? speed;
  final double? fuel;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    final bool showStats = activeTab != _DriverTab.profile;

    return AnimatedContainer(
      duration: _kHeaderTransitionDuration,
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: showStats
          ? const EdgeInsets.fromLTRB(20, 10, 20, 10)
          : const EdgeInsets.fromLTRB(20, 10, 20, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_driverPrimary, _driverAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -18,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          AnimatedSize(
            duration: _kHeaderTransitionDuration,
            curve: Curves.easeInOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onLogoutTapped,
                      icon: const Icon(Icons.power_settings_new_rounded,
                          color: Colors.white),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: _kHeaderTransitionDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _buildStatsContent(showStats),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(bool showStats) {
    if (!showStats) {
      return const SizedBox(
        key: ValueKey('header-no-stats'),
        height: 0,
      );
    }

    if (activeTab == _DriverTab.history) {
      return _HistoryDistanceCard(
        key: const ValueKey('header-history-distance'),
        stops: routeStops,
      );
    }

    return _HeaderStatsRow(
      key: const ValueKey('header-stats-row'),
      speed: speed,
      fuel: fuel,
      distance: distance,
    );
  }
}

class _HeaderStatsRow extends StatelessWidget {
  const _HeaderStatsRow({
    super.key,
    this.speed,
    this.fuel,
    this.distance,
  });

  final double? speed;
  final double? fuel;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Speed',
                  value: _formatMetricValue(speed, 'km/h'),
                  icon: Icons.speed_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Fuel',
                  value: _formatMetricValue(fuel, 'L', decimals: 0),
                  icon: Icons.local_gas_station_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Distance',
                  value: _formatMetricValue(distance, 'km'),
                  icon: Icons.route_outlined,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryDistanceCard extends StatelessWidget {
  const _HistoryDistanceCard({
    super.key,
    required this.stops,
  });

  final int stops;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _driverPrimary.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.route_outlined, color: _driverPrimary),
                  const SizedBox(width: 12),
                  const Text(
                    'Distance overview',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '20 km',
                    style: TextStyle(
                      color: _driverPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Stops scheduled: $stops',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: _driverPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 0.68,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: _driverPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        'ETA',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '02:15 PM',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.mapController,
    required this.driverLocation,
    required this.onCenter,
    required this.customers,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onStatusChanged,
  });

  final MapController mapController;
  final LatLng driverLocation;
  final VoidCallback onCenter;
  final List<_DriverCustomerStop> customers;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(String id, _CustomerStatus status) onStatusChanged;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

enum _CustomerStatus { pending, collected, skipped }

class _DriverCustomerStop {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  _CustomerStatus status;

  _DriverCustomerStop({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.status = _CustomerStatus.pending,
  });
}

class _HomeTabState extends State<_HomeTab> {
  List<LatLng> _orsRoute = [];
  double _driverBearing = 0.0;
  List<_DriverCustomerStop> _customers = [];

  @override
  void initState() {
    super.initState();
    _customers = widget.customers;
    _computeRoute();
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customers != widget.customers ||
        oldWidget.driverLocation != widget.driverLocation) {
      _customers = List<_DriverCustomerStop>.from(widget.customers);
      _computeRoute();
    }
  }

  Future<void> _computeRoute() async {
    if (_customers.isEmpty) {
      setState(() {
        _orsRoute = [];
        _driverBearing = 0.0;
      });
      return;
    }

    // Build ORS coordinates list
    final coords = [
      [widget.driverLocation.longitude, widget.driverLocation.latitude],
      ..._customers.map((c) => [c.location.longitude, c.location.latitude]),
    ];

    // Fetch optimized ORS route
    final route = await ORSService.fetchMultiRoute(coords);

    if (!mounted) return;

    setState(() {
      _orsRoute = route;

      // Bearing toward first ORS segment OR toward first customer
      if (route.length > 1) {
        _driverBearing = ORSService.calculateBearing(route.first, route[1]);
      } else {
        _driverBearing = ORSService.calculateBearing(
          widget.driverLocation,
          _customers.first.location,
        );
      }
    });
  }

  Color _statusColor(_CustomerStatus status) {
    switch (status) {
      case _CustomerStatus.collected:
        return Colors.green;
      case _CustomerStatus.skipped:
        return Colors.orange;
      case _CustomerStatus.pending:
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = constraints.maxHeight;
          return Stack(
            children: [
              SizedBox(
                height: mapHeight,
                width: double.infinity,
                child: FlutterMap(
                  mapController: widget.mapController,
                  options: MapOptions(
                    initialCenter: widget.driverLocation,
                    initialZoom: 14.5,
                    minZoom: 10,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.iwms.citizen.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        if (_orsRoute.isNotEmpty)
                          Polyline(
                            points: _orsRoute,
                            color: Colors.blueAccent,
                            strokeWidth: 4.5,
                          )
                        else if (_customers.isNotEmpty)
                          Polyline(
                            points: [
                              widget.driverLocation,
                              ..._customers.map((c) => c.location),
                            ],
                            color: _driverPrimary.withOpacity(0.6),
                            strokeWidth: 3.5,
                          ),
                      ],
                    ),
                    if (_customers.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 42,
                            height: 42,
                            point: widget.driverLocation,
                            child: _DriverMarker(
                              isActive: true,
                              rotation: _driverBearing,
                            ),
                          ),
                          ..._customers.map(
                            (c) => Marker(
                              width: 36,
                              height: 36,
                              point: c.location,
                              child: _HouseMarker(
                                color: _statusColor(c.status),
                                label: c.name.substring(0, 1).toUpperCase(),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    _CircleIconButton(
                      icon: Icons.gps_fixed_rounded,
                      onPressed: widget.onCenter,
                    ),
                    const SizedBox(height: 10),
                    _CircleIconButton(
                      icon: Icons.refresh_rounded,
                      onPressed: () async {
                        await widget.onRefresh();
                        await _computeRoute();
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SizedBox(
                  height: 140,
                  child: widget.loading
                      ? const Center(child: CircularProgressIndicator())
                      : widget.error != null
                          ? Center(
                              child: Text(
                                widget.error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : _customers.isEmpty
                              ? const Center(
                                  child: Text('No customers assigned'),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  scrollDirection: Axis.horizontal,
                                  itemBuilder: (context, index) {
                                    final customer = _customers[index];
                                    final color = _statusColor(customer.status);
                                    return SizedBox(
                                      width: 230,
                                      child: Card(
                                        elevation: 5,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor:
                                                        color.withOpacity(0.15),
                                                    child: Text(
                                                      customer.name[0]
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                          color: color),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          customer.name,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          customer.address,
                                                          style: TextStyle(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.6),
                                                            fontSize: 11,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: color
                                                          .withOpacity(0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Text(
                                                      customer.status.name,
                                                      style: TextStyle(
                                                        color: color,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: Colors
                                                            .green.shade700,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          customer.status =
                                                              _CustomerStatus
                                                                  .collected;
                                                        });
                                                        widget.onStatusChanged(
                                                          customer.id,
                                                          _CustomerStatus
                                                              .collected,
                                                        );
                                                      },
                                                      child: const Text(
                                                          'Complete'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          customer.status =
                                                              _CustomerStatus
                                                                  .skipped;
                                                        });
                                                        widget.onStatusChanged(
                                                          customer.id,
                                                          _CustomerStatus
                                                              .skipped,
                                                        );
                                                      },
                                                      child: const Text('Skip'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemCount: _customers.length,
                                ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentHistorySection extends StatelessWidget {
  const _RecentHistorySection({
    required this.entries,
  });

  final List<_CollectionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final recent = entries.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent collections',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(recent.length, (index) {
          final entry = recent[index];
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == recent.length - 1 ? 0 : 10),
            child: _HistoryCard(entry: entry),
          );
        }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: _driverPrimary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _driverPrimary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _driverPrimary, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _driverPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.mapController,
    required this.driverLocation,
    required this.routePoints,
    required this.orsRoute,
    required this.driverBearing,
    required this.onCenter,
    required this.stops,
  });

  final MapController mapController;
  final LatLng driverLocation;
  final List<LatLng> routePoints;
  final List<LatLng> orsRoute;
  final double driverBearing;
  final VoidCallback onCenter;
  final List<_DemoStop> stops;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _driverPrimary.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              SizedBox(
                height: 260,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: driverLocation,
                    initialZoom: 14.5,
                    minZoom: 10,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        if (orsRoute.isNotEmpty)
                          Polyline(
                            points: orsRoute,
                            color: Colors.blueAccent,
                            strokeWidth: 4.5,
                          )
                        else if (routePoints.isNotEmpty)
                          Polyline(
                            points: [driverLocation, ...routePoints],
                            color: _driverPrimary.withOpacity(0.6),
                            strokeWidth: 3.5,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 42,
                          height: 42,
                          point: driverLocation,
                          child: _DriverMarker(
                            isActive: true,
                            rotation: driverBearing,
                          ),
                        ),
                        ...stops.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final stop = entry.value;
                          return Marker(
                            width: _kStopMarkerDiameter,
                            height: _kStopMarkerDiameter,
                            point: stop.location,
                            child: _StopMarker(
                              index: idx + 1,
                              label: stop.label,
                              isDestination: idx == stops.length - 1,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    _CircleIconButton(
                      icon: Icons.gps_fixed_rounded,
                      onPressed: onCenter,
                    ),
                    const SizedBox(height: 10),
                    _CircleIconButton(
                      icon: Icons.zoom_in_rounded,
                      onPressed: () {
                        mapController.move(
                          mapController.camera.center,
                          mapController.camera.zoom + 0.6,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _CircleIconButton(
                      icon: Icons.zoom_out_rounded,
                      onPressed: () {
                        mapController.move(
                          mapController.camera.center,
                          mapController.camera.zoom - 0.6,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  final bool isActive;
  final double rotation; // degrees

  const _DriverMarker({required this.isActive, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * 3.14159 / 180,
      child: Image.asset(
        'assets/images/arrow.png',
        width: isActive ? 36 : 30,
        height: isActive ? 36 : 30,
      ),
    );
  }
}

class _HouseMarker extends StatelessWidget {
  const _HouseMarker({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NextStopSummary extends StatelessWidget {
  const _NextStopSummary({
    required this.stop,
    required this.remainingStops,
  });

  final _DemoStop? stop;
  final int remainingStops;

  @override
  Widget build(BuildContext context) {
    if (stop == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _driverPrimary.withOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'No route stops available',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final statusText =
        remainingStops <= 0 ? 'Final stop' : '$remainingStops stops left';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _driverPrimary.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _driverAccent.withOpacity(0.2),
            child: Icon(Icons.navigation_rounded, color: _driverAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next stop',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  stop!.label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (stop!.detail != null)
                  Text(
                    stop!.detail!,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            statusText,
            style: const TextStyle(
                color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: _driverPrimary, size: 20),
        ),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.index,
    required this.label,
    required this.isDestination,
  });

  final int index;
  final String label;
  final bool isDestination;

  @override
  Widget build(BuildContext context) {
    final color = isDestination ? _driverAccent : _driverPrimary;
    return Tooltip(
      message: label,
      child: Container(
        width: _kStopMarkerDiameter,
        height: _kStopMarkerDiameter,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$index',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _StopDropdown extends StatelessWidget {
  const _StopDropdown({
    required this.stops,
  });

  final List<_DemoStop> stops;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        title: const Text('Route stops'),
        subtitle: Text('${stops.length} stops'),
        leading: const Icon(Icons.list_alt_rounded),
        childrenPadding: const EdgeInsets.symmetric(vertical: 4),
        children: stops.asMap().entries.map((entry) {
          final stop = entry.value;
          final isDestination = entry.key == stops.length - 1;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: isDestination ? _driverAccent : _driverPrimary,
              child: Text(
                '${entry.key + 1}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(
              stop.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: stop.detail != null ? Text(stop.detail!) : null,
            trailing: Icon(
              isDestination ? Icons.flag_rounded : Icons.location_on_rounded,
              color: isDestination ? _driverAccent : Colors.black38,
              size: 18,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StartButtonOverlay extends StatelessWidget {
  const _StartButtonOverlay({
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: _kBottomNavigationHeight,
      child: AnimatedSlide(
        duration: _kStartButtonAnimationDuration,
        curve: Curves.easeInOut,
        offset: visible ? Offset.zero : const Offset(0, 0.4),
        child: AnimatedOpacity(
          duration: _kStartButtonAnimationDuration,
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                'Start',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _driverPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullMapPage extends StatefulWidget {
  const _FullMapPage({
    required this.origin,
    required this.routePoints,
    required this.stops,
    this.vehicle,
  });

  final LatLng origin;
  final List<LatLng> routePoints;
  final List<_DemoStop> stops;
  final VehicleModel? vehicle;

  @override
  State<_FullMapPage> createState() => _FullMapPageState();
}

class _FullMapPageState extends State<_FullMapPage> {
  final MapController _mapController = MapController();
  _DriverMapThemeOption _selectedTheme = _DriverMapThemeOption.light;
  List<LatLng> _orsRoute = [];
  double _driverBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _computeFullRoute();
  }

  void _setTheme(_DriverMapThemeOption option) {
    if (_selectedTheme == option) return;
    setState(() => _selectedTheme = option);
  }

  Future<void> _computeFullRoute() async {
    if (widget.routePoints.isEmpty) {
      setState(() {
        _orsRoute = [];
        _driverBearing = 0.0;
      });
      return;
    }

    final dest = widget.routePoints.last;
    final route = await ORSService.fetchRoute(widget.origin, dest);

    if (!mounted) return;

    setState(() {
      _orsRoute = route;
      if (route.isNotEmpty) {
        _driverBearing =
            ORSService.calculateBearing(widget.origin, route.first);
      } else if (widget.stops.isNotEmpty) {
        _driverBearing = ORSService.calculateBearing(
          widget.origin,
          widget.stops.first.location,
        );
      } else {
        _driverBearing = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final liveVehicle = widget.vehicle;
    final nextStop = widget.stops.isNotEmpty ? widget.stops.first : null;
    final remainingStops =
        widget.stops.isNotEmpty ? widget.stops.length - 1 : 0;
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.24;
    final headerStatusContent = nextStop != null
        ? _DriverHeaderNextStop(stop: nextStop, remainingStops: remainingStops)
        : null;
    final headline = widget.stops.isNotEmpty
        ? 'Heading to ${widget.stops.last.label}'
        : 'Trip tracking';
    final statusSecondary =
        '${widget.stops.length} stops | ${widget.routePoints.isNotEmpty ? widget.routePoints.length : 0} legs';
    final themeConfig = _driverMapThemes[_selectedTheme]!;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              width: double.infinity,
              child: TrackingHeroHeader(
                contextLabel:
                    liveVehicle?.registrationNumber ?? 'Trip tracking',
                headline: headline,
                statusPrimary:
                    liveVehicle?.lastUpdated ?? 'Awaiting telemetry update',
                statusSecondary: statusSecondary,
                statusContent: headerStatusContent,
                onBack: () => Navigator.of(context).maybePop(),
                onRefresh: () =>
                    _mapController.move(widget.origin, 15), // recenter
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: widget.origin,
                              initialZoom: 15,
                              minZoom: 10,
                              maxZoom: 18,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: themeConfig.urlTemplate,
                                subdomains: themeConfig.subdomains,
                                userAgentPackageName: 'com.iwms.citizen.app',
                              ),
                              if (_orsRoute.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _orsRoute,
                                      color: Colors.blueAccent,
                                      strokeWidth: 4.5,
                                    ),
                                  ],
                                )
                              else if (widget.routePoints.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: [
                                        widget.origin,
                                        ...widget.routePoints,
                                      ],
                                      color: _driverPrimary.withOpacity(0.6),
                                      strokeWidth: 3.5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    width: 44,
                                    height: 44,
                                    point: widget.origin,
                                    child: _DriverMarker(
                                      isActive: true,
                                      rotation: _driverBearing,
                                    ),
                                  ),
                                  ...widget.stops.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final stop = entry.value;
                                    return Marker(
                                      width: _kStopMarkerDiameter,
                                      height: _kStopMarkerDiameter,
                                      point: stop.location,
                                      child: _StopMarker(
                                        index: idx + 1,
                                        label: stop.label,
                                        isDestination:
                                            idx == widget.stops.length - 1,
                                      ),
                                    );
                                  }),
                                ],
                              ),
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
                          ),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 140,
                          child: _DriverMapStyleSelector(
                            selected: _selectedTheme,
                            onSelected: _setTheme,
                          ),
                        ),
                        DraggableScrollableSheet(
                          initialChildSize: 0.24,
                          minChildSize: 0.18,
                          maxChildSize: 0.78,
                          builder: (context, scrollController) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                  topRight: Radius.circular(28),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, -6),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 16),
                                  child: ListView(
                                    controller: scrollController,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 42,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Route overview',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.route_rounded,
                                              color: _driverPrimary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${widget.routePoints.length} scheduled stops -> ${widget.routePoints.isNotEmpty ? widget.routePoints.length - 1 : 0} legs',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            onPressed: () =>
                                                _mapController.move(
                                                    widget.origin,
                                                    _mapController.camera.zoom),
                                            icon: const Icon(
                                              Icons.center_focus_strong_rounded,
                                              color: _driverPrimary,
                                            ),
                                            label: const Text(
                                              'Re-center',
                                              style: TextStyle(
                                                  color: _driverPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _tripLiveVehicleSummary(liveVehicle),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Upcoming stops',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _StopDropdown(stops: widget.stops),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

const List<_CollectionEntry> _weeklyHistory = [
  _CollectionEntry(
      vehicleId: 'GJ13WY4422', dryKg: 50, wetKg: 150, totalKg: 200),
  _CollectionEntry(
      vehicleId: 'GJ10Q35454', dryKg: 100, wetKg: 100, totalKg: 200),
  _CollectionEntry(
      vehicleId: 'GJ23KJ0000', dryKg: 120, wetKg: 80, totalKg: 200),
  _CollectionEntry(
      vehicleId: 'GJ02MN2345', dryKg: 70, wetKg: 130, totalKg: 200),
  _CollectionEntry(
      vehicleId: 'GJ05HB6756', dryKg: 60, wetKg: 140, totalKg: 200),
];

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.customers,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final List<_DriverCustomerStop> customers;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ))
          else if (error != null)
            Center(
              child: Text(
                error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (customers.isEmpty)
            const Center(child: Text('No history available'))
          else
            ...customers.map((c) {
              final color = c.status == _CustomerStatus.collected
                  ? Colors.green
                  : c.status == _CustomerStatus.skipped
                      ? Colors.orange
                      : Colors.red;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(
                      c.name[0].toUpperCase(),
                      style: TextStyle(color: color),
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    c.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      c.status.name,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  onTap: () {
                    _showCollectedWaste(context, c);
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showCollectedWaste(BuildContext context, _DriverCustomerStop customer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                customer.address,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.recycling, color: _driverPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${customer.status.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Collected weights data not available yet.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DriverHeaderNextStop extends StatelessWidget {
  const _DriverHeaderNextStop({
    required this.stop,
    required this.remainingStops,
  });

  final _DemoStop stop;
  final int remainingStops;

  @override
  Widget build(BuildContext context) {
    final statusText = remainingStops <= 0
        ? 'Final stop'
        : remainingStops == 1
            ? '1 stop left'
            : '$remainingStops stops left';

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next stop',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        stop.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stop.detail != null)
                        Text(
                          stop.detail!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DriverMapStyleSelector extends StatelessWidget {
  const _DriverMapStyleSelector({
    required this.selected,
    required this.onSelected,
  });

  final _DriverMapThemeOption selected;
  final ValueChanged<_DriverMapThemeOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _DriverMapThemeOption.values.map((option) {
          final config = _driverMapThemes[option]!;
          final isSelected = option == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(config.label),
              selected: isSelected,
              onSelected: (value) {
                if (value) onSelected(option);
              },
              selectedColor: theme.colorScheme.primary,
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final _CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _driverPrimary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.recycling_rounded, color: _driverPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Waste Collected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vehicle : ',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    'Total Collected :',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    ' Kg',
                    style: TextStyle(
                      color: _driverPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: _driverAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _driverAccent.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        ' Kg',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Dry',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.black.withOpacity(0.1),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        ' Kg',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Wet',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionEntry {
  final String vehicleId;
  final int dryKg;
  final int wetKg;
  final int totalKg;

  const _CollectionEntry({
    required this.vehicleId,
    required this.dryKg,
    required this.wetKg,
    required this.totalKg,
  });
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: _driverPrimary.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: _driverPrimary.withOpacity(0.12),
                  child:
                      const Icon(Icons.person, color: _driverPrimary, size: 36),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ravi Kumar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Driver ID: DRV-1042',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                _ProfileRow(
                  label: 'Vehicle',
                  value: 'TN 01 AB 1234',
                  icon: Icons.local_shipping_outlined,
                ),
                const SizedBox(height: 10),
                _ProfileRow(
                  label: 'Contact',
                  value: '+91 98765 43210',
                  icon: Icons.phone_rounded,
                ),
                const SizedBox(height: 10),
                _ProfileRow(
                  label: 'Shift',
                  value: '06:00 AM - 02:00 PM',
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _driverPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _driverPrimary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _driverPrimary, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
