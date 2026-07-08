import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

class SupervisorPatternBackground extends StatelessWidget {
  const SupervisorPatternBackground({
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
              painter: _SupervisorDotFieldPainter(color: color),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class SupervisorTimeChip extends StatelessWidget {
  const SupervisorTimeChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? SupervisorTheme.primary : SupervisorTheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? SupervisorTheme.primary : SupervisorTheme.hairline,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : SupervisorTheme.strongText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class SupervisorKpiAreaChart extends StatelessWidget {
  const SupervisorKpiAreaChart({
    super.key,
    required this.kpis,
  });

  final SupervisorKpis kpis;

  @override
  Widget build(BuildContext context) {
    final total = math.max(kpis.total, 1);
    final completedRatio = kpis.completed / total;
    final progressRatio = kpis.inProgress / total;

    return ClipRRect(
      borderRadius: SupervisorTheme.cardRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFCF9).withValues(alpha: 0.72),
            borderRadius: SupervisorTheme.cardRadius,
            boxShadow: SupervisorTheme.elevatedShadow,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Trips today',
                    style: TextStyle(
                      color: SupervisorTheme.strongText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  _miniBadge(
                    icon: Icons.check_rounded,
                    label: '${kpis.completed}',
                    color: SupervisorTheme.success,
                  ),
                  const SizedBox(width: 8),
                  _miniBadge(
                    icon: Icons.timelapse_rounded,
                    label: '${kpis.pendingReview}',
                    color: SupervisorTheme.warning,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 148,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SupervisorAreaChartPainter(
                    completedRatio: completedRatio,
                    progressRatio: progressRatio,
                    pending: kpis.pendingReview,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _AxisLabel('Start'),
                  _AxisLabel('Midday'),
                  _AxisLabel('Now'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: SupervisorTheme.strongText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: SupervisorTheme.mutedText,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SupervisorAreaChartPainter extends CustomPainter {
  const _SupervisorAreaChartPainter({
    required this.completedRatio,
    required this.progressRatio,
    required this.pending,
  });

  final double completedRatio;
  final double progressRatio;
  final int pending;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final base = size.height - 14;
    final top = 16.0;
    final amplitude = math.max(26.0, size.height * 0.42);

    _drawGuides(canvas, size);
    _drawGrain(canvas, size);

    final backPoints = List<Offset>.generate(13, (i) {
      final t = i / 12;
      final wave = math.sin((t * math.pi * 2.2) - 0.4) * 0.22 +
          math.sin((t * math.pi * 4.4) + 0.6) * 0.10;
      final lift = (completedRatio * 0.18) + (progressRatio * 0.12);
      final value = 0.48 + wave + lift;
      return Offset(
        size.width * t,
        (base - amplitude * value).clamp(top, base),
      );
    });

    final frontPoints = List<Offset>.generate(13, (i) {
      final t = i / 12;
      final wave = math.sin((t * math.pi * 3.0) + 0.2) * 0.16 +
          math.sin((t * math.pi * 5.8) - 0.7) * 0.08;
      final lift = math.min(pending, 10) * 0.015;
      final value = 0.26 + wave + lift;
      return Offset(
        size.width * t,
        (base - amplitude * value).clamp(top + 16, base),
      );
    });

    _drawArea(
      canvas,
      backPoints,
      base,
      LinearGradient(
        colors: [
          SupervisorTheme.chartFill.withValues(alpha: 0.82),
          SupervisorTheme.chartFill.withValues(alpha: 0.35),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      SupervisorTheme.chartFill,
      size,
    );
    _drawArea(
      canvas,
      frontPoints,
      base,
      LinearGradient(
        colors: [
          SupervisorTheme.chartFillDeep.withValues(alpha: 0.82),
          SupervisorTheme.chartFillDeep.withValues(alpha: 0.34),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      SupervisorTheme.chartFillDeep,
      size,
    );

    final tagX = size.width * 0.46;
    final tagY = math.min(backPoints[6].dy - 18, size.height - 46);
    final tagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tagX - 24, tagY, 54, 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      tagRect,
      Paint()..color = const Color(0xFF0F766E),
    );
    final label = TextPainter(
      text: TextSpan(
        text: '${(completedRatio * 100).round()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(tagRect.center.dx - label.width / 2, tagRect.center.dy - 7),
    );

    canvas.restore();
  }

  void _drawGuides(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SupervisorTheme.hairline.withValues(alpha: 0.9)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final bottom = size.height - 12;
    for (var i = 0; i <= 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 8), Offset(x, bottom), paint);
    }
  }

  void _drawGrain(Canvas canvas, Size size) {
    final rng = math.Random(27);
    final speckPaint = Paint()..color = const Color(0xFF000000);
    final width = size.width;
    final height = size.height;
    final count = (width * height / 42).round().clamp(180, 420);

    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * width;
      final y = rng.nextDouble() * height;
      final yNorm = y / height;
      final bottomWeight = Curves.easeIn.transform(yNorm);
      if (bottomWeight < 0.1) continue;
      final opacity = (0.015 + bottomWeight * 0.07).clamp(0.01, 0.085);
      final radius =
          (0.25 + bottomWeight * 0.75) * (0.7 + rng.nextDouble() * 0.8);
      speckPaint.color = const Color(0xFF111111).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, speckPaint);
    }
  }

  void _drawArea(
    Canvas canvas,
    List<Offset> points,
    double base,
    Gradient gradient,
    Color strokeColor,
    Size size,
  ) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, base)
      ..lineTo(points.first.dx, base)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = gradient.createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _SupervisorAreaChartPainter oldDelegate) {
    return oldDelegate.completedRatio != completedRatio ||
        oldDelegate.progressRatio != progressRatio ||
        oldDelegate.pending != pending;
  }
}

class _SupervisorDotFieldPainter extends CustomPainter {
  const _SupervisorDotFieldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // A straight, uniform dotted grid (like the reference SVG pattern): every
    // dot is the same small size and the same light opacity, laid out on a
    // perfectly aligned lattice — no stagger, row-curve, y-wobble, or
    // toward-the-bottom size/opacity growth.
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
  bool shouldRepaint(covariant _SupervisorDotFieldPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
