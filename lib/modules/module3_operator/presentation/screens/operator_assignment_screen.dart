// operator_assignment_screen.dart - PART 1/5
// ✅ Fixed: Notification spam, Added "Later" button, SharedPreferences persistence

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
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
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/assignment_status_store.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/skip_reasons.dart';

class OperatorAssignmentScreen extends StatefulWidget {
  const OperatorAssignmentScreen({
    super.key,
    this.initialAssignment,
  });

  final DailyAssignmentModel? initialAssignment;

  @override
  State<OperatorAssignmentScreen> createState() =>
      _OperatorAssignmentScreenState();
}

enum _CustomerStatus { pending, collected, skipped, later }

class _AssignedCustomer {
  const _AssignedCustomer({
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

class _OperatorAssignmentScreenState extends State<OperatorAssignmentScreen> {
  late final AssignmentRepository _assignmentRepository;
  bool _loadingAssignments = true;
  bool _loadingCustomers = false;
  String? _errorMessage;

  List<DailyAssignmentModel> _currentAssignments = [];
  List<DailyAssignmentModel> _historyAssignments = [];
  DailyAssignmentModel? _selectedAssignment;
  List<_AssignedCustomer> _customers = [];
  final Map<String, _CustomerStatus> _customerStatus = {};
  late final VoidCallback _statusListener;

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    _statusListener = _handleStatusStoreChange;
    AssignmentStatusStore.notifier.addListener(_statusListener);
    _loadAssignments();
  }

  @override
  void dispose() {
    AssignmentStatusStore.notifier.removeListener(_statusListener);
    super.dispose();
  }

  DailyAssignmentModel? _findAssignment(
    List<DailyAssignmentModel> list,
    String id,
  ) {
    for (final assignment in list) {
      if (assignment.uniqueId == id) {
        return assignment;
      }
    }
    return null;
  }

  String _normalizeId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  bool _matchesCustomer(_AssignedCustomer customer, String scannedId) {
    final normalized = _normalizeId(scannedId);
    for (final id in customer.matchIds) {
      if (_normalizeId(id) == normalized) {
        return true;
      }
    }
    return false;
  }

  Future<String?> _resolveCustomerId(String scannedId) async {
    try {
      final uri = Uri.parse("${ApiConfig.mobileBase}waste/customer/")
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

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingAssignments = true;
      _errorMessage = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthStateAuthenticated ||
          authState.userId.trim().isEmpty) {
        setState(() {
          _selectedAssignment = null;
          _loadingAssignments = false;
        });
        return;
      }

      final operatorId = authState.userId.trim();
      final assignments =
          await _assignmentRepository.fetchAssignmentsForOperator(
        operatorId: operatorId,
      );
      List<DailyAssignmentModel> historyFromServer = [];
      try {
        historyFromServer =
            await _assignmentRepository.fetchAssignmentHistory(
          operatorId: operatorId,
        );
      } catch (_) {
        historyFromServer = [];
      }

      final completed = await AssignmentStatusStore.getCompletedAssignments();

      bool isCompleted(DailyAssignmentModel assignment) {
        final key = AssignmentStatusStore.normalizeId(assignment.uniqueId);
        return completed.contains(key);
      }

      final currentAssignments = assignments
          .where((assignment) =>
              assignment.isActive && !isCompleted(assignment))
          .toList();
      final historyById = <String, DailyAssignmentModel>{};

      for (final assignment in historyFromServer) {
        if (!assignment.isActive) {
          historyById[
              AssignmentStatusStore.normalizeId(assignment.uniqueId)] =
              assignment;
        }
      }

      for (final assignment in assignments) {
        if (isCompleted(assignment)) {
          historyById.putIfAbsent(
            AssignmentStatusStore.normalizeId(assignment.uniqueId),
            () => assignment,
          );
        }
      }

      final historyAssignments = historyById.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      DailyAssignmentModel? selected = _selectedAssignment;
      if (currentAssignments.isNotEmpty) {
        if (widget.initialAssignment != null) {
          selected = _findAssignment(
                currentAssignments,
                widget.initialAssignment!.uniqueId,
              ) ??
              currentAssignments.first;
        } else if (selected != null) {
          selected =
              _findAssignment(currentAssignments, selected.uniqueId) ??
                  currentAssignments.first;
        } else {
          selected = currentAssignments.first;
        }
      } else {
        selected = null;
      }

      setState(() {
        _currentAssignments = currentAssignments;
        _historyAssignments = historyAssignments;
        _selectedAssignment = selected;
        _loadingAssignments = false;
      });

      if (selected != null) {
        await _loadCustomersForAssignment(selected);
      }
    } catch (e) {
      setState(() {
        _loadingAssignments = false;
        _errorMessage = 'Unable to load assignments.';
      });
    }
  }
// operator_assignment_screen.dart - PART 2/5
// Continue from Part 1...

  Future<void> _loadCustomersForAssignment(DailyAssignmentModel assignment) async {
    setState(() {
      _loadingCustomers = true;
      _customers = [];
      _customerStatus.clear();
    });

    final wardId = assignment.wardId.trim();
    final dio = await authorizedDio();
    List<dynamic> list = [];

    Future<void> fetchWithParam(String paramKey) async {
      final resp = await dio.get(
        ApiConfig.customerList,
        queryParameters: {paramKey: wardId},
      );
      final decoded = resp.data;
      list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);
    }

    try {
      if (wardId.isNotEmpty) {
        await fetchWithParam('ward');
        if (list.isEmpty) {
          await fetchWithParam('ward_id');
        }
      } else {
        final resp = await dio.get(ApiConfig.customerList);
        final decoded = resp.data;
        list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);
      }
    } catch (_) {
      // ignore
    }

