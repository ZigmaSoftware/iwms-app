import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/theme_tokens.dart';

class WasteStatCard extends StatelessWidget {
  const WasteStatCard({
    super.key,
    required this.assetPath,
    required this.label,
    required this.weight,
    required this.accentColor,
    required this.formatter,
    required this.isSelected,
    required this.onTap,
  });

  final String assetPath;
  final String label;
  final double weight;
  final Color accentColor;
  final NumberFormat formatter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = theme.colorScheme.onSurfaceVariant;
    final bool isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(DashboardThemeTokens.radiusXL);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double cardHeight = math.min(screenHeight * 0.22, 200);

    return SizedBox(
      height: cardHeight,
      child: AnimatedContainer(
        duration: DashboardThemeTokens.animationNormal,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.6)
                : onSurface.withValues(alpha: isDark ? 0.2 : 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      assetPath,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment(0.2, 0.2),
                      color: isSelected
                          ? Colors.black.withValues(alpha: 0.1)
                          : null,
                      colorBlendMode: isSelected ? BlendMode.darken : null,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onSurfaceMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(scale: anim, child: child),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${formatter.format(weight)} kg',
                              key: ValueKey<String>(
                                '${label}_${weight.toStringAsFixed(2)}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
