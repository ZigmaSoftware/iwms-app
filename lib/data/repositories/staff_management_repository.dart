import 'package:flutter/foundation.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/core/env.dart';

class StaffManagementRepository {
  const StaffManagementRepository();

  Future<List<StaffMember>> fetchStaff({String? role}) async {
    if (!kEnforcePermissions) return const <StaffMember>[];
    try {
      final dio = await authorizedDio();
      final response = await dio.get(
        '${ApiConfig.desktopBase}user-creation/users-creation/',
      );

      final List items = response.data is List
          ? response.data
          : (response.data['results'] ?? []);

      final staff = items
          .map((json) => StaffMember.fromJson(
                Map<String, dynamic>.from(json as Map),
              ))
          .where((s) {
        if (role == null) return true;
        return s.role.toLowerCase() == role.toLowerCase();
      }).toList();

      return staff;
    } catch (e, st) {
      debugPrint('❌ FETCH STAFF ERROR: $e\n$st');
      return [];
    }
  }

  Future<List<EnhancedAssignmentModel>> fetchStaffAssignmentHistory({
    required String staffId,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (!kEnforcePermissions || !ApiConfig.legacyRoleAssignEnabled) {
      return const <EnhancedAssignmentModel>[];
    }
    try {
      final dio = await authorizedDio();

      final params = <String, dynamic>{
        'staff_id': staffId,
      };
      if (status != null) params['status'] = status;
      if (dateFrom != null) {
        params['date_from'] = dateFrom.toIso8601String().split('T').first;
      }
      if (dateTo != null) {
        params['date_to'] = dateTo.toIso8601String().split('T').first;
      }

      final response = await dio.get(
        ApiConfig.staffAssignments,
        queryParameters: params,
      );

      final List items = response.data is List
          ? response.data
          : (response.data['results'] ?? []);

      return items
          .map((json) => EnhancedAssignmentModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ))
          .toList();
    } catch (e, st) {
      debugPrint('❌ FETCH ASSIGNMENT HISTORY ERROR: $e\n$st');
      return [];
    }
  }

  Future<StaffAssignmentSummary?> fetchStaffSummary(String staffId) async {
    if (!kEnforcePermissions || !ApiConfig.legacyRoleAssignEnabled) return null;
    try {
      final dio = await authorizedDio();

      final response = await dio.get(
        '${ApiConfig.staffAssignments}summary/',
        queryParameters: {'staff_id': staffId},
      );

      return StaffAssignmentSummary.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e, st) {
      debugPrint('❌ FETCH STAFF SUMMARY ERROR: $e\n$st');
      return null;
    }
  }

  Future<EnhancedAssignmentModel?> fetchAssignmentDetails(
    String uniqueId,
  ) async {
    if (!kEnforcePermissions || !ApiConfig.legacyRoleAssignEnabled) return null;
    try {
      final dio = await authorizedDio();
      final response = await dio.get(
        '${ApiConfig.staffAssignments}$uniqueId/',
      );
      return EnhancedAssignmentModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e, st) {
      debugPrint('❌ FETCH ASSIGNMENT DETAILS ERROR: $e\n$st');
      return null;
    }
  }
}
