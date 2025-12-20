import 'package:flutter/material.dart';

class TrackingHeroHeader extends StatelessWidget {
  const TrackingHeroHeader({
    super.key,
    required this.headline,
    required this.contextLabel,
    required this.statusPrimary,
    required this.statusSecondary,
    this.onBack,
    this.onRefresh,
    this.onShare,
    this.statusContent,
  });

  final String headline;
  final String contextLabel;
  final String statusPrimary;
  final String statusSecondary;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onShare;
  final Widget? statusContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasBack = onBack != null;
    final Widget backButton = hasBack
        ? IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
          )
        : const SizedBox(width: 48, height: 48);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F742B), Color(0xFF0B5721)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(26),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  backButton,
                  Expanded(
                    child: Text(
                      contextLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (onShare != null)
                        IconButton(
                          onPressed: onShare,
                          icon: const Icon(Icons.share_rounded,
                              color: Colors.white),
                        ),
                      if (onRefresh != null)
                        IconButton(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.center,
                child: statusContent ??
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer, size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            statusPrimary,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            statusSecondary,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrackingSpeechBubble extends StatelessWidget {
  const TrackingSpeechBubble({
    super.key,
    required this.message,
    this.icon = Icons.eco_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1B5E20), size: 18),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
