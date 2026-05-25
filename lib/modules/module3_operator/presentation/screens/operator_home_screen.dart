// operator_home_screen.dart - PART 1/2
// ✅ Fixed: Notification spam, Real Next Stop data with action buttons

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_service.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cards.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_header.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_qr_button.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/assignment_status_store.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/skip_reasons.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:iwms_citizen_app/router/route_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const EdgeInsets _pagePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

class OperatorHomeScreen extends StatelessWidget {
  const OperatorHomeScreen({
    super.key,
    required this.operatorName,
    required this.operatorCode,
    required this.emp_id,
    required this.employeeCode,
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
  final String employeeCode;
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
              displayId: employeeCode,
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
                  ValueListenableBuilder<int>(
                    valueListenable: AssignmentStatusStore.notifier,
                    builder: (context, _, __) {
                      return _OperatorAssignmentsSection(
                        key: ValueKey(AssignmentStatusStore.notifier.value),
                        onOpenAssignments: onOpenAssignments,
                      );
                    },
                  ),
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
enum _NextStopStatus { pending, collected, skipped, later }

class _NextStopCitizen {
  const _NextStopCitizen({
    required this.id,
    required this.name,
    required this.contact,
    required this.latitude,
    required this.longitude,
    required this.matchIds,
  });

  final String id;
  final String name;
  final String contact;
  final String latitude;
  final String longitude;
  final Set<String> matchIds;
}

// ✅ Real Next Stop Section with Collect/Skip/Later buttons
class _NextStopSection extends StatefulWidget {
  const _NextStopSection({this.onOpenAssignments});

  final void Function(DailyAssignmentModel assignment)? onOpenAssignments;

  @override
  State<_NextStopSection> createState() => _NextStopSectionState();
}

class _NextStopSectionState extends State<_NextStopSection> {
  late final AssignmentRepository _assignmentRepository;
  DailyAssignmentModel? _activeAssignment;
  List<_NextStopCitizen> _citizens = [];
  final Map<String, _NextStopStatus> _statuses = {};
  bool _loading = true;
  late final VoidCallback _statusListener;

  String _normalizeId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  bool _matchesCitizen(_NextStopCitizen citizen, String scannedId) {
    final normalized = _normalizeId(scannedId);
    for (final id in citizen.matchIds) {
      if (_normalizeId(id) == normalized) {
        return true;
      }
    }
    return false;
  }

  _NextStopStatus? _statusFromValue(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'collected':
        return _NextStopStatus.collected;
      case 'skipped':
        return _NextStopStatus.skipped;
      case 'later':
        return _NextStopStatus.later;
      default:
        return null;
    }
  }

  _NextStopStatus? _pickBestStatus(
    _NextStopStatus? current,
    _NextStopStatus candidate,
  ) {
    if (current == null) return candidate;
    if (current == _NextStopStatus.collected) return current;
    if (candidate == _NextStopStatus.collected) return candidate;
    if (current == _NextStopStatus.skipped) return current;
    if (candidate == _NextStopStatus.skipped) return candidate;
    if (current == _NextStopStatus.later) return current;
    if (candidate == _NextStopStatus.later) return candidate;
    return current;
  }

  Future<String?> _resolveCustomerId(String scannedId) async {
    try {
      final uri = Uri.parse("${ApiConfig.desktopBase}waste/customer/")
          .replace(queryParameters: {"unique_id": scannedId});
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map || decoded["status"] != "success") return null;
      final data = decoded["data"];
      if (data is Map && data["unique_id"] != null) {
        return data["unique_id"].toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    _statusListener = _handleStatusStoreChange;
    AssignmentStatusStore.notifier.addListener(_statusListener);
    _loadNextCitizen();
  }

  @override
  void dispose() {
    AssignmentStatusStore.notifier.removeListener(_statusListener);
    super.dispose();
  }

  void _handleStatusStoreChange() {
    if (_activeAssignment == null || _citizens.isEmpty) return;
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final assignment = _activeAssignment;
    if (assignment == null) return;
    final lookupIds = <String>{};
    for (final citizen in _citizens) {
      lookupIds.addAll(citizen.matchIds);
    }
    final persisted = await AssignmentStatusStore.getStatusesFor(
      assignment.uniqueId,
      lookupIds,
    );
    if (!mounted) return;
    setState(() {
      _statuses.clear();
      for (final citizen in _citizens) {
        _NextStopStatus? resolved;
        for (final matchId in citizen.matchIds) {
          final status = _statusFromValue(persisted[matchId]);
          if (status == null) continue;
          resolved = _pickBestStatus(resolved, status);
        }
        if (resolved != null) {
          _statuses[citizen.id] = resolved;
        }
      }
    });
    await _maybeCompleteAssignment(assignment);
  }

  Future<void> _maybeCompleteAssignment(DailyAssignmentModel assignment) async {
    if (_citizens.isEmpty) return;
    final allDone = _citizens.every((c) {
      final status = _statusFor(c.id);
      return status == _NextStopStatus.collected ||
          status == _NextStopStatus.skipped;
    });
    if (!allDone) return;
    final alreadyCompleted =
        await AssignmentStatusStore.isAssignmentCompleted(assignment.uniqueId);
    if (alreadyCompleted) return;
    await AssignmentStatusStore.setAssignmentCompleted(assignment.uniqueId);
    await _markAssignmentComplete(assignment.uniqueId);
    _loadNextCitizen();
  }

  Future<void> _loadNextCitizen() async {
    setState(() => _loading = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthStateAuthenticated) {
        setState(() {
          _activeAssignment = null;
          _citizens = [];
          _statuses.clear();
          _loading = false;
        });
        return;
      }

      final assignments =
          await _assignmentRepository.fetchAssignmentsForOperator(
        operatorId: authState.userId.trim(),
      );

      final completed = await AssignmentStatusStore.getCompletedAssignments();
      bool isCompleted(DailyAssignmentModel assignment) {
        final key = AssignmentStatusStore.normalizeId(assignment.uniqueId);
        return completed.contains(key);
      }

      final activeAssignments = assignments
          .where((assignment) =>
              assignment.isActive && !isCompleted(assignment))
          .toList();

      if (activeAssignments.isEmpty) {
        setState(() {
          _activeAssignment = null;
          _citizens = [];
          _statuses.clear();
          _loading = false;
        });
        return;
      }

      final assignment = activeAssignments.first;
      final dio = await authorizedDio();
      List<dynamic> list = [];

      Future<void> fetchWithParam(String paramKey) async {
        final resp = await dio.get(
          ApiConfig.customerList,
          queryParameters: {paramKey: assignment.wardId},
        );
        final decoded = resp.data;
        list = decoded is List
            ? decoded
            : (decoded is Map
                ? (decoded['results'] ?? decoded['data'] ?? [])
                : []);
      }

      try {
        if (assignment.wardId.trim().isNotEmpty) {
          await fetchWithParam('ward');
          if (list.isEmpty) {
            await fetchWithParam('ward_id');
          }
        } else {
          final resp = await dio.get(ApiConfig.customerList);
          final decoded = resp.data;
          list = decoded is List
              ? decoded
              : (decoded is Map
                  ? (decoded['results'] ?? decoded['data'] ?? [])
                  : []);
        }
      } catch (_) {
        // ignore fetch errors
      }

      final citizens = <_NextStopCitizen>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        if (assignment.wardId.trim().isNotEmpty) {
          final rawWard = entry['ward_id'] ?? entry['ward'];
          String? entryWardId;
          if (rawWard is Map) {
            entryWardId =
                (rawWard['unique_id'] ?? rawWard['id'] ?? rawWard['pk'])
                    ?.toString();
          } else if (rawWard != null) {
            entryWardId = rawWard.toString();
          }
          if (entryWardId != assignment.wardId) {
            continue;
          }
        }
        final id =
            (entry['unique_id'] ?? entry['customer_id'] ?? '').toString();
        if (id.isEmpty) continue;
        citizens.add(
          _NextStopCitizen(
            id: id,
            name: (entry['customer_name'] ?? entry['name'] ?? 'Citizen')
                .toString(),
            contact: (entry['contact_no'] ?? entry['phone'] ?? '').toString(),
            latitude:
                (entry['latitude'] ?? entry['customer_latitude'] ?? '')
                    .toString(),
            longitude:
                (entry['longitude'] ?? entry['customer_longitude'] ?? '')
                    .toString(),
            matchIds: {
              id,
              if (entry['id'] != null) entry['id'].toString(),
              if (entry['customer_id'] != null)
                entry['customer_id'].toString(),
              if (entry['unique_id'] != null) entry['unique_id'].toString(),
              if (entry['contact_no'] != null)
                entry['contact_no'].toString(),
            },
          ),
        );
      }

      final isEmergency =
          assignment.assignmentType.toLowerCase() == 'emergency';
      final emergencyCustomerId = assignment.customerId?.trim() ?? '';
      final filteredCitizens = (isEmergency && emergencyCustomerId.isNotEmpty)
          ? citizens.where((c) => c.id == emergencyCustomerId).toList()
          : citizens;

      final lookupIds = <String>{};
      for (final citizen in filteredCitizens) {
        lookupIds.addAll(citizen.matchIds);
      }
      final persisted = await AssignmentStatusStore.getStatusesFor(
        assignment.uniqueId,
        lookupIds,
      );

      setState(() {
        _activeAssignment = assignment;
        _citizens = filteredCitizens;
        _statuses.clear();
        for (final citizen in filteredCitizens) {
          _NextStopStatus? resolved;
          for (final matchId in citizen.matchIds) {
            final status = _statusFromValue(persisted[matchId]);
            if (status == null) continue;
            resolved = _pickBestStatus(resolved, status);
          }
          if (resolved != null) {
            _statuses[citizen.id] = resolved;
          }
        }
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _activeAssignment = null;
        _citizens = [];
        _statuses.clear();
        _loading = false;
      });
    }
  }

  _NextStopStatus _statusFor(String id) =>
      _statuses[id] ?? _NextStopStatus.pending;

  Future<String?> _promptSkipReason() async {
    String? selectedReason;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Skip Waste Collection'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select a reason for skipping:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      hintText: 'Reason',
                    ),
                    items: operatorSkipReasons
                        .map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(
                              reason,
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setStateDialog(() => selectedReason = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Skip'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return null;
    return selectedReason;
  }

  Future<void> _setStatus(_NextStopCitizen citizen, _NextStopStatus status) async {
    final assignment = _activeAssignment;
    if (assignment == null) return;
    final current = _statuses[citizen.id];
    if (current == _NextStopStatus.collected ||
        current == _NextStopStatus.skipped) {
      return;
    }

    String? skipReason;
    if (status == _NextStopStatus.skipped) {
      skipReason = await _promptSkipReason();
      if (!mounted || skipReason == null) return;
    }

    setState(() => _statuses[citizen.id] = status);
    final statusStr = status == _NextStopStatus.collected
        ? 'collected'
        : status == _NextStopStatus.skipped
            ? 'skipped'
            : 'later';
    await AssignmentStatusStore.setStatusForAssignment(
      assignment.uniqueId,
      citizen.id,
      statusStr,
    );
    await _syncStatusToBackend(
      assignmentId: assignment.uniqueId,
      customerId: citizen.id,
      status: statusStr,
      skipReason: skipReason,
      latitude: citizen.latitude,
      longitude: citizen.longitude,
    );

    final allDone = _citizens.isNotEmpty &&
        _citizens.every((c) {
          final status = _statusFor(c.id);
          return status == _NextStopStatus.collected ||
              status == _NextStopStatus.skipped;
        });
    if (allDone) {
      await AssignmentStatusStore.setAssignmentCompleted(assignment.uniqueId);
      await _markAssignmentComplete(assignment.uniqueId);
      _loadNextCitizen();
    }
  }

  Future<void> _handleCollect(_NextStopCitizen citizen) async {
    final scannedId = await context.push(
      AppRoutePaths.operatorQR,
      extra: {
        'expectedCustomerId': citizen.id,
        'expectedCustomerName': citizen.name,
        'expectedAssignmentId': _activeAssignment?.uniqueId,
        'returnToAssignments': true,
      },
    );

    if (!mounted) return;
    final scanned = scannedId?.toString().trim();
    if (scanned == null || scanned.isEmpty) {
      return;
    }

    String effectiveId = scanned;
    if (!_matchesCitizen(citizen, scanned)) {
      final resolvedId = await _resolveCustomerId(scanned);
      if (!mounted) return;
      if (resolvedId != null) {
        effectiveId = resolvedId;
      }
    }

    if (!_matchesCitizen(citizen, effectiveId)) {
      final matchedOther = _citizens.firstWhere(
        (c) => _matchesCitizen(c, effectiveId),
        orElse: () => citizen,
      );
      final selectedName = citizen.name;
      final scannedName =
          matchedOther == citizen ? 'unknown citizen' : matchedOther.name;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR mismatch. Selected $selectedName, scanned $scannedName.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final didSubmit = await context.push(
      AppRoutePaths.operatorData,
      extra: {
        'customerId': effectiveId,
        'customerName': citizen.name,
        'contactNo': citizen.contact,
        'latitude': citizen.latitude,
        'longitude': citizen.longitude,
        'skipBluetoothInit': true,
        'assignmentId': _activeAssignment?.uniqueId,
      },
    );
    if (!mounted) return;
    if (didSubmit == true) {
      await _setStatus(citizen, _NextStopStatus.collected);
      _loadNextCitizen();
    }
  }

  Future<void> _syncStatusToBackend({
    required String assignmentId,
    required String? customerId,
    required String status,
    String? skipReason,
    String? latitude,
    String? longitude,
  }) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return;

    try {
      final dio = await authorizedDio();
      await dio.post(
        ApiConfig.assignmentCustomerStatuses,
        data: {
          'assignment': assignmentId,
          if (customerId != null) 'customer': customerId,
          'status': status,
          if (skipReason != null) 'skip_reason': skipReason,
          if (latitude != null && latitude.isNotEmpty) 'latitude': latitude,
          if (longitude != null && longitude.isNotEmpty) 'longitude': longitude,
        },
      );
    } catch (_) {
      // ignore best-effort sync failures
    }
  }

  Future<void> _markAssignmentComplete(String assignmentId) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return;

    try {
      final dio = await authorizedDio();
      await dio.post('${ApiConfig.assignments}$assignmentId/complete/');
    } catch (_) {
      // best-effort
    }
  }

  Color _statusColor(_NextStopStatus status) {
    switch (status) {
      case _NextStopStatus.collected:
        return Colors.green.shade700;
      case _NextStopStatus.skipped:
        return Colors.orange.shade700;
      case _NextStopStatus.later:
        return Colors.blue.shade700;
      case _NextStopStatus.pending:
        return AppColors.primary;
    }
  }

  String _statusLabel(_NextStopStatus status) {
    switch (status) {
      case _NextStopStatus.collected:
        return 'Collected';
      case _NextStopStatus.skipped:
        return 'Skipped';
      case _NextStopStatus.later:
        return 'Later';
      case _NextStopStatus.pending:
        return 'Pending';
    }
  }

  Widget _buildCitizenCard(_NextStopCitizen citizen) {
    final status = _statusFor(citizen.id);
    final locked = status == _NextStopStatus.collected ||
        status == _NextStopStatus.skipped;
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  citizen.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ID: ${citizen.id}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (citizen.contact.isNotEmpty)
            Text(
              'Contact: ${citizen.contact}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: locked ? null : () => _handleCollect(citizen),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Collect', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      locked ? null : () => _setStatus(citizen, _NextStopStatus.skipped),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Skip', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      locked ? null : () => _setStatus(citizen, _NextStopStatus.later),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.blue.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Later',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

    if (_activeAssignment == null) {
      return OperatorInfoCard(
        title: 'Next Stop',
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        subtitle: 'No active assignments',
        trailing: const Chip(
          label: Text('Idle',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          backgroundColor: Color(0x1A4CAF50),
          shape: StadiumBorder(),
        ),
        child: const SizedBox(height: 20),
      );
    }

    if (_citizens.isEmpty) {
      return OperatorInfoCard(
        title: 'Next Stop',
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        subtitle: 'No citizens available',
        trailing: const Chip(
          label: Text('Empty',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
          backgroundColor: Color(0x1AFF9800),
          shape: StadiumBorder(),
        ),
        child: const SizedBox(height: 20),
      );
    }

    final nextPending = _citizens.firstWhere(
      (c) => _statusFor(c.id) == _NextStopStatus.pending,
      orElse: () => _citizens.firstWhere(
        (c) => _statusFor(c.id) == _NextStopStatus.later,
        orElse: () => _citizens.first,
      ),
    );

    // If nothing pending, show completed state
    final hasPending = _citizens.any((c) {
      final status = _statusFor(c.id);
      return status == _NextStopStatus.pending ||
          status == _NextStopStatus.later;
    });
    if (!hasPending) {
      return OperatorInfoCard(
        title: 'Next Stop',
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        subtitle: '${_activeAssignment!.ward} • ${_activeAssignment!.shiftDisplay}',
        trailing: const Chip(
          label: Text('Completed',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          backgroundColor: Color(0x1A4CAF50),
          shape: StadiumBorder(),
        ),
        child: const SizedBox(height: 20),
      );
    }

    return OperatorInfoCard(
      title: 'Next Stop',
      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      subtitle: '${_activeAssignment!.ward} • ${_activeAssignment!.shiftDisplay}',
      trailing: const Chip(
        label: Text('Active',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        backgroundColor: Color(0x1A003D7D),
        shape: StadiumBorder(),
      ),
      child: _buildCitizenCard(nextPending),
    );
  }
}

// ✅ FIXED: Notification spam - Only notify once per assignment
class _OperatorAssignmentsSection extends StatefulWidget {
  const _OperatorAssignmentsSection({super.key, this.onOpenAssignments});

  final void Function(DailyAssignmentModel assignment)? onOpenAssignments;

  @override
  State<_OperatorAssignmentsSection> createState() => _OperatorAssignmentsSectionState();
}

class _OperatorAssignmentsSectionState extends State<_OperatorAssignmentsSection>
    with RouteAware {
  late final AssignmentRepository _assignmentRepository;
  late Future<List<DailyAssignmentModel>> _future;
  
  // ✅ FIX: Track notified assignments persistently
  static const String _notifiedKey = 'notified_assignments';
  Set<String> _notifiedAssignmentIds = {};

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    _future = _initAssignments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshAssignments();
  }

  Future<List<DailyAssignmentModel>> _initAssignments() async {
    await _loadNotifiedIds();
    return _loadAssignments();
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

  void _refreshAssignments() {
    if (!mounted) return;
    setState(() {
      _future = _loadAssignments();
    });
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
              onPressed: _refreshAssignments,
            ),
          ],
        ),
        SizedBox(
          height: 170,
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
                          const SizedBox(height: 10),
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
