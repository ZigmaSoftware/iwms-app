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
  static const String _permissionsKey = 'user_permissions';

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
    await _persistOfflineUser(user, sanitizedPassword);
    await saveUser(user);
    return user;
  } on SocketException catch (_) {
    final offlineUser = await _loginOffline(sanitizedUsername, sanitizedPassword);
    await saveUser(offlineUser);
    return offlineUser;
  } on DioException catch (dioError, stackTrace) {
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

      final permissions =
          data["permissions"] is Map<String, dynamic> ? data["permissions"] : null;

      return UserModel(
        userId: data["unique_id"].toString(),
        userName: data["name"].toString(),
        role: data["role"].toString().toLowerCase(),
        authToken: data["access_token"].toString(),
        emp_id: data["emp_id"]?.toString(),
        permissions: permissions,
      );
    } on DioException catch (dioError, stackTrace) {
      final message = _handleDioError(dioError);
      _logError('Staff login failed', dioError, stackTrace);
      throw AuthRepositoryException(message);
    }
  }

  Future<UserModel> _loginMobileCitizen(String username, String password) async {
    final response = await _dio.post(
      ApiConfig.citizenLogin,
      data: {
        "username": username,
        "password": password,
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

    return UserModel.fromJson(local);
  }

  Future<void> _persistOfflineUser(UserModel user, String password) async {
    await saveOperatorToDB(
      {
        "unique_id": user.userId,
        "name": user.userName,
        "role": user.role,
        "access_token": user.authToken,
        "emp_id": user.emp_id,
      },
      password,
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
    final token = _prefs.getString(_tokenKey);
    final permissionsRaw = _prefs.getString(_permissionsKey);
    Map<String, dynamic>? permissions;
    if (permissionsRaw != null && permissionsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(permissionsRaw);
        if (decoded is Map<String, dynamic>) {
          permissions = decoded;
        }
      } catch (_) {}
    }

    if (userId != null && role != null && userName != null) {
      final normalizedRole = role.toLowerCase();
      if (normalizedRole != 'citizen' &&
          normalizedRole != 'customer' &&
          (token == null || token.isEmpty)) {
        return null;
      }
      return UserModel(
        userId: userId,
        userName: userName,
        role: role,
        authToken: token,
        emp_id: emp_id,
        permissions: permissions,
      );
    }
    return null;
  }

  Future<void> logout() async {
    await _prefs.remove(_userKey);
    await _prefs.remove(_roleKey);
    await _prefs.remove(_emp_idKey);
    await _prefs.remove(_nameKey);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_permissionsKey);
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
    final serverMessage =
        _extractServerMessage(responseData) ?? error.message ?? 'Unable to reach the server.';
    return serverMessage;
  }

  String _buildDisplayName({
    String? firstName,
    String? lastName,
    required String fallback,
  }) {
    final cleanedFirst = firstName?.trim() ?? '';
    final cleanedLast = lastName?.trim() ?? '';
    final fullName = '$cleanedFirst $cleanedLast'.trim();
    return fullName.isNotEmpty ? fullName : fallback;
  }

  String? _stringOrNull(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    }
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isNotEmpty ? text : null;
  }

  void _logError(String prefix, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('$prefix: $error');
    debugPrint(stackTrace.toString());
  }
}
