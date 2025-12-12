
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';


import 'attendancehistory.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_home_page.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendance_home_operator.dart';

class HomePage1 extends StatefulWidget {
  final String empid;
  final String userName;

  const HomePage1({
    required this.empid,
    required this.userName,
    super.key,
  });

  @override
  State<HomePage1> createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1> {
  int _activeTab = 1; // Default to Overview

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _checkPermissionsAndGps();

    _pages = [
      OperatorHomePage(),
      AttendancePage(),
      AttendanceHistory(empId: widget.empid),
    ];
  }

  Future<void> _checkPermissionsAndGps() async {
    final status = await Permission.location.status;
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();

    if (!status.isGranted || !gpsEnabled) {
      _showLogoutPopup();
    }
  }

  void _showLogoutPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text("Location Required"),
        content: Text(
          "Location permission or GPS is disabled. You will be logged out.",
        ),
        actions: [
          TextButton(
            onPressed: () => _logout(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    context.push("/login");
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final tabLabels = [
      localizations.attendanceTabHome,
      localizations.attendanceTabMarkAttendance,
      localizations.attendanceTabSummary,
    ];
    return Scaffold(
      body: _pages[_activeTab],

      bottomNavigationBar: SafeArea(
        child: KeyedSubtree(
          key: ValueKey(tabLabels.join('-')),
          child: MotionTabBar(
            labels: tabLabels,
            icons: const [
              Icons.home_outlined,
              Icons.face_2_outlined,
              Icons.summarize,
            ],

            initialSelectedTab: tabLabels[_activeTab],

            tabBarColor: Colors.white,
            tabSelectedColor: const Color(0xFF1B5E20), // Strong operator green
            tabIconColor: Colors.black54,

            tabBarHeight: 64,
            tabSize: 52,
            tabIconSize: 22,
            tabIconSelectedSize: 26,

            onTabItemSelected: (dynamic value) {
              int? index;
              if (value is int) {
                index = value;
              } else if (value is String) {
                index = tabLabels.indexOf(value);
              }
              if (index == null || index < 0 || index >= tabLabels.length) {
                return;
              }

              final resolvedIndex = index;
              if (resolvedIndex == 0) {
                context.go("/operator-home");
              } else if (resolvedIndex == 2) {
                // Dedicated navigation to history/summary
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AttendanceHistory(empId: widget.empid),
                  ),
                );
                setState(() => _activeTab = 2);
              } else {
                setState(() => _activeTab = resolvedIndex);
              }
            },
          ),
        ),
      ),
    );
  }
}
