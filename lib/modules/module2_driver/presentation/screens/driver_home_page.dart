import 'dart:convert';
import 'dart:math' as math;

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
const Duration _kNavigationTransitionDuration = Duration(milliseconds: 600);
const double _kStopMarkerDiameter = 32;
const List<String> _skipReasons = [
  'No one at home',
  'Access blocked / gate locked',
  'Customer requested later collection',
  'Waste already collected',
  'Unsafe conditions',
  'Incorrect address',
  'Other operational issue',
];

enum _NavigationMode { overview, navigating }

enum _CustomerStatus { pending, collected, skipped, navigating }

class _DriverCustomerStop {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  _CustomerStatus status;
  String? skipReason;

  _DriverCustomerStop({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.status = _CustomerStatus.pending,
    this.skipReason,
  });
}

enum _DriverTab { home, history, profile }

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

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  List<LatLng> _orsRoute = [];
  double _driverBearing = 0.0;
  List<_DriverCustomerStop> _customers = [];
  _NavigationMode _navMode = _NavigationMode.overview;
  String? _activeNavigationId;
  late AnimationController _navAnimController;

  @override
  void initState() {
    super.initState();
    _customers = widget.customers;
    _navAnimController = AnimationController(
      vsync: this,
      duration: _kNavigationTransitionDuration,
    );
    _computeRoute();
  }

  @override
  void _followDriver() {
    if (_orsRoute.length < 2) return;

    final center = _orsRoute.first;
    final bearing = ORSService.calculateBearing(_orsRoute[0], _orsRoute[1]);

    widget.mapController.move(center, 17.8);
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _orsRoute = [];
        _driverBearing = 0.0;
      });
      return;
    }

    final List<List<double>> coords = [
      [widget.driverLocation.longitude, widget.driverLocation.latitude],
      ..._customers.map(
        (c) => [c.location.longitude, c.location.latitude],
      ),
    ];

    debugPrint('DRIVER HOME: Computing route for ${coords.length} points');

    try {
      final route = await ORSService.fetchMultiRoute(coords);

      if (!mounted) return;

      setState(() {
        _orsRoute = route;

        if (route.length > 1) {
          _driverBearing = ORSService.calculateBearing(route.first, route[1]);
        } else if (_customers.isNotEmpty) {
          _driverBearing = ORSService.calculateBearing(
            widget.driverLocation,
            _customers.first.location,
          );
        } else {
          _driverBearing = 0.0;
        }
      });

      debugPrint('DRIVER HOME: Route computed with ${_orsRoute.length} points');
    } catch (e) {
      debugPrint('DRIVER HOME: Route computation failed: $e');
      if (!mounted) return;
      setState(() {
        _orsRoute = [];
        _driverBearing = 0.0;
      });
    }
  }

  void _startNavigation(String customerId) {
    final customer = _customers.firstWhere((c) => c.id == customerId);

    setState(() {
      _activeNavigationId = customerId;
      _navMode = _NavigationMode.navigating;
      customer.status = _CustomerStatus.navigating;
    });
    if (_navMode == _NavigationMode.navigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _followDriver();
      });
    }

    widget.onStatusChanged(customerId, _CustomerStatus.navigating);
    _navAnimController.forward();

    // Smooth navigation camera transition
    _animateToNavigationView(customer.location);
    _followDriver();
  }

  void _stopNavigation() {
    setState(() {
      if (_activeNavigationId != null) {
        final customer =
            _customers.firstWhere((c) => c.id == _activeNavigationId);
        customer.status = _CustomerStatus.pending;
        widget.onStatusChanged(_activeNavigationId!, _CustomerStatus.pending);
      }
      _activeNavigationId = null;
      _navMode = _NavigationMode.overview;
    });

    _navAnimController.reverse();

    // Return to overview
    _animateToOverview();
  }

  void _animateToNavigationView(LatLng destination) {
    // Calculate bearing to destination
    final bearing =
        ORSService.calculateBearing(widget.driverLocation, destination);

    // Google Maps style: tilt map, zoom in, rotate to bearing
    final targetZoom = 17.5;
    final targetCenter = widget.driverLocation;

    // Smooth animation to navigation view
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      widget.mapController.move(targetCenter, targetZoom);
    });
  }

  void _animateToOverview() {
    if (_customers.isEmpty) {
      widget.mapController.move(widget.driverLocation, 15.0);
      return;
    }

    // Fit all markers in view
    final allPoints = [
      widget.driverLocation,
      ..._customers.map((c) => c.location),
    ];

    final bounds = LatLngBounds.fromPoints(allPoints);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      widget.mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    });
  }

  Color _statusColor(_CustomerStatus status) {
    switch (status) {
      case _CustomerStatus.collected:
        return Colors.green;
      case _CustomerStatus.skipped:
        return Colors.orange;
      case _CustomerStatus.navigating:
        return Colors.blue;
      case _CustomerStatus.pending:
      default:
        return Colors.red;
    }
  }

  String _getDistanceToCustomer(_DriverCustomerStop customer) {
    final distance = const Distance().as(
      LengthUnit.Meter,
      widget.driverLocation,
      customer.location,
    );

    if (distance < 1000) {
      return '${distance.round()} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNavigating = _navMode == _NavigationMode.navigating;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Stack(
        children: [
          // Map
          Positioned.fill(
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
                if (_orsRoute.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _orsRoute,
                        color: isNavigating
                            ? Colors.blueAccent
                            : Colors.blue.shade300,
                        strokeWidth: isNavigating ? 6.0 : 4.5,
                      ),
                    ],
                  ),
                if (_customers.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 42,
                        height: 42,
                        point: _orsRoute.isNotEmpty
                            ? _orsRoute.first
                            : widget.driverLocation,
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
                            pulse: c.id == _activeNavigationId,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Top controls
          if (!isNavigating)
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    onPressed: widget.onCenter,
                    tooltip: 'Center on me',
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.refresh_rounded,
                    onPressed: () async {
                      await widget.onRefresh();
                      await _computeRoute();
                    },
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

          // Navigation header
          if (isNavigating && _activeNavigationId != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _NavigationHeader(
                customer:
                    _customers.firstWhere((c) => c.id == _activeNavigationId),
                distance: _getDistanceToCustomer(
                  _customers.firstWhere((c) => c.id == _activeNavigationId),
                ),
                onStop: _stopNavigation,
              ),
            ),

          // Bottom customer carousel
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: AnimatedContainer(
              duration: _kNavigationTransitionDuration,
              height: isNavigating ? 0 : 160,
              curve: Curves.easeInOut,
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final customer = _customers[index];
                                return _CustomerCard(
                                  customer: customer,
                                  distance: _getDistanceToCustomer(customer),
                                  onComplete: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Confirm Collection'),
                                        content: const Text(
                                          'Have you completed waste collection for this customer?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    setState(() {
                                      customer.status =
                                          _CustomerStatus.collected;
                                    });

                                    widget.onStatusChanged(
                                        customer.id, _CustomerStatus.collected);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Collection completed'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );

                                    await _computeRoute();
                                  },
                                  onSkip: () async {
                                    String? selectedReason;

                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dialogContext) {
                                        return StatefulBuilder(
                                          builder: (context, setStateDialog) {
                                            return AlertDialog(
                                              title: const Text(
                                                  'Skip Waste Collection'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                      'Select a reason for skipping:'),
                                                  const SizedBox(height: 12),

                                                  // 👇 THEMED DROPDOWN
                                                  DropdownButtonFormField<
                                                      String>(
                                                    value: selectedReason,
                                                    isExpanded: true,
                                                    dropdownColor: Colors
                                                        .white, // FIX 2 (theme)
                                                    decoration:
                                                        const InputDecoration(
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      border:
                                                          OutlineInputBorder(),
                                                      hintText: 'Reason',
                                                    ),
                                                    items: _skipReasons
                                                        .map(
                                                          (r) =>
                                                              DropdownMenuItem(
                                                            value: r,
                                                            child: Text(
                                                              r,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .black),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: (val) {
                                                      setStateDialog(() {
                                                        selectedReason = val;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: selectedReason ==
                                                          null
                                                      ? null
                                                      : () => Navigator.pop(
                                                          dialogContext, true),
                                                  child: const Text('Skip'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );

                                    if (confirmed != true ||
                                        selectedReason == null) return;

                                    setState(() {
                                      customer.status = _CustomerStatus.skipped;
                                      customer.skipReason = selectedReason;
                                    });

                                    widget.onStatusChanged(
                                        customer.id, _CustomerStatus.skipped);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Skipped'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );

                                    await _computeRoute();
                                  },
                                  onStart: () => _startNavigation(customer.id),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemCount: _customers.length,
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationHeader extends StatelessWidget {
  const _NavigationHeader({
    required this.customer,
    required this.distance,
    required this.onStop,
  });

  final _DriverCustomerStop customer;
  final String distance;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.navigation_rounded,
                    color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distance,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onStop,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Stop navigation',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            ],
          ),
          if (customer.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    customer.address,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.distance,
    required this.onComplete,
    required this.onSkip,
    required this.onStart,
  });

  final _DriverCustomerStop customer;
  final String distance;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onStart;

  Color get _statusColor {
    switch (customer.status) {
      case _CustomerStatus.collected:
        return Colors.green;
      case _CustomerStatus.skipped:
        return Colors.orange;
      case _CustomerStatus.navigating:
        return Colors.blue;
      case _CustomerStatus.pending:
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _statusColor.withOpacity(0.15),
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(Icons.near_me_rounded,
                                size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: customer.status == _CustomerStatus.collected
                          ? null
                          : onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Complete',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: customer.status == _CustomerStatus.skipped
                          ? null
                          : onSkip,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Start navigation
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: customer.status == _CustomerStatus.navigating
                      ? null
                      : onStart,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(
                    'Navigate',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          else if (customers.isEmpty)
            const Center(child: Text('No history available'))
          else
            ...customers
                .where((c) =>
                    c.status == _CustomerStatus.collected ||
                    c.status == _CustomerStatus.skipped)
                .map((c) {
              final isCollected = c.status == _CustomerStatus.collected;
              final color = isCollected ? Colors.green : Colors.orange;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.5),
                  color: color.withOpacity(0.08),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(
                      isCollected ? Icons.check_circle : Icons.warning_rounded,
                      color: color,
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.address),
                      if (c.status == _CustomerStatus.skipped &&
                          c.skipReason != null)
                        Text(
                          'Reason: ${c.skipReason}',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    isCollected ? 'Collected' : 'Skipped',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.onLogout});

  final VoidCallback onLogout;

  Widget _profileField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          const Center(
            child: CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Driver Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 24),

          // Profile Fields
          _profileField('Your Name', 'Jeevanantham P'),
          _profileField('Date of Birth', '29 March 1988'),
          _profileField('Language Speak', 'Tamil'),
          _profileField('Experience', '23 Years'),
          _profileField('Driving Licence No', 'TN21X20080011684'),

          // Driving Licence Image
          const Text(
            'Driving Licence',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                'https://your-server-url/driving_licence.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.image_not_supported, size: 40),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Logout
          Center(
            child: ElevatedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  final bool isActive;
  final double rotation;

  const _DriverMarker({
    required this.isActive,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: Icon(
        Icons.navigation_rounded,
        size: isActive ? 38 : 32,
        color: Colors.deepOrange.shade600, // ✅ changed
        shadows: const [
          Shadow(color: Colors.black45, blurRadius: 6),
        ],
      ),
    );
  }
}

class _HouseMarker extends StatelessWidget {
  const _HouseMarker({
    required this.color,
    required this.label,
    this.pulse = false,
  });

  final Color color;
  final String label;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
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

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        icon: Icon(icon, color: _driverPrimary),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
