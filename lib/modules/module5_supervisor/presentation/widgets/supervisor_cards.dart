import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Dashboard KPI tile — a compact number + label card with a tinted icon chip.
class SupervisorKpiCard extends StatelessWidget {
  const SupervisorKpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SupervisorTheme.cardRadius,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SupervisorTheme.surface,
            borderRadius: SupervisorTheme.cardRadius,
            border: Border.all(color: SupervisorTheme.hairline),
            boxShadow: SupervisorTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: SupervisorTheme.chipRadius,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SupervisorTheme.strongText,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: SupervisorTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single row in the activity / alerts feed.
class SupervisorAlertTile extends StatelessWidget {
  const SupervisorAlertTile({super.key, required this.alert});

  final SupervisorAlert alert;

  Color get _color {
    switch (alert.severity) {
      case SupervisorAlertSeverity.danger:
        return SupervisorTheme.danger;
      case SupervisorAlertSeverity.warning:
        return SupervisorTheme.warning;
      case SupervisorAlertSeverity.info:
        return SupervisorTheme.info;
    }
  }

  IconData get _icon {
    switch (alert.severity) {
      case SupervisorAlertSeverity.danger:
        return Icons.error_outline_rounded;
      case SupervisorAlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case SupervisorAlertSeverity.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border: Border.all(color: SupervisorTheme.hairline),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: SupervisorTheme.chipRadius,
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: SupervisorTheme.strongText,
                  ),
                ),
                if (alert.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    alert.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SupervisorTheme.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic info card matching OperatorInfoCard's look (20px radius, soft
/// shadow), used on the profile screen.
class SupervisorInfoCard extends StatelessWidget {
  const SupervisorInfoCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border: Border.all(color: SupervisorTheme.hairline),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SupervisorTheme.strongText,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
