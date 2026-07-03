import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Bottom sheet showing the full detail of a single assignment, plus the
/// (disabled, deferred) approve / reject actions.
class SupervisorAssignmentDetailSheet extends StatelessWidget {
  const SupervisorAssignmentDetailSheet({super.key, required this.assignment});

  final SupervisorAssignment assignment;

  static Future<void> show(
    BuildContext context,
    SupervisorAssignment assignment,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupervisorAssignmentDetailSheet(assignment: assignment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SupervisorTheme.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            assignment.areaName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: SupervisorTheme.strongText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            assignment.tripCode,
            style: const TextStyle(
              fontSize: 12,
              color: SupervisorTheme.mutedText,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 18),
          _row(Icons.flag_rounded, 'Status', assignment.statusLabel),
          _row(Icons.verified_rounded, 'Approval', assignment.approvalStatus),
          if (assignment.zoneName.isNotEmpty)
            _row(Icons.map_outlined, 'Zone', assignment.zoneName),
          if (assignment.wardName.isNotEmpty)
            _row(Icons.location_on_outlined, 'Ward', assignment.wardName),
          if (assignment.wasteTypeName.isNotEmpty)
            _row(Icons.delete_outline_rounded, 'Waste type',
                assignment.wasteTypeName),
          if (assignment.vehicleNo.isNotEmpty)
            _row(
                Icons.local_shipping_outlined, 'Vehicle', assignment.vehicleNo),
          if (assignment.driverName.isNotEmpty)
            _row(Icons.drive_eta_rounded, 'Driver', assignment.driverName),
          if (assignment.operatorName.isNotEmpty)
            _row(
                Icons.engineering_rounded, 'Operator', assignment.operatorName),
          if (assignment.scheduledTime.isNotEmpty)
            _row(Icons.schedule_rounded, 'Scheduled', assignment.scheduledTime),
          if (assignment.remarks.isNotEmpty)
            _row(Icons.notes_rounded, 'Remarks', assignment.remarks),
          const SizedBox(height: 20),
          _approvalActions(context),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: SupervisorTheme.mutedText),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: SupervisorTheme.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: SupervisorTheme.strongText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Approve / Reject buttons — rendered but DISABLED this phase. The backend
  /// approval API exists; the action is intentionally deferred per scope.
  Widget _approvalActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SupervisorTheme.primary,
                  disabledBackgroundColor:
                      SupervisorTheme.primary.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: SupervisorTheme.chipRadius,
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Approve'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SupervisorTheme.danger,
                  disabledForegroundColor:
                      SupervisorTheme.danger.withValues(alpha: 0.4),
                  side: BorderSide(
                    color: SupervisorTheme.primary.withValues(alpha: 0.28),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: SupervisorTheme.chipRadius,
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Reject'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_clock_rounded,
                size: 13, color: SupervisorTheme.mutedText),
            SizedBox(width: 5),
            Text(
              'Approval workflow coming soon',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: SupervisorTheme.mutedText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
