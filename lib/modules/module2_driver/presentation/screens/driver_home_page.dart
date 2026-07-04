import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:animations/animations.dart';
import 'package:iwms_citizen_app/core/ui/app_copy.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di.dart';
import '../../../../core/geofence_config.dart';
import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';
import 'package:iwms_citizen_app/data/repositories/operator_trip_repository.dart';
import '../../../../logic/vehicle_tracking/vehicle_bloc.dart';
import '../../../../logic/vehicle_tracking/vehicle_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/ors_service.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/attendance/attendance_driver.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/captain_home_tab.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/driver_theme.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/widgets/captain_glass.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/widgets/captain_nav_bar.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/widgets/driver_header.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_qr_scanner.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_trip_home_screen.dart'
    show OperatorTripScanScreen;
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cp_card.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_trip_summary_card.dart';
import 'package:iwms_citizen_app/shared/constants/skip_reasons.dart';

const Duration _kNavigationTransitionDuration = Duration(milliseconds: 600);
const List<String> _skipReasons = kSkipReasons;

/// Colour matrix that turns the light OSM raster into a dark-map look
/// (invert luminance, then rotate the hue back so water/land keep sensible
/// tones). Applied via [ColorFiltered] only when the Captain dark theme is on.
const List<double> _darkMapMatrix = <double>[
  -0.6, -0.4, -0.4, 0, 255, //
  -0.4, -0.6, -0.4, 0, 255, //
  -0.4, -0.4, -0.6, 0, 255, //
  0, 0, 0, 1, 0, //
];

enum _NavigationMode { overview, navigating }

enum _CustomerStatus { pending, later, collected, skipped, navigating }

class _DriverAssignmentStop {
  final String assignmentId;
  final String? wardId;
  final String wardName;
  final String? customerName;
  final LatLng location;
  final String assignmentType;
  final String shift;

  _CustomerStatus status = _CustomerStatus.pending;
  String? skipReason;

  _DriverAssignmentStop({
    required this.assignmentId,
    required this.wardId,
    required this.wardName,
    required this.location,
    required this.assignmentType,
    required this.shift,
    this.customerName,
    this.status = _CustomerStatus.pending,
  });

  // =====================
  // BACKWARD COMPATIBILITY
  // =====================

  String get id => assignmentId;

  String get name => (customerName != null && customerName!.trim().isNotEmpty)
      ? customerName!
      : wardName;

  String get address => wardName; // placeholder until API adds address

  String get baseAssignmentId => assignmentId.split('-').first;
}

class _TripPlannedStop {
  final String plannedStopId;
  final int sequence;
  final LatLng location;
  final String collectionPointId;
  final String propertyType;
  final bool isCollected;

  const _TripPlannedStop({
    required this.plannedStopId,
    required this.sequence,
    required this.location,
    required this.collectionPointId,
    required this.propertyType,
    this.isCollected = false,
  });
}

