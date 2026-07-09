import 'package:flutter/material.dart';

/// Evenly spaced dot-field texture for the Citizen module, mirroring
/// `SupervisorPatternBackground` (module5_supervisor/presentation/widgets/
/// supervisor_visuals.dart) so both modules share the same subtle page
/// texture. Kept as a separate citizen-scoped widget so citizen screens can
/// depend on it without reaching into the supervisor module.
class CitizenPatternBackground extends StatelessWidget {
  const CitizenPatternBackground({
    super.key,
    required this.child,
    this.color = const Color(0xFF000000),
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CitizenDotFieldPainter(color: color),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CitizenDotFieldPainter extends CustomPainter {
  const _CitizenDotFieldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Same uniform lattice as the supervisor dot field: fixed spacing/radius,
    // no stagger or gradient falloff, so the two modules read as one system.
    const spacing = 22.0;
    const radius = 1.1;

    final dot = Paint()..color = color.withValues(alpha: 0.07);

    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();

    for (var row = 0; row <= rows; row++) {
      final y = row * spacing;
      for (var col = 0; col <= cols; col++) {
        canvas.drawCircle(Offset(col * spacing, y), radius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CitizenDotFieldPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
