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
import 'package:iwms_citizen_app/data/repositories/assignment_repository.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/assignment_status_store.dart';

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

  List<DailyAssignmentModel> _assignments = [];
  DailyAssignmentModel? _selectedAssignment;
  List<_AssignedCustomer> _customers = [];
  final Map<String, _CustomerStatus> _customerStatus = {};

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    _loadAssignments();
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
          _assignments = [];
          _selectedAssignment = null;
          _loadingAssignments = false;
        });
        return;
      }

      final assignments = await _assignmentRepository.fetchAssignmentsForOperator(
        operatorId: authState.userId.trim(),
      );

      DailyAssignmentModel? selected = _selectedAssignment;
      if (assignments.isNotEmpty) {
        if (widget.initialAssignment != null) {
          selected = _findAssignment(
                assignments,
                widget.initialAssignment!.uniqueId,
              ) ??
              assignments.first;
        } else if (selected != null) {
          selected =
              _findAssignment(assignments, selected.uniqueId) ?? assignments.first;
        } else {
          selected = assignments.first;
        }
      } else {
        selected = null;
      }

      setState(() {
        _assignments = assignments;
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

    // ✅ FIX: Load persisted status from SharedPreferences
    final persisted =
        await AssignmentStatusStore.getStatusesFor(customers.map((c) => c.id));

    setState(() {
      _customers = customers;
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

  void _updateCustomerStatus(String id, _CustomerStatus status) {
    setState(() {
      _customerStatus[id] = status;
    });
    
    // ✅ FIX: Persist to SharedPreferences
    final statusStr = status == _CustomerStatus.collected
        ? 'collected'
        : status == _CustomerStatus.skipped
            ? 'skipped'
            : 'later';
    
    AssignmentStatusStore.setStatus(id, statusStr);
    
    // Check if all done (excluding "later")
    final allDone = _customers.isNotEmpty &&
        _customers.every((c) =>
            _customerStatus[c.id] == _CustomerStatus.collected ||
            _customerStatus[c.id] == _CustomerStatus.skipped);
    
    if (allDone && _selectedAssignment != null) {
      _markAssignmentComplete(_selectedAssignment!);
    }
  }

  Future<void> _handleCollect(_AssignedCustomer customer) async {
    final scannedId = await context.push(
      AppRoutePaths.operatorQR,
      extra: {
        'expectedCustomerId': customer.id,
        'expectedCustomerName': customer.name,
        'returnToAssignments': true,
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
    await context.push(
      AppRoutePaths.operatorData,
      extra: {
        'customerId': effectiveId,
        'customerName': customer.name,
        'contactNo': customer.contact,
        'latitude': customer.latitude,
        'longitude': customer.longitude,
        'skipBluetoothInit': true,
      },
    );
    if (!mounted) return;
    _updateCustomerStatus(customer.id, _CustomerStatus.collected);
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

    if (_assignments.isEmpty) {
      return Center(
        child: Text(
          'No assignments available.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    final selected = _selectedAssignment ?? _assignments.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                    : ListView.separated(
                        itemCount: _customers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final customer = _customers[index];
                          final status = _customerStatus[customer.id] ??
                              _CustomerStatus.pending;
                          return _AssignmentCustomerCard(
                            customer: customer,
                            status: status,
                            onCollect: () => _handleCollect(customer),
                            onSkip: () =>
                                _updateCustomerStatus(customer.id, _CustomerStatus.skipped),
                            onLater: () =>
                                _updateCustomerStatus(customer.id, _CustomerStatus.later),
                          );
                        },
                      ),
          ),
        ],
      ),
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
          items: _assignments
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
                  onPressed: status == _CustomerStatus.collected ? null : onCollect,
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
                  onPressed: status == _CustomerStatus.skipped ? null : onSkip,
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
                  onPressed: status == _CustomerStatus.later ? null : onLater,
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