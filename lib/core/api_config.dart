import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:iwms_citizen_app/core/env.dart';

// This function creates and configures a Dio instance
Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      // You can set a base URL here if all requests share one
      // baseUrl: 'http://zigma.in:80/iwms_app/iwms_app/',
      connectTimeout: const Duration(seconds: 10), // Increased timeout
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // You can add interceptors here for logging or auth tokens
  if (!kReleaseMode) {
    dio.interceptors.add(
      LogInterceptor(responseBody: true, requestBody: true),
    );
  }

  return dio;
}

class ApiConfig {
  /// Desktop endpoints (open lists) used for driver-side data pulls.
  static const String desktopBase = kDesktopBase;
  static const String wasteSummaryEndpoint =
      '${desktopBase}waste/citizen-summary/';
  static const String customerList =
      '${desktopBase}customers/customercreations/';
  static const String assignments = '${desktopBase}role-assign/assignments/';
  static const String staffAssignments =
      '${desktopBase}role-assign/staff-assignments/';
  static const String collectionLogs =
      '${desktopBase}role-assign/collection-logs/';
  static const String assignmentCustomerStatuses =
      '${desktopBase}role-assign/assignment-customer-statuses/';
  static const String citizenAssignments =
      '${desktopBase}role-assign/citizen-assignments/';
  static const String tripAssignments = '${desktopBase}trip-assign/trips/';
  static const String tripShifts = '${desktopBase}trip-assign/shifts/';
  static const String tripCollectionPoints =
      '${desktopBase}trip-assign/collection-points/';
  static const String tripRoutePlans = '${desktopBase}trip-assign/route-plans/';
  static const String tripPlannedStops =
      '${desktopBase}trip-assign/planned-route-stops/';
  static const String tripRouteGeometry =
      '${desktopBase}trip-assign/route-geometry/';
  static const String tripExecutionStops =
      '${desktopBase}trip-assign/trip-execution-stops/';
  static const String tripRoutePlanGenerate =
      '${desktopBase}trip-assign/route-plans/generate/';
  static const String tripGenerate =
      '${desktopBase}trip-assign/trips/generate/';
  static const String tripDriverRoute =
      '${desktopBase}trip-assign/trips/driver-route/';
  static const String staffTemplates =
      '${desktopBase}user-creation/stafftemplate-creation/';
  static const String vehicles = '${desktopBase}vehicles/vehicle-creation/';
  static const String users = '${desktopBase}user-creation/users-creation/';
  static const String subproperties = '${desktopBase}assets/subproperties/';
  static const String wards = '${desktopBase}masters/wards/';
  static const String zones = '${desktopBase}masters/zones/';

  // ORS key is sourced from build-time env (`VITE_ORS_API_KEY`).
  static const String orsApiKey = kOrsApiKey;

  static const String driverNextHouse = '$kApiBase/driver/next-house/';
  static const String updateAssignmentStatus =
      '$kApiBase/driver/assignment/update-status/';

  /// Django backend endpoint for mobile authentication.
  /// Mobile login is exposed at `/api/v1/login/` via the backend mobile alias.
  static const String _defaultMobileLogin = '${desktopBase}login/';
  static const String _defaultCitizenLogin = _defaultMobileLogin;
  static const String citizenLogin = String.fromEnvironment(
    'CITIZEN_LOGIN_URL',
    defaultValue: _defaultCitizenLogin,
  );
  // Mobile apps should use the unified mobile login endpoint.
  static const String staffLogin = _defaultMobileLogin;
  static const String mobileLogin = _defaultMobileLogin;

  /// Default user type identifier expected by the Django login API.
  static const String citizenUserType = 'citizen';
}

// Base URL (without query params)
const String kVehicleApiBaseUrl = kVehicleLiveApiBaseUrl;

// API Parameters (ZIGMA specific credentials - THESE MUST BE PROTECTED!)
const String kProviderName = kVehicleProviderName;
const String kFCode = kVehicleFCode;
