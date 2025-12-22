import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';

class DailyAssignmentModel {
  final int id;
  final String uniqueId;
  final String ward;
  final String driver;
  final String operatorName;
  final String assignmentType;
  final String shift;
  final bool isActive;
  final DateTime date;
  final String? customerName;
  final String? cancelledReason;
  final DateTime? cancelledAt;
  final AssignmentStatus currentStatus;
  final DateTime? completedAt;
  final DateTime? skippedAt;
  final String? skipReason;
  final AssignmentRoleStatus driverStatus;
  final AssignmentRoleStatus operatorStatus;
  final DateTime? driverCompletedAt;
  final DateTime? operatorCompletedAt;

  DailyAssignmentModel({
    required this.id,
    required this.uniqueId,
    required this.ward,
    required this.driver,
    required this.operatorName,
    required this.assignmentType,
    required this.shift,
    required this.isActive,
    required this.date,
    required this.currentStatus,
    this.completedAt,
    this.skippedAt,
    this.skipReason,
    this.customerName,
    this.cancelledReason,
    this.cancelledAt,
    this.driverStatus = AssignmentRoleStatus.pending,
    this.operatorStatus = AssignmentRoleStatus.pending,
    this.driverCompletedAt,
    this.operatorCompletedAt,
  });

  factory DailyAssignmentModel.fromJson(Map<String, dynamic> json) {
    return DailyAssignmentModel(
      id: json['id'] ?? 0,
      uniqueId: json['unique_id']?.toString() ?? '',
      ward: json['ward_name'] ?? json['ward'] ?? 'Unknown Ward',
      driver: json['driver_name'] ?? json['driver'] ?? 'Unknown Driver',
      operatorName: json['operator_name'] ?? 'Unknown Operator',
      assignmentType: json['assignment_type'] ?? 'primary',
      shift: json['shift'] ?? 'full_day',
      isActive: json['is_active'] ?? true,
      currentStatus: AssignmentStatus.fromString(json['current_status']),
      driverStatus: AssignmentRoleStatus.fromString(json['driver_status']),
      operatorStatus: AssignmentRoleStatus.fromString(json['operator_status']),
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      customerName: json['customer_name'],
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
    );
  }

  String get shiftDisplay => shift.replaceAll('_', ' ').toUpperCase();

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

  Color get statusColor => currentStatus.color;
  String get statusLabel => currentStatus.displayName;
}
