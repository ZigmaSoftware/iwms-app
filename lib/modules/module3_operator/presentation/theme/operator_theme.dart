import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/constants.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/ui/app_ui_tokens.dart';

/// Shared color + spacing tokens reused across the revamped operator UI.
class OperatorTheme {
  static const Color primary = kPrimaryColor;
  static const Color primaryAccent = AppColors.primaryVariant;
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color accentLight = AppColors.accentLight;
  static const Color mutedText = AppColors.textSecondary;
  static const Color strongText = AppColors.textPrimary;
  static const Color cardBorder = Color(0x1A1B5E20);
  static const Color attendanceAlert = AppColors.notificationBadge;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(AppUiTokens.spacing24));
  static const BorderRadius chipRadius =
      BorderRadius.all(Radius.circular(AppUiTokens.radiusMedium));

  static const LinearGradient headerGradient = LinearGradient(
    colors: [primary, primaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient quickActionGradient = LinearGradient(
    colors: [primaryAccent, AppColors.operatorAccent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const List<BoxShadow> softShadow = [
    AppUiTokens.softLogoShadow,
  ];

  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);
}
