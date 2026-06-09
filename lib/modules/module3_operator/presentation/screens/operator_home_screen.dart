// operator_home_screen.dart
// Operator dashboard: shows the operator identity header on top, then today's
// trip (panchayat, vehicle, list of collection points) inline. Tapping the
// Scan-Bin-QR FAB opens the universal scanner that validates against the
// active trip and submits the collection event.

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_trip_home_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_header.dart';

class OperatorHomeScreen extends StatefulWidget {
  const OperatorHomeScreen({
    super.key,
    required this.operatorName,
    required this.operatorCode,
    required this.emp_id,
    required this.employeeCode,
    required this.wardLabel,
    required this.zoneLabel,
    required this.onScanPressed,
    required this.onLogout,
    this.designation,
    this.onOpenAssignments,
    this.onOpenProfile,
    this.nextStop,
    this.lastCollection,
    this.attendanceSummary,
  });

  final String operatorName;
  final String operatorCode;
  final String wardLabel;
  final String emp_id;
  final String employeeCode;
  final String zoneLabel;
  final String? designation;
  final VoidCallback onScanPressed;
  final VoidCallback onLogout;
  final void Function(DailyAssignmentModel assignment)? onOpenAssignments;
  final VoidCallback? onOpenProfile;
  final OperatorNextStop? nextStop;
  final OperatorCollectionSummary? lastCollection;
  final OperatorAttendanceSummary? attendanceSummary;

  @override
  State<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends State<OperatorHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OperatorTheme.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            OperatorHeader(
              name: widget.operatorName,
              empId: widget.emp_id,
              displayId: widget.employeeCode,
              badge: widget.operatorCode,
              ward: widget.wardLabel,
              zone: widget.zoneLabel,
              designation: widget.designation,
              onLogout: widget.onLogout,
              onMenuTap: widget.onOpenProfile,
            ),
            const Expanded(
              child: OperatorTripBody(
                showScanFab: false,
                listPadding: EdgeInsets.fromLTRB(18, 16, 18, 220),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
