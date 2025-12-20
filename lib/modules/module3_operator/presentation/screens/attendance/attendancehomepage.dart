
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';


import 'attendancehistory.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_home_page.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendance_home_operator.dart';

// class HomePage1 extends StatefulWidget {
//   final String empid;
//   final String userName;

//   const HomePage1({
//     required this.empid,
//     required this.userName,
//     super.key,
//   });

//   @override
//   State<HomePage1> createState() => _HomePage1State();
// }

// class _HomePage1State extends State<HomePage1> {
//   int _activeTab = 1; // Default to Overview

//   late final List<Widget> _pages;

//   @override
//   void initState() {
//     super.initState();

//     _checkPermissionsAndGps();

//     _pages = [
//       OperatorHomePage(),
//       AttendancePage(),
//       AttendanceHistory(empId: widget.empid),
//     ];
//   }

//   Future<void> _checkPermissionsAndGps() async {
//     final status = await Permission.location.status;
//     final gpsEnabled = await Geolocator.isLocationServiceEnabled();

//     if (!status.isGranted || !gpsEnabled) {
//       _showLogoutPopup();
//     }
//   }

//   void _showLogoutPopup() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: Text("Location Required"),
//         content: Text(
//           "Location permission or GPS is disabled. You will be logged out.",
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => _logout(context),
//             child: Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }

//   void _logout(BuildContext context) {
//     context.push("/login");
//   }

//   /// Convert index → label for MotionTabBar
//   String _tabLabel(int index) {
//     switch (index) {
//       case 0:
//         return "Home";
//       case 1:
//         return "Mark Attendance";
//       case 2:
//         return "Summary";
//       default:
//         return "Mark Attendance";
//     }
//   }

//   /// Convert label → index
//   int _indexFromLabel(String label) {
//     switch (label) {
//       case "Home":
//         return 0;
//       case "Mark Attendance":
//         return 1;
//       case "Summary":
//         return 2;
//       default:
//         return 1;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _pages[_activeTab],

//       bottomNavigationBar: SafeArea(
//         child: MotionTabBar(
//           labels: const ["Home", "Mark Attendance", "Summary"],
//           icons: const [
//             Icons.home_outlined,
//             Icons.face_2_outlined,
//             Icons.summarize,
//           ],

//           initialSelectedTab: _tabLabel(_activeTab),

//           tabBarColor: Colors.white,
//           tabSelectedColor: const Color(0xFF1B5E20), // Strong operator green
//           tabIconColor: Colors.black54,

//           tabBarHeight: 64,
//           tabSize: 52,
//           tabIconSize: 22,
//           tabIconSelectedSize: 26,

//           onTabItemSelected: (dynamic value) {
//             final index = value is String
//                 ? _indexFromLabel(value)
//                 : value is int
//                     ? value
//                     : 1;

//             if (index == 0) {
//               context.go("/operator-home");
//             } else if (index == 2) {
//               // Dedicated navigation to history/summary
//               Navigator.of(context).push(
//                 MaterialPageRoute(
//                   builder: (_) => AttendanceHistory(empId: widget.empid),
//                 ),
//               );
//               setState(() => _activeTab = 2);
//             } else {
//               setState(() => _activeTab = index);
//             }
//           },
//         ),
//       ),
//     );
//   }
// }
class HomePage1 extends StatefulWidget {
  const HomePage1({super.key});

  @override
  State<HomePage1> createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1> {
  int _activeTab = 1;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGps();
  }

  @override
  Widget build(BuildContext context) {
    // ---------------------------------------------------------
    // Fetch authenticated user details from AuthBloc
    // ---------------------------------------------------------
    final nameFromState = context.select<AuthBloc, String?>(
      (bloc) => bloc.state is AuthStateAuthenticated
          ? (bloc.state as AuthStateAuthenticated).userName
          : null,
    );

    final empIdFromState = context.select<AuthBloc, String?>(
      (bloc) => bloc.state is AuthStateAuthenticated
          ? (bloc.state as AuthStateAuthenticated).emp_id
          : null,
    );

    if (empIdFromState == null) {
      return const Scaffold(
        body: Center(child: Text("Invalid session")),
      );
    }

    // Setup pages dynamically with authenticated data
    _pages = [
      OperatorHomePage(
        // userName: nameFromState,
        // empId: empIdFromState,
      ),
      AttendancePage(
        // empId: empIdFromState
        ),
      AttendanceHistory(empId: empIdFromState),
    ];

    return Scaffold(
      body: _pages[_activeTab],

      bottomNavigationBar: SafeArea(
        child: MotionTabBar(
          labels: const ["Home", "Mark Attendance", "Summary"],
          icons: const [
            Icons.home_outlined,
            Icons.face_2_outlined,
            Icons.summarize,
          ],
          initialSelectedTab: _tabLabel(_activeTab),
          tabBarColor: Colors.white,
          tabSelectedColor: const Color(0xFF1B5E20),
          tabIconColor: Colors.black54,
          tabBarHeight: 64,
          tabSize: 52,
          tabIconSize: 22,
          tabIconSelectedSize: 26,
          onTabItemSelected: (dynamic value) {
            final index = _indexFromLabel(value.toString());

            if (index == 0) {
              context.go("/operator-home");
            } else if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AttendanceHistory(empId: empIdFromState),
                ),
              );
              setState(() => _activeTab = 2);
            } else {
              setState(() => _activeTab = index);
            }
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Utility Functions
  // ---------------------------------------------------------
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
        title: const Text("Location Required"),
        content: const Text(
          "Location permission or GPS is disabled. You will be logged out.",
        ),
        actions: [
          TextButton(
            onPressed: () => context.push("/login"),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _tabLabel(int index) {
    switch (index) {
      case 0:
        return "Home";
      case 1:
        return "Mark Attendance";
      case 2:
        return "Summary";
      default:
        return "Mark Attendance";
    }
  }

  int _indexFromLabel(String label) {
    switch (label) {
      case "Home":
        return 0;
      case "Mark Attendance":
        return 1;
      case "Summary":
        return 2;
      default:
        return 1;
    }
  }
}
