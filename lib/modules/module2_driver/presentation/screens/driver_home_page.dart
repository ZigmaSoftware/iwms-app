import 'dart:convert';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/attendance/attendance_driver.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/profile.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_attendance_screen_integration.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:latlong2/latlong.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:path/path.dart';

import '../../../../core/di.dart';
import '../../../../core/geofence_config.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';
import '../../../../logic/vehicle_tracking/vehicle_bloc.dart';
import '../../../../logic/vehicle_tracking/vehicle_event.dart';
import '../../../../router/app_router.dart';
import 'package:iwms_citizen_app/shared/widgets/tracking_view_shell.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';

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

enum _DriverTab { home, history, profile, attendance }

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

  final List<LatLng> _routePoints =
      _demoStops.map((stop) => stop.location).toList();
 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centerOnDriver(GammaGeofenceConfig.center));
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
        OperatorSessionDetails? _sessionDetails;
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
            final origin = driverLocation;
            return Scaffold(
              backgroundColor: const Color(0xFFF0F6F1),
              body: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        // _DriverHeader(
                        //   key: ValueKey<_DriverTab>(_activeTab),
                        //   title: _headerTitle(_activeTab),
                        //   subtitle: _headerSubtitle(_activeTab),
                        //   activeTab: _activeTab,
                        //   routeStops: _routePoints.length,
                        //   onLogoutTapped: () => _logout(context),
                        //   speed: selectedVehicle?.speedKmh,
                        //   fuel: selectedVehicle?.fuelLevel,
                        //   distance: selectedVehicle?.distanceKm,
                        // ),
                        AnimatedSwitcher(
  duration: Duration(milliseconds: 250),
  child: _DriverHeader(
    key: ValueKey(_activeTab),
    title: _headerTitle(_activeTab),
    subtitle: _headerSubtitle(_activeTab),
    activeTab: _activeTab,
    routeStops: _routePoints.length,
    onLogoutTapped: () => _logout(context),
    speed: selectedVehicle?.speedKmh,
    fuel: selectedVehicle?.fuelLevel,
    distance: selectedVehicle?.distanceKm,
  ),
),

                        Expanded(
                          child: PageTransitionSwitcher(
                            duration: const Duration(milliseconds: 320),
                            transitionBuilder: (
                              child,
                              animation,
                              secondaryAnimation,
                            ) {
                              return SharedAxisTransition(
                                animation: animation,
                                secondaryAnimation: secondaryAnimation,
                                transitionType:
                                    SharedAxisTransitionType.horizontal,
                                child: child,
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey<_DriverTab>(_activeTab),
                              child: _buildTab(_activeTab, driverLocation, nameFromState!, empIdFromState!,_sessionDetails),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _StartButtonOverlay(
                      visible: _activeTab == _DriverTab.home,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _FullMapPage(
                              origin: origin,
                              routePoints: _routePoints,
                              stops: _demoStops,
                              vehicle: selectedVehicle,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: MotionTabBar(
                  labels: const ['Home', 'History', 'Profile','Attendance'],
                  icons: const [
                    Icons.home_rounded,
                    Icons.history_rounded,
                    Icons.person_outline_rounded,
                    Icons.face
                  ],
                  initialSelectedTab: _tabLabel(_activeTab),
                  tabBarColor: Colors.white,
                  tabSelectedColor: _driverPrimary,
                  tabIconColor: Colors.black54,
                  tabBarHeight: 66,
                  tabSize: 52,
                  tabIconSize: 24,
                  tabIconSelectedSize: 24,
                  onTabItemSelected: (value) {
                    final tab = value is String
                        ? _tabFromLabel(value)
                        : value is int
                            ? _tabFromIndex(value)
                            : null;
                    if (tab != null && tab != _activeTab) {
                      setState(() => _activeTab = tab);
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTab(_DriverTab tab, LatLng driverLocation,String nameFromState,
  String empIdFromState,OperatorSessionDetails? _sessionDetails) {
    //   OperatorSessionDetails? _sessionDetails;
    //     final nameFromState = context.select<AuthBloc, String?>((bloc) =>
    //     bloc.state is AuthStateAuthenticated
    //         ? (bloc.state as AuthStateAuthenticated).userName
    //         : null);
    //          final emp_idFromState = context.select<AuthBloc, String?>((bloc) =>
    //     bloc.state is AuthStateAuthenticated
    //         ? (bloc.state as AuthStateAuthenticated).emp_id
    //         : null);
  
    switch (tab) {
      case _DriverTab.home:
        return _HomeTab(
          mapController: _mapController,
          driverLocation: driverLocation,
          routePoints: _routePoints,
          onCenter: () => _centerOnDriver(driverLocation),
          stops: _demoStops,
        );
      case _DriverTab.history:
        return const _HistoryTab();
      case _DriverTab.profile:
        return _ProfileTab(onLogout: () => _logout(context as BuildContext));
      case _DriverTab.attendance:
        return  AttendancePageDriver(
          operatorName:nameFromState,
          operatorCode: empIdFromState,
        );
    }
  }

  String _tabLabel(_DriverTab tab) {
    switch (tab) {
      case _DriverTab.home:
        return 'Home';
      case _DriverTab.history:
        return 'History';
      case _DriverTab.profile:
        return 'Profile';
      case _DriverTab.attendance:
        return 'Attendance';

    }
  }

  _DriverTab _tabFromLabel(String label) {
    switch (label) {
      case 'History':
        return _DriverTab.history;
      case 'Profile':
        return _DriverTab.profile;
       case 'Attendance':
        return _DriverTab.attendance;
      case 'Home':
      default:
        return _DriverTab.home;
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

  String _headerTitle(_DriverTab tab) {
    switch (tab) {
      case _DriverTab.history:
        return 'Trip history';
      case _DriverTab.profile:
        return 'Driver profile';
      case _DriverTab.attendance:
        return 'Driver Attendance';
      case _DriverTab.home:
      default:
        return 'Driver Console';
    }
  }

  String _headerSubtitle(_DriverTab tab) {
    switch (tab) {
      case _DriverTab.history:
        return 'Recent collection runs';
      case _DriverTab.profile:
        return 'Your shift, vehicle, and contact';
      case _DriverTab.attendance:
        return "Manage today's presence and history";
      case _DriverTab.home:
      default:
        return 'Live stats - Keep moving safely';
    }
  }

  void _logout(BuildContext context) {
    if (!mounted) return;
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }

}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    super.key,
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
    final bool showStats =
    activeTab != _DriverTab.profile &&
    activeTab != _DriverTab.attendance;

 
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
                // Row(
                //   children: [
                //     Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         Text(
                //           title,
                //           style: const TextStyle(
                //             color: Colors.white,
                //             fontSize: 22,
                //             fontWeight: FontWeight.w800,
                //             letterSpacing: 0.4,
                //           ),
                //         ),
                //         const SizedBox(height: 2),
                //         Text(
                //           subtitle,
                //           style: const TextStyle(
                //             color: Colors.white70,
                //             fontSize: 13,
                //           ),
                //         ),
                //       ],
                //     ),
                //     const Spacer(),
                //     IconButton(
                //       onPressed: onLogoutTapped,
                //       icon: const Icon(Icons.power_settings_new_rounded,
                //           color: Colors.white),
                //       tooltip: 'Logout',
                //     ),
                //   ],
                // ),
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

    // If Attendance → show avatar instead of logout
    if (activeTab == _DriverTab.attendance)
      Builder(
        builder: (context) {
          final empId = context.select<AuthBloc, String?>(
            (bloc) => bloc.state is AuthStateAuthenticated
                ? (bloc.state as AuthStateAuthenticated).emp_id
                : null,
          );

          return DriverAvatar(empId: empId!);
        },
      )
    else
      IconButton(
        onPressed: onLogoutTapped,
        icon: const Icon(
          Icons.power_settings_new_rounded,
          color: Colors.white,
        ),
        tooltip: 'Logout',
      ),
  ],
),

                AnimatedSwitcher(
                  duration: _kHeaderTransitionDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                child: _buildStatsContent(context, showStats),

                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

//   Widget _buildStatsContent(bool showStats) {
//     if (!showStats) {
//       return const SizedBox(
//         key: ValueKey('header-no-stats'),
//         height: 0,
//       );
//     }

//     if (activeTab == _DriverTab.history) {
//       return _HistoryDistanceCard(
//         key: const ValueKey('header-history-distance'),
//         stops: routeStops,
//       );
//     }

//     return _HeaderStatsRow(
//       key: const ValueKey('header-stats-row'),
//       speed: speed,
//       fuel: fuel,
//       distance: distance,
//     );
//   }
// }

Widget _buildStatsContent(BuildContext context, bool showStats) {
  // Case: Profile → No stats, no avatar
  if (activeTab == _DriverTab.profile) {
    return const SizedBox(key: ValueKey('header-profile'), height: 0);
  }

  // Case: Attendance → Show avatar only
 if (activeTab == _DriverTab.attendance) {
  final empId = context.select<AuthBloc, String?>(
    (bloc) => bloc.state is AuthStateAuthenticated
        ? (bloc.state as AuthStateAuthenticated).emp_id
        : null,
  );

  return const SizedBox(key: ValueKey('header-profile'), height: 0);
}

  // Case: History → show distance card
  if (activeTab == _DriverTab.history) {
    return _HistoryDistanceCard(
      key: const ValueKey('header-history-distance'),
      stops: routeStops,
    );
  }

  // Case: Home → normal stats
  return _HeaderStatsRow(
    key: const ValueKey('header-stats-row'),
    speed: speed,
    fuel: fuel,
    distance: distance,
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

  // String convertToUrl(String path) {  
  //   final filename = path.split("\\").last;
  //   return "http://10.164.86.186:8000/media/$filename";
  // }
String convertToUrl(String path) {
  // Normalize slashes for Windows/Linux
  final clean = path.replaceAll("\\", "/");

  // Extract only the filename
  final filename = clean.split("/").last;

  // Construct proper media URL
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

        fetchEmployeeImage(); // Refresh after returning
      },
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        backgroundImage:
            (hasProfile && imageName != null) ? NetworkImage(convertToUrl(imageName!)) : null,
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

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.mapController,
    required this.driverLocation,
    required this.routePoints,
    required this.onCenter,
    required this.stops,
  });

  final MapController mapController;
  final LatLng driverLocation;
  final List<LatLng> routePoints;
  final VoidCallback onCenter;
  final List<_DemoStop> stops;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MapCard(
            mapController: mapController,
            driverLocation: driverLocation,
            routePoints: routePoints,
            onCenter: onCenter,
            stops: stops,
          ),
          const SizedBox(height: 16),
          _RecentHistorySection(entries: _weeklyHistory),
        ],
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
    required this.onCenter,
    required this.stops,
  });

  final MapController mapController;
  final LatLng driverLocation;
  final List<LatLng> routePoints;
  final VoidCallback onCenter;
  final List<_DemoStop> stops;

  @override
  Widget build(BuildContext context) {
    final routeLinePoints = <LatLng>[driverLocation, ...routePoints];
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
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
                          userAgentPackageName: 'com.iwms.citizen.app',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routeLinePoints,
                              color: _driverPrimary.withOpacity(0.7),
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 42,
                              height: 42,
                              point: driverLocation,
                              child: _DriverMarker(isActive: true),
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
                            final zoom = mapController.camera.zoom + 0.6;
                            mapController.move(
                                mapController.camera.center, zoom);
                          },
                        ),
                        const SizedBox(height: 10),
                        _CircleIconButton(
                          icon: Icons.zoom_out_rounded,
                          onPressed: () {
                            final zoom = mapController.camera.zoom - 0.6;
                            mapController.move(
                                mapController.camera.center, zoom);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: _NextStopSummary(
                  stop: stops.isNotEmpty ? stops.first : null,
                  remainingStops: stops.isNotEmpty ? stops.length - 1 : 0,
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
  const _DriverMarker({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: isActive ? _driverPrimary : Colors.white,
        border: Border.all(
          color: isActive ? Colors.white : _driverPrimary.withOpacity(0.6),
          width: 2,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        isActive ? Icons.navigation_rounded : Icons.location_on_outlined,
        color: isActive ? Colors.white : _driverPrimary,
        size: isActive ? 20 : 18,
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

  void _setTheme(_DriverMapThemeOption option) {
    if (_selectedTheme == option) return;
    setState(() => _selectedTheme = option);
  }

  @override
  Widget build(BuildContext context) {
    final routeLinePoints = <LatLng>[widget.origin, ...widget.routePoints];
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
                contextLabel: liveVehicle?.registrationNumber ?? 'Trip tracking',
                headline: headline,
                statusPrimary:
                    liveVehicle?.lastUpdated ?? 'Awaiting telemetry update',
                statusSecondary: statusSecondary,
                statusContent: headerStatusContent,
                onBack: () => Navigator.of(context).maybePop(),
                onRefresh: () => _mapController.move(widget.origin, 15),
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
                              if (widget.routePoints.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: routeLinePoints,
                                      color: _driverPrimary.withOpacity(0.8),
                                      strokeWidth: 4.5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    width: 44,
                                    height: 44,
                                    point: widget.origin,
                                    child:
                                        const _DriverMarker(isActive: true),
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
                                                    _mapController
                                                        .camera.zoom),
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
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _weeklyHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = _weeklyHistory[index];
        return _HistoryCard(entry: entry);
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
                color:
                    isSelected ? Colors.white : theme.colorScheme.onSurface,
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
                children: [
                  const Text(
                    'Total Collected :',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ' Kg',
                    style: const TextStyle(
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
                    children: [
                      Text(
                        ' Kg',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Dry',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.65),
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
                    children: [
                      Text(
                        ' Kg',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Wet',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.65),
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