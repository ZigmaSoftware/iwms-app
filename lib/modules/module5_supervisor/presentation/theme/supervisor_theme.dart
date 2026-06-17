import 'package:flutter/material.dart';

/// Supervisor-scoped design tokens. Uses the EXACT same charcoal-slate +
/// attendance-green palette and structure as OperatorTheme / DriverTheme so
/// the supervisor, operator and driver shells feel like one unified product.
class SupervisorTheme {
  // Core palette — EXACT OPERATOR COLORS
  static const Color primary = Color(0xFF1F2937); // slate-800 (charcoal)
  static const Color primaryAccent = Color(0xFF111827); // slate-900
  static const Color primarySoft = Color(0xFF374151); // slate-700

  static const Color accent = Color(0xFF0F8A58); // attendance green
  static const Color accentDeep = Color(0xFF0D3B26); // deep attendance green
  static const Color accentSoft = Color(0xFFE7F6EE); // attendance green bg

  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6); // slate-100

  static const Color strongText = Color(0xFF0F172A); // slate-900
  static const Color mutedText = Color(0xFF6B7280); // slate-500
  static const Color hairline = Color(0xFFE5E7EB); // slate-200

  static const Color success = Color(0xFF059669); // emerald-600
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626); // red-600
  static const Color info = Color(0xFF2563EB); // blue-600

  // Legacy aliases (parity with OperatorTheme)
  static const Color attendanceAlert = danger;
  static const Color accentLight = accentSoft;
  static const Color cardBorder = hairline;

  // Gradients — EXACT OPERATOR STYLE
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primary, primaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient quickActionGradient = accentGradient;

  // Shadows — match operator
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  // Radii — match operator
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(12));

  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);
}
