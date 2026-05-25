// lib/data/repositories/auth_repository.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/offline_login.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/env.dart';
import 'package:iwms_citizen_app/data/models/permission_bundle.dart';
import 'package:iwms_citizen_app/data/models/user_model.dart';

class AuthRepositoryException implements Exception {
  final String message;

  AuthRepositoryException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  // ignore: unused_field
  final Dio _dio;
  final SharedPreferences _prefs;

  static const String _userKey = 'authenticated_user';
  static const String _roleKey = 'user_role';
  static const String _nameKey = 'user_name';
  static const String _tokenKey = 'auth_token';
  static const String _emp_idKey = 'emp_id';
  static const String _displayEmpIdKey = 'display_emp_id';
  static const String _permissionsKey = 'user_permissions';
  static const String _permissionBundleKey = 'user_permission_bundle';

  AuthRepository(this._dio, this._prefs);

  Future<void> initialize() async {
    // Reserved for future init work (e.g., token refresh)
  }

  // Remote authentication disabled for the current demo build.
  Future<UserModel> registerCitizen({
    required String phone,
    required String ownerName,
    required String contactNo,
    required String buildingNo,
    required String street,
    required String area,
    required String pincode,
    required String city,
    required String district,
    required String state,
    required String zone,
    required String ward,
    required String propertyName,
  }) async =>
      throw UnimplementedError('Remote registration disabled in demo build.');

  // Future<UserModel> loginCitizen({
  //   required String username,
  //   required String password,
  //   String? userType,
  // }) async {
  //   final sanitizedUsername = username.trim();
  //   if (sanitizedUsername.isEmpty) {
  //     throw AuthRepositoryException('Please enter a valid phone number or username.');
  //   }
  //   if (password.isEmpty) {
  //     throw AuthRepositoryException('Password is required.');
  //   }

  //   final resolvedUserType =
  //       (userType?.trim().isNotEmpty ?? false) ? userType!.trim() : ApiConfig.citizenUserType;
  //   try {
  //     final response = await _dio.post(
  //       ApiConfig.citizenLogin,
  //       data: {
  //         'user_type': resolvedUserType,
  //         'username': sanitizedUsername,
  //         'password': password,
  //       },
  //     );

  //     final payload = response.data;
  //     if (payload is! Map<String, dynamic>) {
  //       throw AuthRepositoryException('Unexpected response from server.');
  //     }

  //     final success = payload['status'] == true;
  //     if (!success) {
  //       final message = _extractServerMessage(payload) ?? 'Unable to login with the provided details.';
  //       throw AuthRepositoryException(message);
  //     }

  //     final token = payload['token']?.toString();
  //     final userMap = payload['user'];
  //     final userData = userMap is Map<String, dynamic> ? userMap : <String, dynamic>{};
  //     final usernameFromApi = _stringOrNull(userData['username']) ?? sanitizedUsername;

  //     final displayName = _buildDisplayName(
  //       firstName: _stringOrNull(userData['first_name']),
  //       lastName: _stringOrNull(userData['last_name']),
  //       fallback: usernameFromApi,
  //     );

