import 'package:equatable/equatable.dart';
import 'package:iwms_citizen_app/data/models/permission_bundle.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// App starting / checking persistence
class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

/// Any ongoing login or async process
class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

/// Unified authenticated state
class AuthStateAuthenticated extends AuthState {
  final String userName;
  final String role; // citizen, operator, driver, admin
  final String userId;
  final String? emp_id;
  final String? employeeId;
  final Map<String, dynamic>? permissions;
  final PermissionBundle? permissionBundle;
  const AuthStateAuthenticated({
    required this.userName,
    required this.role,
    required this.userId,
    this.emp_id,
    this.employeeId,
    this.permissions,
    this.permissionBundle,
  });

  @override
  List<Object?> get props => [
        userName,
        role,
        userId,
        emp_id,
        employeeId,
        permissions,
        permissionBundle,
      ];
}

/// Logged out
class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

/// Login failure
class AuthStateFailure extends AuthState {
  final String message;

  const AuthStateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
