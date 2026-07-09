import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:iwms_citizen_app/router/app_router.dart';

import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/common/theme_tokens.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/common/widgets/section_card.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/quick_actions/models/quick_action.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/quick_actions/widgets/quick_action_grid.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/banner/controllers/banner_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/banner/widgets/banner_pager.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/controllers/track_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/models/waste_summary.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/widgets/radial_chart.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/notifications/controllers/notification_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/notifications/widgets/notification_tile.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.bannerController,
    required this.trackController,
    required this.notificationController,
    required this.quickActions,
    required this.userName,
    required this.showUserName,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.outlineColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.highlightColor,
    required this.onStatsTap,
  });


 
  final BannerController bannerController;
  final TrackController trackController;
  final NotificationController notificationController;
  final List<QuickAction> quickActions;
  final String userName;
  final bool showUserName;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color outlineColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color highlightColor;
  final VoidCallback onStatsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = MediaQuery.of(context).size;
    final double headerHeight = (responsive.height * 0.32).clamp(260, 360);
    final double bannerHeight = (headerHeight * 0.55).clamp(140, 190);
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          userName: userName,
          showUserName: showUserName,
          isDarkMode: isDarkMode,
          highlightColor: highlightColor,
          textColor: textColor,
          secondaryTextColor: secondaryTextColor,
          notificationController: notificationController,
          localizations: localizations,
        ),
        const SizedBox(height: DashboardThemeTokens.spacing12),
        AnimatedBuilder(
          animation: bannerController,
          builder: (context, _) {
            final slides = bannerController.slides;
            if (slides.isEmpty) {
              return const SizedBox.shrink();
            }
            return BannerPager(
              controller: bannerController.pageController,
              slides: slides,
              currentIndex: bannerController.currentIndex,
              isDarkMode: isDarkMode,
              pageViewHeight: bannerHeight,
              onPageChanged: bannerController.onPageChanged,
            );
          },
        ),
        const SizedBox(height: DashboardThemeTokens.spacing12),
        AnimatedBuilder(
          animation: trackController,
          builder: (context, _) {
              final stats = _Stats.fromSummary(
                trackController,
                trackController.currentSummary,
                localizations,
              );
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DashboardThemeTokens.spacing16,
              ),
              child: GestureDetector(
                onTap: onStatsTap,
                child: SectionCard(
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  isDarkMode: isDarkMode,
                  child: _CollectionStatsCard(
                    stats: stats,
                    highlightColor: highlightColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: DashboardThemeTokens.spacing16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DashboardThemeTokens.spacing16,
              0,
              DashboardThemeTokens.spacing16,
              DashboardThemeTokens.spacing32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.quickActions,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: DashboardThemeTokens.spacing12),
                QuickActionGrid(
                  actions: quickActions,
                  isDarkMode: isDarkMode,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.showUserName,
    required this.isDarkMode,
    required this.highlightColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.notificationController,
    required this.localizations,
  });

  final String userName;
  final bool showUserName;
  final bool isDarkMode;
  final Color highlightColor;
  final Color textColor;
  final Color secondaryTextColor;
  final NotificationController notificationController;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DashboardThemeTokens.spacing16,
        vertical: DashboardThemeTokens.spacing12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(AppRoutePaths.citizenProfile),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Transform.scale(
                scale: 1.12,
                child: Image.asset(
                  'assets/gif/profile.gif',
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: DashboardThemeTokens.spacing12),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.homeTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                if (showUserName) ...[
                  const SizedBox(height: 2),
                  Text(
                    userName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _NotificationBell(
            controller: notificationController,
            iconColor: highlightColor,
            backgroundColor:
                isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
            borderColor:
                isDarkMode ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.1),
            localizations: localizations,
          ),
        ],
      ),
    );
  }
}

class _Stats {
  _Stats({
    required this.primaryValue,
    required this.primaryLabel,
    required this.progressItems,
    required this.summary,
  });
  final double primaryValue;
  final String primaryLabel;
  final List<RadialBarData> progressItems;
  final WasteSummary summary;

