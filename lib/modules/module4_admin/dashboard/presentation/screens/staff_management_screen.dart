import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/staff_management_repository.dart';
import 'assignment_history_screen.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repository = const StaffManagementRepository();

  List<StaffMember> _drivers = [];
  List<StaffMember> _operators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaff();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _loading = true);

    final drivers = await _repository.fetchStaff(role: 'driver');
    final operators = await _repository.fetchStaff(role: 'operator');

    if (!mounted) return;
    setState(() {
      _drivers = drivers;
      _operators = operators;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.drive_eta_rounded),
              text: 'Drivers (${_drivers.length})',
            ),
            Tab(
              icon: const Icon(Icons.engineering_rounded),
              text: 'Operators (${_operators.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _StaffList(staff: _drivers, role: 'Driver'),
                _StaffList(staff: _operators, role: 'Operator'),
              ],
            ),
    );
  }
}

class _StaffList extends StatelessWidget {
  const _StaffList({
    required this.staff,
    required this.role,
  });

  final List<StaffMember> staff;
  final String role;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${role.toLowerCase()}s found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staff.length,
      itemBuilder: (context, index) {
        final member = staff[index];
        return _StaffCard(
          member: member,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StaffAssignmentHistoryScreen(
                  staff: member,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.onTap,
  });

  final StaffMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.employeeId ?? 'N/A',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (member.vehicleNumber != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              member.vehicleNumber!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9E9E9E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StaffAssignmentHistoryScreen extends StatefulWidget {
  const StaffAssignmentHistoryScreen({
    super.key,
    required this.staff,
  });

  final StaffMember staff;

  @override
  State<StaffAssignmentHistoryScreen> createState() =>
      _StaffAssignmentHistoryScreenState();
}

class _StaffAssignmentHistoryScreenState
    extends State<StaffAssignmentHistoryScreen> {
  final _repository = const StaffManagementRepository();

  List<EnhancedAssignmentModel> _assignments = [];
  StaffAssignmentSummary? _summary;
  bool _loading = true;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final assignments = await _repository.fetchStaffAssignmentHistory(
      staffId: widget.staff.uniqueId,
      status: _filterStatus,
    );

    final summary = await _repository.fetchStaffSummary(
      widget.staff.uniqueId,
    );

    if (!mounted) return;
    setState(() {
      _assignments = assignments;
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              child: Text(
                                widget.staff.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.staff.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    widget.staff.role.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_summary != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _SummaryCards(summary: _summary!),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filterStatus == null,
                      onSelected: () {
                        setState(() => _filterStatus = null);
                        _loadData();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Completed',
                      selected: _filterStatus == 'completed',
                      color: AssignmentStatus.completed.color,
                      onSelected: () {
                        setState(() => _filterStatus = 'completed');
                        _loadData();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Skipped',
                      selected: _filterStatus == 'skipped',
                      color: AssignmentStatus.skipped.color,
                      onSelected: () {
                        setState(() => _filterStatus = 'skipped');
                        _loadData();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Cancelled',
                      selected: _filterStatus == 'cancelled',
                      color: AssignmentStatus.cancelled.color,
                      onSelected: () {
                        setState(() => _filterStatus = 'cancelled');
                        _loadData();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          _loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _assignments.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No assignments found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList.separated(
                        itemCount: _assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final assignment = _assignments[index];
                          return _AssignmentHistoryCard(
                            assignment: assignment,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetailedAssignmentHistoryScreen(
                                    assignment: assignment,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final StaffAssignmentSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Assignments',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.totalAssignments}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 50,
                color: Colors.white30,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completion Rate',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryChip(
                label: 'Completed',
                count: summary.completed,
                color: AssignmentStatus.completed.color,
                icon: AssignmentStatus.completed.icon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryChip(
                label: 'Skipped',
                count: summary.skipped,
                color: AssignmentStatus.skipped.color,
                icon: AssignmentStatus.skipped.icon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryChip(
                label: 'Cancelled',
                count: summary.cancelled,
                color: AssignmentStatus.cancelled.color,
                icon: AssignmentStatus.cancelled.icon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryChip(
                label: 'In Progress',
                count: summary.inProgress,
                color: AssignmentStatus.inProgress.color,
                icon: AssignmentStatus.inProgress.icon,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF2E7D32);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : chipColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: chipColor,
      side: BorderSide(color: chipColor),
      checkmarkColor: Colors.white,
    );
  }
}

class _AssignmentHistoryCard extends StatelessWidget {
  const _AssignmentHistoryCard({
    required this.assignment,
    required this.onTap,
  });

  final EnhancedAssignmentModel assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: assignment.currentStatus.color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: assignment.currentStatus.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            assignment.currentStatus.icon,
                            size: 16,
                            color: assignment.currentStatus.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            assignment.currentStatus.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: assignment.currentStatus.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('MMM dd').format(assignment.date),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  assignment.ward,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      assignment.shift.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      assignment.assignmentType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (assignment.skipReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            assignment.skipReason!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (assignment.cancelledReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: Colors.red.shade900,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            assignment.cancelledReason!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
