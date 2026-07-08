import 'package:flutter/material.dart';

class HomeBaseMarker extends StatelessWidget {
  const HomeBaseMarker({
    super.key,
    this.size = 52,
    this.gradientColors = const [Color(0xFF0B7A32), Color(0xFF0A5C24)],
  });

  final double size;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.home_rounded,
          color: Colors.white,
          size: size * 0.45,
        ),
      ),
    );
  }
}
