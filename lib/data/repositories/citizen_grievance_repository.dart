import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/data/models/grievance_ticket_model.dart';

/// Talks to the citizen-scoped grievance API (`/citizen/grievance-tickets/`).
/// Every call is authenticated; the backend scopes results to the logged-in
/// citizen, so no customer id needs to be passed from the app.
class CitizenGrievanceRepository {
  List<dynamic> _asList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      return (decoded['results'] ?? decoded['data'] ?? []) as List;
    }
    return const [];
  }

  /// Categories (+subcategories) for the raise-grievance chat.
  Future<GrievanceMeta> fetchMeta() async {
    final dio = await authorizedDio();
    final resp = await dio.get(ApiConfig.citizenGrievanceMeta);
    return GrievanceMeta.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Tickets the logged-in citizen has raised.
  Future<List<GrievanceTicket>> fetchMyTickets() async {
    final dio = await authorizedDio();
    final resp = await dio.get(ApiConfig.citizenGrievanceTickets);
    return _asList(resp.data)
        .map((e) => GrievanceTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Full detail (with timeline) for one ticket.
  Future<GrievanceTicket> fetchTicket(String uniqueId) async {
    final dio = await authorizedDio();
    final resp = await dio.get('${ApiConfig.citizenGrievanceTickets}$uniqueId/');
    return GrievanceTicket.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Raise a new grievance. Returns the created ticket (with timeline).
  Future<GrievanceTicket> createTicket({
    required String categoryId,
    String? subcategoryId,
    String? priorityId,
    required String description,
    String? locationText,
  }) async {
    final dio = await authorizedDio();
    final payload = <String, dynamic>{
      'category': categoryId,
      if (subcategoryId != null) 'subcategory': subcategoryId,
      if (priorityId != null) 'priority': priorityId,
      'description': description,
      if (locationText != null) 'location_text': locationText,
    };
    try {
      final resp = await dio.post(
        ApiConfig.citizenGrievanceTickets,
        data: payload,
      );
      return GrievanceTicket.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('❌ createTicket failed: ${e.response?.statusCode} ${e.response?.data}');
      rethrow;
    }
  }
}