  factory _Stats.fromSummary(
    TrackController controller,
    WasteSummary? summary,
    AppLocalizations localizations,
  ) {
    final weightFormatter = controller.weightFormatter;
    final data = summary ?? WasteSummary.zero(controller.selectedDate);
    final hasData = data.totalNetWeight > 0;
    final String periodLabel = controller.periodLabel(controller.selectedPeriod);
    final String primaryLabel = hasData
        ? localizations.wasteCollectedLabel(periodLabel)
        : localizations.noWasteRecorded;

    return _Stats(
      primaryValue: data.totalNetWeight,
      primaryLabel: primaryLabel,
      summary: data,
      progressItems: [
        RadialBarData(
          label: 'Wet',
          value: data.wetWeight,
          valueLabel: 'Wet ${weightFormatter.format(data.wetWeight)} kg',
          color: const Color(0xFF1976D2),
        ),
        RadialBarData(
          label: 'Dry',
          value: data.dryWeight,
          valueLabel: 'Dry ${weightFormatter.format(data.dryWeight)} kg',
          color: const Color(0xFF2E7D32),
        ),
        RadialBarData(
          label: 'Mixed',
          value: data.mixWeight,
          valueLabel:
              'Mixed ${weightFormatter.format(data.mixWeight)} kg',
          color: const Color(0xFFF57F17),
        ),
      ],
    );
  }
}

class _CollectionStatsCard extends StatelessWidget {
  const _CollectionStatsCard({
    required this.stats,
    required this.highlightColor,
    required this.textColor,
    required this.secondaryTextColor,
  });

  final _Stats stats;
  final Color highlightColor;
  final Color textColor;
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = stats.summary;
    final weightFormatter = NumberFormat.decimalPattern();
    final double dryValue = summary.dryWeight;
    final double wetValue = summary.wetWeight;
    final double mixedValue = summary.mixWeight;
    final double computedTotal = dryValue + wetValue + mixedValue;

    Widget buildSwatch(RadialBarData item) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: DashboardThemeTokens.spacing6),
          Text(
            item.valueLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${weightFormatter.format(stats.primaryValue)} Kg',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: DashboardThemeTokens.spacing4),
              Text(
                stats.primaryLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DashboardThemeTokens.spacing6),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      BorderRadius.circular(DashboardThemeTokens.radiusLarge),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: DashboardThemeTokens.spacing12,
                  vertical: DashboardThemeTokens.spacing8,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.start,
                  children:
                      stats.progressItems.map((item) => buildSwatch(item)).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DashboardThemeTokens.spacing12),
        SizedBox(
          width: 120,
          height: 120,
          child: WasteRadialBreakdown(
            items: stats.progressItems,
            totalValue: computedTotal,
            textColor: textColor,
            backgroundColor: theme.colorScheme.surface,
          ),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.controller,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.localizations,
  });
  final NotificationController controller;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final hasAlerts = controller.alerts.isNotEmpty;
    const double bellButtonSize = 34;
    const double bellIconSize = 18.0;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                border: Border.all(color: borderColor),
                boxShadow: const [DashboardThemeTokens.lightShadow],
              ),
              child: IconButton(
                icon: Icon(
                  hasAlerts
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_rounded,
                ),
                color: iconColor,
                tooltip: localizations.notificationsLabel,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: bellButtonSize,
                  height: bellButtonSize,
                ),
                iconSize: bellIconSize,
                onPressed: () {
                  _openNotificationsSheet(context);
                },
              ),
            ),
            if (controller.hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openNotificationsSheet(BuildContext context) async {
    controller.markRead();
    final theme = Theme.of(context);
    if (controller.alerts.isEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: theme.colorScheme.primary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.notificationsCaughtUp,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.notificationsWaiting,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).padding.bottom;
        return FractionallySizedBox(
          heightFactor: 0.65,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              20 + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.notificationsLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: controller.alerts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: DashboardThemeTokens.spacing12),
                    itemBuilder: (_, index) {
                      final alert = controller.alerts[index];
                      final timestampLabel =
                          DateFormat('MMM d, h:mm a').format(alert.timestamp);

                      return NotificationTile(
                        alert: alert,
                        timestampLabel: timestampLabel,
                        onTrack: () {
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