  //     return UserModel(
  //       userId: usernameFromApi,
  //       userName: displayName,
  //       role: 'citizen',
  //       authToken: token?.isNotEmpty == true ? token : null,
  //     );
  //   } on AuthRepositoryException {
  //     rethrow;
  //   } on DioException catch (dioError, stackTrace) {
  //     final message = _handleDioError(dioError);
  //     _logError('Citizen login failed', dioError, stackTrace);
  //     throw AuthRepositoryException(message);
  //   } catch (error, stackTrace) {
  //     _logError('Unexpected citizen login failure', error, stackTrace);
  //     throw AuthRepositoryException('Unexpected error occurred. Please try again.');
  //   }
  // }
  Future<UserModel> loginCitizen({
    required String username,
    required String password,
  }) async {
    final sanitizedUsername = username.trim();
    final sanitizedPassword = password.trim();

    if (sanitizedUsername.isEmpty) {
      throw AuthRepositoryException("Username is required.");
    }
    if (sanitizedPassword.isEmpty) {
      throw AuthRepositoryException("Password is required.");
    }

    try {
      final user = await _loginOnline(
        sanitizedUsername,
        sanitizedPassword,
      );
      final refreshedUser = await _refreshPermissionsForUser(user) ?? user;
      await _persistOfflineUser(
        refreshedUser,
        sanitizedPassword,
        username: sanitizedUsername,
      );
      await saveUser(refreshedUser);
      return refreshedUser;
    } on SocketException catch (_) {
      final offlineUser =
          await _loginOffline(sanitizedUsername, sanitizedPassword);
      await saveUser(offlineUser);
      return offlineUser;
    } on DioException catch (dioError, stackTrace) {
      if (_shouldTryOfflineLogin(dioError)) {
        try {
          final offlineUser =
              await _loginOffline(sanitizedUsername, sanitizedPassword);
          await saveUser(offlineUser);
          return offlineUser;
        } on AuthRepositoryException {
          rethrow;
        }
      }
      final message = _handleDioError(dioError);
      _logError('Login failed', dioError, stackTrace);
      throw AuthRepositoryException(message);
    } on AuthRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      _logError('Unexpected login failure', error, stackTrace);
      throw AuthRepositoryException("Login failed. Please try again.");
    }
  }

  Future<UserModel> _loginOnline(String username, String password) async {
    if (kEnforcePermissions) {
      return _loginDesktopStaff(username, password);
    }
    return _loginMobileCitizen(username, password);
  }

  Future<UserModel> _loginDesktopStaff(String username, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.staffLogin,
        data: {
          "username": username,
          "password": password,
          "login_type": "staff",
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw AuthRepositoryException("Invalid response from staff login.");
      }

      final requiredKeys = ["unique_id", "name", "role", "access_token"];
      final missing = requiredKeys.where((key) => data[key] == null).toList();
      if (missing.isNotEmpty) {
        throw AuthRepositoryException("Incomplete staff login payload.");
      }

      final permissions = data["permissions"] is Map<String, dynamic>
          ? data["permissions"]
          : null;
      final user = UserModel.fromApi({
        ...data,
        "permissions": permissions,
      });
      return user;
    } on DioException catch (dioError, stackTrace) {
      final message = _handleDioError(dioError);
      _logError('Staff login failed', dioError, stackTrace);
      throw AuthRepositoryException(message);
    }
  }

  Future<UserModel> _loginMobileCitizen(
      String username, String password) async {
    final response = await _dio.post(
      ApiConfig.citizenLogin,
      data: {
        "username": username,
        "password": password,
        "login_type": "customer",
      },
    );

    final data = response.data;

    if (data is! Map<String, dynamic> ||
        data["unique_id"] == null ||
        data["role"] == null ||
        data["name"] == null ||
        data["access_token"] == null) {
      throw AuthRepositoryException("Invalid login response from server.");
    }

    return UserModel.fromApi(data);
  }

  Future<UserModel> _loginOffline(String username, String password) async {
    final local = await getOperatorFromDB(username);

    if (local == null) {
      throw AuthRepositoryException(
        "No offline data found for this user.",
      );
    }

    final hash = sha256.convert(utf8.encode(password)).toString();

    if (hash != local["password_hash"]) {
      throw AuthRepositoryException("Incorrect password (offline mode).");
    }

    if (!supportsOfflineAccess(local["role"]?.toString())) {
      throw AuthRepositoryException(
        "Offline login is available only for operator and driver users.",
      );
    }

    final offlineUser = UserModel.fromJson(local);
    final cachedBundle = _readCachedPermissionBundle();
    if (offlineUser.permissionBundle != null || cachedBundle == null) {
      return offlineUser;
    }
    return offlineUser.copyWith(
      permissions: cachedBundle.permissions,
      permissionBundle: cachedBundle,
    );
  }

  bool supportsOfflineAccess(String? role) {
    final normalizedRole = UserModel.normalizeRole(role);
    return normalizedRole == 'operator' || normalizedRole == 'driver';
  }

  bool requiresLiveBackend(String? role) => !supportsOfflineAccess(role);

  Future<void> _persistOfflineUser(
    UserModel user,
    String password, {
    String? username,
  }) async {
    if (!supportsOfflineAccess(user.role)) {
      return;
    }

    await saveOperatorToDB(
      {
        "unique_id": user.userId,
        "username": username,
        "name": user.userName,
        "role": user.role,
        "access_token": user.authToken,
        "emp_id": user.emp_id,
        "employee_id": user.employeeId,
      },
      password,
      username: username,
    );
  }

  Future<UserModel> loginDriver({
    required String userName,
    required String password,
  }) async =>
      throw UnimplementedError('Remote driver login disabled in demo build.');

  Future<UserModel?> getAuthenticatedUser() async {
    final userId = _prefs.getString(_userKey);
    final role = _prefs.getString(_roleKey);
    final userName = _prefs.getString(_nameKey);
    final emp_id = _prefs.getString(_emp_idKey);
    final displayEmpId = _prefs.getString(_displayEmpIdKey);
    final token = _prefs.getString(_tokenKey);
    final permissionsRaw = _prefs.getString(_permissionsKey);
    final permissionBundleRaw = _prefs.getString(_permissionBundleKey);
    Map<String, dynamic>? permissions;
    Map<String, dynamic>? permissionBundle;
    if (permissionsRaw != null && permissionsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(permissionsRaw);
        if (decoded is Map<String, dynamic>) {
          permissions = decoded;
        }
      } catch (_) {}
    }
    if (permissionBundleRaw != null && permissionBundleRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(permissionBundleRaw);
        if (decoded is Map<String, dynamic>) {
          permissionBundle = decoded;
        } else if (decoded is Map) {
          permissionBundle = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    if (userId != null && role != null && userName != null) {
      final normalizedRole = UserModel.normalizeRole(role);
      if (normalizedRole != 'citizen' &&
          normalizedRole != 'customer' &&
          (token == null || token.isEmpty)) {
        return null;
      }
      return UserModel(
        userId: userId,
        userName: userName,
        role: normalizedRole,
        authToken: token,
        emp_id: emp_id,
        employeeId: displayEmpId,
        permissions: permissions,
        permissionBundle: permissionBundle != null
            ? PermissionBundle.fromApi(permissionBundle)
            : null,
      );
    }
    return null;
  }

  Future<UserModel?> refreshCurrentUserPermissions({
    bool requireOnline = false,
  }) async {
    final currentUser = await getAuthenticatedUser();
    if (currentUser == null) {
      return null;
    }
    final updatedUser = await _refreshPermissionsForUser(
      currentUser,
      requireOnline: requireOnline,
    );
    if (updatedUser == null) {
      return null;
    }
    await saveUser(updatedUser);
    return updatedUser;
  }

  Future<void> logout() async {
    await _prefs.remove(_userKey);
    await _prefs.remove(_roleKey);
    await _prefs.remove(_emp_idKey);
    await _prefs.remove(_nameKey);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_permissionsKey);
    await _prefs.remove(_permissionBundleKey);
  }

  Future<void> saveUser(UserModel user) async {
    await _persistUser(user);
  }

  Future<void> _persistUser(UserModel user) async {
    await _prefs.setString(_userKey, user.userId);
    await _prefs.setString(_roleKey, user.role);
    await _prefs.setString(_nameKey, user.userName);
    if (user.emp_id != null && user.emp_id!.isNotEmpty) {
      await _prefs.setString(_emp_idKey, user.emp_id!);
    } else {
      await _prefs.remove(_emp_idKey);
    }
    if (user.employeeId != null && user.employeeId!.isNotEmpty) {
      await _prefs.setString(_displayEmpIdKey, user.employeeId!);
    } else {
      await _prefs.remove(_displayEmpIdKey);
    }

    if (user.authToken != null && user.authToken!.isNotEmpty) {
      await _prefs.setString(_tokenKey, user.authToken!);
    } else {
      await _prefs.remove(_tokenKey);
    }

    final perms = user.permissions;
    if (perms != null && perms.isNotEmpty) {
      await _prefs.setString(_permissionsKey, jsonEncode(perms));
    } else {
      await _prefs.remove(_permissionsKey);
    }

    final bundle = user.permissionBundle;
    if (bundle != null && !bundle.isEmpty) {
      await _prefs.setString(_permissionBundleKey, jsonEncode(bundle.toJson()));
    } else {
      await _prefs.remove(_permissionBundleKey);
    }
  }

  Future<UserModel?> _refreshPermissionsForUser(
    UserModel user, {
    bool requireOnline = false,
  }) async {
    final token = user.authToken;
    if (token == null || token.isEmpty) {
      return requireOnline ? null : user;
    }

    try {
      final dio = _authorizedDioForToken(token);
      final response = await dio.get(ApiConfig.myPermissions);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return requireOnline ? null : user;
      }

      final bundle = PermissionBundle.fromApi(data);
      if (bundle.isEmpty) {
        return requireOnline ? null : user;
      }

      return user.copyWith(
        permissions: bundle.permissions,
        permissionBundle: bundle,
      );
    } on DioException catch (error, stackTrace) {
      _logError('Permission refresh failed', error, stackTrace);
      return requireOnline ? null : user;
    } catch (error, stackTrace) {
      _logError('Unexpected permission refresh failure', error, stackTrace);
      return requireOnline ? null : user;
    }
  }

  bool _shouldTryOfflineLogin(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.error is SocketException;
  }

  PermissionBundle? _readCachedPermissionBundle() {
    final raw = _prefs.getString(_permissionBundleKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PermissionBundle.fromApi(decoded);
      }
      if (decoded is Map) {
        return PermissionBundle.fromApi(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  Dio _authorizedDioForToken(String token) {
    final headers = Map<String, dynamic>.from(_dio.options.headers);
    headers['Content-Type'] = 'application/json';
    headers['Authorization'] = 'Bearer $token';

    final options = BaseOptions(
      baseUrl: _dio.options.baseUrl,
      connectTimeout: _dio.options.connectTimeout,
      receiveTimeout: _dio.options.receiveTimeout,
      sendTimeout: _dio.options.sendTimeout,
      headers: headers,
      contentType: _dio.options.contentType,
      responseType: _dio.options.responseType,
      followRedirects: _dio.options.followRedirects,
      validateStatus: _dio.options.validateStatus,
      receiveDataWhenStatusError: _dio.options.receiveDataWhenStatusError,
    );

    final dio = Dio(options);
    dio.interceptors.addAll(_dio.interceptors);
    dio.httpClientAdapter = _dio.httpClientAdapter;
    return dio;
  }

  String? _extractServerMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();

      final errors = data['errors'];
      if (errors is Map) {
        final buffer = StringBuffer();
        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            buffer.write('$key: ${value.first}. ');
          } else if (value is String && value.isNotEmpty) {
            buffer.write('$key: $value. ');
          }
        });
        final compiled = buffer.toString().trim();
        if (compiled.isNotEmpty) return compiled;
      }

      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return null;
  }

  String _handleDioError(DioException error) {
    final responseData = error.response?.data;
    final serverMessage = _extractServerMessage(responseData) ??
        error.message ??
        'Unable to reach the server.';
    return serverMessage;
  }

  void _logError(String prefix, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('$prefix: $error');
    debugPrint(stackTrace.toString());
  }
}
