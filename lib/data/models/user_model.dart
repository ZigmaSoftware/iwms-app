// import 'package:equatable/equatable.dart';

// class UserModel extends Equatable {
//   final String userId;
//   final String userName;
//   final String role;
//   final String? authToken;
//  final String? emp_id;
//   const UserModel({
//     required this.userId,
//     required this.userName,
//     required this.role,
//     this.authToken,
//      this.emp_id,
//   });

//   factory UserModel.fromApi(Map<String, dynamic> json) {
//     return UserModel(
//       userId: json["unique_id"]?.toString() ?? "",
//       userName: json["name"]?.toString() ?? "",
//       role: json["role"]?.toString().toLowerCase() ?? "citizen",
//       authToken: json["access_token"]?.toString(),
//       emp_id: json["emp_id"]?.toString(),

//     );
//   }

//   @override
//   List<Object?> get props => [userId, userName, role, authToken,emp_id];
// }
import 'package:equatable/equatable.dart';
import 'package:iwms_citizen_app/data/models/permission_bundle.dart';

class UserModel extends Equatable {
  final String userId;
  final String userName;
  final String role;
  final String? authToken;
  final String? emp_id;
  final String? employeeId;
  final Map<String, dynamic>? permissions;
  final PermissionBundle? permissionBundle;

  const UserModel({
    required this.userId,
    required this.userName,
    required this.role,
    this.authToken,
    this.emp_id,
    this.employeeId,
    this.permissions,
    this.permissionBundle,
  });

  static String normalizeRole(String? rawRole) {
    final value = (rawRole ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'citizen';

    final compact = value.replaceAll(RegExp(r'[\s_-]+'), '');
    if (compact.contains('operator')) return 'operator';
    if (compact.contains('driver')) return 'driver';
    if (compact.contains('supervisor')) return 'supervisor';
    if (compact.contains('admin') || compact.contains('superadmin')) {
      return 'admin';
    }
    if (compact.contains('customer') || compact.contains('citizen')) {
      return 'citizen';
    }
    return value;
  }

  factory UserModel.fromApi(Map<String, dynamic> json) {
    final perms = json["permissions"];
    final bundle = _parsePermissionBundle(json);
    return UserModel(
      userId: json["unique_id"]?.toString() ?? "",
      userName: json["name"]?.toString() ?? "",
      role: normalizeRole(json["role"]?.toString()),
      authToken: json["access_token"]?.toString(),
      emp_id: json["emp_id"]?.toString(),
      employeeId: json["employee_id"]?.toString(),
      permissions:
          bundle?.permissions ?? (perms is Map<String, dynamic> ? perms : null),
      permissionBundle: bundle,
    );
  }

  /// Use this when restoring user from offline DB
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final perms = json["permissions"];
    final bundle = _parsePermissionBundle(json);
    return UserModel(
      userId: json["unique_id"] ?? "",
      userName: json["username"] ?? "",
      role: normalizeRole(json["role"]?.toString()),
      authToken: json["access_token"],
      emp_id: json["emp_id"],
      employeeId: json["employee_id"],
      permissions:
          bundle?.permissions ?? (perms is Map<String, dynamic> ? perms : null),
      permissionBundle: bundle,
    );
  }

  /// Needed for saving to DB/local storage
  Map<String, dynamic> toJson() {
    return {
      "unique_id": userId,
      "username": userName,
      "role": role,
      "access_token": authToken,
      "emp_id": emp_id,
      "employee_id": employeeId,
      "permissions": permissions,
      "permission_bundle": permissionBundle?.toJson(),
    };
  }

  UserModel copyWith({
    String? userId,
    String? userName,
    String? role,
    String? authToken,
    String? emp_id,
    String? employeeId,
    Map<String, dynamic>? permissions,
    PermissionBundle? permissionBundle,
    bool clearPermissionBundle = false,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      authToken: authToken ?? this.authToken,
      emp_id: emp_id ?? this.emp_id,
      employeeId: employeeId ?? this.employeeId,
      permissions: permissions ?? this.permissions,
      permissionBundle: clearPermissionBundle
          ? null
          : permissionBundle ?? this.permissionBundle,
    );
  }

  static PermissionBundle? _parsePermissionBundle(Map<String, dynamic> json) {
    final stored = json["permission_bundle"];
    if (stored is Map<String, dynamic>) {
      return PermissionBundle.fromApi(stored);
    }
    if (stored is Map) {
      return PermissionBundle.fromApi(Map<String, dynamic>.from(stored));
    }

    if (json["permissions"] is Map<String, dynamic> ||
        json["permission_details"] is Map<String, dynamic> ||
        json["column_permissions"] is Map<String, dynamic> ||
        json["module_access"] is List ||
        json["app_surfaces"] is List) {
      return PermissionBundle.fromApi(json);
    }
    return null;
  }

  @override
  List<Object?> get props => [
        userId,
        userName,
        role,
        authToken,
        emp_id,
        employeeId,
        permissions,
        permissionBundle,
      ];
}
