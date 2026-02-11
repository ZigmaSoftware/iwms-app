import 'package:flutter/material.dart';

import '../../common/theme_tokens.dart';
import '../models/quick_action.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({
    super.key,
    required this.actions,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textColor,
  });

  final List<QuickAction> actions;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        const spacing = DashboardThemeTokens.spacing12;
        const runSpacing = DashboardThemeTokens.spacing14;
        final availableWidth =
            constraints.maxWidth - (spacing * (columns - 1));
        final tileWidth = (availableWidth / columns)
            .clamp(0, constraints.maxWidth)
            .toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: actions.map((action) {
            return SizedBox(
              width: tileWidth,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(DashboardThemeTokens.radiusMedium),
                  onTap: action.onTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            DashboardThemeTokens.radiusLarge,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDarkMode ? 0.18 : 0.06,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            DashboardThemeTokens.radiusLarge,
                          ),
                          child: Container(
                            width: 54,
                            height: 54,
                            color: isDarkMode
                                ? surfaceColor.withValues(alpha: 0.5)
                                : surfaceColor,
                            child: Image.asset(
                              action.assetPath,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: DashboardThemeTokens.spacing8),
                      Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
