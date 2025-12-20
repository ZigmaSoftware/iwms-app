import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';

const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(24));
const List<BoxShadow> _softShadow = [
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 18,
    offset: Offset(0, 10),
  ),
];

class OperatorInfoCard extends StatelessWidget {
  const OperatorInfoCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.titleStyle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: _cardRadius,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: _cardRadius,
          boxShadow: _softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: titleStyle ??
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class OperatorQuickStat extends StatelessWidget {
  const OperatorQuickStat({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        const SizedBox(height: 6),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
            color: emphasis ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
