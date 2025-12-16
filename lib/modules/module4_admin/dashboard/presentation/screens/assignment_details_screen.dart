import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'cancel_assignment_sheet.dart';

class AssignmentDetailsScreen extends StatelessWidget {
  const AssignmentDetailsScreen({
    super.key,
    required this.assignment,
    required this.onCancelled,
  });

  final DailyAssignmentModel assignment;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoTile(label: 'Ward', value: assignment.ward),
            _InfoTile(label: 'Driver', value: assignment.driver),
            _InfoTile(label: 'Operator', value: assignment.operatorName),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final cancelled = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => CancelAssignmentSheet(
                      assignmentId: assignment.id.toString(),
                    ),
                  );

                  if (cancelled == true && context.mounted) {
                    onCancelled();
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
