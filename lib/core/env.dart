import 'package:flutter/foundation.dart';

/// Environment-style flags for build-time configuration.
/// Set via `--dart-define` when running or building:
///   flutter run --dart-define=VITE_PROD=true --dart-define=VITE_ENFORCE_PERMISSIONS=false --dart-define=VITE_API_LOCAL=https://115.245.93.26:4216/api/v1
const bool kProd = bool.fromEnvironment(
  'VITE_PROD',
  defaultValue: kReleaseMode,
);
const bool kEnforcePermissions =
    bool.fromEnvironment('VITE_ENFORCE_PERMISSIONS', defaultValue: true);

// Override the local/prod bases via dart-define if needed.
const String _localApiOverride = String.fromEnvironment(
  'VITE_API_LOCAL',
  defaultValue: 'http://192.168.6.198:8000/api/v1',
);
const String _prodApiOverride = String.fromEnvironment(
  'VITE_API_PROD',
  defaultValue: 'http://192.168.6.198:8000/api/v1',
);

const String kApiBase = kProd ? _prodApiOverride : _localApiOverride;
/// Base path for the grouped router endpoints (no `/desktop` segment in v1).
const String kDesktopBase = '$kApiBase/';
