import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';
import 'package:iwms_citizen_app/data/repositories/citizen_collection_repository.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/assignment_history_screen.dart';

class CitizenCollectionScreen extends StatefulWidget {
  const CitizenCollectionScreen({super.key});

  @override
  State<CitizenCollectionScreen> createState() =>
      _CitizenCollectionScreenState();
}

class _CitizenCollectionScreenState extends State<CitizenCollectionScreen> {
  final _repository = const CitizenCollectionRepository();
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
    final assignments = await _repository.fetchAssignments(
      status: _filterStatus,
    );
    final summary = await _repository.fetchSummary();
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
      appBar: AppBar(
        title: const Text('Citizen Collections'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  if (_summary != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _CitizenSummaryCards(summary: _summary!),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filterStatus == null,
                            onSelected: () {
                              setState(() => _filterStatus = null);
                              _loadData();
                            },
                          ),
                          _FilterChip(
                            label: 'Pending',
                            selected: _filterStatus == 'pending',
                            color: const Color(0xFFFF9800),
                            onSelected: () {
                              setState(() => _filterStatus = 'pending');
                              _loadData();
                            },
                          ),
                          _FilterChip(
                            label: 'In Progress',
                            selected: _filterStatus == 'in_progress',
                            color: const Color(0xFF2196F3),
                            onSelected: () {
                              setState(() => _filterStatus = 'in_progress');
                              _loadData();
                            },
                          ),
                          _FilterChip(
                            label: 'Completed',
                            selected: _filterStatus == 'completed',
                            color: const Color(0xFF4CAF50),
                            onSelected: () {
                              setState(() => _filterStatus = 'completed');
                              _loadData();
                            },
                          ),
                          _FilterChip(
                            label: 'Skipped',
                            selected: _filterStatus == 'skipped',
                            color: const Color(0xFFFFEB3B),
                            onSelected: () {
                              setState(() => _filterStatus = 'skipped');
                              _loadData();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (_assignments.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('No assignments found'),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList.separated(
                        itemCount: _assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final assignment = _assignments[index];
                          return _CitizenAssignmentCard(
                            assignment: assignment,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CitizenSummaryCards extends StatelessWidget {
  const _CitizenSummaryCards({required this.summary});

  final StaffAssignmentSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
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
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.totalAssignments}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completion Rate',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
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
                label: 'Pending',
                value: summary.pending,
                color: const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryChip(
                label: 'In Progress',
                value: summary.inProgress,
                color: const Color(0xFF2196F3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryChip(
                label: 'Completed',
                value: summary.completed,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryChip(
                label: 'Skipped',
                value: summary.skipped,
                color: const Color(0xFFFFEB3B),
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
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
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

class _CitizenAssignmentCard extends StatelessWidget {
  const _CitizenAssignmentCard({required this.assignment});

  final EnhancedAssignmentModel assignment;

  @override
  Widget build(BuildContext context) {
    final statusColor = assignment.currentStatus.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      assignment.currentStatus.icon,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      assignment.currentStatus.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM d, h:mm a').format(assignment.date),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            assignment.ward,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  assignment.driver,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                assignment.shift.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(width: 12),
              Icon(Icons.category, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                assignment.assignmentType.toUpperCase(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          if (assignment.skipReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assignment.skipReason!,
                      style: TextStyle(color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailedAssignmentHistoryScreen(
                      assignment: assignment,
                    ),
                  ),
                );
              },
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}
