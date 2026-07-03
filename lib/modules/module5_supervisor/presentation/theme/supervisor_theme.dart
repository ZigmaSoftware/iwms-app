import 'package:flutter/material.dart';

/// Supervisor-scoped design tokens.
class SupervisorTheme {
  // Finance-dashboard inspired palette: ink, paper, violet chart ink and gold.
  static const Color primary = Color(0xFF050505);
  static const Color primaryAccent = Color(0xFF111114);
  static const Color primarySoft = Color(0xFF2A2A30);

  static const Color accent = Color(0xFF4F46F6);
  static const Color accentDeep = Color(0xFF2722B9);
  static const Color accentSoft = Color(0xFFECEBFF);
  static const Color gold = Color(0xFFE7B85C);

  static const Color background = Color(0xFFF4F3EF);
  static const Color surface = Color(0xFFFBFAF7);
  static const Color surfaceMuted = Color(0xFFEDEBE5);

  static const Color strongText = Color(0xFF070707);
  static const Color mutedText = Color(0xFF63615C);
  static const Color hairline = Color(0xFFB7B3AA);

  static const Color success = Color(0xFF0B8F61);
  static const Color warning = Color(0xFFD99A21);
  static const Color danger = Color(0xFFD83B3B);
  static const Color info = Color(0xFF2563EB);
  static const Color chartFill = Color(0xFF7771FF);
  static const Color chartFillDeep = Color(0xFF3530D9);

  // Legacy aliases (parity with OperatorTheme)
  static const Color attendanceAlert = danger;
  static const Color accentLight = accentSoft;
  static const Color cardBorder = hairline;

  // Gradients
  static const LinearGradient headerGradient = LinearGradient(
    colors: [surface, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient quickActionGradient = accentGradient;

  static const LinearGradient chartGradient = LinearGradient(
    colors: [chartFill, chartFillDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 12,
      offset: Offset(0, 5),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x22000000),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];

  // Radii
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(18));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(14));

  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);
}
