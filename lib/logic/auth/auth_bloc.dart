import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iwms_citizen_app/data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final Future<void> initialization;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        initialization = authRepository.initialize(),
        super(const AuthStateInitial()) {
    on<AuthStatusChecked>(_onStatusChecked);
    on<AuthCitizenLoginRequested>(_onCitizenLoginRequested);
    on<AuthCitizenRegisterRequested>(_onCitizenRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthOperatorLoginRequested>(_onOperatorLoginRequested);

    initialization.then((_) => add(AuthStatusChecked()));
  }

  Future<void> _onStatusChecked(
    AuthStatusChecked event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateInitial());

    var user = await _authRepository.getAuthenticatedUser();
    if (user == null) {
      emit(const AuthStateUnauthenticated());
      return;
    }

    final refreshedUser = await _authRepository.refreshCurrentUserPermissions(
      requireOnline: _authRepository.requiresLiveBackend(user.role),
    );
    if (refreshedUser == null) {
      await _authRepository.logout();
      emit(const AuthStateUnauthenticated());
      return;
    }

    emit(_authenticatedStateFromUser(refreshedUser));
  }

  // Future<void> _onCitizenLoginRequested(
  //   AuthCitizenLoginRequested event,
  //   Emitter<AuthState> emit,
  // ) async {
  //   emit(const AuthStateLoading());

  //   try {
  //     final user = await _authRepository.loginCitizen(
  //       username: event.username,
  //       password: event.password,
  //     );

  //     await _authRepository.saveUser(user);

  //     emit(AuthStateAuthenticated(
  //       userName: user.userName,
  //       role: user.role.toLowerCase(),
  //       emp_id:user.emp_id
  //     ));
  //   } catch (e) {
  //     emit(AuthStateFailure(message: e.toString()));
  //     emit(const AuthStateUnauthenticated());
  //   }
  // }
  Future<void> _onCitizenLoginRequested(
    AuthCitizenLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());

    try {
      final user = await _authRepository.loginCitizen(
        username: event.username,
        password: event.password,
      );

      emit(_authenticatedStateFromUser(user));
    } catch (e) {
      emit(AuthStateFailure(message: e.toString()));
      emit(const AuthStateUnauthenticated());
    }
  }

  Future<void> _onCitizenRegisterRequested(
    AuthCitizenRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());

    final userName =
        event.fullName.trim().isEmpty ? "Citizen Demo" : event.fullName.trim();

    final user = UserModel(
      userId: "CUS-REG-${userName.replaceAll(" ", "")}",
      userName: userName,
      role: "citizen",
      authToken: "demo-token",
    );

    await _authRepository.saveUser(user);

    emit(AuthStateAuthenticated(
      userName: user.userName,
      role: "citizen",
      userId: user.userId,
      permissions: user.permissions,
      permissionBundle: user.permissionBundle,
    ));
  }

  Future<void> _onOperatorLoginRequested(
    AuthOperatorLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());

    final user = UserModel(
      userId: event.operatorId,
      userName: event.userName,
      role: "operator",
      authToken: "operator-token",
    );

    await _authRepository.saveUser(user);

    emit(AuthStateAuthenticated(
      userName: user.userName,
      role: "operator",
      userId: user.userId,
      permissions: user.permissions,
      permissionBundle: user.permissionBundle,
    ));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthStateUnauthenticated());
  }

  AuthStateAuthenticated _authenticatedStateFromUser(UserModel user) {
    return AuthStateAuthenticated(
      userName: user.userName,
      role: UserModel.normalizeRole(user.role),
      userId: user.userId,
      emp_id: user.emp_id,
      employeeId: user.employeeId,
      permissions: user.permissions,
      permissionBundle: user.permissionBundle,
    );
  }
}
