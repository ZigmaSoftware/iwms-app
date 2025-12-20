import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iwms_citizen_app/data/models/user_model.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/offline_login.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:crypto/crypto.dart';
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

    final user = await _authRepository.getAuthenticatedUser();
    if (user == null) {
      emit(const AuthStateUnauthenticated());
      return;
    }

    emit(AuthStateAuthenticated(
      userName: user.userName,
      role: user.role.toLowerCase(),
      userId: user.userId,
      emp_id: user.emp_id,
    ));
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
    // Try ONLINE login first
    final user = await _authRepository.loginCitizen(
      username: event.username,
      password: event.password,
    );

    // Save user to local DB for offline access
    await saveOperatorToDB(user.toJson(), event.password);

    emit(AuthStateAuthenticated(
      userName: user.userName,
      role: user.role.toLowerCase(),
      userId: user.userId,
      emp_id: user.emp_id,
    ));
  } catch (e) {
    // ----------------------------------------------------
    // FALLBACK TO OFFLINE DB LOGIN
    // ----------------------------------------------------
    final localUser = await getOperatorFromDB(event.username);

    if (localUser == null) {
      emit(AuthStateFailure(message: "Invalid credentials (Offline mode)."));
      emit(const AuthStateUnauthenticated());
      return;
    }

    // Validate password hash offline
    final hash = sha256.convert(utf8.encode(event.password)).toString();

    if (localUser["password_hash"] != hash) {
      emit(AuthStateFailure(message: "Incorrect password (Offline mode)."));
      emit(const AuthStateUnauthenticated());
      return;
    }

    // OFFLINE LOGIN SUCCESS
    emit(AuthStateAuthenticated(
      userName: localUser["name"],
      role: localUser["role"],
      userId: (localUser["unique_id"] ?? "").toString(),
      emp_id: localUser["emp_id"],
    ));
  }
}

  Future<void> _onCitizenRegisterRequested(
    AuthCitizenRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());

    final userName = event.fullName.trim().isEmpty
        ? "Citizen Demo"
        : event.fullName.trim();

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
    ));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthStateUnauthenticated());
  }
}
