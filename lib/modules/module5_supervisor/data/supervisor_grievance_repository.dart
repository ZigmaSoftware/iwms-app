import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/data/models/grievance_ticket_model.dart';

/// Supervisor-side grievance API. Hits the staff endpoint
/// `/grievance/tickets/`, which the backend already scopes to the logged-in
/// supervisor's department, so no filtering is needed here.
class SupervisorGrievanceRepository {
  List<dynamic> _asList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      return (decoded['results'] ?? decoded['data'] ?? []) as List;
    }
    return const [];
  }

  Future<List<GrievanceTicket>> fetchTickets() async {
    final dio = await authorizedDio();
    final resp = await dio.get(ApiConfig.grievanceTickets);
    return _asList(resp.data)
        .map((e) => GrievanceTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GrievanceTicket> fetchTicket(String id) async {
    final dio = await authorizedDio();
    final resp = await dio.get('${ApiConfig.grievanceTickets}$id/');
    return GrievanceTicket.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> start(String id) => _action('$id/status/', {'status_code': 'IN_PROGRESS'});

  Future<void> escalate(String id, String reason) =>
      _action('$id/escalate/', {'reason': reason});

  Future<void> resolve(String id, String note) =>
      _action('$id/resolve/', {'resolution_note': note});

  Future<void> _action(String path, Map<String, dynamic> body) async {
    final dio = await authorizedDio();
    try {
      await dio.post('${ApiConfig.grievanceTickets}$path', data: body);
    } on DioException catch (e) {
      debugPrint('❌ grievance action failed: ${e.response?.statusCode} ${e.response?.data}');
      rethrow;
    }
  }
}
