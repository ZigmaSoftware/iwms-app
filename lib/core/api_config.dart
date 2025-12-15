import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
  static const String _legacyBase = 'https://zigma.in/iwms_app/iwms_app/';
  static const String _localMobileBase =
      'http://192.168.5.92:8000/api/mobile/'; // bharathi
  // static const String _localMobileBase = 'http://192.168.5.92:8000/api/mobile/'; //sameer
  static const String _localDesktopBase =
      'http://192.168.5.92:8000/api/desktop/';
  // static const String _localMobileBase = 'http://10.111.127.123:8000/api/mobile/';
  //  // static const String _localMobileBase = 'http://115.245.93.26:4216/api/mobile/'; server

  /// Base URL used by the Flutter apps for mobile endpoints.
  static const String mobileBase = _localMobileBase;
  static const String wasteSummaryEndpoint =
      '${mobileBase}waste/citizen-summary/';

  /// Desktop endpoints (open lists) used for driver-side data pulls.
  static const String desktopBase = _localDesktopBase;
  static const String customerList = '${desktopBase}customercreations/';
  static const String assignments = '${desktopBase}assignments/';
  

  // TEMP: Hardcoded ORS key (DEBUG / INTERNAL ONLY)
  static const String orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjU3MzI5ZTM0NjM3YTQ2N2ZhZDYwMDM0ZmQ3ZDk0NTc3IiwiaCI6Im11cm11cjY0In0=';

  static const String driverNextHouse =
      'https://192.168.5.92:8000/api/driver/next-house/';
  static const String updateAssignmentStatus = 'https://192.168.5.92:8000/driver/assignment/update-status/';



  // static const String orsApiKey = String.fromEnvironment(
  //   'ORS_API_KEY',
  //   defaultValue:
  //       'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjU3MzI5ZTM0NjM3YTQ2N2ZhZDYwMDM0ZmQ3ZDk0NTc3IiwiaCI6Im11cm11cjY0In0=',
  // );

  static const String driverLogin = '${_legacyBase}login.php';
  static const String citizenRegister = '${_legacyBase}citizen_register.php';

  /// Django backend endpoint for citizen authentication.
  // static const String _defaultCitizenLogin = '${_localMobileBase}customer/login/';
  static const String _defaultCitizenLogin = '${_localMobileBase}login/';
  static const String citizenLogin = String.fromEnvironment('CITIZEN_LOGIN_URL',
      defaultValue: _defaultCitizenLogin);

  /// Default user type identifier expected by the Django login API.
  static const String citizenUserType = 'citizen';
}

// Base URL (without query params)
const String kVehicleApiBaseUrl =
    "https://api.vamosys.com/mobile/getGrpDataForTrustedClients";

// API Parameters (ZIGMA specific credentials - THESE MUST BE PROTECTED!)
const String kProviderName = "BLUEPLANET";
const String kFCode = "VAM";