    final customers = <_AssignedCustomer>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      if (wardId.isNotEmpty) {
        final rawWard = entry['ward_id'] ?? entry['ward'];
        String? entryWardId;
        if (rawWard is Map) {
          entryWardId =
              (rawWard['unique_id'] ?? rawWard['id'] ?? rawWard['pk'])
                  ?.toString();
        } else if (rawWard != null) {
          entryWardId = rawWard.toString();
        }
        if (entryWardId != wardId) continue;
      }

      final id = (entry['unique_id'] ?? entry['customer_id'] ?? '').toString();
      if (id.isEmpty) continue;
      customers.add(
        _AssignedCustomer(
          id: id,
          name: (entry['customer_name'] ?? entry['name'] ?? 'Citizen').toString(),
          contact: (entry['contact_no'] ?? entry['phone'] ?? '').toString(),
          latitude: (entry['latitude'] ?? entry['customer_latitude'] ?? '')
              .toString(),
          longitude: (entry['longitude'] ?? entry['customer_longitude'] ?? '')
              .toString(),
          matchIds: {
            id,
            if (entry['id'] != null) entry['id'].toString(),
            if (entry['customer_id'] != null) entry['customer_id'].toString(),
            if (entry['unique_id'] != null) entry['unique_id'].toString(),
            if (entry['contact_no'] != null) entry['contact_no'].toString(),
          },
        ),
      );
    }

    var filteredCustomers = customers;
    final isEmergency =
        assignment.assignmentType.toLowerCase() == 'emergency';
    final emergencyCustomerId = assignment.customerId?.trim() ?? '';
    if (isEmergency && emergencyCustomerId.isNotEmpty) {
      filteredCustomers =
          customers.where((c) => c.id == emergencyCustomerId).toList();
    }

    // ✅ FIX: Load persisted status from SharedPreferences
    final persisted = await AssignmentStatusStore.getStatusesFor(
      assignment.uniqueId,
      filteredCustomers.map((c) => c.id),
    );

    setState(() {
      _customers = filteredCustomers;
      _loadingCustomers = false;
      for (final entry in persisted.entries) {
        final status = entry.value.toLowerCase();
        if (status == 'collected') {
          _customerStatus[entry.key] = _CustomerStatus.collected;
        } else if (status == 'skipped') {
          _customerStatus[entry.key] = _CustomerStatus.skipped;
        } else if (status == 'later') {
          _customerStatus[entry.key] = _CustomerStatus.later;
        }
      }
    });

    await _maybeCompleteAssignment(assignment);
  }

  void _handleStatusStoreChange() {
    final assignment = _selectedAssignment;
    if (assignment == null) return;
    if (_customers.isNotEmpty) {
      _refreshStatusesForAssignment(assignment);
    }
    _syncCompletionStatus(assignment);
  }

  Future<void> _syncCompletionStatus(
    DailyAssignmentModel assignment,
  ) async {
    final completed =
        await AssignmentStatusStore.isAssignmentCompleted(assignment.uniqueId);
    if (!mounted) return;
    if (completed) {
      await _loadAssignments();
    }
  }

  Future<void> _refreshStatusesForAssignment(
    DailyAssignmentModel assignment,
  ) async {
    final persisted = await AssignmentStatusStore.getStatusesFor(
      assignment.uniqueId,
      _customers.map((c) => c.id),
    );
    if (!mounted) return;
    setState(() {
      _customerStatus.clear();
      for (final entry in persisted.entries) {
        final status = entry.value.toLowerCase();
        if (status == 'collected') {
          _customerStatus[entry.key] = _CustomerStatus.collected;
        } else if (status == 'skipped') {
          _customerStatus[entry.key] = _CustomerStatus.skipped;
        } else if (status == 'later') {
          _customerStatus[entry.key] = _CustomerStatus.later;
        }
      }
    });
    await _maybeCompleteAssignment(assignment);
  }

  Future<void> _maybeCompleteAssignment(
    DailyAssignmentModel assignment,
  ) async {
    if (_customers.isEmpty) return;
    final allDone = _customers.every((c) {
      final status = _customerStatus[c.id] ?? _CustomerStatus.pending;
      return status == _CustomerStatus.collected ||
          status == _CustomerStatus.skipped;
    });
    if (!allDone) return;
    final alreadyCompleted =
        await AssignmentStatusStore.isAssignmentCompleted(assignment.uniqueId);
    if (alreadyCompleted) return;
    await AssignmentStatusStore.setAssignmentCompleted(assignment.uniqueId);
    await _markAssignmentComplete(assignment);
  }

  Future<void> _markAssignmentComplete(DailyAssignmentModel assignment) async {
    try {
      final dio = await authorizedDio();
      await dio.post('${ApiConfig.assignments}${assignment.uniqueId}/complete/');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment completed')),
      );
      await _loadAssignments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark assignment complete'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _updateCustomerStatus(
    String id,
    _CustomerStatus status, {
    String? skipReason,
  }) {
    final current = _customerStatus[id];
    if (current == _CustomerStatus.collected ||
        current == _CustomerStatus.skipped) {
      return;
    }

    setState(() {
      _customerStatus[id] = status;
    });
    
    // ✅ FIX: Persist to SharedPreferences
    final statusStr = status == _CustomerStatus.collected
        ? 'collected'
        : status == _CustomerStatus.skipped
            ? 'skipped'
            : 'later';

    final assignmentId = _selectedAssignment?.uniqueId;
    if (assignmentId != null && assignmentId.isNotEmpty) {
      AssignmentStatusStore.setStatusForAssignment(
        assignmentId,
        id,
        statusStr,
      );
      String? latitude;
      String? longitude;
      for (final customer in _customers) {
        if (customer.id == id) {
          latitude = customer.latitude;
          longitude = customer.longitude;
          break;
        }
      }
      _syncStatusToBackend(
        assignmentId: assignmentId,
        customerId: id,
        status: statusStr,
        skipReason: skipReason,
        latitude: latitude,
        longitude: longitude,
      );
    }
    
    // Check if all done (no pending)
    final allDone = _customers.isNotEmpty &&
        _customers.every((c) {
          final status = _customerStatus[c.id] ?? _CustomerStatus.pending;
          return status == _CustomerStatus.collected ||
              status == _CustomerStatus.skipped;
        });
    
    if (allDone && _selectedAssignment != null) {
      AssignmentStatusStore.setAssignmentCompleted(
        _selectedAssignment!.uniqueId,
      );
      _loadAssignments();
      _markAssignmentComplete(_selectedAssignment!);
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
      // best-effort; ignore failures
    }
  }

  Future<void> _handleCollect(_AssignedCustomer customer) async {
    final current = _customerStatus[customer.id];
    if (current == _CustomerStatus.collected ||
        current == _CustomerStatus.skipped) {
      return;
    }

    final scannedId = await context.push(
      AppRoutePaths.operatorQR,
      extra: {
        'expectedCustomerId': customer.id,
        'expectedCustomerName': customer.name,
        'returnToAssignments': true,
        'expectedAssignmentId': _selectedAssignment?.uniqueId,
      },
    );
    if (!mounted) return;
    final scanned = scannedId?.toString().trim();
    if (scanned == null || scanned.isEmpty) {
      return;
    }

    String effectiveId = scanned;
    if (!_matchesCustomer(customer, scanned)) {
      final resolvedId = await _resolveCustomerId(scanned);
      if (!mounted) return;
      if (resolvedId != null) {
        effectiveId = resolvedId;
      }
    }

    if (!_matchesCustomer(customer, effectiveId)) {
      final matchedOther = _customers.firstWhere(
        (c) => _matchesCustomer(c, effectiveId),
        orElse: () => customer,
      );
      final selectedName = customer.name;
      final scannedName =
          matchedOther == customer ? 'unknown citizen' : matchedOther.name;
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

    if (!mounted) return;
    final didSubmit = await context.push(
      AppRoutePaths.operatorData,
      extra: {
        'customerId': effectiveId,
        'customerName': customer.name,
        'contactNo': customer.contact,
        'latitude': customer.latitude,
        'longitude': customer.longitude,
        'skipBluetoothInit': true,
        'assignmentId': _selectedAssignment?.uniqueId,
      },
    );
    if (!mounted) return;
    if (didSubmit == true) {
      _updateCustomerStatus(customer.id, _CustomerStatus.collected);
    }
  }

  Future<void> _handleSkip(_AssignedCustomer customer) async {
    final current = _customerStatus[customer.id];
    if (current == _CustomerStatus.collected ||
        current == _CustomerStatus.skipped) {
      return;
    }

    final reason = await _promptSkipReason();
    if (!mounted || reason == null) return;

    _updateCustomerStatus(
      customer.id,
      _CustomerStatus.skipped,
      skipReason: reason,
    );
  }

  Map<String, int> _summarizeCustomerStatuses(
    List<AssignmentCustomerStatusEntry> statuses,
  ) {
    final summary = {
      'collected': 0,
      'skipped': 0,
      'later': 0,
      'pending': 0,
    };
    for (final entry in statuses) {
      switch (entry.status.toLowerCase()) {
        case 'collected':
          summary['collected'] = summary['collected']! + 1;
          break;
        case 'skipped':
          summary['skipped'] = summary['skipped']! + 1;
          break;
        case 'later':
          summary['later'] = summary['later']! + 1;
          break;
        default:
          summary['pending'] = summary['pending']! + 1;
      }
    }
    return summary;
  }

  Color _statusColorForCustomerStatus(String status) {
    switch (status.toLowerCase()) {
      case 'collected':
        return Colors.green.shade700;
      case 'skipped':
        return Colors.orange.shade700;
      case 'later':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildStatusPill(String label, int count, Color color) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCustomerStatusRow(AssignmentCustomerStatusEntry entry) {
    final statusColor = _statusColorForCustomerStatus(entry.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.customerName.trim().isNotEmpty
                      ? entry.customerName
                      : entry.customerId,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.customerId.isNotEmpty)
                  Text(
                    'ID: ${entry.customerId}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (entry.skipReason != null &&
                    entry.skipReason!.trim().isNotEmpty)
                  Text(
                    'Reason: ${entry.skipReason}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              entry.statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
// operator_assignment_screen.dart - PART 3/5
// Continue from Part 2...

  @override
  Widget build(BuildContext context) {
    if (_loadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    if (_currentAssignments.isEmpty && _historyAssignments.isEmpty) {
      return Center(
        child: Text(
          'No assignments available.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    final selected = _selectedAssignment ??
        (_currentAssignments.isNotEmpty ? _currentAssignments.first : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Assignment',
                  style: AppTextStyles.heading2.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: _loadAssignments,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Current'),
                Tab(text: 'History'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCurrentTab(selected),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab(DailyAssignmentModel? selected) {
    if (_currentAssignments.isEmpty) {
      return Center(
        child: Text(
          'No active assignments.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (selected == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildAssignmentSelector(selected),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingCustomers
              ? const Center(child: CircularProgressIndicator())
              : _customers.isEmpty
                  ? Center(
                      child: Text(
                        'No citizens available for this ward.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ValueListenableBuilder<int>(
                      valueListenable: AssignmentStatusStore.notifier,
                      builder: (context, _, __) {
                        return ListView.separated(
                          itemCount: _customers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            final status = _customerStatus[customer.id] ??
                                _CustomerStatus.pending;
                            return _AssignmentCustomerCard(
                              customer: customer,
                              status: status,
                              onCollect: () => _handleCollect(customer),
                              onSkip: () => _handleSkip(customer),
                              onLater: () => _updateCustomerStatus(
                                customer.id,
                                _CustomerStatus.later,
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

  Widget _buildHistoryTab() {
    if (_historyAssignments.isEmpty) {
      return Center(
        child: Text(
          'No completed assignments yet.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _historyAssignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final assignment = _historyAssignments[index];
        final statuses = assignment.customerStatuses;
        final summary = _summarizeCustomerStatuses(statuses);
        return Container(
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.ward,
                          style: AppTextStyles.heading2.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Shift: ${assignment.shiftDisplay} • ${assignment.typeDisplay}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: assignment.statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      assignment.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: assignment.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (statuses.isEmpty)
                Text(
                  'No citizen updates recorded.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildStatusPill(
                          'Collected',
                          summary['collected'] ?? 0,
                          Colors.green.shade700,
                        ),
                        _buildStatusPill(
                          'Skipped',
                          summary['skipped'] ?? 0,
                          Colors.orange.shade700,
                        ),
                        _buildStatusPill(
                          'Later',
                          summary['later'] ?? 0,
                          Colors.blue.shade700,
                        ),
                        _buildStatusPill(
                          'Pending',
                          summary['pending'] ?? 0,
                          Colors.grey.shade600,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...statuses.map(_buildCustomerStatusRow),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignmentSelector(DailyAssignmentModel selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DailyAssignmentModel>(
          value: selected,
          isExpanded: true,
          items: _currentAssignments
              .map(
                (assignment) => DropdownMenuItem(
                  value: assignment,
                  child: Text(
                    '${assignment.ward} • ${assignment.shiftDisplay}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (assignment) {
            if (assignment == null) return;
            setState(() => _selectedAssignment = assignment);
            _loadCustomersForAssignment(assignment);
          },
        ),
      ),
    );
  }
}

// ✅ Updated card with "Later" button
class _AssignmentCustomerCard extends StatelessWidget {
  const _AssignmentCustomerCard({
    required this.customer,
    required this.status,
    required this.onCollect,
    required this.onSkip,
    required this.onLater,
  });

  final _AssignedCustomer customer;
  final _CustomerStatus status;
  final VoidCallback onCollect;
  final VoidCallback onSkip;
  final VoidCallback onLater;

  Color _statusColor() {
    switch (status) {
      case _CustomerStatus.collected:
        return Colors.green.shade700;
      case _CustomerStatus.skipped:
        return Colors.orange.shade700;
      case _CustomerStatus.later:
        return Colors.blue.shade700;
      case _CustomerStatus.pending:
        return AppColors.primary;
    }
  }

  String _statusLabel() {
    switch (status) {
      case _CustomerStatus.collected:
        return 'Collected';
      case _CustomerStatus.skipped:
        return 'Skipped';
      case _CustomerStatus.later:
        return 'Later';
      case _CustomerStatus.pending:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final locked =
        status == _CustomerStatus.collected || status == _CustomerStatus.skipped;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  customer.name,
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ID: ${customer.id}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (customer.contact.isNotEmpty)
            Text(
              'Contact: ${customer.contact}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: locked ? null : onCollect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Collect'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: locked ? null : onSkip,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: locked ? null : onLater,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.blue.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Later',
                    style: TextStyle(color: Colors.blue.shade700),
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
