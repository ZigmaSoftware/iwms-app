import 'package:equatable/equatable.dart';

class AppSurfaceAccess extends Equatable {
  final String key;
  final String label;
  final String route;
  final bool isDefault;

  const AppSurfaceAccess({
    required this.key,
    required this.label,
    required this.route,
    required this.isDefault,
  });

  factory AppSurfaceAccess.fromJson(Map<String, dynamic> json) {
    return AppSurfaceAccess(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'route': route,
      'isDefault': isDefault,
    };
  }

  @override
  List<Object?> get props => [key, label, route, isDefault];
}

class PermissionLanding extends Equatable {
  final String? surfaceKey;
  final String? route;
  final String? moduleKey;
  final String? screenKey;

  const PermissionLanding({
    this.surfaceKey,
    this.route,
    this.moduleKey,
    this.screenKey,
  });

  factory PermissionLanding.fromJson(Map<String, dynamic> json) {
    return PermissionLanding(
      surfaceKey: json['surfaceKey']?.toString(),
      route: json['route']?.toString(),
      moduleKey: json['moduleKey']?.toString(),
      screenKey: json['screenKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surfaceKey': surfaceKey,
      'route': route,
      'moduleKey': moduleKey,
      'screenKey': screenKey,
    };
  }

  @override
  List<Object?> get props => [surfaceKey, route, moduleKey, screenKey];
}

class PermissionBundle extends Equatable {
  final Map<String, dynamic> permissions;
  final Map<String, dynamic> permissionDetails;
  final Map<String, dynamic> columnPermissions;
  final List<Map<String, dynamic>> moduleAccess;
  final List<AppSurfaceAccess> appSurfaces;
  final PermissionLanding? landing;
  final String? permissionVersion;
  final String? generatedAt;
  final String? source;

  const PermissionBundle({
    required this.permissions,
    required this.permissionDetails,
    required this.columnPermissions,
    required this.moduleAccess,
    required this.appSurfaces,
    this.landing,
    this.permissionVersion,
    this.generatedAt,
    this.source,
  });

  const PermissionBundle.empty()
      : permissions = const {},
        permissionDetails = const {},
        columnPermissions = const {},
        moduleAccess = const [],
        appSurfaces = const [],
        landing = null,
        permissionVersion = null,
        generatedAt = null,
        source = null;

  factory PermissionBundle.fromApi(Map<String, dynamic> json) {
    final rawPermissions = _mapOrEmpty(json['permissions']);
    final rawPermissionDetails = _mapOrEmpty(json['permission_details']);
    final rawColumnPermissions = _mapOrEmpty(json['column_permissions']);
    final rawModuleAccess = _listOfMaps(json['module_access']);
    final rawSurfaces = (json['app_surfaces'] as List?)
            ?.whereType<Map>()
            .map((item) =>
                AppSurfaceAccess.fromJson(Map<String, dynamic>.from(item)))
            .toList() ??
        const <AppSurfaceAccess>[];
    final rawLanding = json['landing'] is Map<String, dynamic>
        ? PermissionLanding.fromJson(json['landing'] as Map<String, dynamic>)
        : json['landing'] is Map
            ? PermissionLanding.fromJson(
                Map<String, dynamic>.from(json['landing'] as Map))
            : null;

    return PermissionBundle(
      permissions: rawPermissions,
      permissionDetails: rawPermissionDetails,
      columnPermissions: rawColumnPermissions,
      moduleAccess: rawModuleAccess,
      appSurfaces: rawSurfaces,
      landing: rawLanding,
      permissionVersion: json['permission_version']?.toString(),
      generatedAt: json['generated_at']?.toString(),
      source: json['source']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permissions': permissions,
      'permission_details': permissionDetails,
      'column_permissions': columnPermissions,
      'module_access': moduleAccess,
      'app_surfaces': appSurfaces.map((item) => item.toJson()).toList(),
      'landing': landing?.toJson(),
      'permission_version': permissionVersion,
      'generated_at': generatedAt,
      'source': source,
    };
  }

  bool get isEmpty =>
      permissions.isEmpty &&
      permissionDetails.isEmpty &&
      columnPermissions.isEmpty &&
      moduleAccess.isEmpty &&
      appSurfaces.isEmpty;

  AppSurfaceAccess? get defaultSurface {
    if (appSurfaces.isEmpty) return null;
    for (final surface in appSurfaces) {
      if (surface.isDefault) return surface;
    }
    return appSurfaces.first;
  }

  bool hasAppSurface(String surfaceKey) {
    final target = _normalizeKey(surfaceKey);
    return appSurfaces.any((surface) => _normalizeKey(surface.key) == target);
  }

  bool hasPermission(
    String moduleName,
    String screenName, {
    String action = 'view',
  }) {
    final targetModule = _normalizeKey(moduleName);
    final targetScreen = _normalizeKey(screenName);
    final targetAction = _normalizeKey(action);

    for (final entry in permissions.entries) {
      if (_normalizeKey(entry.key) != targetModule) {
        continue;
      }

      final screens = entry.value;
      if (screens is! Map) {
        return false;
      }

      for (final screenEntry in screens.entries) {
        if (_normalizeKey(screenEntry.key.toString()) != targetScreen) {
          continue;
        }

        final actions = screenEntry.value;
        if (actions is! List) {
          return false;
        }

        return actions.any(
          (candidate) =>
              _normalizeKey(candidate?.toString() ?? '') == targetAction,
        );
      }
    }

    return false;
  }

  static Map<String, dynamic> _mapOrEmpty(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _normalizeKey(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return '';
    return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(
          RegExp(r'-+'),
          '-',
        );
  }

  @override
  List<Object?> get props => [
        permissions,
        permissionDetails,
        columnPermissions,
        moduleAccess,
        appSurfaces,
        landing,
        permissionVersion,
        generatedAt,
        source,
      ];
}
