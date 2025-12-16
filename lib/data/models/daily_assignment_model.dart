class DailyAssignmentModel {
  final int id;
  final String ward;
  final String driver;
  final String operatorName;
  final String assignmentType;
  final String shift;
  final bool isActive;

  DailyAssignmentModel({
    required this.id,
    required this.ward,
    required this.driver,
    required this.operatorName,
    required this.assignmentType,
    required this.shift,
    required this.isActive,
  });

  factory DailyAssignmentModel.fromJson(Map<String, dynamic> json) {
    return DailyAssignmentModel(
      id: json['id'],
      ward: json['ward_name'] ?? json['ward'],
      driver: json['driver_name'] ?? json['driver'],
      operatorName: json['operator_name'] ?? '',
      assignmentType: json['assignment_type'] ?? '',
      shift: json['shift'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }
}
