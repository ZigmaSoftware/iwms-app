import 'package:dio/dio.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';

/// Raised when a supervisor data fetch fails. Carries an optional [code] so
/// callers can branch (e.g. NO_ZONE_SCOPE → empty state instead of error).
class SupervisorException implements Exception {
  SupervisorException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'SupervisorException($code): $message';
}

/// Data access for the supervisor module. Wraps [authorizedDio] and the
/// existing backend endpoints (zone map + daily trip assignments). Read-only
/// for this phase — assignment approval is intentionally not wired yet.
class SupervisorRepository {
  static const String _zoneMapMe =
      '${ApiConfig.desktopBase}user-creations/supervisor-zone-map/me/';
  static const String _assignments =
      '${ApiConfig.desktopBase}schedule-masters/daily-trip-assignments/';

  /// Fetch the requesting supervisor's authorised zone scope.
  Future<SupervisorZoneScope> fetchMyZoneScope() async {
    try {
      final dio = await authorizedDio();
      final res = await dio.get(_zoneMapMe);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return SupervisorZoneScope.fromMeJson(data);
      }
      return SupervisorZoneScope.empty;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        // No supervisor staff context — treat as empty scope.
        return SupervisorZoneScope.empty;
      }
      throw SupervisorException(_message(e));
    } catch (e) {
      throw SupervisorException(e.toString());
    }
  }

  /// Fetch today's (or [date]'s) assignments, optionally scoped to [zoneIds].
  /// When the supervisor has multiple zones we fetch per-zone and merge, since
  /// the backend filter accepts a single `zone_id`.
  Future<List<SupervisorAssignment>> fetchAssignments({
    DateTime? date,
    List<String> zoneIds = const [],
    String? status,
  }) async {
    final dio = await authorizedDio();
    final dateStr = _formatDate(date ?? DateTime.now());

    Future<List<SupervisorAssignment>> fetchFor(String? zoneId) async {
      final query = <String, dynamic>{'date': dateStr};
      if (zoneId != null && zoneId.isNotEmpty) query['zone_id'] = zoneId;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final res = await dio.get(_assignments, queryParameters: query);
      return _parseList(res.data);
    }

    try {
      if (zoneIds.isEmpty) {
        return await fetchFor(null);
      }

      final results = await Future.wait(zoneIds.map(fetchFor));
      // De-duplicate by uniqueId (a trip could surface under overlapping
      // zone/ward filters).
      final seen = <String>{};
      final merged = <SupervisorAssignment>[];
      for (final list in results) {
        for (final a in list) {
          if (seen.add(a.uniqueId)) merged.add(a);
        }
      }
      return merged;
    } on DioException catch (e) {
      throw SupervisorException(_message(e));
    } catch (e) {
      throw SupervisorException(e.toString());
    }
  }

  List<SupervisorAssignment> _parseList(dynamic data) {
    final List raw;
    if (data is List) {
      raw = data;
    } else if (data is Map && data['results'] is List) {
      raw = data['results'] as List;
    } else if (data is Map && data['data'] is List) {
      raw = data['data'] as List;
    } else {
      raw = const [];
    }
    return raw
        .whereType<Map>()
        .map((e) => SupervisorAssignment.fromJson(
            Map<String, dynamic>.from(e)))
        .toList();
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return e.message ?? 'Network error';
  }
}
