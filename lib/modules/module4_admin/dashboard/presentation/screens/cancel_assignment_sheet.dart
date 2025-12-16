import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';

class CancelAssignmentSheet extends StatefulWidget {
  const CancelAssignmentSheet({
    super.key,
    required this.assignmentId,
  });

  final String assignmentId;

  @override
  State<CancelAssignmentSheet> createState() =>
      _CancelAssignmentSheetState();
}

class _CancelAssignmentSheetState extends State<CancelAssignmentSheet> {
  String? _selectedReason;
  bool _submitting = false;

  final List<String> _reasons = const [
    'Driver unavailable',
    'Vehicle breakdown',
    'Emergency reassignment',
    'Wrong assignment',
    'Other',
  ];

  Future<void> _submit() async {
    if (_selectedReason == null) return;

    setState(() => _submitting = true);

    try {
      final dio = await authorizedDio();

      await dio.post(
        '${ApiConfig.assignments}${widget.assignmentId}/cancel/',
        data: {'reason': _selectedReason},
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation failed')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cancel Assignment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'This action cannot be undone. Please select a reason.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedReason,
            items: _reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Cancellation reason',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _selectedReason = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _selectedReason == null || _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm Cancellation'),
            ),
          ),
        ],
      ),
    );
  }
}
