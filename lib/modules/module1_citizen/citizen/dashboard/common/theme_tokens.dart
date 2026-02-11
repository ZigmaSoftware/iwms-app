import 'package:flutter/material.dart';

/// Centralized design tokens for the citizen dashboard.
class DashboardThemeTokens {
  const DashboardThemeTokens._();

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusXL = 28;

  static const double spacing4 = 4;
  static const double spacing6 = 6;
  static const double spacing8 = 8;
  static const double spacing10 = 10;
  static const double spacing12 = 12;
  static const double spacing14 = 14;
  static const double spacing16 = 16;
  static const double spacing18 = 18;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing28 = 28;
  static const double spacing32 = 32;

  static const Duration animationFast = Duration(milliseconds: 180);
  static const Duration animationNormal = Duration(milliseconds: 260);
  static const Duration animationSlow = Duration(milliseconds: 420);

  static const BoxShadow lightShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 20,
    offset: Offset(0, 12),
  );

  static const BoxShadow darkShadow = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 30,
    offset: Offset(0, 12),
  );
}
