import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cards.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_header.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_qr_button.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

const EdgeInsets _pagePadding =
    EdgeInsets.symmetric(horizontal: 20, vertical: 16);

class OperatorHomeScreen extends StatelessWidget {
  const OperatorHomeScreen({
    super.key,
    required this.operatorName,
    required this.operatorCode,
    required this.wardLabel,
    required this.zoneLabel,
    required this.onScanPressed,
    required this.onLogout,
    this.onOpenAttendance,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenAttendanceSummary,
    this.nextStop,
    this.lastCollection,
    this.attendanceSummary,
  });

  final String operatorName;
  final String operatorCode;
  final String wardLabel;
  final String zoneLabel;
  final VoidCallback onScanPressed;
  final VoidCallback onLogout;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenAttendanceSummary;
  final OperatorNextStop? nextStop;
  final OperatorCollectionSummary? lastCollection;
  final OperatorAttendanceSummary? attendanceSummary;

  @override
  Widget build(BuildContext context) {
    final resolvedNextStop = nextStop ?? const OperatorNextStop();
    final resolvedLastCollection =
        lastCollection ?? const OperatorCollectionSummary();
    final resolvedAttendance =
        attendanceSummary ?? const OperatorAttendanceSummary();
    final localizations = AppLocalizations.of(context);

    final nextSubtitle = resolvedNextStop.locationName.isNotEmpty
        ? resolvedNextStop.locationName
        : (resolvedNextStop.label ?? '');
    final nextStatus = resolvedNextStop.status ?? 'Scheduled';
    final nextEta = resolvedNextStop.scheduledTime.isNotEmpty
        ? resolvedNextStop.scheduledTime
        : (resolvedNextStop.timeRemaining ?? '--');
    final nextRoute = resolvedNextStop.routeName ?? 'Route not assigned';

    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OperatorHeader(
              name: operatorName,
              badge: operatorCode,
              ward: wardLabel,
              zone: zoneLabel,
              onLogout: onLogout,
              onMenuTap: onOpenProfile,
              subtitle: localizations.operatorHeaderSubtitle(
                operatorName,
                operatorCode,
              ),
            ),
            Padding(
              padding: _pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OperatorInfoCard(
                    title: localizations.operatorNextStop,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    subtitle: nextSubtitle.isNotEmpty
                        ? nextSubtitle
                        : localizations.operatorUpcomingStop,
                    trailing: Chip(
                      label: Text(
                        nextStatus,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      children: [
                        _InfoRowItem(
                          icon: Icons.location_pin,
                          title: localizations.operatorRouteLabel,
                          value: nextRoute,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.center,
                    child: OperatorQRButton(onTap: onScanPressed),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      localizations.operatorTapToScan,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OperatorInfoCard(
                    title: localizations.operatorLastCollected,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    subtitle: resolvedLastCollection.collectedAt ??
                        resolvedLastCollection.lastPickupAt,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 14),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _InfoRowItem(
                          icon: Icons.recycling_rounded,
                          title: localizations.operatorWet,
                          value:
                              '${(resolvedLastCollection.wetKg ?? resolvedLastCollection.totalWetKg).toStringAsFixed(1)} kg',
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Colors.black.withOpacity(0.05),
                        ),
                        _InfoRowItem(
                          icon: Icons.layers_rounded,
                          title: localizations.operatorDry,
                          value:
                              '${(resolvedLastCollection.dryKg ?? resolvedLastCollection.totalDryKg).toStringAsFixed(1)} kg',
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Colors.black.withOpacity(0.05),
                        ),
                        _InfoRowItem(
                          icon: Icons.access_time,
                          title: localizations.operatorTime,
                          value: resolvedLastCollection.timeTaken ??
                              resolvedLastCollection.lastPickupAt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AttendanceSection(
                    summary: resolvedAttendance,
                    onTap: onOpenAttendance,
                    onHistoryTap: onOpenHistory,
                    onSummaryTap: onOpenAttendanceSummary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRowItem extends StatelessWidget {
  const _InfoRowItem({
    required this.icon,
    required this.title,
    required this.value,
    this.expand = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (expand) {
      return Expanded(child: content);
    }
    return Flexible(fit: FlexFit.loose, child: content);
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({
    required this.summary,
    this.onTap,
    this.onHistoryTap,
    this.onSummaryTap,
  });

  final OperatorAttendanceSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onSummaryTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final localizations = AppLocalizations.of(context);
    return OperatorInfoCard(
      title: localizations.operatorAttendanceTitle,
      subtitle: localizations.operatorAttendanceSubtitle,
      trailing: IconButton(
        tooltip: localizations.operatorAttendanceOpen,
        onPressed: onTap,
        icon: const Icon(
          Icons.open_in_new_rounded,
          color: AppColors.primary,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OperatorQuickStat(
                      label: localizations.operatorAttendanceToday,
                      value: summary.todayStatus,
                      icon: Icons.check_circle_outline,
                      emphasis: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OperatorQuickStat(
                      label: localizations.operatorAttendanceMonth,
                      value: summary.monthStat ?? "--",
                      icon: Icons.calendar_month_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OperatorQuickStat(
                      label: localizations.operatorLeaveBalance,
                      value: summary.leaveBalance ?? "--",
                      icon: Icons.local_florist_outlined,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.streakLabel ?? localizations.operatorAttendanceStreak,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      const SizedBox(height: 4),
                      Text(
                        summary.streakValue ?? "--",
                        style: AppTextStyles.heading2.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: localizations.operatorAttendanceSummary,
                      onPressed: onSummaryTap ?? onTap,
                      icon:
                          const Icon(Icons.summarize, color: AppColors.primary),
                    ),
                    IconButton(
                      tooltip: localizations.operatorAttendanceHistory,
                      onPressed: onHistoryTap ?? onTap,
                      icon: const Icon(Icons.history, color: AppColors.primary),
                    ),
                    ElevatedButton.icon(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.event_available,
                          color: Colors.white),
                      label: Text(
                        localizations.operatorAttendanceMark,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
