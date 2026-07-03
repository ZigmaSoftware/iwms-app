/// Data models for the operator-mobile trip flow.
///
/// These mirror the backend `/api/v1/operator-mobile/...` payloads.
library;

class OperatorTripPanchayat {
  final String uniqueId;
  final String name;
  final double? latitude;
  final double? longitude;

  const OperatorTripPanchayat({
    required this.uniqueId,
    required this.name,
    this.latitude,
    this.longitude,
  });

  factory OperatorTripPanchayat.fromJson(Map<String, dynamic> json) {
    return OperatorTripPanchayat(
      uniqueId: json['unique_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
    );
  }
}

class OperatorTripWasteType {
  final String uniqueId;
  final String name;

  const OperatorTripWasteType({required this.uniqueId, required this.name});

  factory OperatorTripWasteType.fromJson(Map<String, dynamic> json) {
    return OperatorTripWasteType(
      uniqueId: json['unique_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  bool get isWet => name.toLowerCase().contains('wet');
  bool get isDry => name.toLowerCase().contains('dry');
}

class OperatorTripVehicle {
  final String uniqueId;
  final String vehicleNo;
  final double? capacity;

  const OperatorTripVehicle({
    required this.uniqueId,
    required this.vehicleNo,
    this.capacity,
  });

  factory OperatorTripVehicle.fromJson(Map<String, dynamic> json) {
    return OperatorTripVehicle(
      uniqueId: json['unique_id']?.toString() ?? '',
      vehicleNo: json['vehicle_no']?.toString() ?? '',
      capacity: _parseDouble(json['capacity']),
    );
  }
}

class OperatorTripCollectionPointBrief {
  final String uniqueId;
  final String name;
  final double? latitude;
  final double? longitude;

  const OperatorTripCollectionPointBrief({
    required this.uniqueId,
    required this.name,
    this.latitude,
    this.longitude,
  });

  factory OperatorTripCollectionPointBrief.fromJson(Map<String, dynamic> json) {
    return OperatorTripCollectionPointBrief(
      uniqueId: json['unique_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
    );
  }
}

class OperatorTripBinBrief {
  final String uniqueId;
  final String binName;
  // Scanner value used by the operator-mobile API. Server now sends the
  // bin's `unique_id` here (matches the QR payload's `id` field).
  final String binQr;
  final String? binQrImageUrl;
  final int binCapacity;
  final OperatorTripWasteType? wasteType;

  const OperatorTripBinBrief({
    required this.uniqueId,
    required this.binName,
    required this.binQr,
    required this.binCapacity,
    this.binQrImageUrl,
    this.wasteType,
  });

  /// What the operator scans / sends back. We prefer the explicit `bin_qr`
  /// field but fall back to the bin's unique_id (older payloads).
  String get scanValue => binQr.isNotEmpty ? binQr : uniqueId;

  factory OperatorTripBinBrief.fromJson(Map<String, dynamic> json) {
    return OperatorTripBinBrief(
      uniqueId: json['unique_id']?.toString() ?? '',
      binName: json['bin_name']?.toString() ?? '',
      binQr: json['bin_qr']?.toString() ?? '',
      binQrImageUrl: json['bin_qr_image_url']?.toString(),
      binCapacity: _parseInt(json['bin_capacity']) ?? 0,
      wasteType: json['waste_type'] is Map<String, dynamic>
          ? OperatorTripWasteType.fromJson(
              json['waste_type'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class OperatorTripCollectionPoint {
  final String uniqueId;
  final int sequence;
  final bool isCollected;
  final String status;
  final DateTime? collectedAt;
  final double? collectedWeightKg;
  final OperatorTripCollectionPointBrief collectionPoint;
  final OperatorTripBinBrief bin;

  const OperatorTripCollectionPoint({
    required this.uniqueId,
    required this.sequence,
    required this.isCollected,
    required this.status,
    required this.collectionPoint,
    required this.bin,
    this.collectedAt,
    this.collectedWeightKg,
  });

  factory OperatorTripCollectionPoint.fromJson(Map<String, dynamic> json) {
    return OperatorTripCollectionPoint(
      uniqueId: json['unique_id']?.toString() ?? '',
      sequence: _parseInt(json['sequence']) ?? 0,
      isCollected: json['is_collected'] == true,
      status: json['status']?.toString() ?? 'Pending',
      collectedAt: _parseDate(json['collected_at']),
      collectedWeightKg: _parseDouble(json['collected_weight_kg']),
      collectionPoint: OperatorTripCollectionPointBrief.fromJson(
        Map<String, dynamic>.from(json['collection_point'] as Map),
      ),
      bin: OperatorTripBinBrief.fromJson(
        Map<String, dynamic>.from(json['bin'] as Map),
      ),
    );
  }
}

class OperatorTripProgress {
  final int collected;
  final int total;
  final bool completed;

  const OperatorTripProgress({
    required this.collected,
    required this.total,
    required this.completed,
  });

  factory OperatorTripProgress.fromJson(Map<String, dynamic> json) {
    return OperatorTripProgress(
      collected: _parseInt(json['collected']) ?? 0,
      total: _parseInt(json['total']) ?? 0,
      completed: json['completed'] == true,
    );
  }

  double get fraction => total == 0 ? 0.0 : collected / total;
}

class OperatorTripWard {
  final String uniqueId;
  final String name;

  const OperatorTripWard({required this.uniqueId, required this.name});

  factory OperatorTripWard.fromJson(Map<String, dynamic> json) {
    return OperatorTripWard(
      uniqueId: json['unique_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class OperatorTripToday {
  final String assignmentUniqueId;
  final DateTime tripDate;
  final String status;
  final String? scheduledTime;
  final String? actualStartTime;
  final String? actualEndTime;
  // A trip is either panchayat- or ward-based; exactly one is set.
  final OperatorTripPanchayat? panchayat;
  final OperatorTripWard? ward;
  final OperatorTripWasteType wasteType;
  final OperatorTripVehicle? vehicle;
  final OperatorTripPlanBrief? tripPlan;
  final OperatorTripProgress progress;
  final List<OperatorTripCollectionPoint> collectionPoints;
  // Everyone working this vehicle today (driver + operator + extras). The
  // merged driver app renders this read-only so the driver knows their crew.
  final OperatorTripCrew? crew;

  const OperatorTripToday({
    required this.assignmentUniqueId,
    required this.tripDate,
    required this.status,
    required this.wasteType,
    required this.progress,
    required this.collectionPoints,
    this.panchayat,
    this.ward,
    this.vehicle,
    this.tripPlan,
    this.scheduledTime,
    this.actualStartTime,
    this.actualEndTime,
    this.crew,
  });

  /// Display name for the trip's service area (panchayat or ward).
  String get areaName =>
      panchayat?.name ?? ward?.name ?? '—';

  /// Adapt today's single-trip payload into the history *summary* shape the
  /// driver/operator screens already render. `my-trip-today` and trip-history
  /// describe the same DailyTripAssignment, so the overlapping fields map
  /// directly; history-only fields (staff block, plan, total weight, remarks)
  /// aren't part of this endpoint and stay null/zero.
  OperatorTripHistorySummary toHistorySummary() {
    return OperatorTripHistorySummary(
      assignmentUniqueId: assignmentUniqueId,
      tripDate: tripDate,
      status: status,
      scheduledTime: scheduledTime,
      actualStartTime: actualStartTime,
      actualEndTime: actualEndTime,
      panchayat: panchayat,
      ward: ward,
      wasteType: wasteType,
      vehicle: vehicle,
      tripPlan: tripPlan,
      progress: progress,
      totalWeightKg: 0.0,
    );
  }

  /// Adapt today's single-trip payload into the history *detail* shape. The
  /// collection points carry through directly; `events` is empty because
  /// `my-trip-today` doesn't embed the per-bin event log (the history detail
  /// endpoint does).
  OperatorTripHistoryDetail toHistoryDetail() {
    return OperatorTripHistoryDetail(
      summary: toHistorySummary(),
      collectionPoints: collectionPoints,
      events: const [],
    );
  }

  factory OperatorTripToday.fromJson(Map<String, dynamic> json) {
    return OperatorTripToday(
      assignmentUniqueId: json['assignment_unique_id']?.toString() ?? '',
      tripDate: DateTime.parse(json['trip_date'].toString()),
      status: json['status']?.toString() ?? 'Scheduled',
      scheduledTime: json['scheduled_time']?.toString(),
      actualStartTime: json['actual_start_time']?.toString(),
      actualEndTime: json['actual_end_time']?.toString(),
      panchayat: json['panchayat'] is Map
          ? OperatorTripPanchayat.fromJson(
              Map<String, dynamic>.from(json['panchayat'] as Map),
            )
          : null,
      ward: json['ward'] is Map
          ? OperatorTripWard.fromJson(
              Map<String, dynamic>.from(json['ward'] as Map),
            )
          : null,
      // Multi-waste-type trips can ship `waste_type: null`; fall back to a
      // harmless placeholder instead of crashing the parse.
      wasteType: json['waste_type'] is Map
          ? OperatorTripWasteType.fromJson(
              Map<String, dynamic>.from(json['waste_type'] as Map),
            )
          : const OperatorTripWasteType(uniqueId: '', name: ''),
      vehicle: json['vehicle'] is Map<String, dynamic>
          ? OperatorTripVehicle.fromJson(
              Map<String, dynamic>.from(json['vehicle'] as Map),
            )
          : null,
      tripPlan: json['trip_plan'] is Map
          ? OperatorTripPlanBrief.fromJson(
              Map<String, dynamic>.from(json['trip_plan'] as Map),
            )
          : null,
      progress: OperatorTripProgress.fromJson(
        Map<String, dynamic>.from(json['progress'] as Map),
      ),
      collectionPoints: (json['collection_points'] as List? ?? [])
          .map((e) => OperatorTripCollectionPoint.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      crew: json['crew'] is Map
          ? OperatorTripCrew.fromJson(
              Map<String, dynamic>.from(json['crew'] as Map),
            )
          : null,
    );
  }
}

/// One crew member on today's trip (driver / operator / extra operator),
/// as served by the `crew` block on `/operator-mobile/my-trip-today/`.
class OperatorTripCrewMember {
  final String uniqueId;
  final String? name;
  final String? empId;
  final String? role;
  final String? phone;
  final String? photoUrl;

  const OperatorTripCrewMember({
    required this.uniqueId,
    this.name,
    this.empId,
    this.role,
    this.phone,
    this.photoUrl,
  });

  String get displayName => (name?.trim().isNotEmpty == true) ? name! : '—';

  /// "Company Operator" → "Operator", "company_driver" → "Driver".
  String get roleLabel {
    final raw = (role ?? '').replaceAll('_', ' ').trim();
    if (raw.isEmpty) return '';
    final cleaned = raw.toLowerCase().startsWith('company ')
        ? raw.substring(8)
        : raw;
    if (cleaned.isEmpty) return '';
    return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'[\s_]+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty || parts.first == '—') return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory OperatorTripCrewMember.fromJson(Map<String, dynamic> json) {
    return OperatorTripCrewMember(
      uniqueId: json['unique_id']?.toString() ?? '',
      name: json['name']?.toString(),
      empId: json['emp_id']?.toString(),
      role: json['role']?.toString(),
      phone: json['phone']?.toString(),
      photoUrl: json['photo_url']?.toString(),
    );
  }
}

/// The full crew block: driver + primary operator + extra operators.
class OperatorTripCrew {
  final OperatorTripCrewMember? driver;
  final OperatorTripCrewMember? operator;
  final List<OperatorTripCrewMember> extraOperators;
  final bool isAltActive;
  final String? templateCode;
  final String? altTemplateCode;

  const OperatorTripCrew({
    this.driver,
    this.operator,
    this.extraOperators = const [],
    this.isAltActive = false,
    this.templateCode,
    this.altTemplateCode,
  });

  /// All operators on the vehicle (primary + extras).
  List<OperatorTripCrewMember> get operators => [
        if (operator != null) operator!,
        ...extraOperators,
      ];

  factory OperatorTripCrew.fromJson(Map<String, dynamic> json) {
    return OperatorTripCrew(
      driver: json['driver'] is Map
          ? OperatorTripCrewMember.fromJson(
              Map<String, dynamic>.from(json['driver'] as Map),
            )
          : null,
      operator: json['operator'] is Map
          ? OperatorTripCrewMember.fromJson(
              Map<String, dynamic>.from(json['operator'] as Map),
            )
          : null,
      extraOperators: (json['extra_operators'] as List? ?? [])
          .whereType<Map>()
          .map((e) =>
              OperatorTripCrewMember.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      isAltActive: json['is_alt_active'] == true,
      templateCode: json['template_code']?.toString(),
      altTemplateCode: json['alt_template_code']?.toString(),
    );
  }
}

class BinScanValidateResult {
  final OperatorTripBinBrief bin;
  final OperatorTripCollectionPointBrief collectionPoint;
  final OperatorTripCollectionPoint? tripCollectionPoint;
  final Map<String, dynamic> assignment;
  final OperatorTripProgress progress;

  const BinScanValidateResult({
    required this.bin,
    required this.collectionPoint,
    required this.assignment,
    required this.progress,
    this.tripCollectionPoint,
  });

  factory BinScanValidateResult.fromJson(Map<String, dynamic> json) {
    return BinScanValidateResult(
      bin: OperatorTripBinBrief.fromJson(
        Map<String, dynamic>.from(json['bin'] as Map),
      ),
      collectionPoint: OperatorTripCollectionPointBrief.fromJson(
        Map<String, dynamic>.from(json['collection_point'] as Map),
      ),
      tripCollectionPoint: json['trip_collection_point'] is Map
          ? OperatorTripCollectionPoint.fromJson({
              ...Map<String, dynamic>.from(json['trip_collection_point'] as Map),
              'collection_point': json['collection_point'],
              'bin': json['bin'],
            })
          : null,
      assignment: Map<String, dynamic>.from(json['assignment'] as Map),
      progress: OperatorTripProgress.fromJson(
        Map<String, dynamic>.from(json['trip_progress'] as Map),
      ),
    );
  }
}

class BinScanSubmitResult {
  final BinScanValidateResult context;
  final String eventUniqueId;
  final DateTime eventAt;
  final double collectedWeightKg;

  const BinScanSubmitResult({
    required this.context,
    required this.eventUniqueId,
    required this.eventAt,
    required this.collectedWeightKg,
  });

  factory BinScanSubmitResult.fromJson(Map<String, dynamic> json) {
    final event = Map<String, dynamic>.from(json['event'] as Map);
    return BinScanSubmitResult(
      context: BinScanValidateResult.fromJson(json),
      eventUniqueId: event['unique_id']?.toString() ?? '',
      eventAt: _parseDate(event['event_at']) ?? _parseDate(event['created_at']) ?? DateTime.now(),
      collectedWeightKg:
          _parseDouble(event['collected_weight_kg']) ?? 0.0,
    );
  }

  bool get tripCompleted => context.progress.completed;
}

/// One person (driver or operator) — used in trip history detail.
class OperatorTripStaffBrief {
  final String uniqueId;
  final String? username;
  final String? name;
  final String? phone;

  const OperatorTripStaffBrief({
    required this.uniqueId,
    this.username,
    this.name,
    this.phone,
  });

  String get displayName =>
      (name?.isNotEmpty == true ? name! : (username ?? '—'));

  factory OperatorTripStaffBrief.fromJson(Map<String, dynamic> json) {
    return OperatorTripStaffBrief(
      uniqueId: json['unique_id']?.toString() ?? '',
      username: json['username']?.toString(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

/// Driver + operator block on a trip, with substitution status.
class OperatorTripStaffBlock {
  final OperatorTripStaffBrief? driver;
  final OperatorTripStaffBrief? operator;
  final bool isAltActive;
  final String? templateCode;
  final String? altTemplateCode;

  const OperatorTripStaffBlock({
    this.driver,
    this.operator,
    this.isAltActive = false,
    this.templateCode,
    this.altTemplateCode,
  });

  factory OperatorTripStaffBlock.fromJson(Map<String, dynamic> json) {
    return OperatorTripStaffBlock(
      driver: json['driver'] is Map
          ? OperatorTripStaffBrief.fromJson(
              Map<String, dynamic>.from(json['driver'] as Map),
            )
          : null,
      operator: json['operator'] is Map
          ? OperatorTripStaffBrief.fromJson(
              Map<String, dynamic>.from(json['operator'] as Map),
            )
          : null,
      isAltActive: json['is_alt_active'] == true,
      templateCode: json['template_code']?.toString(),
      altTemplateCode: json['alt_template_code']?.toString(),
    );
  }
}

class OperatorTripPlanBrief {
  final String uniqueId;
  final String displayCode;

  const OperatorTripPlanBrief({
    required this.uniqueId,
    required this.displayCode,
  });

  factory OperatorTripPlanBrief.fromJson(Map<String, dynamic> json) {
    return OperatorTripPlanBrief(
      uniqueId: json['unique_id']?.toString() ?? '',
      displayCode: json['display_code']?.toString() ?? '',
    );
  }
}

class OperatorTripHistorySummary {
  final String assignmentUniqueId;
  final DateTime tripDate;
  final String status;
  final String? approvalStatus;
  final String? scheduledTime;
  final String? actualStartTime;
  final String? actualEndTime;
  final OperatorTripPanchayat? panchayat;
  final OperatorTripWard? ward;
  final OperatorTripWasteType wasteType;
  final OperatorTripVehicle? vehicle;
  final OperatorTripStaffBlock? staff;
  final OperatorTripPlanBrief? tripPlan;
  final OperatorTripProgress progress;
  final double totalWeightKg;
  final String? remarks;

  const OperatorTripHistorySummary({
    required this.assignmentUniqueId,
    required this.tripDate,
    required this.status,
    required this.wasteType,
    required this.progress,
    required this.totalWeightKg,
    this.approvalStatus,
    this.scheduledTime,
    this.actualStartTime,
    this.actualEndTime,
    this.panchayat,
    this.ward,
    this.vehicle,
    this.staff,
    this.tripPlan,
    this.remarks,
  });

  String get areaName =>
      panchayat?.name ?? ward?.name ?? '—';

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isInProgress => status.toLowerCase() == 'in progress';
  bool get isScheduled => status.toLowerCase() == 'scheduled';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  /// Estimated duration if both start + end are known.
  Duration? get duration {
    final start = _timeToToday(actualStartTime, tripDate);
    final end = _timeToToday(actualEndTime, tripDate);
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    return diff.isNegative ? null : diff;
  }

  factory OperatorTripHistorySummary.fromJson(Map<String, dynamic> json) {
    return OperatorTripHistorySummary(
      assignmentUniqueId: json['assignment_unique_id']?.toString() ?? '',
      tripDate: DateTime.parse(json['trip_date'].toString()),
      status: json['status']?.toString() ?? '',
      approvalStatus: json['approval_status']?.toString(),
      scheduledTime: json['scheduled_time']?.toString(),
      actualStartTime: json['actual_start_time']?.toString(),
      actualEndTime: json['actual_end_time']?.toString(),
      panchayat: json['panchayat'] is Map
          ? OperatorTripPanchayat.fromJson(
              Map<String, dynamic>.from(json['panchayat'] as Map),
            )
          : null,
      ward: json['ward'] is Map
          ? OperatorTripWard.fromJson(
              Map<String, dynamic>.from(json['ward'] as Map),
            )
          : null,
      vehicle: json['vehicle'] is Map
          ? OperatorTripVehicle.fromJson(
              Map<String, dynamic>.from(json['vehicle'] as Map),
            )
          : null,
      staff: json['staff'] is Map
          ? OperatorTripStaffBlock.fromJson(
              Map<String, dynamic>.from(json['staff'] as Map),
            )
          : null,
      tripPlan: json['trip_plan'] is Map
          ? OperatorTripPlanBrief.fromJson(
              Map<String, dynamic>.from(json['trip_plan'] as Map),
            )
          : null,
      remarks: json['remarks']?.toString(),
      wasteType: OperatorTripWasteType.fromJson(
        Map<String, dynamic>.from(json['waste_type'] as Map),
      ),
      progress: OperatorTripProgress.fromJson(
        Map<String, dynamic>.from(json['progress'] as Map),
      ),
      totalWeightKg: _parseDouble(json['total_weight_kg']) ?? 0.0,
    );
  }
}

class BinCollectionEventEntry {
  final String uniqueId;
  final DateTime eventAt;
  final double collectedWeightKg;
  final String scannedQr;
  final String binName;
  final String cpName;
  final double? latitude;
  final double? longitude;
  final String? notes;

  const BinCollectionEventEntry({
    required this.uniqueId,
    required this.eventAt,
    required this.collectedWeightKg,
    required this.scannedQr,
    required this.binName,
    required this.cpName,
    this.latitude,
    this.longitude,
    this.notes,
  });

  factory BinCollectionEventEntry.fromJson(Map<String, dynamic> json) {
    final bin = json['bin'] is Map ? Map<String, dynamic>.from(json['bin'] as Map) : const <String, dynamic>{};
    final cp = json['collection_point'] is Map
        ? Map<String, dynamic>.from(json['collection_point'] as Map)
        : const <String, dynamic>{};
    return BinCollectionEventEntry(
      uniqueId: json['unique_id']?.toString() ?? '',
      eventAt: _parseDate(json['event_at']) ?? _parseDate(json['created_at']) ?? DateTime.now(),
      collectedWeightKg: _parseDouble(json['collected_weight_kg']) ?? 0.0,
      scannedQr: json['scanned_qr']?.toString() ?? bin['unique_id']?.toString() ?? '',
      binName: bin['bin_name']?.toString() ?? '',
      cpName: cp['name']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      notes: json['notes']?.toString(),
    );
  }
}

class OperatorTripHistoryDetail {
  final OperatorTripHistorySummary summary;
  final List<OperatorTripCollectionPoint> collectionPoints;
  final List<BinCollectionEventEntry> events;

  const OperatorTripHistoryDetail({
    required this.summary,
    required this.collectionPoints,
    required this.events,
  });

  factory OperatorTripHistoryDetail.fromJson(Map<String, dynamic> json) {
    return OperatorTripHistoryDetail(
      summary: OperatorTripHistorySummary.fromJson(json),
      collectionPoints: (json['collection_points'] as List? ?? [])
          .map((e) => OperatorTripCollectionPoint.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      events: (json['events'] as List? ?? [])
          .map((e) => BinCollectionEventEntry.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

/// Combine an `HH:mm[:ss[.ffff]]` time string with a base date so we can
/// compute durations across `actual_start_time` / `actual_end_time`.
DateTime? _timeToToday(String? raw, DateTime baseDate) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);
  if (hh == null || mm == null) return null;
  int ss = 0;
  if (parts.length >= 3) {
    final secPart = parts[2].split('.').first;
    ss = int.tryParse(secPart) ?? 0;
  }
  return DateTime(baseDate.year, baseDate.month, baseDate.day, hh, mm, ss);
}
