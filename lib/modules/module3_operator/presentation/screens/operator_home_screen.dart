// operator_home_screen.dart - PART 1/2
// ✅ Fixed: Notification spam, Real Next Stop data with action buttons

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_repository.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cards.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_header.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_qr_button.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/assignment_status_store.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const EdgeInsets _pagePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

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
    this.onOpenAssignments,
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
  final void Function(DailyAssignmentModel assignment)? onOpenAssignments;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenAttendanceSummary;
  final OperatorNextStop? nextStop;
  final OperatorCollectionSummary? lastCollection;
  final OperatorAttendanceSummary? attendanceSummary;

  @override
  Widget build(BuildContext context) {
    final resolvedLastCollection = lastCollection ?? const OperatorCollectionSummary();
    final resolvedAttendance = attendanceSummary ?? const OperatorAttendanceSummary();
    final localizations = AppLocalizations.of(context);

    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OperatorHeader(
              name: operatorName,
              empId: emp_id,
              badge: operatorCode,
              ward: wardLabel,
              zone: zoneLabel,
              onLogout: onLogout,
              onMenuTap: onOpenProfile,
              subtitle: localizations.operatorHeaderSubtitle(operatorName, operatorCode),
            ),
            Padding(
              padding: _pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Real Next Stop with action buttons
                  _NextStopSection(
                    onOpenAssignments: onOpenAssignments,
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
                  _OperatorAssignmentsSection(onOpenAssignments: onOpenAssignments),
                  const SizedBox(height: 24),
                  OperatorInfoCard(
                    title: localizations.operatorLastCollected,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    subtitle: resolvedLastCollection.collectedAt ?? resolvedLastCollection.lastPickupAt,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 14),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _InfoRowItem(
                          icon: Icons.recycling_rounded,
                          title: localizations.operatorWet,
                          value: '${(resolvedLastCollection.wetKg ?? resolvedLastCollection.totalWetKg).toStringAsFixed(1)} kg',
                        ),
                        Container(width: 1, height: 42, color: Colors.black.withOpacity(0.05)),
                        _InfoRowItem(
                          icon: Icons.layers_rounded,
                          title: localizations.operatorDry,
                          value: '${(resolvedLastCollection.dryKg ?? resolvedLastCollection.totalDryKg).toStringAsFixed(1)} kg',
                        ),
                        Container(width: 1, height: 42, color: Colors.black.withOpacity(0.05)),
                        _InfoRowItem(
                          icon: Icons.access_time,
                          title: localizations.operatorTime,
                          value: resolvedLastCollection.timeTaken ?? resolvedLastCollection.lastPickupAt,
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
    return Flexible(
      fit: FlexFit.loose,
      child: Row(
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
      ),
    );
  }
}
// operator_home_screen.dart - PART 2/2
// ✅ Real Next Stop Section with Collect/Skip/Later buttons

class _NextStopSection extends StatefulWidget {
  const _NextStopSection({this.onOpenAssignments});
  
  final void Function(DailyAssignmentModel assignment)? onOpenAssignments;

  @override
  State<_NextStopSection> createState() => _NextStopSectionState();
}

class _NextStopSectionState extends State<_NextStopSection> {
  late final AssignmentRepository _assignmentRepository;
  Map<String, dynamic>? _nextCitizen;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    _loadNextCitizen();
  }

  Future<void> _loadNextCitizen() async {
    setState(() => _loading = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthStateAuthenticated) {
        setState(() {
          _nextCitizen = null;
          _loading = false;
        });
        return;
      }

      final assignments = await _assignmentRepository.fetchAssignmentsForOperator(
        operatorId: authState.userId.trim(),
      );

      if (assignments.isEmpty) {
        setState(() {
          _nextCitizen = null;
          _loading = false;
        });
        return;
      }

      // Get first assignment
      final assignment = assignments.first;
      final dio = await authorizedDio();
      
      // Fetch customers for this ward
      final resp = await dio.get(
        ApiConfig.customerList,
        queryParameters: {'ward': assignment.wardId},
      );
      
      final decoded = resp.data;
      final list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);

      if (list.isEmpty) {
        setState(() {
          _nextCitizen = null;
          _loading = false;
        });
        return;
      }

      // Load statuses from SharedPreferences
      final ids = list.map((e) => (e['unique_id'] ?? e['customer_id'] ?? '').toString()).toList();
      final statuses = await AssignmentStatusStore.getStatusesFor(ids);

      // Find first pending citizen
      Map<String, dynamic>? nextPending;
      for (final customer in list) {
        if (customer is! Map) continue;
        final id = (customer['unique_id'] ?? customer['customer_id'] ?? '').toString();
        if (id.isEmpty) continue;
        
        final status = statuses[id]?.toLowerCase();
        if (status == null || status == 'later') {
nextPending = Map<String, dynamic>.from(customer as Map);
          break;
        }
      }

      setState(() {
        _nextCitizen = nextPending;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _nextCitizen = null;
        _loading = false;
      });
    }
  }

  Future<void> _handleAction(String action) async {
    if (_nextCitizen == null) return;

    final id = (_nextCitizen!['unique_id'] ?? _nextCitizen!['customer_id'] ?? '').toString();
    
    if (action == 'collect') {
      // Navigate to data collection screen
      if (!mounted) return;
      await context.push(
        AppRoutePaths.operatorData,
        extra: {
          'customerId': id,
          'customerName': (_nextCitizen!['customer_name'] ?? _nextCitizen!['name'] ?? 'Citizen').toString(),
          'contactNo': (_nextCitizen!['contact_no'] ?? _nextCitizen!['phone'] ?? '').toString(),
          'latitude': (_nextCitizen!['latitude'] ?? _nextCitizen!['customer_latitude'] ?? '').toString(),
          'longitude': (_nextCitizen!['longitude'] ?? _nextCitizen!['customer_longitude'] ?? '').toString(),
          'skipBluetoothInit': true,
        },
      );
      if (!mounted) return;
      await AssignmentStatusStore.setStatus(id, 'collected');
      _loadNextCitizen();
    } else if (action == 'skip') {
      await AssignmentStatusStore.setStatus(id, 'skipped');
      _loadNextCitizen();
    } else if (action == 'later') {
      await AssignmentStatusStore.setStatus(id, 'later');
      _loadNextCitizen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return OperatorInfoCard(
        title: 'Next Stop',
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        subtitle: 'Loading...',
        child: const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_nextCitizen == null) {
      return OperatorInfoCard(
        title: 'Next Stop',
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        subtitle: 'All citizens completed',
        trailing: const Chip(
          label: Text('Done', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          backgroundColor: Color(0x1A4CAF50),
          shape: StadiumBorder(),
        ),
        child: const SizedBox(height: 20),
      );
    }

    final name = (_nextCitizen!['customer_name'] ?? _nextCitizen!['name'] ?? 'Citizen').toString();
    final id = (_nextCitizen!['unique_id'] ?? _nextCitizen!['customer_id'] ?? '').toString();
    final contact = (_nextCitizen!['contact_no'] ?? _nextCitizen!['phone'] ?? '').toString();

    return OperatorInfoCard(
      title: 'Next Stop',
      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      subtitle: name,
      trailing: const Chip(
        label: Text('Pending', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        backgroundColor: Color(0x1A003D7D),
        shape: StadiumBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'ID: $id',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (contact.isNotEmpty)
            Text(
              'Contact: $contact',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleAction('collect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Collect', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleAction('skip'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleAction('later'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: Colors.blue.shade700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Later', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ✅ FIXED: Notification spam - Only notify once per assignment
class _OperatorAssignmentsSection extends StatefulWidget {
  const _OperatorAssignmentsSection({this.onOpenAssignments});

  final void Function(DailyAssignmentModel assignment)? onOpenAssignments;

  @override
  State<_OperatorAssignmentsSection> createState() => _OperatorAssignmentsSectionState();
}

class _OperatorAssignmentsSectionState extends State<_OperatorAssignmentsSection> {
  late final AssignmentRepository _assignmentRepository;
  late Future<List<DailyAssignmentModel>> _future;
  
  // ✅ FIX: Track notified assignments persistently
  static const String _notifiedKey = 'notified_assignments';
  Set<String> _notifiedAssignmentIds = {};

@override
void initState() {
  super.initState();
  _assignmentRepository = getIt<AssignmentRepository>();

  // ✅ Always initialize immediately
  _future = _loadAssignments();

  // Load notified IDs in background
  _loadNotifiedIds();
}


  Future<void> _loadNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_notifiedKey) ?? [];
    _notifiedAssignmentIds = Set.from(list);
  }

  Future<void> _saveNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_notifiedKey, _notifiedAssignmentIds.toList());
  }

  Future<List<DailyAssignmentModel>> _loadAssignments() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthStateAuthenticated) return [];

    final operatorId = authState.userId.trim();
    if (operatorId.isEmpty) return [];

    final assignments = await _assignmentRepository.fetchAssignmentsForOperator(operatorId: operatorId);
    
    // ✅ Only notify NEW assignments
    await _notifyNewAssignments(assignments);
    
    return assignments;
  }

  Future<void> _notifyNewAssignments(List<DailyAssignmentModel> assignments) async {
    final newItems = assignments.where((a) => !_notifiedAssignmentIds.contains(a.uniqueId)).toList();
    
    if (newItems.isEmpty) return;

    // Add to notified set
    for (final item in newItems) {
      _notifiedAssignmentIds.add(item.uniqueId);
    }
    await _saveNotifiedIds();

    // Show notification
    final notificationService = getIt<NotificationService>();
    final title = newItems.length == 1 ? 'New assignment' : 'New assignments';
    final message = 'You have ${newItems.length} assignment(s) scheduled today.';
    notificationService.showAssignmentNotification(title: title, message: message);
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
          Text('$label: ${status.displayName}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status.color)),
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
Text("Today's Assignments",
  style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.w800),
),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () => setState(() => _future = _loadAssignments()),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: Text('No assignments yet.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
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
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.onOpenAssignments == null ? null : () => widget.onOpenAssignments!(assignment),
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(assignment.ward, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Driver: ${assignment.driver}', style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 2),
                          Text('Shift: ${assignment.shiftDisplay}', style: AppTextStyles.subTitle.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _statusChip('Driver', assignment.driverStatus),
                              const SizedBox(width: 8),
                              _statusChip('You', assignment.operatorStatus),
                            ],
                          ),
                          const Spacer(),
                          Text('Tap to manage collection', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
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
        icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: OperatorQuickStat(label: localizations.operatorAttendanceToday, value: summary.todayStatus, icon: Icons.check_circle_outline, emphasis: true)),
              const SizedBox(width: 12),
              Expanded(child: OperatorQuickStat(label: localizations.operatorAttendanceMonth, value: summary.monthStat ?? "--", icon: Icons.calendar_month_outlined)),
              const SizedBox(width: 12),
              Expanded(child: OperatorQuickStat(label: localizations.operatorLeaveBalance, value: summary.leaveBalance ?? "--", icon: Icons.local_florist_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.streakLabel ?? localizations.operatorAttendanceStreak, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(summary.streakValue ?? "--", style: AppTextStyles.heading2.copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(tooltip: localizations.operatorAttendanceSummary, onPressed: onSummaryTap ?? onTap, icon: const Icon(Icons.summarize, color: AppColors.primary)),
                    IconButton(tooltip: localizations.operatorAttendanceHistory, onPressed: onHistoryTap ?? onTap, icon: const Icon(Icons.history, color: AppColors.primary)),
                    ElevatedButton.icon(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.event_available, color: Colors.white),
                      label: Text(localizations.operatorAttendanceMark, style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontSize: 12)),
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