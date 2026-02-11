import 'package:flutter/material.dart';

import '../theme_tokens.dart';

/// Generic surface card used across dashboard sections.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    required this.surfaceColor,
    required this.outlineColor,
    required this.isDarkMode,
    this.padding,
    this.borderRadius = DashboardThemeTokens.radiusLarge,
  });

  final Widget child;
  final Color surfaceColor;
  final Color outlineColor;
  final bool isDarkMode;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: outlineColor),
        boxShadow: [
          isDarkMode
              ? DashboardThemeTokens.darkShadow
              : DashboardThemeTokens.lightShadow,
        ],
      ),
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: DashboardThemeTokens.spacing16,
            vertical: DashboardThemeTokens.spacing14,
          ),
      child: child,
    );
  }
}
