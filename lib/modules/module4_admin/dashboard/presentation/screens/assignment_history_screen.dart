import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';

import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';

class DetailedAssignmentHistoryScreen extends StatelessWidget {
  const DetailedAssignmentHistoryScreen({
    super.key,
    required this.assignment,
    this.floatingActionButton,
  });

  final EnhancedAssignmentModel assignment;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: assignment.currentStatus.color,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      assignment.currentStatus.color,
                      assignment.currentStatus.color.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                assignment.currentStatus.icon,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                assignment.currentStatus.displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          assignment.ward,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy')
                              .format(assignment.date),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailsCard(assignment: assignment),
                  const SizedBox(height: 16),
                  _TimelineSection(
                    history: assignment.statusHistory,
                    collectionLogs: assignment.collectionLogs,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.assignment});

  final EnhancedAssignmentModel assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Assignment Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.person_rounded,
            label: 'Driver',
            value: assignment.driver,
          ),
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.verified_rounded,
            label: 'Driver status',
            value: assignment.driverStatus.displayName,
          ),
          if (assignment.driverCompletedAt != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Driver completed at',
              value: DateFormat('MMM d, yyyy h:mm a')
                  .format(assignment.driverCompletedAt!),
            ),
          ],
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.engineering_rounded,
            label: 'Operator',
            value: assignment.operatorName,
          ),
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.verified_rounded,
            label: 'Operator status',
            value: assignment.operatorStatus.displayName,
          ),
          if (assignment.operatorCompletedAt != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Operator completed at',
              value: DateFormat('MMM d, yyyy h:mm a')
                  .format(assignment.operatorCompletedAt!),
            ),
          ],
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Shift',
            value: assignment.shift.replaceAll('_', ' ').toUpperCase(),
          ),
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.category_rounded,
            label: 'Type',
            value: assignment.assignmentType.toUpperCase(),
          ),
          if (assignment.completedAt != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.check_circle_rounded,
              label: 'Completed At',
              value: DateFormat('MMM d, yyyy h:mm a')
                  .format(assignment.completedAt!),
            ),
          ],
          if (assignment.skippedAt != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.skip_next_rounded,
              label: 'Skipped At',
              value: DateFormat('MMM d, yyyy h:mm a')
                  .format(assignment.skippedAt!),
            ),
          ],
          if (assignment.cancelledAt != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.cancel_rounded,
              label: 'Cancelled At',
              value: DateFormat('MMM d, yyyy h:mm a')
                  .format(assignment.cancelledAt!),
            ),
          ],
          if (assignment.skipReason != null &&
              assignment.skipReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _DetailRow(
                icon: Icons.info_outline,
                label: 'Skip reason',
                value: assignment.skipReason!,
              ),
            ),
          if (assignment.cancelledReason != null &&
              assignment.cancelledReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _DetailRow(
                icon: Icons.info_outline,
                label: 'Cancelled reason',
                value: assignment.cancelledReason!,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.history,
    required this.collectionLogs,
  });

  final List<AssignmentStatusHistoryEntry> history;
  final List<CollectionLogEntry> collectionLogs;

  @override
  Widget build(BuildContext context) {
    final allEvents = <_TimelineEvent>[];

    for (final entry in history) {
      allEvents.add(_TimelineEvent.fromHistory(entry));
    }
    for (final log in collectionLogs) {
      allEvents.add(_TimelineEvent.fromLog(log));
    }

    allEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (allEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Activity Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            allEvents.length,
            (index) {
              final event = allEvents[index];
              final isFirst = index == 0;
              final isLast = index == allEvents.length - 1;
              return TimelineTile(
                isFirst: isFirst,
                isLast: isLast,
                indicatorStyle: IndicatorStyle(
                  width: 26,
                  color: event.color,
                  indicatorXY: 0.1,
                  iconStyle: IconStyle(
                    iconData: event.icon,
                    color: Colors.white,
                  ),
                ),
                beforeLineStyle: LineStyle(color: Colors.grey.shade300),
                afterLineStyle: LineStyle(color: Colors.grey.shade300),
                endChild: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (event.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, h:mm a').format(event.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent {
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final Color color;
  final IconData icon;

  _TimelineEvent({
    required this.title,
    this.subtitle,
    required this.timestamp,
    required this.color,
    required this.icon,
  });

  factory _TimelineEvent.fromHistory(AssignmentStatusHistoryEntry entry) {
    Color color;
    IconData icon;

    switch (entry.status) {
      case 'driver_completed':
        color = const Color(0xFF2E7D32);
        icon = Icons.badge_rounded;
        break;
      case 'operator_completed':
        color = const Color(0xFF1565C0);
        icon = Icons.engineering_rounded;
        break;
      case 'completed':
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle;
        break;
      case 'skipped':
        color = const Color(0xFFFFEB3B);
        icon = Icons.skip_next;
        break;
      case 'cancelled':
        color = const Color(0xFFF44336);
        icon = Icons.cancel;
        break;
      case 'in_progress':
        color = const Color(0xFF2196F3);
        icon = Icons.directions_car;
        break;
      default:
        color = const Color(0xFF9E9E9E);
        icon = Icons.schedule;
    }

    return _TimelineEvent(
      title: entry.status.replaceAll('_', ' ').toUpperCase(),
      subtitle: entry.changedBy != null
          ? 'By ${entry.changedBy}${entry.reason != null ? " - ${entry.reason}" : ""}'
          : entry.reason,
      timestamp: entry.timestamp,
      color: color,
      icon: icon,
    );
  }

  factory _TimelineEvent.fromLog(CollectionLogEntry log) {
    Color color;
    IconData icon;

    switch (log.action) {
      case 'started_navigation':
        color = const Color(0xFF2196F3);
        icon = Icons.navigation;
        break;
      case 'arrived':
        color = const Color(0xFF9C27B0);
        icon = Icons.location_on;
        break;
      case 'collection_started':
        color = const Color(0xFFFF9800);
        icon = Icons.play_arrow;
        break;
      case 'collection_completed':
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle;
        break;
      case 'skipped':
        color = const Color(0xFFFFEB3B);
        icon = Icons.skip_next;
        break;
      default:
        color = const Color(0xFF9E9E9E);
        icon = Icons.info;
    }

    String subtitle = 'By ${log.driverName ?? "Driver"}';
    if (log.skipReason != null) {
      subtitle += ' - ${log.skipReason}';
    }
    if (log.wasteWeight != null) {
      subtitle += ' - ${log.wasteWeight} kg';
    }

    return _TimelineEvent(
      title: log.displayAction,
      subtitle: subtitle,
      timestamp: log.timestamp,
      color: color,
      icon: icon,
    );
  }
}
