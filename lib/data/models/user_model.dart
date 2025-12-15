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

  const UserModel({
    required this.userId,
    required this.userName,
    required this.role,
    this.authToken,
    this.emp_id,
  });

  factory UserModel.fromApi(Map<String, dynamic> json) {
    return UserModel(
      userId: json["unique_id"]?.toString() ?? "",
      userName: json["name"]?.toString() ?? "",
      role: json["role"]?.toString().toLowerCase() ?? "citizen",
      authToken: json["access_token"]?.toString(),
      emp_id: json["emp_id"]?.toString(),
    );
  }

  /// Use this when restoring user from offline DB
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json["unique_id"] ?? "",
      userName: json["username"] ?? "",
      role: json["role"] ?? "",
      authToken: json["access_token"],
      emp_id: json["emp_id"],
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
    };
  }

  @override
  List<Object?> get props => [
        userId,
        userName,
        role,
        authToken,
        emp_id,
      ];
}