/// Captain shell tabs. Home is the today-first dashboard; Map hosts the
/// turn-by-turn navigation view; the centre Scan FAB owns collection.
/// (Assignments folded into Home — trip history opens from a quick action.)
enum _DriverTab { home, map, attendance, profile }

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  _DriverTab _activeTab = _DriverTab.home;
  late final OperatorTripRepository _tripRepository;
  final MapController _mapController = MapController();
  List<_DriverAssignmentStop> _customers = [];
  List<_TripPlannedStop> _tripStops = [];
  List<LatLng> _tripPolyline = [];
  String? _activeTripId;
  String? _activeRoutePlanId;
  String? _activeVehicleType;
  List<OperatorTripHistorySummary> _currentAssignments = [];
  List<OperatorTripHistorySummary> _historyAssignments = [];
  OperatorTripToday? _todayTrip;
  OperatorTripHistoryDetail? _activeTripDetail;
  LatLng? _staticDriverLocation;
  bool _loadingCustomers = true;
  bool _loadingAssignments = true;
  bool _loadingTrip = false;
  String? _customerError;
  String? _assignmentError;
  String? _tripError;

  @override
  void initState() {
    super.initState();
    // Hydrate the persisted light/dark choice before first paint settles.
    CaptainThemeStore.load();
    _tripRepository = getIt<OperatorTripRepository>();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerOnDriver(GammaGeofenceConfig.center),
    );
    _loadAssignmentsForDriver();
  }

  VehicleModel? _selectedVehicleFrom(VehicleState state) {
    return state is VehicleLoaded ? state.selectedVehicle : null;
  }

  LatLng _resolveDriverLocation(VehicleModel? vehicle) {
    if (_staticDriverLocation != null) return _staticDriverLocation!;
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

    // Human-readable employee id (e.g. "13753223") for display in the header
    // badge. The API ships this as `employee_id`; `emp_id` is the internal
    // staff unique id ("STC-...") used only for the profile-photo lookup.
    final employeeIdFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).employeeId
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

            // Rebuild the whole Captain shell when the light/dark toggle
            // flips so every mode-aware token re-resolves.
            return ValueListenableBuilder<bool>(
              valueListenable: CaptainThemeStore.isDark,
              builder: (context, _, __) => _buildShell(
                context,
                driverLocation,
                nameFromState,
                empIdFromState,
                employeeIdFromState,
                selectedVehicle,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShell(
    BuildContext context,
    LatLng driverLocation,
    String? nameFromState,
    String? empIdFromState,
    String? employeeIdFromState,
    VehicleModel? selectedVehicle,
  ) {
    return Scaffold(
              backgroundColor: DriverTheme.background,
              extendBody: true,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    DriverHeader(
                      name: nameFromState ?? 'Driver',
                      empId: empIdFromState ?? '',
                      displayId: employeeIdFromState,
                      onLogout: () => _logout(context),
                      onProfileTap: () =>
                          setState(() => _activeTab = _DriverTab.profile),
                      collapsed: _activeTab == _DriverTab.map,
                    ),
                    Expanded(
                      child: PageTransitionSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder:
                            (child, animation, secondaryAnimation) {
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
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
              floatingActionButton: CaptainScanFab(onPressed: _openScanner),
              bottomNavigationBar: CaptainNavBar(
                activeIndex: _activeTab.index,
                onTabSelected: (index) {
                  final tab = _tabFromIndex(index);
                  if (_activeTab != tab) setState(() => _activeTab = tab);
                },
                items: const [
                  CaptainNavItem(
                    icon: Icons.home_rounded,
                    label: AppCopy.driverTabHome,
                  ),
                  CaptainNavItem(
                    icon: Icons.map_rounded,
                    label: AppCopy.driverTabMap,
                  ),
                  CaptainNavItem(
                    icon: Icons.event_available_rounded,
                    label: AppCopy.driverTabAttendance,
                    blink: true,
                  ),
                  CaptainNavItem(
                    icon: Icons.person_outline_rounded,
                    label: AppCopy.driverTabProfile,
                  ),
                ],
              ),
            );
  }

  Future<void> _loadAssignmentsForDriver() async {
    setState(() {
      _loadingCustomers = true;
      _loadingAssignments = true;
      _loadingTrip = true;
      _customerError = null;
      _assignmentError = null;
      _tripError = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthStateAuthenticated) {
        setState(() {
          _loadingCustomers = false;
          _loadingAssignments = false;
          _loadingTrip = false;
          _customerError = 'User not authenticated';
          _assignmentError = 'User not authenticated';
          _tripError = 'User not authenticated';
        });
        return;
      }

      final today = DateTime.now();

      // Active trip comes from the CENTRALIZED single-trip endpoint
      // (/operator-mobile/my-trip-today/), exactly like the operator app. The
      // backend resolves it against the staff template, so the operator and the
      // driver on the same template get the same DailyTripAssignment — and the
      // same collection-point rows, so collection progress is shared instantly.
      OperatorTripToday? todayTrip;
      try {
        todayTrip = await _tripRepository.fetchMyTripToday();
      } on OperatorTripException catch (e) {
        // "No trip assigned today" is a normal empty state, not a failure.
        if (e.code != 'NO_ACTIVE_TRIP') rethrow;
        todayTrip = null;
      }

      // History list (completed / cancelled past trips) is still backed by
      // trip-history, but it no longer decides the active trip or feeds the
      // header carousel.
      final history = await _tripRepository.fetchHistory(
        from: today.subtract(const Duration(days: 45)),
        to: today.add(const Duration(days: 1)),
      );
      final activeAssignmentId = todayTrip?.assignmentUniqueId;
      final historyAssignments = history
          .where((trip) => trip.assignmentUniqueId != activeAssignmentId)
          .toList();

      // The header carousel surfaces only the driver's single active trip.
      final detail = todayTrip?.toHistoryDetail();
      final activeTrip = todayTrip?.toHistorySummary();
      final currentAssignments = <OperatorTripHistorySummary>[
        if (activeTrip != null) activeTrip,
      ];

      final stops = <_DriverAssignmentStop>[];
      final tripStops = <_TripPlannedStop>[];
      if (detail != null) {
        for (final cp in detail.collectionPoints) {
          final lat = cp.collectionPoint.latitude;
          final lng = cp.collectionPoint.longitude;
          if (lat == null || lng == null) continue;
          final status = cp.isCollected
              ? _CustomerStatus.collected
              : _CustomerStatus.pending;
          final areaName = detail.summary.areaName;
          stops.add(
            _DriverAssignmentStop(
              assignmentId: cp.uniqueId,
              wardId: detail.summary.ward?.uniqueId ??
                  detail.summary.panchayat?.uniqueId,
              wardName: areaName,
              customerName: cp.collectionPoint.name,
              assignmentType: detail.summary.wasteType.name,
              shift: detail.summary.scheduledTime ?? 'scheduled',
              location: LatLng(lat, lng),
              status: status,
            ),
          );
          tripStops.add(
            _TripPlannedStop(
              plannedStopId: cp.uniqueId,
              sequence: cp.sequence > 0 ? cp.sequence : tripStops.length + 1,
              location: LatLng(lat, lng),
              collectionPointId: cp.collectionPoint.uniqueId,
              propertyType: cp.status,
              isCollected: cp.isCollected,
            ),
          );
        }
        tripStops.sort((a, b) => a.sequence.compareTo(b.sequence));
      }

      setState(() {
        _customers = stops;
        _tripStops = tripStops;
        _tripPolyline = tripStops.map((stop) => stop.location).toList();
        _todayTrip = todayTrip;
        _activeTripId = activeTrip?.assignmentUniqueId;
        _activeRoutePlanId = detail?.summary.tripPlan?.uniqueId;
        _activeVehicleType = null;
        _activeTripDetail = detail;
        _staticDriverLocation = _staticLocationNearStops(tripStops);
        _currentAssignments = currentAssignments;
        _historyAssignments = historyAssignments;
        _loadingCustomers = false;
        _loadingAssignments = false;
        _loadingTrip = false;
        _customerError = null;
        _assignmentError = null;
        _tripError = null;
      });
    } catch (e) {
      setState(() {
        _loadingCustomers = false;
        _loadingAssignments = false;
        _loadingTrip = false;
        _customerError = 'Failed to load assignments';
        _assignmentError = 'Failed to load assignments';
        _tripError = _tripError ?? 'Failed to load trip route';
      });
    }
  }

  LatLng _staticLocationNearStops(List<_TripPlannedStop> stops) {
    if (stops.isEmpty) return GammaGeofenceConfig.center;

    var minLat = stops.first.location.latitude;
    var maxLat = minLat;
    var minLng = stops.first.location.longitude;
    var maxLng = minLng;
    for (final stop in stops) {
      final point = stop.location;
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final latOffset = max(0.003, (maxLat - minLat) * 0.18);
    final lngOffset = max(0.003, (maxLng - minLng) * 0.18);
    return LatLng(centerLat - latOffset, centerLng - lngOffset);
  }

  // List<_DriverAssignmentStop> _decodeCustomerList(String body,
  //     {bool fromAssignments = false}) {
  //   final List<_DriverAssignmentStop> out = [];

  //   try {
  //     final decoded = jsonDecode(body);
  //     final list = decoded is List
  //         ? decoded
  //         : (decoded is Map && decoded['results'] is List
  //             ? decoded['results']
  //             : []);

  //     if (list is! List) return out;

  //     for (final entry in list) {
  //       if (entry is! Map) continue;
  //       final map = Map<String, dynamic>.from(entry);

  //       final id = (map['unique_id'] ?? map['customer_id'] ?? '').toString();
  //       if (id.trim().isEmpty) continue;

  //       final latRaw =
  //           fromAssignments ? map['customer_latitude'] : map['latitude'];
  //       final lonRaw =
  //           fromAssignments ? map['customer_longitude'] : map['longitude'];

  //       final position = _safeLatLng(latRaw, lonRaw);
  //       if (position == null) continue;

  //       final name = (map['customer_name'] ??
  //               map['ward_name'] ??
  //               map['driver_name'] ??
  //               'Unknown')
  //           .toString();

  //       final addressParts = [
  //         map['building_no'],
  //         map['street'],
  //         map['area'],
  //         map['pincode'],
  //       ].whereType<String>().where((v) => v.trim().isNotEmpty).toList();

  //       out.add(_DriverAssignmentStop(
  //         assignmentId: id,
  //         wardName: name,
  //         assignmentType: 'primary',
  //         shift: 'morning',
  //         location: position,
  //       ));
  //     }
  //   } catch (_) {}

  //   return out;
  // }

  Widget _buildTab(_DriverTab tab, LatLng driverLocation, String nameFromState,
      String empIdFromState, VehicleModel? vehicle) {
    switch (tab) {
      case _DriverTab.home:
        return CaptainHomeTab(
          trip: _todayTrip,
          loading: _loadingTrip,
          error: _tripError,
          onRefresh: _loadAssignmentsForDriver,
          onOpenMap: () => setState(() => _activeTab = _DriverTab.map),
          onScan: _openScanner,
          onOpenTrips: _openTripsPage,
          driverName: nameFromState,
        );
      case _DriverTab.map:
        return _HomeTab(
          mapController: _mapController,
          driverLocation: driverLocation,
          onCenter: () => _centerOnDriver(driverLocation),
          customers: _customers,
          currentAssignments: _currentAssignments,
          activeTripDetail: _activeTripDetail,
          tripStops: _tripStops,
          tripPolyline: _tripPolyline,
          activeTripId: _activeTripId,
          activeRoutePlanId: _activeRoutePlanId,
          activeVehicleType: _activeVehicleType,
          tripLoading: _loadingTrip,
          tripError: _tripError,
          loading: _loadingCustomers,
          error: _customerError,
          onRefresh: _loadAssignmentsForDriver,
          onStatusChanged: _updateCustomerStatus,
        );
      case _DriverTab.attendance:
        return AttendancePageDriver(
          driverName: nameFromState,
          driverCode: empIdFromState,
        );
      case _DriverTab.profile:
        return _ProfileTab(
          onLogout: () => _logout(context),
          driverName: nameFromState,
          empId: empIdFromState,
          vehicle: vehicle,
        );
    }
  }

  _DriverTab _tabFromIndex(int index) {
    switch (index) {
      case 1:
        return _DriverTab.map;
      case 2:
        return _DriverTab.attendance;
      case 3:
        return _DriverTab.profile;
      case 0:
      default:
        return _DriverTab.home;
    }
  }

  /// Full trips view (current + history tabs), preserved from the old
  /// Assignments tab and now pushed from the Home dashboard.
  void _openTripsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        // The trips view keeps the operator module's light styling (dark
        // text), so it needs a light scaffold — not the Captain black.
        builder: (_) => Scaffold(
          backgroundColor: OperatorTheme.background,
          appBar: AppBar(
            title: const Text('My Trips'),
            backgroundColor: CaptainTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: _AssignmentsTab(
            currentAssignments: _currentAssignments,
            historyAssignments: _historyAssignments,
            activeTripDetail: _activeTripDetail,
            loading: _loadingAssignments,
            error: _assignmentError,
            onRefresh: _loadAssignmentsForDriver,
          ),
        ),
      ),
    );
  }

  /// Centre Scan FAB → choose between the two collection flows the vehicle
  /// crew performs (both inherited from the operator app):
  ///   • Bin QR — validate a bin against today's trip, then weight entry.
  ///   • Household — scan a customer QR, then wet/dry/mixed weighment.
  Future<void> _openScanner() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: CaptainTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: CaptainTheme.hairline),
            boxShadow: CaptainTheme.elevatedShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are you collecting?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CaptainTheme.strongText,
                ),
              ),
              const SizedBox(height: 14),
              _ScanChoiceTile(
                icon: Icons.delete_rounded,
                color: CaptainTheme.accent,
                title: 'Bin collection',
                subtitle: 'Scan a bin QR and record its weight',
                onTap: () => Navigator.of(sheetContext).pop('bin'),
              ),
              const SizedBox(height: 10),
              _ScanChoiceTile(
                icon: Icons.home_work_rounded,
                color: CaptainTheme.info,
                title: 'Household collection',
                subtitle: 'Scan a customer QR, enter wet / dry / mixed weights',
                onTap: () => Navigator.of(sheetContext).pop('household'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'bin') {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OperatorTripScanScreen()),
      );
      if (!mounted) return;
      if (result != null) await _loadAssignmentsForDriver();
    } else if (choice == 'household') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OperatorQRScanner()),
      );
      if (!mounted) return;
      await _loadAssignmentsForDriver();
    }
  }

  void _logout(BuildContext context) {
    if (!mounted) return;
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }

  void _updateCustomerStatus(String id, _CustomerStatus status) {
    setState(() {
      for (final c in _customers) {
        if (c.assignmentId == id) {
          c.status = status;
        }
      }
    });
  }
}

