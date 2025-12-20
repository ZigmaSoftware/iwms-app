// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/logic/vehicle_tracking/vehicle_bloc.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/chatbot.dart';

// Citizen Modules
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/splashscreen.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/citizen_intro_slides.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/auth_intro.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/login.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/home.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/calender.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/track_waste.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/driver_details.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/map.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/profile.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/personal_map.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/alloted_vehicle_map.dart';

// Operator Modules
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/main_operator_tabbar.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_attendance_screen_integration.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_home_page.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_data_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_qr_scanner.dart';

// Driver
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/driver_home_page.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/driver_login_screen.dart';

// Admin
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/dashboard_screen.dart';

// Route Observer

class AppRoutePaths {
  static const String splash = '/';
  static const String citizenIntroSlides = '/citizen/intro';
  static const String citizenAuthIntro = '/citizen/auth';
  static const String citizenLogin = '/citizen/login';
  static const String citizenHome = '/citizen/home';
  static const String citizenHistory = '/citizen/history';
  static const String citizenTrack = '/citizen/track';
  static const String citizenDriverDetails = '/citizen/driver-details';
  static const String citizenMap = '/citizen/map';
  static const String citizenPersonalMap = '/citizen/personal-map';
  static const String citizenAllotedVehicleMap = '/citizen/alloted-vehicle-map';
  static const String citizenGrievanceChat = '/citizen/grievance-chat';
  static const String citizenProfile = '/citizen/profile';

  static const String operatorLogin = '/operator/login';
  static const String operatorHome = '/operator/home';
  static const String operatorQR = '/operator/qr';
  static const String operatorData = '/operator/data';
  static const String attendanceHomepageOperator =
      '/operator/attendance/homepage';
  static const String operatorOverview = '/operator/overview';
  static const String operatorProfile = '/operator/profile';
  static const String operatorAttendance = '/operator/attendance';

  static const String driverLogin = '/driver/login';
  static const String driverHome = '/driver/home';

  static const String adminHome = '/admin/home';
}

class AppRouter {
  final AuthBloc authBloc;
  final RouteObserver<PageRoute> routeObserver;
  late final GoRouter router;

  AppRouter({
    required this.authBloc,
    required this.routeObserver,
    required Listenable refreshListenable,
  }) {
    router = GoRouter(
      debugLogDiagnostics: true,
      initialLocation: AppRoutePaths.citizenIntroSlides,
      refreshListenable: refreshListenable,
      observers: [routeObserver],
      redirect: _redirect,
      routes: [
        // Splash
        GoRoute(
          path: AppRoutePaths.splash,
          builder: (context, state) => const SplashScreen(),
        ),

        // Citizen Public
        GoRoute(
          path: AppRoutePaths.citizenIntroSlides,
          builder: (context, state) => const CitizenIntroSlidesScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.citizenAuthIntro,
          builder: (context, state) => const CitizenAuthIntroScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.citizenLogin,
          builder: (context, state) => const LoginScreen(),
        ),

        // Citizen Authenticated
        GoRoute(
          path: AppRoutePaths.citizenHome,
          builder: (context, state) {
            final s = authBloc.state;
            final username =
                (s is AuthStateAuthenticated) ? s.userName : "Citizen";
            return BlocProvider(
              create: (_) => getIt<VehicleBloc>(),
              child: CitizenDashboard(userName: username),
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.citizenHistory,
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.citizenTrack,
          builder: (context, state) => TrackWasteScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.citizenDriverDetails,
          builder: (context, state) => const DriverDetailsScreen(
              driverName: 'Rajesh Kumar', vehicleNumber: 'TN 01 AB 1234'),
        ),
        GoRoute(
          path: AppRoutePaths.citizenMap,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return MapScreen(
              driverName: extra['driverName'],
              vehicleNumber: extra['vehicleNumber'],
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.citizenAllotedVehicleMap,
          builder: (context, state) => const CitizenAllotedVehicleMapScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.citizenPersonalMap,
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>? ?? {};
            return CitizenPersonalMapScreen(
              vehicleId: data['vehicleId'],
              vehicleNumber: data['vehicleNumber'],
              siteName: data['siteName'],
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.citizenGrievanceChat,
          builder: (context, state) => const GrievanceChatScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.citizenProfile,
          builder: (context, state) {
            final s = authBloc.state;
            final username =
                (s is AuthStateAuthenticated) ? s.userName : "Citizen";
            return ProfileScreen(userName: username);
          },
        ),

        // Operator
        // ---------------- OPERATOR ROUTES ----------------

        GoRoute(
          path: AppRoutePaths.operatorHome,
          builder: (context, state) => const OperatorHomePage(),
        ),

        GoRoute(
          path: '/operator/qr',
          builder: (context, state) => const OperatorQRScanner(),
        ),

        GoRoute(
          path: AppRoutePaths.operatorData,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return OperatorDataScreen(
              customerId: extra['customerId'],
              customerName: extra['customerName'],
              contactNo: extra['contactNo'],
              latitude: extra['latitude'],
              longitude: extra['longitude'],
            );
          },
        ),

        GoRoute(
          path: AppRoutePaths.operatorOverview,
          builder: (context, state) =>
              const MainOperatorTabBar(initialTab: OperatorNavTab.overview),
        ),

        GoRoute(
          path: AppRoutePaths.operatorProfile,
          builder: (context, state) =>
              const MainOperatorTabBar(initialTab: OperatorNavTab.profile),
        ),

        GoRoute(
          path: AppRoutePaths.operatorAttendance,
          builder: (context, state) =>
              const MainOperatorTabBar(initialTab: OperatorNavTab.attendance),
        ),

        GoRoute(
          path: AppRoutePaths.attendanceHomepageOperator,
          builder: (context, state) =>
              const OperatorAttendanceScreenIntegration(),
        ),

        // Driver
        GoRoute(
          path: AppRoutePaths.driverLogin,
          builder: (context, state) => const DriverLoginScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.driverHome,
          builder: (context, state) => const DriverHomePage(),
        ),

        // Admin
        GoRoute(
          path: AppRoutePaths.adminHome,
          builder: (context, state) => const DashboardScreen(),
        ),
      ],
    );
  }

  // REDIRECT LOGIC

  String? _redirect(BuildContext context, GoRouterState state) {
    final auth = authBloc.state;
    final location = state.matchedLocation;

    // Allow app to initialize
    if (auth is AuthStateInitial || auth is AuthStateLoading) return null;

    // PUBLIC ROUTES
    final publicRoutes = {
      AppRoutePaths.citizenLogin,
      AppRoutePaths.citizenAuthIntro,
      AppRoutePaths.citizenIntroSlides,
      AppRoutePaths.operatorLogin,
      AppRoutePaths.driverLogin,
    };

    final isPublic = publicRoutes.contains(location);

    // AUTHENTICATED USERS
    if (auth is AuthStateAuthenticated) {
      final role = auth.role;

      switch (role) {
        case "citizen":
        case "customer":
          return isPublic ? AppRoutePaths.citizenHome : null;

        case "operator":
          return isPublic ? AppRoutePaths.operatorHome : null;

        case "driver":
          return isPublic ? AppRoutePaths.driverHome : null;

        case "admin":
          return isPublic ? AppRoutePaths.adminHome : null;

        default:
          return AppRoutePaths.citizenLogin;
      }
    }

    // UNAUTHENTICATED USERS
    if (auth is AuthStateUnauthenticated || auth is AuthStateFailure) {
      if (isPublic) return null;
      return AppRoutePaths.citizenLogin;
    }

    return null;
  }
}
