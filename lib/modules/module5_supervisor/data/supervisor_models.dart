// Supervisor module data models. These mirror the backend payloads from
// `/api/v1/user-creations/supervisor-zone-map/me/` and
// `/api/v1/schedule-masters/daily-trip-assignments/`.

/// The zone scope a supervisor is authorised to operate in.
class SupervisorZoneScope {
  const SupervisorZoneScope({
    required this.supervisorId,
    required this.zoneIds,
    required this.zoneNames,
    this.districtId,
    this.cityId,
  });

  final String supervisorId;
  final List<String> zoneIds;
  final List<String> zoneNames;
  final String? districtId;
  final String? cityId;

  bool get isEmpty => zoneIds.isEmpty;

  factory SupervisorZoneScope.fromMeJson(Map<String, dynamic> json) {
    final zoneIds = (json['zone_ids'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];

    final maps = (json['maps'] as List?) ?? const [];
    String? districtId;
    String? cityId;
    if (maps.isNotEmpty && maps.first is Map) {
      final first = maps.first as Map;
      districtId = first['district_id']?.toString();
      cityId = first['city_id']?.toString();
    }

    return SupervisorZoneScope(
      supervisorId: json['supervisor_id']?.toString() ?? '',
      zoneIds: zoneIds,
      zoneNames: const [],
      districtId: districtId,
      cityId: cityId,
    );
  }

  static const SupervisorZoneScope empty = SupervisorZoneScope(
    supervisorId: '',
    zoneIds: [],
    zoneNames: [],
  );
}

/// A single daily trip assignment as the supervisor sees it.
class SupervisorAssignment {
  const SupervisorAssignment({
    required this.uniqueId,
    required this.areaName,
    required this.zoneId,
    required this.zoneName,
    required this.wardName,
    required this.tripCode,
    required this.wasteTypeName,
    required this.vehicleNo,
    required this.driverName,
    required this.operatorName,
    required this.status,
    required this.approvalStatus,
    required this.tripDate,
    required this.scheduledTime,
    required this.remarks,
  });

  final String uniqueId;
  final String areaName;
  final String zoneId;
  final String zoneName;
  final String wardName;
  final String tripCode;
  final String wasteTypeName;
  final String vehicleNo;
  final String driverName;
  final String operatorName;
  final String status; // SCHEDULED / IN_PROGRESS / COMPLETED / CANCELLED
  final String approvalStatus; // PENDING / APPROVED / REJECTED
  final DateTime? tripDate;
  final String scheduledTime;
  final String remarks;

  bool get isScheduled => status.toUpperCase() == 'SCHEDULED';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isPendingApproval => approvalStatus.toUpperCase() == 'PENDING';

  /// Human-readable status: "In Progress" instead of "IN_PROGRESS".
  String get statusLabel => status
      .split('_')
      .map((w) => w.isEmpty
          ? ''
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  factory SupervisorAssignment.fromJson(Map<String, dynamic> json) {
    final tripPlan = (json['trip_plan'] as Map?) ?? const {};
    final zone = (json['zone'] as Map?) ?? const {};
    final ward = (json['ward'] as Map?) ?? const {};
    final panchayat = (json['panchayat'] as Map?) ?? const {};
    final wasteType = (json['waste_type'] as Map?) ?? const {};
    final vehicle = (json['vehicle'] as Map?) ?? const {};
    final staff = (json['effective_staff'] as Map?) ?? const {};

    final wardName = ward['ward_name']?.toString() ??
        panchayat['panchayat_name']?.toString() ??
        '';
    final zoneName = zone['zone_name']?.toString() ??
        ward['zone_name']?.toString() ??
        '';

    return SupervisorAssignment(
      uniqueId: json['unique_id']?.toString() ?? '',
      areaName: wardName.isNotEmpty
          ? wardName
          : (zoneName.isNotEmpty ? zoneName : 'Unassigned area'),
      zoneId: zone['unique_id']?.toString() ??
          ward['zone_id']?.toString() ??
          '',
      zoneName: zoneName,
      wardName: wardName,
      tripCode: tripPlan['display_code']?.toString() ??
          json['unique_id']?.toString() ??
          '',
      wasteTypeName: wasteType['waste_type_name']?.toString() ??
          tripPlan['waste_type_name']?.toString() ??
          '',
      vehicleNo: vehicle['vehicle_no']?.toString() ??
          tripPlan['vehicle_no']?.toString() ??
          '',
      driverName: staff['driver']?.toString() ?? '',
      operatorName: staff['operator']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SCHEDULED',
      approvalStatus: json['approval_status']?.toString() ?? 'PENDING',
      tripDate: _parseDate(json['trip_date']),
      scheduledTime: json['scheduled_time']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

/// Dashboard KPI rollup derived from the day's assignments.
class SupervisorKpis {
  const SupervisorKpis({
    required this.total,
    required this.inProgress,
    required this.completed,
    required this.scheduled,
    required this.pendingReview,
  });

  final int total;
  final int inProgress;
  final int completed;
  final int scheduled;
  final int pendingReview;

  factory SupervisorKpis.fromAssignments(List<SupervisorAssignment> items) {
    return SupervisorKpis(
      total: items.length,
      inProgress: items.where((a) => a.isInProgress).length,
      completed: items.where((a) => a.isCompleted).length,
      scheduled: items.where((a) => a.isScheduled).length,
      pendingReview: items.where((a) => a.isPendingApproval).length,
    );
  }

  static const SupervisorKpis empty = SupervisorKpis(
    total: 0,
    inProgress: 0,
    completed: 0,
    scheduled: 0,
    pendingReview: 0,
  );
}

enum SupervisorAlertSeverity { info, warning, danger }

/// A single row in the dashboard activity / alerts feed.
class SupervisorAlert {
  const SupervisorAlert({
    required this.title,
    required this.subtitle,
    required this.severity,
  });

  final String title;
  final String subtitle;
  final SupervisorAlertSeverity severity;

  /// Derive a lightweight alert feed from the day's assignments.
  static List<SupervisorAlert> fromAssignments(
    List<SupervisorAssignment> items,
  ) {
    final alerts = <SupervisorAlert>[];

    final pending = items.where((a) => a.isPendingApproval).toList();
    if (pending.isNotEmpty) {
      alerts.add(SupervisorAlert(
        title: '${pending.length} assignment(s) awaiting review',
        subtitle: pending.map((a) => a.areaName).take(3).join(', '),
        severity: SupervisorAlertSeverity.warning,
      ));
    }

    final notStarted = items.where((a) => a.isScheduled).toList();
    if (notStarted.isNotEmpty) {
      alerts.add(SupervisorAlert(
        title: '${notStarted.length} trip(s) not started yet',
        subtitle: notStarted.map((a) => a.areaName).take(3).join(', '),
        severity: SupervisorAlertSeverity.info,
      ));
    }

    final cancelled = items.where((a) => a.isCancelled).toList();
    if (cancelled.isNotEmpty) {
      alerts.add(SupervisorAlert(
        title: '${cancelled.length} trip(s) cancelled today',
        subtitle: cancelled.map((a) => a.areaName).take(3).join(', '),
        severity: SupervisorAlertSeverity.danger,
      ));
    }

    return alerts;
  }
}
