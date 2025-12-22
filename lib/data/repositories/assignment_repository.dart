import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';

import '../models/daily_assignment_model.dart';
import '../../core/api_config.dart';

class AssignmentRepository {
  final Dio _dio;

  AssignmentRepository(this._dio);

  /// Fetches today's assignments based on the logged-in user's role
  Future<List<DailyAssignmentModel>> fetchTodayAssignments() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final authRepo = getIt<AuthRepository>();
    final user = await authRepo.getAuthenticatedUser();

    debugPrint('📋 ASSIGNMENT QUERY → date=$today role=${user?.role}');

    try {
      // Use authorized Dio that includes JWT token
      final dio = await authorizedDio();
      
      final resp = await dio.get(
        ApiConfig.assignments,
        queryParameters: {
          'date': today,
          if (user?.role != null) 'role': user!.role,
        },
      );

      debugPrint('✅ Assignments response: ${resp.statusCode}');

      // Handle different response formats
      final decoded = resp.data;
      final List list = decoded is List 
          ? decoded 
          : (decoded is Map 
              ? (decoded['results'] ?? decoded['data'] ?? [])
              : []);

      final assignments = list
          .map((e) => DailyAssignmentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('📊 Found ${assignments.length} assignment(s)');
      return assignments;
      
    } on DioException catch (e) {
      debugPrint('❌ DioException fetching assignments: ${e.message}');
      
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      }
      
      if (e.response?.statusCode == 403) {
        debugPrint('🚫 Permission denied: ${e.response?.data}');
        throw Exception('You do not have permission to view assignments.');
      }
      
      if (e.response?.statusCode == 404) {
        debugPrint('⚠️ Assignments endpoint not found');
        return [];
      }
      
      rethrow;
    } catch (e) {
      debugPrint('❌ Error fetching assignments: $e');
      rethrow;
    }
  }

  /// Fetches assignments for a specific date
  Future<List<DailyAssignmentModel>> fetchAssignmentsByDate(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    debugPrint('📋 ASSIGNMENT QUERY → date=$dateStr');

    try {
      final dio = await authorizedDio();
      
      final resp = await dio.get(
        ApiConfig.assignments,
        queryParameters: {'date': dateStr},
      );

      final decoded = resp.data;
      final List list = decoded is List 
          ? decoded 
          : (decoded is Map 
              ? (decoded['results'] ?? decoded['data'] ?? [])
              : []);

      return list
          .map((e) => DailyAssignmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
          
    } on DioException catch (e) {
      debugPrint('❌ Error fetching assignments for $dateStr: ${e.message}');
      
      if (e.response?.statusCode == 403) {
        throw Exception('You do not have permission to view assignments.');
      }
      
      rethrow;
    }
  }

  Future<List<DailyAssignmentModel>> fetchAssignmentHistory({
    DateTime? date,
  }) async {
    final resolvedDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(resolvedDate);

    debugPrint('📚 ASSIGNMENT HISTORY → date=$dateStr');

    try {
      final dio = await authorizedDio();

      final resp = await dio.get(
        ApiConfig.staffAssignments,
        queryParameters: {
          'date_from': dateStr,
          'date_to': dateStr,
        },
      );

      final decoded = resp.data;
      final List list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);

      return list
          .map((e) => DailyAssignmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('❌ Error fetching assignment history: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error fetching assignment history: $e');
      rethrow;
    }
  }

  Future<List<DailyAssignmentModel>> fetchAssignmentsForOperator({
    required String operatorId,
    DateTime? date,
  }) async {
    final resolvedDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(resolvedDate);

    debugPrint(
      '📋 OPERATOR ASSIGNMENTS → date=$dateStr operator_id=$operatorId',
    );

    try {
      final dio = await authorizedDio();

      final resp = await dio.get(
        ApiConfig.assignments,
        queryParameters: {
          'date': dateStr,
          'operator_id': operatorId,
        },
      );

      final decoded = resp.data;
      final List list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);

      return list
          .map((e) => DailyAssignmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('❌ Error fetching operator assignments: ${e.message}');
      if (e.response?.statusCode == 403) {
        throw Exception('You do not have permission to view assignments.');
      }
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error fetching operator assignments: $e');
      rethrow;
    }
  }

  /// Creates a new assignment
  Future<bool> createAssignment({
    required DateTime date,
    required String wardId,
    required String driverId,
    required String operatorId,
    required String shift,
    required String assignmentType,
    String? customerId,
  }) async {
    debugPrint('📤 Creating assignment...');

    final payload = {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'ward': wardId,
      'driver': driverId,
      'operator': operatorId,
      'shift': shift,
      'assignment_type': assignmentType,
      if (customerId != null && customerId.isNotEmpty) 'customer': customerId,
    };

    debugPrint('📦 Payload: $payload');

    try {
      final dio = await authorizedDio();
      
      final resp = await dio.post(
        ApiConfig.assignments,
        data: payload,
      );

      debugPrint('✅ Assignment created: ${resp.statusCode}');
      return resp.statusCode != null && 
             resp.statusCode! >= 200 && 
             resp.statusCode! < 300;
             
    } on DioException catch (e) {
      debugPrint('❌ Error creating assignment: ${e.message}');
      debugPrint('   Response: ${e.response?.data}');
      
      if (e.response?.statusCode == 403) {
        throw Exception('You do not have permission to create assignments.');
      }
      
      if (e.response?.statusCode == 400) {
        final errorData = e.response?.data;
        if (errorData is Map) {
          final errorMsg = errorData['detail'] ?? 
                          errorData['error'] ?? 
                          'Invalid assignment data';
          throw Exception(errorMsg);
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return false;
    }
  }

  /// Checks if there's a conflicting assignment for the given ward, date, and shift
  Future<bool> checkConflict({
    required DateTime date,
    required String wardId,
    required String shift,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    debugPrint('🔍 Checking conflict: date=$dateStr ward=$wardId shift=$shift');

    try {
      final dio = await authorizedDio();
      
      final resp = await dio.get(
        ApiConfig.assignments,
        queryParameters: {
          'date': dateStr,
          'ward_id': wardId,
          'shift': shift,
        },
      );

      final decoded = resp.data;
      final List items = decoded is List
          ? decoded
          : (decoded is Map 
              ? (decoded['results'] ?? decoded['data'] ?? [])
              : []);

      final hasConflict = items.isNotEmpty;
      
      if (hasConflict) {
        debugPrint('⚠️ Conflict found: ${items.length} existing assignment(s)');
      } else {
        debugPrint('✅ No conflict');
      }

      return hasConflict;
      
    } on DioException catch (e) {
      debugPrint('⚠️ Conflict check failed: ${e.message}');
      // Fail open - don't block on network error
      return false;
    } catch (e) {
      debugPrint('⚠️ Unexpected error in conflict check: $e');
      return false;
    }
  }
}