/// One option row in the Scan chooser sheet — big tap target, icon plate,
/// title + one-line explanation.
class _ScanChoiceTile extends StatelessWidget {
  const _ScanChoiceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: CaptainTheme.strongText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: CaptainTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
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
    required this.customers, // ✅ DECLARED
    required this.currentAssignments,
    required this.activeTripDetail,
    required this.tripStops,
    required this.tripPolyline,
    required this.activeTripId,
    required this.activeRoutePlanId,
    required this.activeVehicleType,
    required this.tripLoading,
    required this.tripError,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onStatusChanged,
  });

  final MapController mapController;
  final LatLng driverLocation;
  final VoidCallback onCenter;
  final List<_DriverAssignmentStop> customers; // ✅ ADD THIS
  final List<OperatorTripHistorySummary> currentAssignments;
  final OperatorTripHistoryDetail? activeTripDetail;
  final List<_TripPlannedStop> tripStops;
  final List<LatLng> tripPolyline;
  final String? activeTripId;
  final String? activeRoutePlanId;
  final String? activeVehicleType;
  final bool tripLoading;
  final String? tripError;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(String id, _CustomerStatus status) onStatusChanged;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  static const EdgeInsets _overviewFitPadding =
      EdgeInsets.fromLTRB(46, 238, 46, 252);

  List<LatLng> _orsRoute = [];
  List<LatLng> _tripPolyline = [];
  double _driverBearing = 0.0;
  List<_DriverAssignmentStop> _customers = [];
  List<_TripPlannedStop> _tripStops = [];
  _NavigationMode _navMode = _NavigationMode.overview;
  String? _activeNavigationId;
  late AnimationController _navAnimController;
  LatLng _driverLocation = GammaGeofenceConfig.center;
  bool _manualDriverOverride = false;
  bool _isDraggingDriver = false;
  Point<double>? _driverScreenPoint;
  String? _tripId;
  String? _routePlanId;
  String? _vehicleType;
  bool _rerouting = false;
  int _tripRouteRequestId = 0;
  List<String> _lastActualSequence = [];
  bool _autoRerouteDone = false;

  @override
  void initState() {
    super.initState();
    _driverLocation = _sanitizeDriverLocation(widget.driverLocation);
    _customers = widget.customers
        .where((c) =>
            c.status == _CustomerStatus.pending ||
            c.status == _CustomerStatus.later ||
            c.status == _CustomerStatus.navigating)
        .toList();
    _tripStops = widget.tripStops;
    _tripPolyline = widget.tripPolyline;
    _tripId = widget.activeTripId;
    _routePlanId = widget.activeRoutePlanId;
    _vehicleType = widget.activeVehicleType;
    _lastActualSequence = _tripStops
        .map((stop) => stop.plannedStopId)
        .where((id) => id.isNotEmpty)
        .toList();
    _navAnimController = AnimationController(
      vsync: this,
      duration: _kNavigationTransitionDuration,
    );
    _computeRoute();
    _computeTripRoadRoute();
    _maybeAutoReroute();
  }

  LatLng _sanitizeDriverLocation(LatLng location) {
    return location;
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  void _updateCustomerStatus(String id, _CustomerStatus status) {
    final isDone = status == _CustomerStatus.collected ||
        status == _CustomerStatus.skipped;
    final shouldExitNavigation =
        _navMode == _NavigationMode.navigating && _activeNavigationId == id;

    setState(() {
      if (isDone) {
        _customers.removeWhere((c) => c.id == id);
        if (shouldExitNavigation) {
          _activeNavigationId = null;
          _navMode = _NavigationMode.overview;
        }
      } else {
        for (final c in _customers) {
          if (c.id == id) {
            c.status = status;
          }
        }
      }
    });

    if (shouldExitNavigation) {
      _navAnimController.reverse();
      _animateToOverview();
    }
    widget.onStatusChanged(id, status);
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final customersChanged = oldWidget.customers != widget.customers;
    final driverChanged = oldWidget.driverLocation != widget.driverLocation;
    final tripChanged = oldWidget.tripStops != widget.tripStops ||
        oldWidget.tripPolyline != widget.tripPolyline ||
        oldWidget.activeTripId != widget.activeTripId ||
        oldWidget.activeRoutePlanId != widget.activeRoutePlanId;

    if (driverChanged && !_manualDriverOverride && !_isDraggingDriver) {
      _driverLocation = _sanitizeDriverLocation(widget.driverLocation);
    }

    if (customersChanged) {
      _customers = widget.customers
          .where((c) =>
              c.status == _CustomerStatus.pending ||
              c.status == _CustomerStatus.later ||
              c.status == _CustomerStatus.navigating)
          .toList();
    }

    if (tripChanged) {
      _tripStops = widget.tripStops;
      _tripPolyline = widget.tripPolyline;
      _tripId = widget.activeTripId;
      _routePlanId = widget.activeRoutePlanId;
      _vehicleType = widget.activeVehicleType;
      _autoRerouteDone = false;
      _lastActualSequence = _tripStops
          .map((stop) => stop.plannedStopId)
          .where((id) => id.isNotEmpty)
          .toList();
    }

    if (customersChanged || driverChanged) {
      _computeRoute();
    }

    if (tripChanged || driverChanged) {
      _computeTripRoadRoute();
    }

    if (tripChanged && !_autoRerouteDone) {
      _maybeAutoReroute();
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
      [_driverLocation.longitude, _driverLocation.latitude],
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

    final bounds = LatLngBounds.fromPoints([
      _driverLocation,
      ..._customers.map((customer) => customer.location),
    ]);

    widget.mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: _overviewFitPadding,
      ),
    );
  }

  void _fitTripRoute() {
    if (_tripStops.isEmpty) return;
    final bounds = LatLngBounds.fromPoints([
      _driverLocation,
      ..._tripStops.map((stop) => stop.location),
    ]);

    widget.mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: _overviewFitPadding,
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
        final customer =
            _customers.firstWhere((c) => c.id == _activeNavigationId);
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
      if (_customers.isEmpty && _tripStops.isNotEmpty) {
        _fitTripRoute();
      } else {
        _fitDriverAndNextCustomer();
      }
    }
  }

  void _animateToNavigationView() {
    if (_orsRoute.isEmpty) return;

    // Position driver at bottom third of screen, facing up
    final driverPos = _orsRoute.first;

    // Calculate offset to position driver marker at bottom third
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
      if (_tripStops.isNotEmpty) {
        _fitTripRoute();
      } else {
        widget.mapController.move(_driverLocation, 15.0);
        widget.mapController.rotate(0);
      }
      return;
    }

    final allPoints = [
      _driverLocation,
      ..._customers.map((c) => c.location),
    ];

    final bounds = LatLngBounds.fromPoints(allPoints);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      widget.mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: _overviewFitPadding,
        ),
      );
      widget.mapController.rotate(0);
    });
  }

  void _centerOnDriver() {
    if (_manualDriverOverride) {
      widget.mapController.move(_driverLocation, 15.0);
    } else {
      widget.onCenter();
    }
  }

  void _zoomBy(double delta) {
    final camera = widget.mapController.camera;
    final next = (camera.zoom + delta).clamp(10.0, 18.0);
    widget.mapController.move(camera.center, next);
  }

  void _startDriverDrag(DragStartDetails details) {
    _isDraggingDriver = true;
    _driverScreenPoint =
        widget.mapController.camera.latLngToScreenPoint(_driverLocation);
  }

  void _updateDriverDrag(DragUpdateDetails details) {
    if (_driverScreenPoint == null) return;
    final nextPoint = Point<double>(
      _driverScreenPoint!.x + details.delta.dx,
      _driverScreenPoint!.y + details.delta.dy,
    );
    final nextLocation = widget.mapController.camera.pointToLatLng(nextPoint);
    setState(() {
      _manualDriverOverride = true;
      _driverLocation = nextLocation;
    });
    _driverScreenPoint = nextPoint;
  }

  void _endDriverDrag(DragEndDetails details) {
    _isDraggingDriver = false;
    _driverScreenPoint = null;
    _computeRoute();
    _rerouteTripFromDriver();
  }

  void _resetDriverLocation() {
    setState(() {
      _manualDriverOverride = false;
      _driverLocation = _sanitizeDriverLocation(widget.driverLocation);
    });
    _computeRoute();
  }

  void _maybeAutoReroute() {
    if (_autoRerouteDone) return;
    if (widget.tripLoading || widget.tripError != null) return;
    if (_tripStops.length < 2) return;
    if (_vehicleType == null || _vehicleType!.trim().isEmpty) return;
    if (_tripId == null || _tripId!.isEmpty) return;

    _autoRerouteDone = true;
    _rerouteTripFromDriver();
  }

  bool _isSameSequence(List<String> next, List<String> previous) {
    if (next.length != previous.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i] != previous[i]) return false;
    }
    return true;
  }

  Future<void> _postActualSequence(
    String tripId,
    List<_TripPlannedStop> stops,
  ) async {
    final ordered =
        stops.where((stop) => stop.plannedStopId.isNotEmpty).toList();
    if (ordered.isEmpty) return;

    final dio = await authorizedDio();
    for (var i = 0; i < ordered.length; i++) {
      final stop = ordered[i];
      await dio.post(
        ApiConfig.tripExecutionStops,
        data: {
          'trip_id': tripId,
          'planned_route_stop_id': stop.plannedStopId,
          'actual_sequence_number': i + 1,
          'gps_lat': _driverLocation.latitude,
          'gps_lng': _driverLocation.longitude,
        },
      );
    }
  }

  Future<void> _computeTripRoadRoute({bool force = false}) async {
    if (_tripStops.isEmpty) return;

    final needsRoad =
        _tripPolyline.isEmpty || _tripPolyline.length <= _tripStops.length + 1;
    if (!force && !needsRoad) return;

    final requestId = ++_tripRouteRequestId;
    final orderedStops = _tripStops.map((s) => s.location).toList();
    final route = await ORSService.fetchRoadRoute(
      driver: _driverLocation,
      stops: orderedStops,
    );

    if (!mounted || requestId != _tripRouteRequestId) return;
    if (route.isEmpty) return;

    setState(() {
      _tripPolyline = route;
    });
  }

  Future<void> _rerouteTripFromDriver() async {
    if (_rerouting) return;
    if (_tripStops.isEmpty) return;
    final tripId = _tripId;
    final vehicleType = _vehicleType;
    if (tripId == null || tripId.isEmpty) return;
    if (vehicleType == null || vehicleType.trim().isEmpty) return;

    final collectionPointIds = _tripStops
        .map((stop) => stop.collectionPointId)
        .where((id) => id.isNotEmpty)
        .toList();

    if (collectionPointIds.isEmpty) return;

    setState(() {
      _rerouting = true;
    });

    try {
      final dio = await authorizedDio();
      final payload = <String, dynamic>{
        'trip_id': tripId,
        'start_lat': _driverLocation.latitude,
        'start_lng': _driverLocation.longitude,
        'collection_point_ids': collectionPointIds,
        'vehicle_type': vehicleType,
        'generated_by': 'ORS',
        'generated_reason': 'MANUAL',
      };

      final parentRoutePlanId = _routePlanId;
      if (parentRoutePlanId != null && parentRoutePlanId.isNotEmpty) {
        payload['parent_route_plan_id'] = parentRoutePlanId;
      }

      final resp =
          await dio.post(ApiConfig.tripRoutePlanGenerate, data: payload);
      final data = resp.data;

      final plan = data is Map ? data['route_plan'] : null;
      final plannedStops = data is Map && data['planned_stops'] is List
          ? data['planned_stops'] as List
          : const [];

      final stops = <_TripPlannedStop>[];
      for (final item in plannedStops) {
        if (item is! Map) continue;
        final lat = double.tryParse(
          item['collection_point_latitude']?.toString() ?? '',
        );
        final lng = double.tryParse(
          item['collection_point_longitude']?.toString() ?? '',
        );
        if (lat == null || lng == null) continue;
        final seqRaw = item['planned_sequence_number'] ?? item['sequence'];
        final sequence = int.tryParse(seqRaw?.toString() ?? '') ?? 0;
        final plannedStopId = (item['unique_id'] ?? '').toString();
        final pointId = (item['collection_point_id'] ?? '').toString();
        final propertyType = (item['collection_point_type'] ?? '').toString();

        stops.add(
          _TripPlannedStop(
            plannedStopId: plannedStopId,
            sequence: sequence > 0 ? sequence : stops.length + 1,
            location: LatLng(lat, lng),
            collectionPointId: pointId,
            propertyType: propertyType,
          ),
        );
      }

      stops.sort((a, b) => a.sequence.compareTo(b.sequence));

      final geometry = data is Map && data['route_geometry'] is Map
          ? data['route_geometry'] as Map
          : null;
      final encoded = geometry?['encoded_polyline'];
      List<LatLng> polyline = [];
      if (encoded is String && encoded.trim().isNotEmpty) {
        polyline = ORSService.decodePolyline(encoded.trim());
      }
      if (polyline.isEmpty && stops.isNotEmpty) {
        polyline = stops.map((s) => s.location).toList();
      }

      if (!mounted) return;
      final newSequence = stops
          .map((stop) => stop.plannedStopId)
          .where((id) => id.isNotEmpty)
          .toList();
      final sequenceChanged = newSequence.isNotEmpty &&
          !_isSameSequence(newSequence, _lastActualSequence);

      setState(() {
        _tripStops = stops.isEmpty ? _tripStops : stops;
        _tripPolyline = polyline;
        _routePlanId =
            plan is Map ? plan['unique_id']?.toString() : _routePlanId;
        _rerouting = false;
      });

      if (sequenceChanged && tripId.isNotEmpty) {
        try {
          await _postActualSequence(tripId, stops);
          if (!mounted) return;
          setState(() {
            _lastActualSequence = newSequence;
          });
        } catch (_) {
          // Best effort only: route display should not fail when sequence logging
          // has a transient backend issue.
        }
      }

      if (stops.isNotEmpty) {
        _fitTripRoute();
      }
      await _computeTripRoadRoute(force: true);
    } on DioException catch (e) {
      final message = _extractDioMessage(e) ?? 'Reroute failed';
      if (!mounted) return;
      setState(() {
        _rerouting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rerouting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reroute failed'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _reportCompletion(_DriverAssignmentStop customer) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return;

    final assignmentId = customer.baseAssignmentId;
    String? driverId;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthStateAuthenticated) {
      final trimmed = authState.userId.trim();
      if (trimmed.isNotEmpty) {
        driverId = trimmed;
      }
    }
    final dio = await authorizedDio();

    try {
      await dio.post(
        '${ApiConfig.assignments}$assignmentId/complete/',
      );
    } on DioException catch (e) {
      final alreadyCompleted =
          await _verifyAssignmentCompletion(dio, assignmentId);
      if (alreadyCompleted) return;
      final message = _extractDioMessage(e) ?? 'Failed to sync completion';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    } catch (_) {
      final alreadyCompleted =
          await _verifyAssignmentCompletion(dio, assignmentId);
      if (alreadyCompleted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sync completion'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await dio.post(
        ApiConfig.collectionLogs,
        data: {
          'assignment': assignmentId,
          if (driverId != null) 'driver': driverId,
          'action': 'collection_completed',
          'latitude': _driverLocation.latitude,
          'longitude': _driverLocation.longitude,
        },
      );
    } catch (_) {
      // ignore log failures once completion succeeded
    }
  }

  String? _extractDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['reason'] ?? data['message'];
      if (detail != null) return detail.toString();
    }
    return null;
  }

  Future<bool> _verifyAssignmentCompletion(
    Dio dio,
    String assignmentId,
  ) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return false;

    try {
      final resp = await dio.get('${ApiConfig.assignments}$assignmentId/');
      final data = resp.data;
      if (data is Map) {
        final status = data['current_status']?.toString().toLowerCase();
        return status == 'completed' ||
            status == 'skipped' ||
            status == 'cancelled';
      }
    } catch (_) {}
    return false;
  }

  Future<void> _handleCollect(_DriverAssignmentStop customer) async {
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

    _updateCustomerStatus(customer.id, _CustomerStatus.collected);

    await _reportCompletion(customer);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collection completed'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    await _computeRoute();
  }

  Future<void> _handleSkip(_DriverAssignmentStop customer) async {
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
                              style: const TextStyle(color: Colors.black),
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
                  onPressed: () => Navigator.pop(dialogContext, false),
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

    _updateCustomerStatus(customer.id, _CustomerStatus.skipped);

    await _reportSkip(customer, selectedReason!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skipped'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    await _computeRoute();
  }

  void _handleLater(_DriverAssignmentStop customer) {
    setState(() {
      customer.status = _CustomerStatus.later;
    });

    _updateCustomerStatus(customer.id, _CustomerStatus.later);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked for later'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openAssignmentScreen(_DriverAssignmentStop customer) {
    final wardId = customer.wardId;
    final wardName = customer.wardName;

    if (wardId == null && wardName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ward not available for this assignment')),
      );
      return;
    }

    final wardCustomers = _customers.where((c) {
      if (wardId != null && wardId.isNotEmpty) {
        return c.wardId == wardId;
      }
      return c.wardName == wardName;
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AssignmentScreen(
          wardName: wardName,
          customers: wardCustomers,
          onCollect: _handleCollect,
          onLater: _handleLater,
          onSkip: _handleSkip,
        ),
      ),
    );
  }

  Future<void> _reportSkip(
    _DriverAssignmentStop customer,
    String reason,
  ) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return;

    try {
      final dio = await authorizedDio();
      final assignmentId = customer.baseAssignmentId;

      await dio.post(
        '${ApiConfig.assignments}$assignmentId/skip/',
        data: {'reason': reason},
      );

      await dio.post(
        ApiConfig.collectionLogs,
        data: {
          'assignment': assignmentId,
          'action': 'skipped',
          'skip_reason': reason,
          'latitude': _driverLocation.latitude,
          'longitude': _driverLocation.longitude,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sync skip'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Color _statusColor(_CustomerStatus status) {
    switch (status) {
      case _CustomerStatus.collected:
        return CaptainTheme.success;
      case _CustomerStatus.later:
        return CaptainTheme.gold;
      case _CustomerStatus.skipped:
        return CaptainTheme.warning;
      case _CustomerStatus.navigating:
        return CaptainTheme.accent;
      case _CustomerStatus.pending:
        return CaptainTheme.danger;
    }
  }

  String _getDistanceToCustomer(_DriverAssignmentStop customer) {
    final distance = const Distance().as(
      LengthUnit.Meter,
      _driverLocation,
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
    _DriverAssignmentStop? activeCustomer;
    if (_activeNavigationId != null) {
      for (final c in _customers) {
        if (c.id == _activeNavigationId) {
          activeCustomer = c;
          break;
        }
      }
    }
    final navigationCustomer = isNavigating ? activeCustomer : null;
    final nextCustomer =
        !isNavigating && _customers.isNotEmpty ? _customers.first : null;
    final nextCustomerPosition = nextCustomer == null
        ? 0
        : widget.customers
            .indexWhere((customer) => customer.id == nextCustomer.id);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomOverlayOffset = 84.0 + bottomInset;
    // The map now carries ONLY the next-collection-point card (the daily
    // assignment carousel was removed to declutter the view); controls sit
    // just below it, or at the top when there's no next stop.
    final mapControlsTop =
        isNavigating ? 12.0 : (nextCustomer != null ? 118.0 : 12.0);
    final dark = CaptainThemeStore.isDark.value;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Stack(
        children: [
          // Map
          Positioned.fill(
            child: FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                initialCenter: _driverLocation,
                initialZoom: 14.5,
                minZoom: 10,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // In dark mode the light OSM raster is run through an
                // invert+hue matrix so it reads as a proper dark map instead
                // of glaring white on the black Captain canvas.
                dark
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix(_darkMapMatrix),
                        child: TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.iwms.citizen.app',
                        ),
                      )
                    : TileLayer(
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
                            ? CaptainTheme.accent
                            : CaptainTheme.accent.withValues(alpha: 0.7),
                        strokeWidth: isNavigating ? 6.0 : 4.5,
                      ),
                    ],
                  ),
                if (_tripPolyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _tripPolyline,
                        color: CaptainTheme.gold,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 42,
                      height: 42,
                      point: _orsRoute.isNotEmpty
                          ? _orsRoute.first
                          : _driverLocation,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _startDriverDrag,
                        onPanUpdate: _updateDriverDrag,
                        onPanEnd: _endDriverDrag,
                        child: _DriverMarker(
                          isActive: true,
                          rotation: _driverBearing,
                        ),
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
                    ..._tripStops.map(
                      (stop) => Marker(
                        width: 42,
                        height: 48,
                        point: stop.location,
                        child: _TripStopMarker(
                          sequence: stop.sequence,
                          propertyType: stop.propertyType,
                          isCollected: stop.isCollected,
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
            top: mapControlsTop,
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
                    onPressed: _centerOnDriver,
                    tooltip: 'Center on me',
                  ),
                  const SizedBox(height: 8),
                  // Fit the whole route in view — quick way to see all
                  // remaining stops at a glance.
                  _MapButton(
                    icon: Icons.zoom_out_map_rounded,
                    onPressed: _recenterNavigation,
                    tooltip: 'Fit route',
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.add_rounded,
                    onPressed: () => _zoomBy(1),
                    tooltip: 'Zoom in',
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.remove_rounded,
                    onPressed: () => _zoomBy(-1),
                    tooltip: 'Zoom out',
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
                  if (_manualDriverOverride) ...[
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.gps_fixed_rounded,
                      onPressed: _resetDriverLocation,
                      tooltip: 'Reset GPS',
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Next collection point — the only card overlaid on the map (the
          // daily-assignment carousel was removed for a cleaner view).
          if (nextCustomer != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _NextCollectionPointCard(
                customer: nextCustomer,
                distance: _getDistanceToCustomer(nextCustomer),
                position:
                    nextCustomerPosition >= 0 ? nextCustomerPosition + 1 : 1,
                total: widget.customers.length,
                onNavigate: () => _startNavigation(nextCustomer.id),
              ),
            ),

          // Navigation header
          if (navigationCustomer != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _NavigationHeader(
                customer: navigationCustomer,
                distance: _getDistanceToCustomer(navigationCustomer),
                onStop: _stopNavigation,
              ),
            ),

          // Navigation action tray
          // Navigation action tray
if (navigationCustomer != null)
  Positioned(
    left: 0,
    right: 0,
    bottom: bottomOverlayOffset,
    child: AnimatedContainer(
      duration: _kNavigationTransitionDuration,
      curve: Curves.easeInOut,
      height: 120,
      child: _NavigationActionCard(
        customer: navigationCustomer,
        distance: _getDistanceToCustomer(navigationCustomer),
        onComplete: () => _handleCollect(navigationCustomer),
        onSkip: () => _handleSkip(navigationCustomer),
      ),
    ),
  ),

          // Bottom customer carousel - compact design
          // Positioned(
          //   left: 0,
          //   right: 0,
          //   bottom: bottomOverlayOffset,
          //   child: AnimatedContainer(
          //     duration: _kNavigationTransitionDuration,
          //     curve: Curves.easeInOut,
          //     height: isNavigating ? 0 : 140,
          //     child: widget.loading
          //         ? const Center(child: CircularProgressIndicator())
          //         : widget.error != null
          //             ? Center(
          //                 child: Text(
          //                   widget.error!,
          //                   style: const TextStyle(
          //                     color: Colors.red,
          //                     fontWeight: FontWeight.w700,
          //                   ),
          //                 ),
          //               )
          //             : _customers.isEmpty
          //                 ? const Center(
          //                     child: Text(
          //                       'All customers completed!',
          //                       style: TextStyle(
          //                         fontSize: 16,
          //                         fontWeight: FontWeight.w700,
          //                         color: Colors.green,
          //                       ),
          //                     ),
          //                   )
          //                 : ListView.separated(
          //                     padding:
          //                         const EdgeInsets.symmetric(horizontal: 16),
          //                     scrollDirection: Axis.horizontal,
          //                     itemBuilder: (context, index) {
          //                       final customer = _customers[index];
          //                       return _CustomerCard(
          //                         customer: customer,
          //                         distance: _getDistanceToCustomer(customer),
          //                         onComplete: () => _handleCollect(customer),
          //                         onSkip: () => _handleSkip(customer),
          //                         onStart: () => _startNavigation(customer.id),
          //                         onOpenAssignment: () =>
          //                             _openAssignmentScreen(customer),
          //                       );
          //                     },
          //                     separatorBuilder: (_, __) =>
          //                         const SizedBox(width: 10),
          //                     itemCount: _customers.length,
          //                   ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _NextCollectionPointCard extends StatelessWidget {
  const _NextCollectionPointCard({
    required this.customer,
    required this.distance,
    required this.position,
    required this.total,
    required this.onNavigate,
  });

  final _DriverAssignmentStop customer;
  final String distance;
  final int position;
  final int total;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return CaptainGlassCard(
      onTap: onNavigate,
      tint: CaptainTheme.gold,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: CaptainTheme.accentGradient,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Text(
              position.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded,
                        size: 12, color: CaptainTheme.gold),
                    const SizedBox(width: 4),
                    Text(
                      'NEXT COLLECTION POINT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CaptainTheme.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CaptainTheme.strongText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total > 0 ? 'Stop $position of $total' : 'Ready for route',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CaptainTheme.mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: CaptainTheme.accentSoft,
              borderRadius: CaptainTheme.chipRadius,
              border: Border.all(
                color: CaptainTheme.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distance,
                  style: TextStyle(
                    color: CaptainTheme.accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'away',
                  style: TextStyle(
                    color: CaptainTheme.accent.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

// ============================================================
// PART 4: NavigationHeader, Cards, History, Profile, and Markers
// ============================================================

class _NavigationHeader extends StatelessWidget {
  const _NavigationHeader({
    required this.customer,
    required this.distance,
    required this.onStop,
  });

  final _DriverAssignmentStop customer;
  final String distance;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CaptainGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CaptainGlassChip(
                  icon: Icons.navigation_rounded,
                  color: CaptainTheme.accent,
                  size: 20,
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
                          color: CaptainTheme.accent,
                        ),
                      ),
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CaptainTheme.strongText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close_rounded,
                          color: CaptainTheme.mutedText, size: 18),
                      onPressed: onStop,
                      tooltip: 'Stop navigation',
                    ),
                  ),
                ),
              ],
            ),
            if (customer.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: CaptainTheme.mutedText),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customer.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: CaptainTheme.mutedText,
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
      ),
    );
  }
}

class _NavigationActionCard extends StatelessWidget {
  const _NavigationActionCard({
    required this.customer,
    required this.distance,
    required this.onComplete,
    required this.onSkip,
  });

  final _DriverAssignmentStop customer;
  final String distance;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final displayName = customer.customerName?.trim().isNotEmpty == true
        ? customer.customerName!
        : customer.wardName;
    final isDone = customer.status == _CustomerStatus.collected ||
        customer.status == _CustomerStatus.skipped;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CaptainGlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: CaptainTheme.accentGradient,
              ),
              alignment: Alignment.center,
              child: Text(
                displayName[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: CaptainTheme.strongText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distance,
                    style: TextStyle(
                      color: CaptainTheme.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.shift.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: CaptainTheme.mutedText.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isDone ? null : onComplete,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: isDone
                          ? CaptainTheme.mutedText.withValues(alpha: 0.3)
                          : CaptainTheme.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDone ? CaptainTheme.mutedText : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: isDone ? null : onSkip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: BorderSide(
                        color: CaptainTheme.hairline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: CaptainTheme.strongText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    required this.onOpenAssignment,
  });

  final _DriverAssignmentStop customer;
  final String distance;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onStart;
  final VoidCallback onOpenAssignment;

  Color get _statusColor {
    switch (customer.status) {
      case _CustomerStatus.collected:
        return Colors.green;
      case _CustomerStatus.skipped:
        return Colors.orange;
      case _CustomerStatus.later:
        return Colors.deepOrange;
      case _CustomerStatus.navigating:
        return Colors.blue;
      case _CustomerStatus.pending:
        return Colors.red;
    }
  }

  Color get _assignmentBg {
    switch (customer.assignmentType.toLowerCase()) {
      case 'emergency':
        return Colors.red.shade100;
      case 'temporary':
        return Colors.orange.shade100;
      default:
        return Colors.green.shade100;
    }
  }

  Color get _assignmentFg {
    switch (customer.assignmentType.toLowerCase()) {
      case 'emergency':
        return Colors.red.shade700;
      case 'temporary':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = customer.customerName?.trim().isNotEmpty == true
        ? customer.customerName!
        : customer.wardName;
    final isDone = customer.status == _CustomerStatus.collected ||
        customer.status == _CustomerStatus.skipped;

    return SizedBox(
      width: 240,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpenAssignment,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= HEADER =================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _statusColor.withOpacity(0.15),
                      child: Text(
                        displayName[0].toUpperCase(),
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
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
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

                    // ===== ASSIGNMENT TYPE BADGE =====
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _assignmentBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        customer.assignmentType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _assignmentFg,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ================= ACTION BUTTONS =================
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: isDone ? null : onComplete,
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
                          onPressed: isDone ? null : onSkip,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Skip',
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

                // ================= NAVIGATE =================
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed:
                        isDone || customer.status == _CustomerStatus.navigating
                            ? null
                            : onStart,
                    icon: const Icon(Icons.navigation_rounded, size: 13),
                    label: const Text(
                      'Navigate',
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
      ),
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({
    required this.currentAssignments,
    required this.historyAssignments,
    required this.activeTripDetail,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final List<OperatorTripHistorySummary> currentAssignments;
  final List<OperatorTripHistorySummary> historyAssignments;
  final OperatorTripHistoryDetail? activeTripDetail;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _AssignmentsErrorState(
        message: error!,
        onRetry: () => onRefresh(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssignmentsHeader(
            currentCount: currentAssignments.length,
            historyCount: historyAssignments.length,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: TabBar(
              labelColor: OperatorTheme.primary,
              unselectedLabelColor: OperatorTheme.mutedText,
              indicatorColor: OperatorTheme.primary,
              tabs: [
                Tab(text: 'Current Trip'),
                Tab(text: 'History'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DriverCurrentTripTab(
                  detail: activeTripDetail,
                  fallbackTrips: currentAssignments,
                  onRefresh: onRefresh,
                ),
                _DriverTripHistoryTab(
                  assignments: historyAssignments,
                  onRefresh: onRefresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCurrentTripTab extends StatelessWidget {
  const _DriverCurrentTripTab({
    required this.detail,
    required this.fallbackTrips,
    required this.onRefresh,
  });

  final OperatorTripHistoryDetail? detail;
  final List<OperatorTripHistorySummary> fallbackTrips;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = detail?.summary ??
        (fallbackTrips.isNotEmpty ? fallbackTrips.first : null);

    return RefreshIndicator(
      color: OperatorTheme.accent,
      onRefresh: onRefresh,
      child: summary == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 140),
              children: const [
                _DriverEmptyAssignmentMessage(
                  icon: Icons.route_rounded,
                  message: 'No current trip assigned.',
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              children: [
                OperatorTripSummaryCard(
                  trip: summary,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Collection Points',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: OperatorTheme.strongText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${detail?.collectionPoints.length ?? 0}',
                      style: TextStyle(
                        color: OperatorTheme.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (detail == null || detail!.collectionPoints.isEmpty)
                  const _DriverEmptyAssignmentMessage(
                    icon: Icons.location_off_rounded,
                    message: 'No collection points found for this trip.',
                  )
                else
                  ...detail!.collectionPoints.map(
                    (cp) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OperatorCpCard(cp: cp),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DriverTripHistoryTab extends StatelessWidget {
  const _DriverTripHistoryTab({
    required this.assignments,
    required this.onRefresh,
  });

  final List<OperatorTripHistorySummary> assignments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: OperatorTheme.accent,
      onRefresh: onRefresh,
      child: assignments.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 140),
              children: const [
                _DriverEmptyAssignmentMessage(
                  icon: Icons.history_toggle_off_rounded,
                  message: 'No completed trips yet.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              itemCount: assignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trip = assignments[index];
                return OperatorTripSummaryCard(
                  trip: trip,
                );
              },
            ),
    );
  }
}

class _DriverEmptyAssignmentMessage extends StatelessWidget {
  const _DriverEmptyAssignmentMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: OperatorTheme.mutedText, size: 46),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: OperatorTheme.mutedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AssignmentsHeader extends StatelessWidget {
  const _AssignmentsHeader({
    required this.currentCount,
    required this.historyCount,
  });

  final int currentCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Text(
            AppCopy.driverAssignments,
            style: TextStyle(
              color: OperatorTheme.strongText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _CountChip(
            label: AppCopy.driverCurrent,
            count: currentCount,
            color: OperatorTheme.primary,
          ),
          const SizedBox(width: 8),
          _CountChip(
            label: AppCopy.driverHistory,
            count: historyCount,
            color: OperatorTheme.mutedText,
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AssignmentsErrorState extends StatelessWidget {
  const _AssignmentsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: OperatorTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentScreen extends StatefulWidget {
  const _AssignmentScreen({
    required this.wardName,
    required this.customers,
    required this.onCollect,
    required this.onLater,
    required this.onSkip,
  });

  final String wardName;
  final List<_DriverAssignmentStop> customers;
  final Future<void> Function(_DriverAssignmentStop customer) onCollect;
  final void Function(_DriverAssignmentStop customer) onLater;
  final Future<void> Function(_DriverAssignmentStop customer) onSkip;

  @override
  State<_AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<_AssignmentScreen> {
  @override
  Widget build(BuildContext context) {
    final title = widget.wardName.isNotEmpty ? widget.wardName : 'Assignment';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final customer = widget.customers[index];
          final displayName = customer.customerName?.trim().isNotEmpty == true
              ? customer.customerName!
              : customer.wardName;
          final isDone = customer.status == _CustomerStatus.collected ||
              customer.status == _CustomerStatus.skipped;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shift: ${customer.shift.replaceAll('_', ' ').toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (customer.customerName == null ||
                    customer.customerName!.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ward: ${customer.wardName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isDone
                            ? null
                            : () async {
                                await widget.onCollect(customer);
                                if (mounted) setState(() {});
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Collect'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onLater(customer);
                          setState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDone
                            ? null
                            : () async {
                                await widget.onSkip(customer);
                                if (mounted) setState(() {});
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
                if (customer.status == _CustomerStatus.skipped &&
                    customer.skipReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${customer.skipReason}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (customer.status == _CustomerStatus.later) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Marked for later',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepOrange.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
    return CaptainBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile card
            CaptainGlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: CaptainTheme.accentGradient,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.person_rounded,
                        size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    driverName.isEmpty ? 'Captain' : driverName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CaptainTheme.strongText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: $empId',
                    style: TextStyle(
                      fontSize: 11,
                      color: CaptainTheme.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Vehicle card
            if (vehicle != null)
              CaptainGlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping_rounded,
                            size: 18, color: CaptainTheme.accent),
                        const SizedBox(width: 8),
                        Text(
                          'VEHICLE',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: CaptainTheme.mutedText,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SimpleRow(
                      'Number',
                      vehicle!.vehicleNumber ?? '—',
                    ),
                    const SizedBox(height: 8),
                    _SimpleRow(
                      'Type',
                      vehicle!.vehicleType ?? '—',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SimpleRow(
                            'Status',
                            (vehicle!.status ?? '').trim().isNotEmpty
                                ? vehicle!.status!
                                : '—',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (vehicle!.status ?? '')
                                        .toLowerCase() ==
                                    'running'
                                ? CaptainTheme.success
                                : CaptainTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (vehicle != null) const SizedBox(height: 18),

            // Theme toggle
            CaptainGlassCard(
              padding: const EdgeInsets.all(14),
              child: ValueListenableBuilder<bool>(
                valueListenable: CaptainThemeStore.isDark,
                builder: (context, isDark, _) {
                  return Row(
                    children: [
                      Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        size: 18,
                        color: CaptainTheme.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Theme',
                          style: TextStyle(
                            fontSize: 13,
                            color: CaptainTheme.strongText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        isDark ? 'Dark' : 'Light',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: CaptainTheme.mutedText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Switch(
                        value: isDark,
                        activeColor: CaptainTheme.accent,
                        onChanged: (value) =>
                            CaptainThemeStore.setDark(value),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CaptainTheme.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: CaptainTheme.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: CaptainTheme.strongText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

class _TripStopMarker extends StatelessWidget {
  const _TripStopMarker({
    required this.sequence,
    required this.propertyType,
    required this.isCollected,
  });

  final int sequence;
  final String propertyType;
  final bool isCollected;

  Color _colorForType() {
    switch (propertyType.toLowerCase()) {
      case 'industry':
        return const Color(0xFFFB8C00);
      case 'commercial':
        return const Color(0xFF6D4C41);
      case 'house':
      default:
        return const Color(0xFF00897B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType();
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ColorFiltered(
          colorFilter: isCollected
              ? const ColorFilter.mode(Colors.green, BlendMode.modulate)
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Image.asset(
            'assets/icons/pin.png',
            width: 36,
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          top: 5,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCollected ? Colors.green.shade700 : color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              sequence.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
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
      color: CaptainTheme.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: CaptainTheme.hairline),
          boxShadow: CaptainTheme.softShadow,
        ),
        child: IconButton(
          icon: Icon(icon, color: CaptainTheme.accent),
          onPressed: onPressed,
          tooltip: tooltip,
        ),
      ),
    );
  }
}
