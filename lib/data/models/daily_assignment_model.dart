import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';

class DailyAssignmentModel {
  final int id;
  final String uniqueId;
  final String ward;
  final String wardId;
  final String driver;
  final String operatorName;
  final String assignmentType;
  final String shift;
  final bool isActiveFlag;
  final DateTime date;
  final String? customerName; 
  final String? customerId;
  final String? cancelledReason;
  final DateTime? cancelledAt;
  final AssignmentStatus currentStatus;
  final String? currentStatusRaw;
  final DateTime? completedAt;
  final DateTime? skippedAt;
  final String? skipReason;
  final AssignmentRoleStatus driverStatus;
  final AssignmentRoleStatus operatorStatus;
  final DateTime? driverCompletedAt;
  final DateTime? operatorCompletedAt;
  final List<AssignmentCustomerStatusEntry> customerStatuses;

  DailyAssignmentModel({
    required this.id,
    required this.uniqueId,
    required this.ward,
    this.wardId = '',
    required this.driver,
    required this.operatorName,
    required this.assignmentType,
    required this.shift,
    required this.isActiveFlag,
    required this.date,
    required this.currentStatus,
    this.currentStatusRaw,
    this.completedAt,
    this.skippedAt,
    this.skipReason,
    this.customerName,
    this.customerId,
    this.cancelledReason,
    this.cancelledAt,
    this.driverStatus = AssignmentRoleStatus.pending,
    this.operatorStatus = AssignmentRoleStatus.pending,
    this.driverCompletedAt,
    this.operatorCompletedAt,
    this.customerStatuses = const [],
  });

  factory DailyAssignmentModel.fromJson(Map<String, dynamic> json) {
    return DailyAssignmentModel(
      id: json['id'] ?? 0,
      uniqueId: json['unique_id']?.toString() ?? '',
      wardId: (json['ward'] ?? json['ward_id'] ?? '').toString(),
      ward: json['ward_name'] ?? json['ward'] ?? 'Unknown Ward',
      driver: json['driver_name'] ?? json['driver'] ?? 'Unknown Driver',
      operatorName: json['operator_name'] ?? 'Unknown Operator',
      assignmentType: json['assignment_type'] ?? 'primary',
      shift: json['shift'] ?? 'full_day',
      isActiveFlag: json['is_active'] ?? true,
      currentStatus: AssignmentStatus.fromString(json['current_status']),
      currentStatusRaw: json['current_status']?.toString(),
      driverStatus: AssignmentRoleStatus.fromString(json['driver_status']),
      operatorStatus: AssignmentRoleStatus.fromString(json['operator_status']),
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      customerName: json['customer_name'],
      customerId: json['customer']?.toString(),
      cancelledReason: json['cancelled_reason'],
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      driverCompletedAt: json['driver_completed_at'] != null
          ? DateTime.tryParse(json['driver_completed_at'])
          : null,
      operatorCompletedAt: json['operator_completed_at'] != null
          ? DateTime.tryParse(json['operator_completed_at'])
          : null,
      skippedAt: json['skipped_at'] != null
          ? DateTime.tryParse(json['skipped_at'])
          : null,
      skipReason: json['skip_reason'],
      customerStatuses: (json['customer_statuses'] as List?)
              ?.map((e) => AssignmentCustomerStatusEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          const [],
    );
  }

  String get shiftDisplay => shift.replaceAll('_', ' ').toUpperCase();

  String get statusKey {
    final raw = currentStatusRaw?.toLowerCase().trim() ?? '';
    if (raw.isNotEmpty) {
      return raw.replaceAll(' ', '_');
    }
    switch (currentStatus) {
      case AssignmentStatus.inProgress:
        return 'in_progress';
      case AssignmentStatus.completed:
        return 'completed';
      case AssignmentStatus.skipped:
        return 'skipped';
      case AssignmentStatus.cancelled:
        return 'cancelled';
      case AssignmentStatus.pending:
      default:
        return 'pending';
    }
  }

  bool get isActive {
    switch (statusKey) {
      case 'pending':
      case 'assigned':
      case 'in_progress':
        return true;
      case 'completed':
      case 'skipped':
      case 'cancelled':
      case 'failed':
      case 'expired':
        return false;
      default:
        return isActiveFlag ||
            currentStatus == AssignmentStatus.pending ||
            currentStatus == AssignmentStatus.inProgress;
    }
  }

  bool get isHistory => !isActive;

  String get typeDisplay {
    switch (assignmentType.toLowerCase()) {
      case 'temporary':
        return 'TEMPORARY';
      case 'emergency':
        return 'EMERGENCY';
      default:
        return 'PRIMARY';
    }
  }

  Color get typeColor {
    switch (assignmentType.toLowerCase()) {
      case 'temporary':
        return const Color(0xFFF57C00);
      case 'emergency':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Color get typeBgColor {
    switch (assignmentType.toLowerCase()) {
      case 'temporary':
        return const Color(0xFFFFF3E0);
      case 'emergency':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  Color get statusColor {
    switch (statusKey) {
      case 'assigned':
        return const Color(0xFF2196F3);
      case 'failed':
        return const Color(0xFFD32F2F);
      case 'expired':
        return const Color(0xFF616161);
      default:
        return currentStatus.color;
    }
  }

  String get statusLabel {
    switch (statusKey) {
      case 'assigned':
        return 'Assigned';
      case 'failed':
        return 'Failed';
      case 'expired':
        return 'Expired';
      default:
        return currentStatus.displayName;
    }
  }
}
