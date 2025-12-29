import 'package:flutter/material.dart';

enum AssignmentStatus {
  pending,
  inProgress,
  completed,
  skipped,
  cancelled;

  String get displayName {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Pending';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.skipped:
        return 'Skipped';
      case AssignmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case AssignmentStatus.pending:
        return const Color(0xFFFF9800);
      case AssignmentStatus.inProgress:
        return const Color(0xFF2196F3);
      case AssignmentStatus.completed:
        return const Color(0xFF4CAF50);
      case AssignmentStatus.skipped:
        return const Color(0xFFFFEB3B);
      case AssignmentStatus.cancelled:
        return const Color(0xFFF44336);
    }
  }

  IconData get icon {
    switch (this) {
      case AssignmentStatus.pending:
        return Icons.schedule;
      case AssignmentStatus.inProgress:
        return Icons.directions_car;
      case AssignmentStatus.completed:
        return Icons.check_circle;
      case AssignmentStatus.skipped:
        return Icons.skip_next;
      case AssignmentStatus.cancelled:
        return Icons.cancel;
    }
  }

  static AssignmentStatus fromString(String? status) {
    if (status == null) return AssignmentStatus.pending;
    switch (status.toLowerCase()) {
      case 'in_progress':
        return AssignmentStatus.inProgress;
      case 'completed':
        return AssignmentStatus.completed;
      case 'skipped':
        return AssignmentStatus.skipped;
      case 'cancelled':
        return AssignmentStatus.cancelled;
      default:
        return AssignmentStatus.pending;
    }
  }
}

enum AssignmentRoleStatus {
  pending,
  completed;

  String get displayName {
    switch (this) {
      case AssignmentRoleStatus.pending:
        return 'Pending';
      case AssignmentRoleStatus.completed:
        return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case AssignmentRoleStatus.pending:
        return const Color(0xFFFFB300);
      case AssignmentRoleStatus.completed:
        return const Color(0xFF43A047);
    }
  }

  IconData get icon {
    switch (this) {
      case AssignmentRoleStatus.pending:
        return Icons.schedule;
      case AssignmentRoleStatus.completed:
        return Icons.check_circle;
    }
  }

  static AssignmentRoleStatus fromString(String? status) {
    if (status == null) return AssignmentRoleStatus.pending;
    switch (status.toLowerCase()) {
      case 'completed':
        return AssignmentRoleStatus.completed;
      default:
        return AssignmentRoleStatus.pending;
    }
  }
}

class StaffMember {
  final String uniqueId;
  final String name;
  final String role; // driver or operator
  final String? employeeId;
  final String? phone;
  final String? vehicleNumber;

  StaffMember({
    required this.uniqueId,
    required this.name,
    required this.role,
    this.employeeId,
    this.phone,
    this.vehicleNumber,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      uniqueId: json['unique_id']?.toString() ?? '',
      name: json['staff_name'] ??
          json['employee_name'] ??
          json['name'] ??
          'Unknown',
      role: json['staffusertype_name']?.toString().toLowerCase() ?? 'staff',
      employeeId: json['emp_id']?.toString(),
      phone: json['phone']?.toString(),
      vehicleNumber: json['vehicle_number']?.toString(),
    );
  }
}

class AssignmentStatusHistoryEntry {
  final int id;
  final String status;
  final String? changedBy;
  final String? reason;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AssignmentStatusHistoryEntry({
    required this.id,
    required this.status,
    this.changedBy,
    this.reason,
    required this.timestamp,
    this.metadata,
  });

