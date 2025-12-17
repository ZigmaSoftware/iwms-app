import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/staff_management_repository.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/assignment_history_screen.dart';
import 'cancel_assignment_sheet.dart';

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
  bool _cancelling = false;

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

  Future<void> _cancelAssignment() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EnhancedCancelAssignmentSheet(
        assignmentId: widget.assignment.id.toString(),
        uniqueId: widget.assignment.uniqueId,
        wardName: widget.assignment.ward,
        driverName: widget.assignment.driver,
      ),
    );

    if (!mounted) return;
    setState(() => _cancelling = false);

    if (result == true) {
      widget.onCancelled();
      await _loadAssignment();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment cancelled'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _enhanced == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _enhanced ?? _fallback;
    final canCancel = data.currentStatus != AssignmentStatus.cancelled &&
        data.currentStatus != AssignmentStatus.completed;

    return DetailedAssignmentHistoryScreen(
      assignment: data,
      floatingActionButton: canCancel
          ? FloatingActionButton.extended(
              onPressed: _cancelAssignment,
              backgroundColor: const Color(0xFFB71C1C),
              icon: _cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cancel_schedule_send),
              label: const Text('Cancel Assignment'),
            )
          : null,
    );
  }
}
