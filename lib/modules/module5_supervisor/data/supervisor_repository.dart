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
  static const String _staff =
      '${ApiConfig.desktopBase}user-creations/staffcreation/';
  static const String _staffTemplates =
      '${ApiConfig.desktopBase}schedule-masters/staff-templates/';
  static const String _tripLogs =
      '${ApiConfig.desktopBase}schedule-masters/daily-trip-logs/';

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
    bool mine = false,
  }) async {
    final dio = await authorizedDio();
    final dateStr = date == null ? null : _formatDate(date);

    Future<List<SupervisorAssignment>> fetchFor(String? zoneId) async {
      final query = <String, dynamic>{};
      if (dateStr != null) query['date'] = dateStr;
      // `mine=true` scopes to assignments whose trip plan this supervisor owns
      // (TripPlan.supervisor_id == me), replacing zone-based scoping.
      if (mine) query['mine'] = 'true';
      if (zoneId != null && zoneId.isNotEmpty) query['zone_id'] = zoneId;
      if (status != null && status.isNotEmpty) query['status'] = status;

      final res = await dio.get(_assignments, queryParameters: query);
      return _parseList(res.data);
    }

    try {
      // Supervisor-scoped or unscoped fetches are a single call; only
      // zone-scoped fan-out needs the per-zone merge.
      if (mine || zoneIds.isEmpty) {
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

  /// This supervisor's trip history, sourced from the daily trip log
  /// (actuals recorded during/after each trip), newest first. Adapted into
  /// the same [SupervisorAssignment] shape as `fetchAssignments` so the UI
  /// (`SupervisorAssignmentCard`) matches exactly.
  Future<List<SupervisorAssignment>> fetchAssignmentHistory() async {
    try {
      final dio = await authorizedDio();
      final res = await dio.get(_tripLogs, queryParameters: {'mine': 'true'});
      final list = _rawList(res.data)
          .map((e) => SupervisorAssignment.fromTripLogJson(e))
          .toList();
      list.sort((a, b) {
        final ad = a.tripDate, bd = b.tripDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      return list;
    } on DioException catch (e) {
      throw SupervisorException(_message(e));
    } catch (e) {
      throw SupervisorException(e.toString());
    }
  }

  /// The supervisor's collected-waste time series (one entry per trip log),
  /// sourced from the daily trip log's bin + household weights. Bucketing by
  /// day/week/month is done in the chart widget.
  Future<List<SupervisorWastePoint>> fetchWasteSeries() async {
    try {
      final dio = await authorizedDio();
      final res = await dio.get(
        _tripLogs,
        queryParameters: {'mine': 'true', 'limit': '1000'},
      );
      return _rawList(res.data)
          .map((e) => SupervisorWastePoint.fromLogJson(e))
          .where((p) => p.hasValidDate)
          .toList();
    } on DioException catch (e) {
      throw SupervisorException(_message(e));
    } catch (e) {
      throw SupervisorException(e.toString());
    }
  }

  /// Staff list (company-scoped by the backend), used by the Staffs screen
  /// which groups by designation.
  Future<List<SupervisorStaff>> fetchStaff() async {
    try {
      final dio = await authorizedDio();
      final res = await dio.get(_staff);
      return _rawList(res.data)
          .map((e) => SupervisorStaff.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw SupervisorException(_message(e));
    } catch (e) {
      throw SupervisorException(e.toString());
    }
  }

  /// Staff templates (the "Teams" list).
  Future<List<SupervisorTeam>> fetchTeams() async {
    try {
      final dio = await authorizedDio();
      final res = await dio.get(_staffTemplates);
      return _rawList(res.data)
          .map((e) => SupervisorTeam.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw SupervisorException(_message(e));
    } catch (e) {
      throw SupervisorException(e.toString());
    }
  }

  List<Map<String, dynamic>> _rawList(dynamic data) {
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
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
