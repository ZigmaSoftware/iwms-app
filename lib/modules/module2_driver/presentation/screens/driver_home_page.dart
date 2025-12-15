// ============================================================
// PART 1: Imports, Constants, Enums, and Main Widget Classes
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:animations/animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../../../core/di.dart';
import '../../../../core/geofence_config.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';
import '../../../../logic/vehicle_tracking/vehicle_bloc.dart';
import '../../../../logic/vehicle_tracking/vehicle_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/ors_service.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/attendance/attendance_driver.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/profile.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/driver_details.dart';

const Color _driverPrimary = Color(0xFF1B5E20);
const Color _driverAccent = Color(0xFF66BB6A);
const Duration _kHeaderTransitionDuration = Duration(milliseconds: 320);
const Duration _kNavigationTransitionDuration = Duration(milliseconds: 600);

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

enum _DriverTab { home, history, profile, attendance }

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
    final nameFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).userName
            : null);

    final empIdFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).emp_id
            : null);

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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _DriverHeader(
                        activeTab: _activeTab,
                        onLogoutTapped: () => _logout(context),
                        empId: empIdFromState ?? '',
                        driverName: nameFromState ?? 'Driver',
                      ),
                    ),
                    Expanded(
                      child: PageTransitionSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, animation, secondaryAnimation) {
                          return SharedAxisTransition(
                            animation: animation,
                            secondaryAnimation: secondaryAnimation,
                            transitionType: SharedAxisTransitionType.horizontal,
                            child: child,
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<_DriverTab>(_activeTab),
                          child: _buildTab(
                            _activeTab,
                            driverLocation,
                            nameFromState ?? 'Driver',
                            empIdFromState ?? '',
                            selectedVehicle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _activeTab.index,
                  selectedItemColor: _driverPrimary,
                  unselectedItemColor: Colors.black54,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
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
                    BottomNavigationBarItem(
                      icon: Icon(Icons.event_available_rounded),
                      label: 'Attendance',
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
      final resp = await http.get(assignmentsUri).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final decodedAssignments = _decodeCustomerList(resp.body, fromAssignments: true);
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
          _customerError = 'Failed to load customers (${customersResp.statusCode})';
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

  List<_DriverCustomerStop> _decodeCustomerList(String body, {bool fromAssignments = false}) {
    final List<_DriverCustomerStop> out = [];

    try {
      final decoded = jsonDecode(body);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['results'] is List ? decoded['results'] : []);

      if (list is! List) return out;

      for (final entry in list) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);

        final id = (map['unique_id'] ?? map['customer_id'] ?? '').toString();
        if (id.trim().isEmpty) continue;

        final latRaw = fromAssignments ? map['customer_latitude'] : map['latitude'];
        final lonRaw = fromAssignments ? map['customer_longitude'] : map['longitude'];

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

  Widget _buildTab(_DriverTab tab, LatLng driverLocation, String nameFromState, String empIdFromState, VehicleModel? vehicle) {
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
        return _ProfileTab(
          onLogout: () => _logout(context),
          driverName: nameFromState,
          empId: empIdFromState,
          vehicle: vehicle,
        );
      case _DriverTab.attendance:
        return AttendancePageDriver(
          operatorName: nameFromState,
          operatorCode: empIdFromState,
        );
    }
  }

  _DriverTab _tabFromIndex(int index) {
    switch (index) {
      case 1:
        return _DriverTab.history;
      case 2:
        return _DriverTab.profile;
      case 3:
        return _DriverTab.attendance;
      case 0:
      default:
        return _DriverTab.home;
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
            skipReason: c.skipReason,
          );
        }
        return c;
      }).toList();
    });
  }
}
// ============================================================
// PART 2: Header, Stats, and Avatar Widgets
// ============================================================

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    super.key,
    required this.activeTab,
    required this.onLogoutTapped,
    required this.empId,
    required this.driverName,
  });

  final _DriverTab activeTab;
  final VoidCallback onLogoutTapped;
  final String empId;
  final String driverName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_driverPrimary, _driverAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            driverName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (activeTab == _DriverTab.attendance)
            DriverAvatar(empId: empId)
          else
            IconButton(
              onPressed: onLogoutTapped,
              icon: const Icon(Icons.power_settings_new_rounded,
                  color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class DriverAvatar extends StatefulWidget {
  final String empId;
  const DriverAvatar({super.key, required this.empId});

  @override
  State<DriverAvatar> createState() => _DriverAvatarState();
}

class _DriverAvatarState extends State<DriverAvatar> {
  bool hasProfile = false;
  bool imageLoading = true;
  String? imageName;

  @override
  void initState() {
    super.initState();
    fetchEmployeeImage();
  }

  Future<void> fetchEmployeeImage() async {
    try {
      final url =
          "http://10.164.86.186:8000/api/mobile/staff-profile/?staff_id_id=${widget.empId}";

      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);

      if (json["status"] == "success") {
        setState(() {
          imageName = json["data"]["photo"] ?? "";
          hasProfile = imageName != null && imageName!.isNotEmpty;
          imageLoading = false;
        });
      } else {
        setState(() {
          hasProfile = false;
          imageLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasProfile = false;
        imageLoading = false;
      });
    }
  }

  String convertToUrl(String path) {
    final clean = path.replaceAll("\\", "/");
    final filename = clean.split("/").last;
    return "http://10.164.86.186:8000/media/emp_image/$filename";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(empId: widget.empId),
          ),
        );
        fetchEmployeeImage();
      },
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        backgroundImage: (hasProfile && imageName != null)
            ? NetworkImage(convertToUrl(imageName!))
            : null,
        child: imageLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              )
            : (!hasProfile)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.person_add_alt_1, size: 26, color: Colors.green),
                      SizedBox(height: 2),
                      Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  )
                : null,
      ),
    );
  }
}
// ============================================================
// PART 3: HomeTab Widget with Map and Navigation
// ============================================================

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
    _customers = widget.customers
        .where((c) => c.status == _CustomerStatus.pending || c.status == _CustomerStatus.navigating)
        .toList();
    _navAnimController = AnimationController(
      vsync: this,
      duration: _kNavigationTransitionDuration,
    );
    _computeRoute();
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
      _customers = widget.customers
          .where((c) => c.status == _CustomerStatus.pending || c.status == _CustomerStatus.navigating)
          .toList();
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
      ..._customers.map((c) => [c.location.longitude, c.location.latitude]),
    ];

    try {
      final route = await ORSService.fetchMultiRoute(coords);

      if (!mounted) return;

      setState(() {
        _orsRoute = route;

        if (route.length > 1) {
          _driverBearing = ORSService.calculateBearing(route.first, route[1]);
        } else {
          _driverBearing = 0.0;
        }
      });

      if (_navMode == _NavigationMode.overview) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _fitDriverAndNextCustomer();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orsRoute = [];
        _driverBearing = 0.0;
      });
    }
  }

  void _fitDriverAndNextCustomer() {
    if (_customers.isEmpty) return;

    final nextCustomer = _customers.first;

    final bounds = LatLngBounds.fromPoints([
      widget.driverLocation,
      nextCustomer.location,
    ]);

    widget.mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  void _startNavigation(String customerId) {
    final customer = _customers.firstWhere((c) => c.id == customerId);

    setState(() {
      _activeNavigationId = customerId;
      _navMode = _NavigationMode.navigating;
      customer.status = _CustomerStatus.navigating;
    });

    widget.onStatusChanged(customerId, _CustomerStatus.navigating);
    _navAnimController.forward();
    _animateToNavigationView();
  }

  void _stopNavigation() {
    setState(() {
      if (_activeNavigationId != null) {
        final customer = _customers.firstWhere((c) => c.id == _activeNavigationId);
        customer.status = _CustomerStatus.pending;
        widget.onStatusChanged(_activeNavigationId!, _CustomerStatus.pending);
      }
      _activeNavigationId = null;
      _navMode = _NavigationMode.overview;
    });

    _navAnimController.reverse();
    _animateToOverview();
  }

  void _recenterNavigation() {
    if (_navMode == _NavigationMode.navigating) {
      _animateToNavigationView();
    } else {
      _fitDriverAndNextCustomer();
    }
  }

  void _animateToNavigationView() {
    if (_orsRoute.isEmpty) return;

    // Position driver at bottom third of screen, facing up
    final driverPos = _orsRoute.first;
    
    // Calculate offset to position driver marker at bottom third
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight - 200; // approximate map height
    final offsetLat = 0.003; // Adjust this value based on zoom level
    
    final targetCenter = LatLng(
      driverPos.latitude + offsetLat,
      driverPos.longitude,
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      widget.mapController.move(targetCenter, 17.5);
      widget.mapController.rotate(0); // North-up orientation
    });
  }

  void _animateToOverview() {
    if (_customers.isEmpty) {
      widget.mapController.move(widget.driverLocation, 15.0);
      widget.mapController.rotate(0);
      return;
    }

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
      widget.mapController.rotate(0);
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
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                if (isNavigating)
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    onPressed: _recenterNavigation,
                    tooltip: 'Recenter',
                  ),
                if (!isNavigating) ...[
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
                customer: _customers.firstWhere((c) => c.id == _activeNavigationId),
                distance: _getDistanceToCustomer(
                  _customers.firstWhere((c) => c.id == _activeNavigationId),
                ),
                onStop: _stopNavigation,
              ),
            ),

          // Bottom customer carousel - compact design
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: AnimatedContainer(
              duration: _kNavigationTransitionDuration,
              curve: Curves.easeInOut,
              height: isNavigating ? 0 : 140, // Reduced from 180 to 140
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
                              child: Text(
                                'All customers completed!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    setState(() {
                                      customer.status = _CustomerStatus.collected;
                                    });

                                    widget.onStatusChanged(customer.id, _CustomerStatus.collected);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Collection completed'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }

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
                                              title: const Text('Skip Waste Collection'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('Select a reason for skipping:'),
                                                  const SizedBox(height: 12),
                                                  DropdownButtonFormField<String>(
                                                    value: selectedReason,
                                                    isExpanded: true,
                                                    dropdownColor: Colors.white,
                                                    decoration: const InputDecoration(
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      border: OutlineInputBorder(),
                                                      hintText: 'Reason',
                                                    ),
                                                    items: _skipReasons
                                                        .map(
                                                          (r) => DropdownMenuItem(
                                                            value: r,
                                                            child: Text(
                                                              r,
                                                              style: const TextStyle(
                                                                  color: Colors.black),
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
                                                      Navigator.pop(dialogContext, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: selectedReason == null
                                                      ? null
                                                      : () => Navigator.pop(dialogContext, true),
                                                  child: const Text('Skip'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );

                                    if (confirmed != true || selectedReason == null) return;

                                    setState(() {
                                      customer.status = _CustomerStatus.skipped;
                                      customer.skipReason = selectedReason;
                                    });

                                    widget.onStatusChanged(customer.id, _CustomerStatus.skipped);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Skipped'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }

                                    await _computeRoute();
                                  },
                                  onStart: () => _startNavigation(customer.id),
                                );
                              },
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemCount: _customers.length,
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// PART 4: NavigationHeader, Cards, History, Profile, and Markers
// ============================================================

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
            color: Colors.black.withValues(alpha: 0.15),
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
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240, // Reduced from 260
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10), // Reduced from 12
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 16, // Reduced from 18
                    backgroundColor: _statusColor.withValues(alpha: 0.15),
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.near_me_rounded,
                              size: 11,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              distance,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
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

              const SizedBox(height: 8),

              // Complete / Skip buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32, // Reduced from 36
                      child: ElevatedButton(
                        onPressed: customer.status == _CustomerStatus.collected
                            ? null
                            : onComplete,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Complete',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: customer.status == _CustomerStatus.skipped
                            ? null
                            : onSkip,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Navigate button
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton.icon(
                  onPressed:
                      customer.status == _CustomerStatus.navigating ? null : onStart,
                  icon: const Icon(
                    Icons.navigation_rounded,
                    size: 13,
                  ),
                  label: const Text(
                    'Navigate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
    final completedCustomers = customers
        .where((c) =>
            c.status == _CustomerStatus.collected ||
            c.status == _CustomerStatus.skipped)
        .toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Collection History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _driverPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${completedCustomers.length} completed',
                  style: const TextStyle(
                    color: _driverPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          else if (completedCustomers.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No collection history yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ...completedCustomers.map((c) {
              final isCollected = c.status == _CustomerStatus.collected;
              final color = isCollected ? Colors.green : Colors.orange;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.5),
                  color: color.withValues(alpha: 0.08),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
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
                      if (c.address.isNotEmpty) Text(c.address),
                      if (c.status == _CustomerStatus.skipped && c.skipReason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Reason: ${c.skipReason}',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCollected ? 'Collected' : 'Skipped',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
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
  const _ProfileTab({
    required this.onLogout,
    required this.driverName,
    required this.empId,
    required this.vehicle,
  });

  final VoidCallback onLogout;
  final String driverName;
  final String empId;
  final VehicleModel? vehicle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_driverPrimary, _driverAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: _driverPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  driverName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Employee ID: $empId',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Vehicle Information
          if (vehicle != null) ...[
            _ProfileSection(
              title: 'Vehicle Information',
              icon: Icons.local_shipping_rounded,
              children: [
                _ProfileItem(
                  label: 'Vehicle Number',
                  value: vehicle!.vehicleNumber ?? 'N/A',
                  icon: Icons.confirmation_number_outlined,
                ),
                _ProfileItem(
                  label: 'Vehicle Type',
                  value: vehicle!.vehicleType ?? 'N/A',
                  icon: Icons.category_outlined,
                ),
                _ProfileItem(
                  label: 'Status',
                  value: vehicle!.status ?? 'N/A',
                  icon: Icons.circle,
                  valueColor: (vehicle!.status ?? '').toLowerCase() == 'running'
                      ? Colors.green
                      : Colors.orange,
                ),
                _ProfileItem(
                  label: 'Driver Name',
                  value: vehicle!.driverName ?? 'N/A',
                  icon: Icons.person_outline,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Work Information
          _ProfileSection(
            title: 'Work Information',
            icon: Icons.work_outline_rounded,
            children: [
              _ProfileItem(
                label: 'Role',
                value: 'Waste Collection Driver',
                icon: Icons.badge_outlined,
              ),
              _ProfileItem(
                label: 'Department',
                value: 'Waste Management',
                icon: Icons.business_outlined,
              ),
              _ProfileItem(
                label: 'Shift',
                value: 'Morning (6:00 AM - 2:00 PM)',
                icon: Icons.access_time_outlined,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Contact Information
          _ProfileSection(
            title: 'Contact Information',
            icon: Icons.contact_phone_outlined,
            children: [
              _ProfileItem(
                label: 'Phone',
                value: '+91 XXXXX XXXXX',
                icon: Icons.phone_outlined,
              ),
              _ProfileItem(
                label: 'Emergency Contact',
                value: '1800-XXX-XXXX',
                icon: Icons.emergency_outlined,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: _driverPrimary, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _driverPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? Colors.black87,
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

class _DriverMarker extends StatelessWidget {
  final bool isActive;
  final double rotation;

  const _DriverMarker({
    required this.isActive,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.navigation_rounded,
      size: 38,
      color: Colors.deepOrange,
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
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
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