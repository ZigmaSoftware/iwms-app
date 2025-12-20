import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendance_home_operator.dart';

/// Wrapper widget so the attendance module can be slotted inside the new tab UI
/// without altering any of its internal business logic.
class OperatorAttendanceScreenIntegration extends StatelessWidget {
  const OperatorAttendanceScreenIntegration({
    super.key,
    this.operatorName = '',
    this.operatorCode = '',
  });

  final String operatorName;
  final String operatorCode;

  @override
  Widget build(BuildContext context) {
    return AttendancePage(
      operatorName: operatorName,
      operatorCode: operatorCode,
    );
  }
}
