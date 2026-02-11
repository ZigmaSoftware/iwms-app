import 'dart:math' as math;

import 'package:flutter/material.dart';

class RadialBarData {
  const RadialBarData({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.color,
  });

  final String label;
  final double value;
  final String valueLabel;
  final Color color;
}

class WasteRadialBreakdown extends StatefulWidget {
  const WasteRadialBreakdown({
    super.key,
    required this.items,
    required this.totalValue,
    required this.textColor,
    required this.backgroundColor,
  });

  final List<RadialBarData> items;
  final double totalValue;
  final Color textColor;
  final Color backgroundColor;

  @override
  State<WasteRadialBreakdown> createState() => _WasteRadialBreakdownState();
}

class _WasteRadialBreakdownState extends State<WasteRadialBreakdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completedOnce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completedOnce = true;
        }
      });
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant WasteRadialBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool dataChanged =
        _hasChartDataChanged(oldWidget.items, widget.items) ||
            oldWidget.totalValue != widget.totalValue;

    if (dataChanged) {
      _completedOnce = false;
      _controller
        ..reset()
        ..forward();
    } else if (!_completedOnce && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasChartDataChanged(
    List<RadialBarData> previous,
    List<RadialBarData> current,
  ) {
    if (previous.length != current.length) return true;
    for (var i = 0; i < previous.length; i++) {
      final oldItem = previous[i];
      final newItem = current[i];
      if (oldItem.label != newItem.label ||
          oldItem.valueLabel != newItem.valueLabel ||
          oldItem.value != newItem.value ||
          oldItem.color != newItem.color) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxChartSize = math.min(screenWidth * 0.7, 280.0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final animationValue = Curves.easeOutCubic.transform(_controller.value);
        return LayoutBuilder(
          builder: (context, constraints) {
            final double size = math.min(
              math.min(constraints.maxWidth, constraints.maxHeight),
              maxChartSize,
            );
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(size),
                      painter: _RadialArcPainter(
                        items: widget.items,
                        totalValue: widget.totalValue,
                        animationValue: animationValue,
                      ),
                    ),
                    Container(
                      width: size * 0.4,
                      height: size * 0.4,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/gif/dumpster.gif',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RadialArcPainter extends CustomPainter {
  const _RadialArcPainter({
    required this.items,
    required this.totalValue,
    required this.animationValue,
  });

  final List<RadialBarData> items;
  final double totalValue;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2.2;
    var radius = maxRadius;
    const gap = 4.0;

    for (final data in items) {
      final strokeWidth = radius * 0.18;
      final bgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = Colors.white;

      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            data.color.withValues(alpha: 0.8),
            data.color,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);
      final sweep =
          totalValue == 0 ? 0.0 : (data.value / totalValue).clamp(0.0, 1.0);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * sweep * animationValue,
        false,
        fgPaint,
      );

      radius -= strokeWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RadialArcPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.totalValue != totalValue ||
        oldDelegate.animationValue != animationValue;
  }
}
