import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/staff_management_repository.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/assignment_history_screen.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  const AssignmentDetailsScreen({
    super.key,
    required this.assignment,
    required this.onCancelled,
  });

  final DailyAssignmentModel assignment;
  final VoidCallback onCancelled;

  @override
  State<AssignmentDetailsScreen> createState() =>
      _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  final _repository = const StaffManagementRepository();
  EnhancedAssignmentModel? _enhanced;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    setState(() => _loading = true);
    final data =
        await _repository.fetchAssignmentDetails(widget.assignment.uniqueId);
    if (!mounted) return;
    setState(() {
      _enhanced = data;
      _loading = false;
    });
  }

  EnhancedAssignmentModel get _fallback {
    return EnhancedAssignmentModel(
      id: widget.assignment.id,
      uniqueId: widget.assignment.uniqueId,
      date: widget.assignment.date,
      ward: widget.assignment.ward,
      driver: widget.assignment.driver,
      operatorName: widget.assignment.operatorName,
      assignmentType: widget.assignment.assignmentType,
      shift: widget.assignment.shift,
      currentStatus: widget.assignment.currentStatus,
      createdAt: widget.assignment.date,
      completedAt: widget.assignment.completedAt,
      skippedAt: widget.assignment.skippedAt,
      skipReason: widget.assignment.skipReason,
      cancelledAt: widget.assignment.cancelledAt,
      cancelledReason: widget.assignment.cancelledReason,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _enhanced == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _enhanced ?? _fallback;
    return DetailedAssignmentHistoryScreen(
      assignment: data,
      floatingActionButton: null,
    );
  }
}

