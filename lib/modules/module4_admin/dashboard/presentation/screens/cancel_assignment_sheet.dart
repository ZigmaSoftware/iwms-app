import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';

/// Enhanced, animated cancel assignment sheet
class EnhancedCancelAssignmentSheet extends StatefulWidget {
  const EnhancedCancelAssignmentSheet({
    super.key,
    required this.assignmentId,
    required this.uniqueId,
    required this.wardName,
    required this.driverName,
  });

  final String assignmentId;
  final String uniqueId;
  final String wardName;
  final String driverName;

  @override
  State<EnhancedCancelAssignmentSheet> createState() =>
      _EnhancedCancelAssignmentSheetState();
}

class _EnhancedCancelAssignmentSheetState
    extends State<EnhancedCancelAssignmentSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedReason;
  final _customReasonController = TextEditingController();
  bool _submitting = false;
  bool _showSuccess = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  final List<CancellationReason> _reasons = const [
    CancellationReason(
      'Driver unavailable',
      Icons.person_off_outlined,
      'Driver called in sick or is on leave',
    ),
    CancellationReason(
      'Vehicle breakdown',
      Icons.build_outlined,
      'Vehicle requires maintenance or repair',
    ),
    CancellationReason(
      'Emergency reassignment',
      Icons.warning_amber_outlined,
      'Urgent reassignment needed elsewhere',
    ),
    CancellationReason(
      'Schedule conflict',
      Icons.event_busy_outlined,
      'Overlapping assignment or scheduling error',
    ),
    CancellationReason(
      'Weather conditions',
      Icons.cloud_outlined,
      'Severe weather preventing operations',
    ),
    CancellationReason(
      'Other',
      Icons.more_horiz,
      'Specify custom reason below',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _customReasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      _showSnackBar('Please select a cancellation reason', isError: true);
      return;
    }

    if (_selectedReason == 'Other' &&
        _customReasonController.text.trim().isEmpty) {
      _showSnackBar('Please provide a custom reason', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final authDio = await authorizedDio();
      final reason = _selectedReason == 'Other'
          ? _customReasonController.text.trim()
          : _selectedReason!;

      Response response;
      try {
        response = await authDio.delete(
          '${ApiConfig.assignments}${widget.uniqueId}/',
          data: {'reason': reason},
        );
      } on DioException catch (e) {
        // Fallback to cancel endpoint if DELETE is blocked
        response = await authDio.post(
          '${ApiConfig.assignments}${widget.uniqueId}/cancel/',
          data: {'reason': reason},
        );
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _showSuccess = true;
          _submitting = false;
        });
        _animController.forward();

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context, true);
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnackBar(
          'Failed to cancel assignment. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                bottomInset + 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: _showSuccess ? _buildSuccessView() : _buildFormView(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 50,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Assignment Cancelled',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The assignment for ${widget.wardName} has been successfully cancelled.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF616161),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFD32F2F),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cancel Assignment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${widget.wardName} • ${widget.driverName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF5F5F5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'This action cannot be undone. Please select a reason.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Select Cancellation Reason',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 12),
        ..._reasons.map((reason) => _buildReasonCard(reason)),
        if (_selectedReason == 'Other') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _customReasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Specify reason',
              hintText: 'Enter detailed reason for cancellation...',
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF2E7D32),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selectedReason == null || _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Confirm Cancellation',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReasonCard(CancellationReason reason) {
    final isSelected = _selectedReason == reason.title;

    return GestureDetector(
      onTap: _submitting ? null : () => setState(() => _selectedReason = reason.title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2196F3).withOpacity(0.1)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                reason.icon,
                size: 22,
                color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF757575),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF1976D2) : const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2196F3),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class CancellationReason {
  final String title;
  final IconData icon;
  final String description;

  const CancellationReason(this.title, this.icon, this.description);
}
