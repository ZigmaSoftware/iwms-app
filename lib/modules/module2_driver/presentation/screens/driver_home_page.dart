// ============================================================
// PART 1: Imports, Constants, Enums, and Main Widget Classes
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dynamic_tabbar/dynamic_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:animations/animations.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di.dart';
import '../../../../core/geofence_config.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_service.dart';
import '../../../../logic/vehicle_tracking/vehicle_bloc.dart';
import '../../../../logic/vehicle_tracking/vehicle_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/ors_service.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/attendance/attendance_driver.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/profile.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _driverPrimary = Color(0xFF1B5E20);
const Color _driverAccent = Color(0xFF66BB6A);
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

  const _TripPlannedStop({
    required this.plannedStopId,
    required this.sequence,
    required this.location,
    required this.collectionPointId,
    required this.propertyType,
  });
}

enum _DriverTab { home, assignments, attendance, profile }

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  _DriverTab _activeTab = _DriverTab.home;
  late final AssignmentRepository _assignmentRepository;
  final MapController _mapController = MapController();
  List<_DriverAssignmentStop> _customers = [];
  List<_TripPlannedStop> _tripStops = [];
  List<LatLng> _tripPolyline = [];
  String? _activeTripId;
  String? _activeRoutePlanId;
  String? _activeVehicleType;
  List<DailyAssignmentModel> _currentAssignments = [];
  List<DailyAssignmentModel> _historyAssignments = [];
  bool _loadingCustomers = true;
  bool _loadingAssignments = true;
  bool _loadingTrip = false;
  String? _customerError;
  String? _assignmentError;
  String? _tripError;
  final Set<String> _notifiedAssignmentIds = {};
  final Set<String> _notifiedCancelledAssignmentIds = {};
  bool _notificationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerOnDriver(GammaGeofenceConfig.center),
    );
    _loadAssignmentsForDriver();
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
                        key: ValueKey(_activeTab),
                        activeTab: _activeTab,
                        onLogoutTapped: () => _logout(context),
                        empId: empIdFromState ?? '',
                        driverName: nameFromState ?? 'Driver',
                      ),
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
              bottomNavigationBar: SafeArea(
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _activeTab.index,
                  selectedItemColor: _driverPrimary,
                  unselectedItemColor: Colors.black54,
                  selectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w700),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500),
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
                      icon: Icon(Icons.assignment_rounded),
                      label: 'Assignments',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.event_available_rounded),
                      label: 'Attendance',
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
      // 🔹 GET AUTH STATE SAFELY
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

      final driverId = authState.userId.trim();

      if (driverId.isEmpty) {
        setState(() {
          _loadingCustomers = false;
          _loadingAssignments = false;
          _loadingTrip = false;
          _customerError = 'Missing driver id';
          _assignmentError = 'Missing driver id';
          _tripError = 'Missing driver id';
        });
        return;
      }

      final dio = await authorizedDio();
      await _loadTripRouteForDriver(driverId, dio: dio);

      final today = DateTime.now();
      final dateStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // 🔹 USE empId HERE
      final resp = await dio.get(
        "${ApiConfig.assignments}?date=$dateStr&driver_id=$driverId",
      );

      final List list =
          resp.data is List ? resp.data : (resp.data['results'] ?? []);
      final currentAssignments = list
          .whereType<Map>()
          .map(
            (entry) =>
                DailyAssignmentModel.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();

      await _loadNotifiedIds();

      _notifyNewAssignments(list);
      await _notifyCancelledAssignments(driverId, dateStr);

      final stops = <_DriverAssignmentStop>[];

      // Helper to decode customer list for a ward
      Future<void> hydrateWardCustomers({
        required String wardId,
        required Map m,
        required String assignmentId,
        required String assignmentType,
        required String shift,
        required bool isEmergency,
        required String emergencyCustomerId,
      }) async {
        List wardList = [];

        Future<void> fetchWithParam(String paramKey) async {
          final wardResp = await dio.get(
            ApiConfig.customerList,
            queryParameters: {paramKey: wardId},
          );
          final decoded = wardResp.data;
          wardList = decoded is List
              ? decoded
              : (decoded is Map ? (decoded['results'] ?? []) : []);
        }

        try {
          await fetchWithParam('ward');
          if (wardList.isEmpty) {
            await fetchWithParam('ward_id');
          }
        } catch (_) {
          // ignore, fall back below
        }

        wardList = wardList.where((entry) {
          if (entry is! Map) return false;
          final rawWard = entry['ward_id'] ?? entry['ward'];
          String? entryWardId;
          if (rawWard is Map) {
            entryWardId =
                (rawWard['unique_id'] ?? rawWard['id'] ?? rawWard['pk'])
                    ?.toString();
          } else if (rawWard != null) {
            entryWardId = rawWard.toString();
          }
          if (entryWardId == null || entryWardId != wardId) return false;
          if (isEmergency && emergencyCustomerId.isNotEmpty) {
            final entryId = (entry['unique_id'] ?? entry['customer_id'] ?? '')
                .toString();
            return entryId == emergencyCustomerId;
          }
          return true;
        }).toList();

        if (wardList.isEmpty) {
          stops.add(
            _DriverAssignmentStop(
              assignmentId: assignmentId,
              wardId: wardId,
              wardName: m['ward_name']?.toString() ?? 'Ward',
              customerName: m['customer_name'],
              assignmentType: assignmentType,
              shift: shift,
              location: GammaGeofenceConfig.center,
            ),
          );
          return;
        }

        for (final entry in wardList) {
          if (entry is! Map) continue;
          final pos = _safeLatLng(
                entry['latitude'] ?? entry['customer_latitude'],
                entry['longitude'] ?? entry['customer_longitude'],
              ) ??
              GammaGeofenceConfig.center;

          final customerId =
              (entry['unique_id'] ?? entry['customer_id'] ?? '').toString();
          final customerName =
              (entry['customer_name'] ?? entry['name'] ?? '').toString();

          final combinedId = customerId.isNotEmpty
              ? '$assignmentId-$customerId'
              : assignmentId;
          stops.add(
            _DriverAssignmentStop(
              assignmentId: combinedId,
              wardId: wardId,
              wardName: m['ward_name']?.toString() ?? 'Ward',
              customerName: customerName.isNotEmpty ? customerName : null,
              assignmentType: assignmentType,
              shift: shift,
              location: pos,
            ),
          );
        }
      }

      for (final m in list) {
        final assignmentId = (m['unique_id'] ?? '').toString();
        final wardId = (m['ward'] ?? '').toString();
        final assignmentType = m['assignment_type']?.toString() ?? 'primary';
        final shift = m['shift']?.toString() ?? 'full_day';
        final customerId = (m['customer'] ?? m['customer_id'] ?? '').toString();
        final isEmergency = assignmentType.toLowerCase() == 'emergency';

        final directPos =
            _safeLatLng(m['customer_latitude'], m['customer_longitude']);

        if (directPos != null) {
          final combinedId = customerId.isNotEmpty
              ? '$assignmentId-$customerId'
              : assignmentId;
          stops.add(
            _DriverAssignmentStop(
              assignmentId: combinedId,
              wardId: wardId.isNotEmpty ? wardId : null,
              wardName: m['ward_name']?.toString() ?? 'Ward',
              customerName: m['customer_name'],
              assignmentType: assignmentType,
              shift: shift,
              location: directPos,
            ),
          );
          continue;
        }

        // If assignment has no specific customer point, hydrate ward customers
        if (wardId.isNotEmpty) {
          await hydrateWardCustomers(
            wardId: wardId,
            m: m,
            assignmentId: assignmentId,
            assignmentType: assignmentType,
            shift: shift,
            isEmergency: isEmergency,
            emergencyCustomerId: customerId,
          );
        } else {
          // Fallback single stop at center
          final combinedId = customerId.isNotEmpty
              ? '$assignmentId-$customerId'
              : assignmentId;
          stops.add(
            _DriverAssignmentStop(
              assignmentId: combinedId,
              wardId: null,
              wardName: m['ward_name']?.toString() ?? 'Ward',
              customerName: m['customer_name'],
              assignmentType: assignmentType,
              shift: shift,
              location: GammaGeofenceConfig.center,
            ),
          );
        }
      }

      setState(() {
        _customers = stops;
        _currentAssignments = currentAssignments;
        _loadingCustomers = false;
      });

      await _loadAssignmentHistory(driverId);
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

  Future<void> _loadTripRouteForDriver(
    String driverId, {
    Dio? dio,
  }) async {
    try {
      final client = dio ?? await authorizedDio();
      final resp = await client.get(
        ApiConfig.tripDriverRoute,
        queryParameters: {'driver_id': driverId},
      );

      final data = resp.data;
      if (data is! Map) {
        setState(() {
          _tripStops = [];
          _tripPolyline = [];
          _activeTripId = null;
          _activeRoutePlanId = null;
          _loadingTrip = false;
        });
        return;
      }

      final trip = data['trip'] as Map?;
      final routePlan = data['route_plan'] as Map?;
      final geometry = data['route_geometry'] as Map?;
      final plannedStops = data['planned_stops'] is List
          ? data['planned_stops'] as List
          : const [];

      final stops = <_TripPlannedStop>[];
      for (final item in plannedStops) {
        if (item is! Map) continue;
        final lat = double.tryParse(item['latitude']?.toString() ?? '');
        final lng = double.tryParse(item['longitude']?.toString() ?? '');
        if (lat == null || lng == null) continue;
        final sequenceRaw = item['planned_sequence_number'] ?? item['sequence'];
        final sequence = int.tryParse(sequenceRaw?.toString() ?? '') ?? 0;
        final plannedStopId = (item['planned_stop_id'] ??
                item['planned_route_stop_id'] ??
                item['unique_id'] ??
                '')
            .toString();
        final pointId = (item['collection_point_id'] ?? '').toString();
        final propertyType = (item['property_type'] ?? '').toString();

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

      final encoded = geometry?['encoded_polyline'];
      List<LatLng> polyline = [];
      if (encoded is String && encoded.trim().isNotEmpty) {
        polyline = ORSService.decodePolyline(encoded.trim());
      }
      if (polyline.isEmpty && stops.isNotEmpty) {
        polyline = stops.map((s) => s.location).toList();
      }

      setState(() {
        _tripStops = stops;
        _tripPolyline = polyline;
        _activeTripId = trip?['unique_id']?.toString();
        _activeRoutePlanId = routePlan?['unique_id']?.toString();
        _activeVehicleType = routePlan?['vehicle_type']?.toString();
        _loadingTrip = false;
        _tripError = null;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        setState(() {
          _tripStops = [];
          _tripPolyline = [];
          _activeTripId = null;
          _activeRoutePlanId = null;
          _loadingTrip = false;
          _tripError = null;
        });
        return;
      }
      setState(() {
        _tripStops = [];
        _tripPolyline = [];
        _activeTripId = null;
        _activeRoutePlanId = null;
        _loadingTrip = false;
        _tripError = 'Failed to load trip route';
      });
    } catch (_) {
      setState(() {
        _tripStops = [];
        _tripPolyline = [];
        _activeTripId = null;
        _activeRoutePlanId = null;
        _loadingTrip = false;
        _tripError = 'Failed to load trip route';
      });
    }
  }

  Future<void> _loadAssignmentHistory(String driverId) async {
    try {
      final history =
          await _assignmentRepository.fetchAssignmentHistory(driverId: driverId);
      final completedHistory =
          history.where((assignment) => !assignment.isActive).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _historyAssignments = completedHistory;
        _loadingAssignments = false;
      });
    } catch (_) {
      setState(() {
        _historyAssignments = [];
        _loadingAssignments = false;
      });
    }
  }

  Future<void> _loadNotifiedIds() async {
    if (_notificationsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _notifiedAssignmentIds.addAll(
      prefs.getStringList('driver_notified_assignments') ?? <String>[],
    );
    _notifiedCancelledAssignmentIds.addAll(
      prefs.getStringList('driver_notified_cancelled_assignments') ??
          <String>[],
    );
    _notificationsLoaded = true;
  }

  Future<void> _saveNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'driver_notified_assignments',
      _notifiedAssignmentIds.toList(),
    );
    await prefs.setStringList(
      'driver_notified_cancelled_assignments',
      _notifiedCancelledAssignmentIds.toList(),
    );
  }

  void _notifyNewAssignments(List<dynamic> assignments) {
    final newAssignments = <String>[];

    for (final item in assignments) {
      if (item is! Map) continue;
      final id = item['unique_id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (_notifiedAssignmentIds.add(id)) {
        newAssignments.add(id);
      }
    }

    if (newAssignments.isEmpty) return;
    final notificationService = getIt<NotificationService>();
    final title =
        newAssignments.length == 1 ? 'New assignment' : 'New assignments';
    final message =
        'You have ${newAssignments.length} assignment(s) scheduled today.';
    notificationService.showAssignmentNotification(
      title: title,
      message: message,
    );
    _saveNotifiedIds();
  }

  Future<void> _notifyCancelledAssignments(
    String staffId,
    String dateStr,
  ) async {
    try {
      final dio = await authorizedDio();
      final resp = await dio.get(
        ApiConfig.staffAssignments,
        queryParameters: {
          'staff_id': staffId,
          'status': 'cancelled',
          'date_from': dateStr,
          'date_to': dateStr,
        },
      );

      final decoded = resp.data;
      final List list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);

      bool changed = false;
      for (final item in list) {
        if (item is! Map) continue;
        final id = item['unique_id']?.toString();
        if (id == null || id.isEmpty) continue;
        if (!_notifiedCancelledAssignmentIds.add(id)) continue;
        changed = true;

        final wardName = item['ward_name']?.toString() ?? 'Assignment';
        final reason =
            item['cancelled_reason']?.toString() ?? 'No reason provided';

        final notificationService = getIt<NotificationService>();
        notificationService.showAssignmentNotification(
          title: 'Assignment cancelled',
          message: '$wardName • $reason',
        );
      }
      if (changed) {
        await _saveNotifiedIds();
      }
    } catch (_) {
      // Ignore notification failures.
    }
  }

  LatLng? _safeLatLng(dynamic latRaw, dynamic lonRaw) {
    if (latRaw == null || lonRaw == null) return null;
    final lat = double.tryParse(latRaw.toString());
    final lon = double.tryParse(lonRaw.toString());
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
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
        return _HomeTab(
          mapController: _mapController,
          driverLocation: driverLocation,
          onCenter: () => _centerOnDriver(driverLocation),
          customers: _customers,
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
      case _DriverTab.assignments:
        return _AssignmentsTab(
          currentAssignments: _currentAssignments,
          historyAssignments: _historyAssignments,
          loading: _loadingAssignments,
          error: _assignmentError,
          onRefresh: _loadAssignmentsForDriver,
        );
      case _DriverTab.attendance:
        return AttendancePageDriver(
          operatorName: nameFromState,
          operatorCode: empIdFromState,
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
        return _DriverTab.assignments;
      case 2:
        return _DriverTab.attendance;
      case 3:
        return _DriverTab.profile;
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
      for (final c in _customers) {
        if (c.assignmentId == id) {
          c.status = status;
        }
      }
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
          "http://10.164.86.186:8000/api/desktop/staff-profile/?staff_id_id=${widget.empId}";

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
                      Icon(Icons.person_add_alt_1,
                          size: 26, color: Colors.green),
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
    required this.customers, // ✅ DECLARED
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
  String? _rerouteError;
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
    if (GammaGeofenceConfig.contains(location) ||
        GammaGeofenceConfig.isNear(location)) {
      return location;
    }
    return GammaGeofenceConfig.center;
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

    final nextCustomer = _customers.first;

    final bounds = LatLngBounds.fromPoints([
      _driverLocation,
      nextCustomer.location,
    ]);

    widget.mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
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
          padding: const EdgeInsets.all(80),
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
    final nextLocation =
        widget.mapController.camera.pointToLatLng(nextPoint);
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
    final ordered = stops
        .where((stop) => stop.plannedStopId.isNotEmpty)
        .toList();
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

    final needsRoad = _tripPolyline.isEmpty ||
        _tripPolyline.length <= _tripStops.length + 1;
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
      _rerouteError = null;
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

      final geometry =
          data is Map && data['route_geometry'] is Map ? data['route_geometry'] as Map : null;
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
      final sequenceChanged =
          newSequence.isNotEmpty && !_isSameSequence(newSequence, _lastActualSequence);

      setState(() {
        _tripStops = stops.isEmpty ? _tripStops : stops;
        _tripPolyline = polyline;
        _routePlanId = plan is Map ? plan['unique_id']?.toString() : _routePlanId;
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
          if (!mounted) return;
          setState(() {
            _rerouteError = 'Failed to log actual sequence';
          });
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
        _rerouteError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rerouting = false;
        _rerouteError = 'Reroute failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reroute failed'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _reportCompletion(_DriverAssignmentStop customer) async {
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
        return Colors.green;
      case _CustomerStatus.later:
        return Colors.deepOrange;
      case _CustomerStatus.skipped:
        return Colors.orange;
      case _CustomerStatus.navigating:
        return Colors.blue;
      case _CustomerStatus.pending:
        return Colors.red;
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
                if (_tripPolyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _tripPolyline,
                        color: Colors.deepOrangeAccent,
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
                        width: 34,
                        height: 34,
                        point: stop.location,
                        child: _TripStopMarker(
                          sequence: stop.sequence,
                          propertyType: stop.propertyType,
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
                    onPressed: _centerOnDriver,
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

          if (_tripStops.isNotEmpty || widget.tripLoading || widget.tripError != null)
            Positioned(
              top: 64,
              left: 12,
              right: 12,
              child: _TripRouteSummaryCard(
                tripId: _tripId ?? widget.activeTripId,
                routePlanId: _routePlanId ?? widget.activeRoutePlanId,
                stopCount: _tripStops.length,
                loading: widget.tripLoading || _rerouting,
                error: _rerouteError ?? widget.tripError,
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
          if (navigationCustomer != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final customer = _customers[index];
                                return _CustomerCard(
                                  customer: customer,
                                  distance: _getDistanceToCustomer(customer),
                                  onComplete: () => _handleCollect(customer),
                                  onSkip: () => _handleSkip(customer),
                                  onStart: () => _startNavigation(customer.id),
                                  onOpenAssignment: () =>
                                      _openAssignmentScreen(customer),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue.shade50,
            child: Text(
              displayName[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.blue.shade700,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  distance,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customer.shift.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Type: ${customer.assignmentType.toUpperCase()}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (customer.wardName.trim().isNotEmpty &&
                    customer.wardName.trim() != displayName.trim())
                  Text(
                    'Ward: ${customer.wardName}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: OutlinedButton(
                  onPressed: isDone ? null : onSkip,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
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

class _AssignmentsTab extends StatefulWidget {
  const _AssignmentsTab({
    required this.currentAssignments,
    required this.historyAssignments,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final List<DailyAssignmentModel> currentAssignments;
  final List<DailyAssignmentModel> historyAssignments;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> {
  bool _didSetInitialTab = false;

  List<TabData> _buildTabs() {
    return [
      TabData(
        index: 0,
        title: const Tab(text: 'Current'),
        content: _DriverAssignmentList(
          assignments: widget.currentAssignments,
          emptyTitle: 'No current assignments',
          emptySubtitle: 'You are all caught up for now.',
          onRefresh: widget.onRefresh,
        ),
      ),
      TabData(
        index: 1,
        title: const Tab(text: 'History'),
        content: _DriverAssignmentList(
          assignments: widget.historyAssignments,
          emptyTitle: 'No completed assignments',
          emptySubtitle: 'Completed assignments will appear here.',
          onRefresh: widget.onRefresh,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null) {
      return _AssignmentsErrorState(
        message: widget.error!,
        onRetry: () => widget.onRefresh(),
      );
    }

    return Column(
      children: [
        _AssignmentsHeader(
          currentCount: widget.currentAssignments.length,
          historyCount: widget.historyAssignments.length,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DynamicTabBarWidget(
            dynamicTabs: _buildTabs(),
            onTabControllerUpdated: (controller) {
              if (_didSetInitialTab || controller.length == 0) return;
              _didSetInitialTab = true;
              controller.animateTo(0);
            },
            onTabChanged: (_) => widget.onRefresh(),
            isScrollable: false,
            indicatorColor: _driverPrimary,
            labelColor: _driverPrimary,
            unselectedLabelColor: Colors.black54,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          const Text(
            'Assignments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          _CountChip(
            label: 'Current',
            count: currentCount,
            color: _driverPrimary,
          ),
          const SizedBox(width: 8),
          _CountChip(
            label: 'History',
            count: historyCount,
            color: Colors.grey.shade600,
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
              backgroundColor: _driverPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _DriverAssignmentList extends StatelessWidget {
  const _DriverAssignmentList({
    required this.assignments,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
  });

  final List<DailyAssignmentModel> assignments;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: assignments.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                Icon(Icons.assignment_rounded,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  emptyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  emptySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: assignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _DriverAssignmentCard(
                  assignment: assignments[index],
                );
              },
            ),
    );
  }
}

class _DriverAssignmentCard extends StatelessWidget {
  const _DriverAssignmentCard({
    required this.assignment,
  });

  final DailyAssignmentModel assignment;

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String? _statusTimestamp() {
    if (assignment.completedAt != null) {
      return 'Completed: ${_formatDate(assignment.completedAt!)}';
    }
    if (assignment.skippedAt != null) {
      return 'Skipped: ${_formatDate(assignment.skippedAt!)}';
    }
    if (assignment.cancelledAt != null) {
      return 'Cancelled: ${_formatDate(assignment.cancelledAt!)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusNote = _statusTimestamp();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.ward,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: assignment.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  assignment.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: assignment.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Shift: ${assignment.shiftDisplay} • ${assignment.typeDisplay}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Operator: ${assignment.operatorName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          if (assignment.customerName != null &&
              assignment.customerName!.trim().isNotEmpty)
            Text(
              'Citizen: ${assignment.customerName}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          if (statusNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                statusNote,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (assignment.skipReason != null &&
              assignment.skipReason!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Reason: ${assignment.skipReason}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    final title = widget.wardName.isNotEmpty
        ? widget.wardName
        : 'Assignment';

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
          final displayName =
              customer.customerName?.trim().isNotEmpty == true
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
                        onPressed:
                            isDone
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

class _TripStopMarker extends StatelessWidget {
  const _TripStopMarker({
    required this.sequence,
    required this.propertyType,
  });

  final int sequence;
  final String propertyType;

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
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        sequence.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TripRouteSummaryCard extends StatelessWidget {
  const _TripRouteSummaryCard({
    required this.tripId,
    required this.routePlanId,
    required this.stopCount,
    required this.loading,
    required this.error,
  });

  final String? tripId;
  final String? routePlanId;
  final int stopCount;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _buildContainer(
        child: Row(
          children: const [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading trip route...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return _buildContainer(
        child: Text(
          error!,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (tripId == null && stopCount == 0) {
      return const SizedBox.shrink();
    }

    return _buildContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Route Plan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trip: ${tripId ?? 'N/A'}',
            style: const TextStyle(fontSize: 12),
          ),
          if (routePlanId != null)
            Text(
              'Route Plan: $routePlanId',
              style: const TextStyle(fontSize: 12),
            ),
          Text(
            'Stops: $stopCount',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
