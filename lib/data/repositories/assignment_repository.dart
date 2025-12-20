import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';

import '../models/daily_assignment_model.dart';
import '../../core/api_config.dart';

class AssignmentRepository {
    AssignmentRepository(this._dio);
    final Dio _dio;
 Future<List<DailyAssignmentModel>> fetchTodayAssignments() async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final authRepo = getIt<AuthRepository>();
  final user = await authRepo.getAuthenticatedUser();

  debugPrint('ASSIGNMENT QUERY → date=$today role=${user?.role}');

  final resp = await _dio.get(
    ApiConfig.assignments,
    queryParameters: {
      'date': today,
      'role': user?.role,
    },
  );

  final decoded = resp.data;
  final List list =
      decoded is List ? decoded : (decoded['results'] ?? []);

  return list
      .map((e) => DailyAssignmentModel.fromJson(e))
      .toList();
}
}