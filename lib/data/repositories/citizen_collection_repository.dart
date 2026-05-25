import 'package:flutter/foundation.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/data/models/customer_profile.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';

class CitizenCollectionRepository {
  const CitizenCollectionRepository();

  Future<List<CustomerProfile>> fetchCustomers() async {
    try {
      final dio = await authorizedDio();
      final response = await dio.get(ApiConfig.customerList);

      final List items = response.data is List
          ? response.data
          : (response.data['results'] ?? []);

      return items
          .map((json) => CustomerProfile.fromJson(
                Map<String, dynamic>.from(json as Map),
              ))
          .toList();
    } catch (e, st) {
      debugPrint('❌ FETCH CUSTOMERS ERROR: $e\n$st');
      return [];
    }
  }

  Future<List<EnhancedAssignmentModel>> fetchAssignments({
    String? wardId,
    String? customerId,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (!ApiConfig.legacyRoleAssignEnabled) {
      return const <EnhancedAssignmentModel>[];
    }

    try {
      final dio = await authorizedDio();
      final params = <String, dynamic>{};
      if (wardId != null) params['ward_id'] = wardId;
      if (customerId != null) params['customer_id'] = customerId;
      if (status != null) params['status'] = status;
      if (dateFrom != null) {
        params['date_from'] = dateFrom.toIso8601String().split('T').first;
      }
      if (dateTo != null) {
        params['date_to'] = dateTo.toIso8601String().split('T').first;
      }

      final response = await dio.get(
        ApiConfig.citizenAssignments,
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
      debugPrint('❌ FETCH CITIZEN ASSIGNMENTS ERROR: $e\n$st');
      return [];
    }
  }

  Future<StaffAssignmentSummary?> fetchSummary({String? wardId}) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return null;

    try {
      final dio = await authorizedDio();
      final response = await dio.get(
        '${ApiConfig.citizenAssignments}summary/',
        queryParameters: wardId != null ? {'ward_id': wardId} : null,
      );

      return StaffAssignmentSummary.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e, st) {
      debugPrint('❌ FETCH CITIZEN SUMMARY ERROR: $e\n$st');
      return null;
    }
  }
}
