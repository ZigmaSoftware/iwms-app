import 'package:flutter/material.dart';

import '../models/citizen_alert.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.alert,
    required this.timestampLabel,
    required this.onTrack,
  });

  final CitizenAlert alert;
  final String timestampLabel;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseSurface = theme.colorScheme.surfaceContainerHighest;
    final background = isDark
        ? baseSurface.withValues(alpha: 0.28)
        : baseSurface.withValues(alpha: 0.7);
    final localizations = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timestampLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alert.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onTrack,
              icon: const Icon(Icons.route_outlined),
              label: Text(localizations.trackButtonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