  factory AssignmentStatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AssignmentStatusHistoryEntry(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'unknown',
      changedBy: json['changed_by_name'],
      reason: json['reason'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class CollectionLogEntry {
  final int id;
  final String action;
  final String? driverName;
  final String? skipReason;
  final double? wasteWeight;
  final DateTime timestamp;
  final String? notes;

  CollectionLogEntry({
    required this.id,
    required this.action,
    this.driverName,
    this.skipReason,
    this.wasteWeight,
    required this.timestamp,
    this.notes,
  });

  factory CollectionLogEntry.fromJson(Map<String, dynamic> json) {
    return CollectionLogEntry(
      id: json['id'] ?? 0,
      action: json['action'] ?? '',
      driverName: json['driver_name'],
      skipReason: json['skip_reason'],
      wasteWeight: json['waste_weight'] != null
          ? double.tryParse(json['waste_weight'].toString())
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      notes: json['notes'],
    );
  }

  String get displayAction {
    switch (action) {
      case 'started_navigation':
        return 'Started Navigation';
      case 'arrived':
        return 'Arrived at Location';
      case 'collection_started':
        return 'Collection Started';
      case 'collection_completed':
        return 'Collection Completed';
      case 'skipped':
        return 'Skipped';
      default:
        return action;
    }
  }
}

class AssignmentCustomerStatusEntry {
  final int id;
  final String customerId;
  final String customerName;
  final String status;
  final String? skipReason;
  final DateTime? updatedAt;

  AssignmentCustomerStatusEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.status,
    this.skipReason,
    this.updatedAt,
  });

  factory AssignmentCustomerStatusEntry.fromJson(Map<String, dynamic> json) {
    return AssignmentCustomerStatusEntry(
      id: json['id'] ?? 0,
      customerId: json['customer']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Citizen',
      status: json['status']?.toString() ?? 'pending',
      skipReason: json['skip_reason'],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'collected':
        return 'Collected';
      case 'skipped':
        return 'Skipped';
      case 'later':
        return 'Later';
      default:
        return 'Pending';
    }
  }
}

class EnhancedAssignmentModel {
  final int id;
  final String uniqueId;
  final DateTime date;
  final String ward;
  final String driver;
  final String operatorName;
  final String assignmentType;
  final String shift;
  final AssignmentStatus currentStatus;
  final AssignmentRoleStatus driverStatus;
  final AssignmentRoleStatus operatorStatus;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? driverCompletedAt;
  final DateTime? operatorCompletedAt;
  final DateTime? skippedAt;
  final String? skipReason;
  final DateTime? cancelledAt;
  final String? cancelledReason;
  final List<AssignmentStatusHistoryEntry> statusHistory;
  final List<CollectionLogEntry> collectionLogs;
  final List<AssignmentCustomerStatusEntry> customerStatuses;
  final int totalStatusChanges;

  EnhancedAssignmentModel({
    required this.id,
    required this.uniqueId,
    required this.date,
    required this.ward,
    required this.driver,
    required this.operatorName,
    required this.assignmentType,
    required this.shift,
    required this.currentStatus,
    this.driverStatus = AssignmentRoleStatus.pending,
    this.operatorStatus = AssignmentRoleStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.driverCompletedAt,
    this.operatorCompletedAt,
    this.skippedAt,
    this.skipReason,
    this.cancelledAt,
    this.cancelledReason,
    this.statusHistory = const [],
    this.collectionLogs = const [],
    this.customerStatuses = const [],
    this.totalStatusChanges = 0,
  });

  factory EnhancedAssignmentModel.fromJson(Map<String, dynamic> json) {
    return EnhancedAssignmentModel(
      id: json['id'] ?? 0,
      uniqueId: json['unique_id']?.toString() ?? '',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      ward: json['ward_name'] ?? 'Unknown Ward',
      driver: json['driver_name'] ?? 'Unknown Driver',
      operatorName: json['operator_name'] ?? 'Unknown Operator',
      assignmentType: json['assignment_type'] ?? 'primary',
      shift: json['shift'] ?? 'full_day',
      currentStatus: AssignmentStatus.fromString(json['current_status']),
      driverStatus: AssignmentRoleStatus.fromString(json['driver_status']),
      operatorStatus: AssignmentRoleStatus.fromString(json['operator_status']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      driverCompletedAt: json['driver_completed_at'] != null
          ? DateTime.parse(json['driver_completed_at'])
          : null,
      operatorCompletedAt: json['operator_completed_at'] != null
          ? DateTime.parse(json['operator_completed_at'])
          : null,
      skippedAt: json['skipped_at'] != null
          ? DateTime.parse(json['skipped_at'])
          : null,
      skipReason: json['skip_reason'],
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
      cancelledReason: json['cancelled_reason'],
      statusHistory: (json['status_history'] as List?)
              ?.map((e) => AssignmentStatusHistoryEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [],
      collectionLogs: (json['collection_logs'] as List?)
              ?.map((e) => CollectionLogEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [],
      customerStatuses: (json['customer_statuses'] as List?)
              ?.map((e) => AssignmentCustomerStatusEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [],
      totalStatusChanges: json['total_status_changes'] ?? 0,
    );
  }
}

class StaffAssignmentSummary {
  final int totalAssignments;
  final int completed;
  final int skipped;
  final int cancelled;
  final int inProgress;
  final int pending;

  StaffAssignmentSummary({
    required this.totalAssignments,
    required this.completed,
    required this.skipped,
    required this.cancelled,
    required this.inProgress,
    required this.pending,
  });

  factory StaffAssignmentSummary.fromJson(Map<String, dynamic> json) {
    return StaffAssignmentSummary(
      totalAssignments: json['total_assignments'] ?? 0,
      completed: json['completed'] ?? 0,
      skipped: json['skipped'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      inProgress: json['in_progress'] ?? 0,
      pending: json['pending'] ?? 0,
    );
  }

  double get completionRate {
    if (totalAssignments == 0) return 0;
    return (completed / totalAssignments) * 100;
  }
}
