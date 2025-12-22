import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_repository.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cards.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_header.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_qr_button.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

const EdgeInsets _pagePadding =
    EdgeInsets.symmetric(horizontal: 20, vertical: 16);

class OperatorHomeScreen extends StatelessWidget {
  const OperatorHomeScreen({
    super.key,
    required this.operatorName,
    required this.operatorCode,
    required this.emp_id,
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
   final String emp_id;
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
  empId: emp_id, // ✅ map old variable to new param
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
                  const _OperatorAssignmentsSection(),
                  const SizedBox(height: 24),
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
  });

  final IconData icon;
  final String title;
  final String value;

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

    return Flexible(fit: FlexFit.loose, child: content);
  }
}

class _OperatorAssignmentsSection extends StatefulWidget {
  const _OperatorAssignmentsSection();

  @override
  State<_OperatorAssignmentsSection> createState() =>
      _OperatorAssignmentsSectionState();
}

class _OperatorAssignmentsSectionState
    extends State<_OperatorAssignmentsSection> {
  late final AssignmentRepository _assignmentRepository;
  late Future<List<DailyAssignmentModel>> _future;
  final Set<String> _notifiedAssignmentIds = {};
  final Set<String> _notifiedCancelledAssignmentIds = {};

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    _future = _loadAssignments();
  }

  Future<List<DailyAssignmentModel>> _loadAssignments() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthStateAuthenticated) {
      return [];
    }

    final operatorId = authState.userId.trim();
    if (operatorId.isEmpty) {
      return [];
    }

    final assignments = await _assignmentRepository.fetchAssignmentsForOperator(
      operatorId: operatorId,
    );
    _notifyNewAssignments(assignments);
    await _notifyCancelledAssignments(operatorId);
    return assignments;
  }

  void _notifyNewAssignments(List<DailyAssignmentModel> assignments) {
    final newItems = assignments
        .where((a) => _notifiedAssignmentIds.add(a.uniqueId))
        .toList();
    if (newItems.isEmpty) return;

    final notificationService = getIt<NotificationService>();
    final title =
        newItems.length == 1 ? 'New assignment' : 'New assignments';
    final message =
        'You have ${newItems.length} assignment(s) scheduled today.';
    notificationService.showAssignmentNotification(
      title: title,
      message: message,
    );
  }

  Future<void> _notifyCancelledAssignments(String staffId) async {
    try {
      final dio = await authorizedDio();
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final resp = await dio.get(
        ApiConfig.staffAssignments,
        queryParameters: {
          'staff_id': staffId,
          'status': 'cancelled',
          'date_from': dateStr,
          'date_to': dateStr,
        },
      );

      final decoded = resp.data;
      final List list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);

      for (final item in list) {
        if (item is! Map) continue;
        final id = item['unique_id']?.toString();
        if (id == null || id.isEmpty) continue;
        if (!_notifiedCancelledAssignmentIds.add(id)) continue;

        final wardName = item['ward_name']?.toString() ?? 'Assignment';
        final reason =
            item['cancelled_reason']?.toString() ?? 'No reason provided';

        final notificationService = getIt<NotificationService>();
        notificationService.showAssignmentNotification(
          title: 'Assignment cancelled',
          message: '$wardName • $reason',
        );
      }
    } catch (_) {
      // Ignore notification failures.
    }
  }

  Future<void> _markCompleted(DailyAssignmentModel assignment) async {
    try {
      final authRepo = getIt<AuthRepository>();
      final user = await authRepo.getAuthenticatedUser();
      if (user?.authToken == null || user!.authToken!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final dio = await authorizedDio();
      await dio.post(
        '${ApiConfig.assignments}${assignment.uniqueId}/complete/',
        options: Options(
          headers: {'Authorization': 'Bearer ${user.authToken}'},
        ),
      );
      if (!mounted) return;
      setState(() {
        _future = _loadAssignments();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as completed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update completion'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _statusChip(String label, AssignmentRoleStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status.color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(
            '$label: ${status.displayName}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Today’s Assignments',
              style: AppTextStyles.heading2.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () {
                setState(() {
                  _future = _loadAssignments();
                });
              },
            ),
          ],
        ),
        SizedBox(
          height: 190,
          child: FutureBuilder<List<DailyAssignmentModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final assignments = snapshot.data ?? [];
              if (assignments.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'No assignments yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: assignments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  final canComplete =
                      assignment.operatorStatus != AssignmentRoleStatus.completed &&
                          assignment.currentStatus != AssignmentStatus.cancelled &&
                          assignment.currentStatus != AssignmentStatus.skipped;

                  return Container(
                    width: 260,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.ward,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading2.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Driver: ${assignment.driver}',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shift: ${assignment.shiftDisplay}',
                          style: AppTextStyles.subTitle.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _statusChip('Driver', assignment.driverStatus),
                            const SizedBox(width: 8),
                            _statusChip('You', assignment.operatorStatus),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                canComplete ? () => _markCompleted(assignment) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              assignment.operatorStatus ==
                                      AssignmentRoleStatus.completed
                                  ? 'Completed'
                                  : 'Mark Completed',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
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
