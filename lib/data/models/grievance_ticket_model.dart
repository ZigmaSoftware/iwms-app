import 'package:equatable/equatable.dart';

/// A single event on the citizen-visible timeline.
class GrievanceTimelineEvent extends Equatable {
  final String statusCode;
  final String statusName;
  final DateTime? at;
  final String? remarks;

  const GrievanceTimelineEvent({
    required this.statusCode,
    required this.statusName,
    this.at,
    this.remarks,
  });

  factory GrievanceTimelineEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return GrievanceTimelineEvent(
      statusCode: json['status_code']?.toString() ?? '',
      statusName: json['status_name']?.toString() ?? '',
      at: parseDate(json['at']),
      remarks: json['remarks']?.toString(),
    );
  }

  @override
  List<Object?> get props => [statusCode, statusName, at, remarks];
}

/// A grievance ticket (shared by citizen + supervisor screens).
class GrievanceTicket extends Equatable {
  final String uniqueId;
  final String ticketNo;
  final String? title;
  final String? description;
  final String? categoryName;
  final String? subcategoryName;
  final String? priorityCode;
  final String? statusCode;
  final String? statusName;
  final String? assignedTeamName;
  final String? assignedStaffName;
  final String? assignedDepartmentName;
  final String? locationText;
  final String? waPhone;
  final String? customerName;
  final DateTime? createdAt;
  final DateTime? slaDueAt;
  final List<GrievanceTimelineEvent> timeline;

  const GrievanceTicket({
    required this.uniqueId,
    required this.ticketNo,
    this.title,
    this.description,
    this.categoryName,
    this.subcategoryName,
    this.priorityCode,
    this.statusCode,
    this.statusName,
    this.assignedTeamName,
    this.assignedStaffName,
    this.assignedDepartmentName,
    this.locationText,
    this.waPhone,
    this.customerName,
    this.createdAt,
    this.slaDueAt,
    this.timeline = const [],
  });

  bool get isFinal =>
      const {'RESOLVED', 'CLOSED', 'REJECTED', 'CANCELLED'}.contains(statusCode);

  factory GrievanceTicket.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    final tl = (json['public_timeline'] as List?) ?? const [];
    return GrievanceTicket(
      uniqueId: json['unique_id']?.toString() ?? '',
      ticketNo: json['ticket_no']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      categoryName: json['category_name']?.toString(),
      subcategoryName: json['subcategory_name']?.toString(),
      priorityCode: json['priority_code']?.toString(),
      statusCode: json['status_code']?.toString(),
      statusName: json['status_name']?.toString(),
      assignedTeamName: json['assigned_team_name']?.toString(),
      assignedStaffName: json['assigned_staff_name']?.toString(),
      assignedDepartmentName: json['assigned_department_name']?.toString(),
      locationText: json['location_text']?.toString(),
      waPhone: json['wa_phone']?.toString(),
      customerName: json['customer_name']?.toString(),
      createdAt: parseDate(json['created']),
      slaDueAt: parseDate(json['sla_due_at']),
      timeline: tl
          .map((e) => GrievanceTimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [uniqueId, ticketNo, statusCode, assignedTeamName];
}

/// Category + priority choices for the citizen chat (from the `meta` endpoint).
class GrievanceCategoryOption extends Equatable {
  final String uniqueId;
  final String code;
  final String name;
  final String? defaultPriority; // priority unique_id
  final String? defaultPriorityCode;
  final bool requiresLocation;

  const GrievanceCategoryOption({
    required this.uniqueId,
    required this.code,
    required this.name,
    this.defaultPriority,
    this.defaultPriorityCode,
    this.requiresLocation = false,
  });

  factory GrievanceCategoryOption.fromJson(Map<String, dynamic> json) {
    return GrievanceCategoryOption(
      uniqueId: json['unique_id']?.toString() ?? '',
      code: json['category_code']?.toString() ?? '',
      name: json['category_name']?.toString() ?? '',
      defaultPriority: json['default_priority']?.toString(),
      defaultPriorityCode: json['default_priority_code']?.toString(),
      requiresLocation: json['requires_location'] == true,
    );
  }

  @override
  List<Object?> get props => [uniqueId];
}

class GrievanceSubcategoryOption extends Equatable {
  final String uniqueId;
  final String category; // parent category unique_id
  final String name;

  const GrievanceSubcategoryOption({
    required this.uniqueId,
    required this.category,
    required this.name,
  });

  factory GrievanceSubcategoryOption.fromJson(Map<String, dynamic> json) {
    return GrievanceSubcategoryOption(
      uniqueId: json['unique_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      name: json['subcategory_name']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [uniqueId];
}

class GrievanceMeta {
  final List<GrievanceCategoryOption> categories;
  final List<GrievanceSubcategoryOption> subcategories;

  const GrievanceMeta({this.categories = const [], this.subcategories = const []});

  factory GrievanceMeta.fromJson(Map<String, dynamic> json) {
    return GrievanceMeta(
      categories: ((json['categories'] as List?) ?? const [])
          .map((e) => GrievanceCategoryOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      subcategories: ((json['subcategories'] as List?) ?? const [])
          .map((e) => GrievanceSubcategoryOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  List<GrievanceSubcategoryOption> subFor(String categoryId) =>
      subcategories.where((s) => s.category == categoryId).toList();
}
