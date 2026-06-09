import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/data/repositories/operator_trip_repository.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_trip_history_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cp_card.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_trip_summary_card.dart';

/// Operator Assignments screen.
///
/// UI is intentionally identical to the driver Assignments tab
/// (`_AssignmentsTab` in driver_home_page.dart): a "N Current / N History"
/// header, "Current Trip | History" tabs, the trip summary card + Collection
/// Points list on Current, and a list of summary cards on History.
///
/// The DATA, however, is the operator's own. The repository calls run with the
/// operator's auth token, so `/operator-mobile/my-trip-today/` and
/// `/operator-mobile/trip-history/` resolve against the operator side of the
/// staff template — this screen never shows the driver's assignments.
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

class _OperatorAssignmentScreenState extends State<OperatorAssignmentScreen> {
  OperatorTripRepository get _repo => GetIt.instance<OperatorTripRepository>();

  bool _loading = true;
  String? _error;

  OperatorTripHistoryDetail? _activeTripDetail;
  List<OperatorTripHistorySummary> _currentAssignments = [];
  List<OperatorTripHistorySummary> _historyAssignments = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final today = DateTime.now();

      // Operator's active trip from the centralized single-trip endpoint. The
      // backend resolves it against the operator on the staff template, so this
      // is the SAME assignment the paired driver sees — collection progress is
      // shared instantly.
      OperatorTripToday? todayTrip;
      try {
        todayTrip = await _repo.fetchMyTripToday();
      } on OperatorTripException catch (e) {
        if (e.code != 'NO_ACTIVE_TRIP') rethrow;
        todayTrip = null;
      }

      // Operator's own trip history (completed / cancelled / past trips).
      final history = await _repo.fetchHistory(
        from: today.subtract(const Duration(days: 45)),
        to: today.add(const Duration(days: 1)),
      );

      final activeAssignmentId = todayTrip?.assignmentUniqueId;
      final historyAssignments = history
          .where((trip) => trip.assignmentUniqueId != activeAssignmentId)
          .toList();

      final detail = todayTrip?.toHistoryDetail();
      final activeTrip = todayTrip?.toHistorySummary();
      final currentAssignments = <OperatorTripHistorySummary>[
        if (activeTrip != null) activeTrip,
      ];

      if (!mounted) return;
      setState(() {
        _activeTripDetail = detail;
        _currentAssignments = currentAssignments;
        _historyAssignments = historyAssignments;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load assignments';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _AssignmentsErrorState(
        message: _error!,
        onRetry: _loadAssignments,
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssignmentsHeader(
            currentCount: _currentAssignments.length,
            historyCount: _historyAssignments.length,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: TabBar(
              labelColor: OperatorTheme.primary,
              unselectedLabelColor: OperatorTheme.mutedText,
              indicatorColor: OperatorTheme.primary,
              tabs: [
                Tab(text: 'Current Trip'),
                Tab(text: 'History'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OperatorCurrentTripTab(
                  detail: _activeTripDetail,
                  fallbackTrips: _currentAssignments,
                  onRefresh: _loadAssignments,
                ),
                _OperatorTripHistoryTab(
                  assignments: _historyAssignments,
                  onRefresh: _loadAssignments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorCurrentTripTab extends StatelessWidget {
  const _OperatorCurrentTripTab({
    required this.detail,
    required this.fallbackTrips,
    required this.onRefresh,
  });

  final OperatorTripHistoryDetail? detail;
  final List<OperatorTripHistorySummary> fallbackTrips;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = detail?.summary ??
        (fallbackTrips.isNotEmpty ? fallbackTrips.first : null);

    return RefreshIndicator(
      color: OperatorTheme.accent,
      onRefresh: onRefresh,
      child: summary == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 140),
              children: const [
                _OperatorEmptyAssignmentMessage(
                  icon: Icons.route_rounded,
                  message: 'No current trip assigned.',
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              children: [
                OperatorTripSummaryCard(
                  trip: summary,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text(
                      'Collection Points',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: OperatorTheme.strongText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${detail?.collectionPoints.length ?? 0}',
                      style: const TextStyle(
                        color: OperatorTheme.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (detail == null || detail!.collectionPoints.isEmpty)
                  const _OperatorEmptyAssignmentMessage(
                    icon: Icons.location_off_rounded,
                    message: 'No collection points found for this trip.',
                  )
                else
                  ...detail!.collectionPoints.map(
                    (cp) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OperatorCpCard(cp: cp),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _OperatorTripHistoryTab extends StatelessWidget {
  const _OperatorTripHistoryTab({
    required this.assignments,
    required this.onRefresh,
  });

  final List<OperatorTripHistorySummary> assignments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: OperatorTheme.accent,
      onRefresh: onRefresh,
      child: assignments.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 140),
              children: const [
                _OperatorEmptyAssignmentMessage(
                  icon: Icons.history_toggle_off_rounded,
                  message: 'No completed trips yet.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              itemCount: assignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trip = assignments[index];
                return OperatorTripSummaryCard(
                  trip: trip,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OperatorTripHistoryDetailScreen(
                        tripId: trip.assignmentUniqueId,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _OperatorEmptyAssignmentMessage extends StatelessWidget {
  const _OperatorEmptyAssignmentMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: OperatorTheme.mutedText, size: 46),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: OperatorTheme.mutedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AssignmentsHeader extends StatelessWidget {
  const _AssignmentsHeader({
    required this.currentCount,
    required this.historyCount,
  });

  final int currentCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const Text(
            'Assignments',
            style: TextStyle(
              color: OperatorTheme.strongText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _CountChip(
            label: 'Current',
            count: currentCount,
            color: OperatorTheme.primary,
          ),
          const SizedBox(width: 8),
          _CountChip(
            label: 'History',
            count: historyCount,
            color: OperatorTheme.mutedText,
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AssignmentsErrorState extends StatelessWidget {
  const _AssignmentsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: OperatorTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
