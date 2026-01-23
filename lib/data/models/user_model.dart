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

class UserModel extends Equatable {
  final String userId;
  final String userName;
  final String role;
  final String? authToken;
  final String? emp_id;
  final String? employeeId;
  final Map<String, dynamic>? permissions;

  const UserModel({
    required this.userId,
    required this.userName,
    required this.role,
    this.authToken,
    this.emp_id,
    this.employeeId,
    this.permissions,
  });

  factory UserModel.fromApi(Map<String, dynamic> json) {
    final perms = json["permissions"];
    return UserModel(
      userId: json["unique_id"]?.toString() ?? "",
      userName: json["name"]?.toString() ?? "",
      role: json["role"]?.toString().toLowerCase() ?? "citizen",
      authToken: json["access_token"]?.toString(),
      emp_id: json["emp_id"]?.toString(),
      employeeId: json["employee_id"]?.toString(),
      permissions: perms is Map<String, dynamic> ? perms : null,
    );
  }

  /// Use this when restoring user from offline DB
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final perms = json["permissions"];
    return UserModel(
      userId: json["unique_id"] ?? "",
      userName: json["username"] ?? "",
      role: json["role"] ?? "",
      authToken: json["access_token"],
      emp_id: json["emp_id"],
      employeeId: json["employee_id"],
      permissions: perms is Map<String, dynamic> ? perms : null,
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
    };
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
      ];
}
