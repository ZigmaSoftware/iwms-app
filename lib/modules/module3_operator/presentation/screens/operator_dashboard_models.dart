class OperatorNextStop {
  const OperatorNextStop({
    String? locationName,
    String? scheduledTime,
    this.remainingPickups,
    this.isDelayed,
    this.routeName,
    this.status,
    // Deprecated: prefer locationName
    this.label,
    // Deprecated: prefer scheduledTime
    this.timeRemaining,
  })  : locationName = locationName ?? label ?? '',
        scheduledTime = scheduledTime ?? timeRemaining ?? '';

  /// Preferred: human-readable location for the next stop.
  final String locationName;

  /// Preferred: scheduled arrival/collection time.
  final String scheduledTime;

  /// Optional: remaining pickups on this route.
  final int? remainingPickups;

  /// Optional: whether this stop is delayed.
  final bool? isDelayed;

  /// Optional route name/identifier.
  final String? routeName;

  /// Optional status string (e.g., En-route, Paused).
  final String? status;

  // Deprecated: legacy UI fields
  final String? label;
  final String? timeRemaining;

  OperatorNextStop copyWith({
    String? locationName,
    String? scheduledTime,
    int? remainingPickups,
    bool? isDelayed,
    String? routeName,
    String? status,
    String? label,
    String? timeRemaining,
  }) {
    return OperatorNextStop(
      locationName: locationName ?? this.locationName,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      remainingPickups: remainingPickups ?? this.remainingPickups,
      isDelayed: isDelayed ?? this.isDelayed,
      routeName: routeName ?? this.routeName,
      status: status ?? this.status,
      label: label ?? this.label,
      timeRemaining: timeRemaining ?? this.timeRemaining,
    );
  }
}

class OperatorCollectionSummary {
  const OperatorCollectionSummary({
    this.firstPickupAt = '',
    this.lastPickupAt = '',
    this.totalWetKg = 0,
    this.totalDryKg = 0,
    this.totalMixedKg = 0,
    this.totalPickups = 0,
    // Deprecated: prefer firstPickupAt/lastPickupAt & totals
    this.collectedAt,
    this.wetKg,
    this.dryKg,
    this.timeTaken,
  });

  /// Time of the first pickup recorded today.
  final String firstPickupAt;

  /// Time of the last pickup recorded today.
  final String lastPickupAt;

  final double totalWetKg;
  final double totalDryKg;
  final double totalMixedKg;
  final int totalPickups;

  // Deprecated: legacy fields
  final String? collectedAt;
  final double? wetKg;
  final double? dryKg;
  final String? timeTaken;

  OperatorCollectionSummary copyWith({
    String? firstPickupAt,
    String? lastPickupAt,
    double? totalWetKg,
    double? totalDryKg,
    double? totalMixedKg,
    int? totalPickups,
    String? collectedAt,
    double? wetKg,
    double? dryKg,
    String? timeTaken,
  }) {
    return OperatorCollectionSummary(
      firstPickupAt: firstPickupAt ?? this.firstPickupAt,
      lastPickupAt: lastPickupAt ?? this.lastPickupAt,
      totalWetKg: totalWetKg ?? this.totalWetKg,
      totalDryKg: totalDryKg ?? this.totalDryKg,
      totalMixedKg: totalMixedKg ?? this.totalMixedKg,
      totalPickups: totalPickups ?? this.totalPickups,
      collectedAt: collectedAt ?? this.collectedAt,
      wetKg: wetKg ?? this.wetKg,
      dryKg: dryKg ?? this.dryKg,
      timeTaken: timeTaken ?? this.timeTaken,
    );
  }
}

class OperatorAttendanceSummary {
  const OperatorAttendanceSummary({
    this.todayStatus = '',
    this.checkInTime = '',
    this.checkOutTime = '',
    // Deprecated/optional: profile-level stats
    this.monthStat,
    this.leaveBalance,
    this.streakLabel,
    this.streakValue,
  });

  /// Required: current day's status (Present/Absent/On Leave).
  final String todayStatus;

  /// Actual check-in time for today.
  final String checkInTime;

  /// Actual check-out time for today.
  final String checkOutTime;

  // Deprecated/optional fields
  final String? monthStat;
  final String? leaveBalance;
  final String? streakLabel;
  final String? streakValue;

  OperatorAttendanceSummary copyWith({
    String? todayStatus,
    String? checkInTime,
    String? checkOutTime,
    String? monthStat,
    String? leaveBalance,
    String? streakLabel,
    String? streakValue,
  }) {
    return OperatorAttendanceSummary(
      todayStatus: todayStatus ?? this.todayStatus,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      monthStat: monthStat ?? this.monthStat,
      leaveBalance: leaveBalance ?? this.leaveBalance,
      streakLabel: streakLabel ?? this.streakLabel,
      streakValue: streakValue ?? this.streakValue,
    );
  }
}

class OperatorContactInfo {
  const OperatorContactInfo({
    this.phone = '',
    this.email = '',
    this.designation,
    this.address,
  });

  final String phone;
  final String email;
  final String? designation;
  final String? address;

  OperatorContactInfo copyWith({
    String? phone,
    String? email,
    String? designation,
    String? address,
  }) {
    return OperatorContactInfo(
      phone: phone ?? this.phone,
      email: email ?? this.email,
      designation: designation ?? this.designation,
      address: address ?? this.address,
    );
  }
}

class OperatorSessionDetails {
  const OperatorSessionDetails({
    required this.displayName,
    required this.operatoremp_id,
    required this.operatorCode,
    this.wardLabel = '',
    this.zoneLabel = '',
    this.shift = '',
    this.contactInfo = const OperatorContactInfo(),
  });

  final String displayName;
  final String operatorCode;
  final String operatoremp_id;
  final String wardLabel;
  final String zoneLabel;
  final String shift;
  final OperatorContactInfo contactInfo;

  OperatorSessionDetails copyWith({
    String? displayName,
    String? operatorCode,
    String? wardLabel,
    String? zoneLabel,
    String? shift,
    OperatorContactInfo? contactInfo,
  }) {
    return OperatorSessionDetails(
      displayName: displayName ?? this.displayName,
      operatorCode: operatorCode ?? this.operatorCode,
      wardLabel: wardLabel ?? this.wardLabel,
      zoneLabel: zoneLabel ?? this.zoneLabel,
      shift: shift ?? this.shift,
      contactInfo: contactInfo ?? this.contactInfo,
      operatoremp_id:operatoremp_id
    );
  }
}
