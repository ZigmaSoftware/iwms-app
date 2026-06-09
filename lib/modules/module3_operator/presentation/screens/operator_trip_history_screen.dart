import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/data/repositories/operator_trip_repository.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_trip_summary_card.dart';

// ============================================================
// HISTORY LIST
// ============================================================

/// Lists this operator's trips (today + past) with status filters and a
/// summary card per trip. Tap → full detail panel.
class OperatorTripHistoryScreen extends StatefulWidget {
  const OperatorTripHistoryScreen({super.key});

  static const routeName = '/operator/trip/history';

  @override
  State<OperatorTripHistoryScreen> createState() =>
      _OperatorTripHistoryScreenState();
}

enum _HistoryFilter { all, inProgress, completed }

class _OperatorTripHistoryScreenState extends State<OperatorTripHistoryScreen> {
  late Future<List<OperatorTripHistorySummary>> _future;
  _HistoryFilter _filter = _HistoryFilter.all;

  OperatorTripRepository get _repo => GetIt.instance<OperatorTripRepository>();

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.fetchHistory();
    });
    await _future;
  }

  List<OperatorTripHistorySummary> _applyFilter(
    List<OperatorTripHistorySummary> trips,
  ) {
    switch (_filter) {
      case _HistoryFilter.inProgress:
        return trips.where((t) => t.isInProgress || t.isScheduled).toList();
      case _HistoryFilter.completed:
        return trips.where((t) => t.isCompleted).toList();
      case _HistoryFilter.all:
        return trips;
    }
  }

  ({int total, int active, int done}) _counts(
    List<OperatorTripHistorySummary> trips,
  ) {
    var active = 0;
    var done = 0;
    for (final t in trips) {
      if (t.isCompleted) {
        done += 1;
      } else if (t.isInProgress || t.isScheduled) {
        active += 1;
      }
    }
    return (total: trips.length, active: active, done: done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OperatorTheme.background,
      appBar: AppBar(
        title: const Text('My Collection History'),
        backgroundColor: OperatorTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: OperatorTheme.accent,
        onRefresh: _refresh,
        child: FutureBuilder<List<OperatorTripHistorySummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final allTrips =
                snapshot.data ?? const <OperatorTripHistorySummary>[];
            final counts = _counts(allTrips);
            final trips = _applyFilter(allTrips);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _HistoryStats(counts: counts),
                const SizedBox(height: 14),
                _FilterChips(
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                  counts: counts,
                ),
                const SizedBox(height: 14),
                if (trips.isEmpty) ...[
                  const SizedBox(height: 60),
                  const Icon(Icons.history_toggle_off_outlined,
                      size: 48, color: OperatorTheme.mutedText),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'No trips match this filter.',
                      style: TextStyle(color: OperatorTheme.mutedText),
                    ),
                  ),
                ] else
                  ...trips.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OperatorTripSummaryCard(
                        trip: t,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OperatorTripHistoryDetailScreen(
                              tripId: t.assignmentUniqueId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// LIST WIDGETS
// ============================================================

class _HistoryStats extends StatelessWidget {
  final ({int total, int active, int done}) counts;
  const _HistoryStats({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: OperatorTheme.headerGradient,
        borderRadius: OperatorTheme.cardRadius,
        boxShadow: OperatorTheme.softShadow,
      ),
      child: Row(
        children: [
          _stat(counts.total, 'TOTAL', Colors.white),
          Container(
              width: 1, height: 36, color: Colors.white24),
          _stat(counts.active, 'IN PROGRESS', const Color(0xFF38BDF8)),
          Container(
              width: 1, height: 36, color: Colors.white24),
          _stat(counts.done, 'COMPLETED', const Color(0xFF34D399)),
        ],
      ),
    );
  }

  Widget _stat(int value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _HistoryFilter selected;
  final ValueChanged<_HistoryFilter> onSelected;
  final ({int total, int active, int done}) counts;

  const _FilterChips({
    required this.selected,
    required this.onSelected,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All (${counts.total})', _HistoryFilter.all,
              OperatorTheme.primary),
          const SizedBox(width: 8),
          _chip('In Progress (${counts.active})', _HistoryFilter.inProgress,
              const Color(0xFF0EA5E9)),
          const SizedBox(width: 8),
          _chip('Completed (${counts.done})', _HistoryFilter.completed,
              OperatorTheme.success),
        ],
      ),
    );
  }

  Widget _chip(String label, _HistoryFilter value, Color color) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color : OperatorTheme.surface,
          border: Border.all(
            color: isSelected ? color : OperatorTheme.hairline,
          ),
          borderRadius: OperatorTheme.chipRadius,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : OperatorTheme.strongText,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HISTORY DETAIL
// ============================================================

class OperatorTripHistoryDetailScreen extends StatefulWidget {
  final String tripId;
  const OperatorTripHistoryDetailScreen({super.key, required this.tripId});

  @override
  State<OperatorTripHistoryDetailScreen> createState() =>
      _OperatorTripHistoryDetailScreenState();
}

class _OperatorTripHistoryDetailScreenState
    extends State<OperatorTripHistoryDetailScreen> {
  late Future<OperatorTripHistoryDetail> _future;

  OperatorTripRepository get _repo => GetIt.instance<OperatorTripRepository>();

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchHistoryDetail(widget.tripId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.fetchHistoryDetail(widget.tripId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OperatorTheme.background,
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: OperatorTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<OperatorTripHistoryDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final detail = snapshot.data!;
          final summary = detail.summary;
          return RefreshIndicator(
            color: OperatorTheme.accent,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _DetailHeader(summary: summary),
                const SizedBox(height: 14),
                _ProgressStrip(summary: summary),
                const SizedBox(height: 14),
                _MetricsRow(summary: summary, eventCount: detail.events.length),
                const SizedBox(height: 14),
                if (summary.staff != null) ...[
                  _StaffSection(staff: summary.staff!),
                  const SizedBox(height: 14),
                ],
                _TimingSection(summary: summary),
                const SizedBox(height: 14),
                if (summary.vehicle != null) ...[
                  _VehicleSection(
                    vehicle: summary.vehicle!,
                    tripPlan: summary.tripPlan,
                  ),
                  const SizedBox(height: 14),
                ],
                if (summary.remarks != null &&
                    summary.remarks!.trim().isNotEmpty) ...[
                  _RemarksSection(remarks: summary.remarks!),
                  const SizedBox(height: 14),
                ],
                _SectionHeader(
                  icon: Icons.location_on_outlined,
                  title: 'Collection points',
                  badge: '${detail.collectionPoints.length}',
                ),
                const SizedBox(height: 10),
                ...detail.collectionPoints
                    .map((cp) => _CpDetailTile(cp: cp))
                    ,
                if (detail.events.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _SectionHeader(
                    icon: Icons.timeline_rounded,
                    title: 'Scan timeline',
                    badge: '${detail.events.length}',
                  ),
                  const SizedBox(height: 10),
                  _EventTimeline(events: detail.events),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// DETAIL SECTIONS
// ============================================================

class _DetailHeader extends StatelessWidget {
  final OperatorTripHistorySummary summary;
  const _DetailHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = _StatusPalette.of(summary.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: OperatorTheme.headerGradient,
        borderRadius: OperatorTheme.cardRadius,
        boxShadow: OperatorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  summary.areaName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _statusPill(s),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _wasteChip(summary.wasteType),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.assignmentUniqueId,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                _dateLabel(summary.tripDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (summary.tripPlan != null) ...[
                const SizedBox(width: 14),
                const Icon(Icons.route_rounded,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    summary.tripPlan!.displayCode,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(_StatusPalette s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.22),
        borderRadius: OperatorTheme.chipRadius,
        border: Border.all(color: s.color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12, color: s.color),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: TextStyle(
              color: s.color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wasteChip(OperatorTripWasteType waste) {
    final isWet = waste.isWet;
    final c = isWet ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.22),
        borderRadius: OperatorTheme.chipRadius,
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        waste.name,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final OperatorTripHistorySummary summary;
  const _ProgressStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final p = summary.progress;
    final s = _StatusPalette.of(summary.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OperatorTheme.surface,
        borderRadius: OperatorTheme.cardRadius,
        border: Border.all(color: OperatorTheme.hairline),
        boxShadow: OperatorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TRIP PROGRESS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: OperatorTheme.mutedText,
                ),
              ),
              const Spacer(),
              Text(
                '${p.collected}/${p.total}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: OperatorTheme.strongText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: p.fraction,
              backgroundColor: OperatorTheme.hairline,
              valueColor: AlwaysStoppedAnimation(s.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p.completed
                ? 'Trip completed. All bins collected.'
                : summary.isInProgress
                    ? 'Operator is currently collecting bins on this trip.'
                    : 'Trip scheduled — not started yet.',
            style: TextStyle(
              fontSize: 12.5,
              color: p.completed ? OperatorTheme.success : OperatorTheme.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final OperatorTripHistorySummary summary;
  final int eventCount;
  const _MetricsRow({required this.summary, required this.eventCount});

  @override
  Widget build(BuildContext context) {
    final dur = summary.duration;
    return Row(
      children: [
        Expanded(
          child: _metric(
            Icons.scale_rounded,
            '${summary.totalWeightKg.toStringAsFixed(2)} kg',
            'Total collected',
            OperatorTheme.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metric(
            Icons.qr_code_scanner_rounded,
            '$eventCount',
            'Scans logged',
            const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metric(
            Icons.schedule_rounded,
            dur != null ? _durationText(dur) : '—',
            'Duration',
            const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _metric(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OperatorTheme.surface,
        borderRadius: OperatorTheme.cardRadius,
        border: Border.all(color: OperatorTheme.hairline),
        boxShadow: OperatorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: OperatorTheme.strongText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: OperatorTheme.mutedText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffSection extends StatelessWidget {
  final OperatorTripStaffBlock staff;
  const _StaffSection({required this.staff});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.groups_2_outlined,
            title: 'Crew',
            trailing: staff.isAltActive
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.16),
                      borderRadius: OperatorTheme.chipRadius,
                    ),
                    child: const Text(
                      'ALT ACTIVE',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _person(
                  icon: Icons.directions_car_outlined,
                  role: 'Driver',
                  staff: staff.driver,
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _person(
                  icon: Icons.engineering_outlined,
                  role: 'Operator',
                  staff: staff.operator,
                  color: OperatorTheme.accent,
                ),
              ),
            ],
          ),
          if (staff.templateCode != null || staff.altTemplateCode != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.qr_code_2_rounded,
                    size: 14, color: OperatorTheme.mutedText),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    staff.altTemplateCode ?? staff.templateCode ?? '',
                    style: const TextStyle(
                      color: OperatorTheme.mutedText,
                      fontSize: 11.5,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _person({
    required IconData icon,
    required String role,
    required OperatorTripStaffBrief? staff,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: OperatorTheme.mutedText,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  staff?.displayName ?? '—',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OperatorTheme.strongText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimingSection extends StatelessWidget {
  final OperatorTripHistorySummary summary;
  const _TimingSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.schedule_rounded, title: 'Timing'),
          const SizedBox(height: 10),
          _row('Scheduled', _formatTime(summary.scheduledTime),
              Icons.event_available_outlined),
          const SizedBox(height: 8),
          _row('Started', _formatTime(summary.actualStartTime),
              Icons.play_arrow_rounded,
              activeColor: const Color(0xFF0EA5E9)),
          const SizedBox(height: 8),
          _row('Ended', _formatTime(summary.actualEndTime),
              Icons.flag_rounded,
              activeColor: OperatorTheme.success),
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon,
      {Color? activeColor}) {
    final isSet = value != '—';
    final color =
        isSet ? (activeColor ?? OperatorTheme.strongText) : OperatorTheme.mutedText;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: OperatorTheme.mutedText,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _VehicleSection extends StatelessWidget {
  final OperatorTripVehicle vehicle;
  final OperatorTripPlanBrief? tripPlan;
  const _VehicleSection({required this.vehicle, this.tripPlan});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.local_shipping_outlined, title: 'Vehicle'),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: OperatorTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.local_shipping_outlined,
                    color: OperatorTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.vehicleNo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: OperatorTheme.strongText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Capacity ${vehicle.capacity?.toStringAsFixed(0) ?? '—'} kg',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: OperatorTheme.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (tripPlan != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: OperatorTheme.surfaceMuted,
                    borderRadius: OperatorTheme.chipRadius,
                  ),
                  child: Text(
                    tripPlan!.displayCode,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OperatorTheme.strongText,
                      letterSpacing: 0.4,
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

class _RemarksSection extends StatelessWidget {
  final String remarks;
  const _RemarksSection({required this.remarks});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.sticky_note_2_outlined, title: 'Remarks'),
          const SizedBox(height: 8),
          Text(
            remarks,
            style: const TextStyle(
              fontSize: 13,
              color: OperatorTheme.strongText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CpDetailTile extends StatelessWidget {
  final OperatorTripCollectionPoint cp;
  const _CpDetailTile({required this.cp});

  @override
  Widget build(BuildContext context) {
    final isDone = cp.isCollected;
    final accent = isDone ? OperatorTheme.success : OperatorTheme.warning;
    final collectedAtLocal = cp.collectedAt?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OperatorTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OperatorTheme.hairline),
        boxShadow: OperatorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  (isDone ? 'Collected' : (cp.status)).toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Text(
                  '#${cp.sequence}',
                  style: const TextStyle(
                    color: OperatorTheme.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cp.collectionPoint.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OperatorTheme.strongText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cp.bin.binName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: OperatorTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (cp.collectedWeightKg != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: OperatorTheme.accent.withValues(alpha: 0.12),
                          borderRadius: OperatorTheme.chipRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.scale_rounded,
                                size: 13, color: OperatorTheme.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${cp.collectedWeightKg!.toStringAsFixed(2)} kg',
                              style: const TextStyle(
                                color: OperatorTheme.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (collectedAtLocal != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: OperatorTheme.surfaceMuted,
                          borderRadius: OperatorTheme.chipRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 13, color: OperatorTheme.mutedText),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(collectedAtLocal),
                              style: const TextStyle(
                                color: OperatorTheme.mutedText,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }
}

class _EventTimeline extends StatelessWidget {
  final List<BinCollectionEventEntry> events;
  const _EventTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _EventTimelineTile(
            event: events[i],
            isFirst: i == 0,
            isLast: i == events.length - 1,
            index: i,
          ),
      ],
    );
  }
}

class _EventTimelineTile extends StatelessWidget {
  final BinCollectionEventEntry event;
  final bool isFirst;
  final bool isLast;
  final int index;

  const _EventTimelineTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final ts = event.eventAt.toLocal();
    final hasLatLng = event.latitude != null && event.longitude != null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                    width: 2,
                    height: 6,
                    color: isFirst
                        ? Colors.transparent
                        : OperatorTheme.hairline),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: OperatorTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: OperatorTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isLast ? Colors.transparent : OperatorTheme.hairline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OperatorTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OperatorTheme.hairline),
                boxShadow: OperatorTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.cpName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: OperatorTheme.strongText,
                          ),
                        ),
                      ),
                      Text(
                        _formatDateTime(ts),
                        style: const TextStyle(
                          color: OperatorTheme.mutedText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.binName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OperatorTheme.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip(
                        '${event.collectedWeightKg.toStringAsFixed(2)} kg',
                        Icons.scale_rounded,
                        OperatorTheme.accent,
                      ),
                      _chip(
                        event.scannedQr,
                        Icons.qr_code_2_rounded,
                        OperatorTheme.primary,
                      ),
                      if (hasLatLng)
                        _chip(
                          '${event.latitude!.toStringAsFixed(4)}, '
                          '${event.longitude!.toStringAsFixed(4)}',
                          Icons.location_on_outlined,
                          const Color(0xFFEF4444),
                        ),
                    ],
                  ),
                  if (event.notes != null && event.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: OperatorTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.notes!,
                        style: const TextStyle(
                          color: OperatorTheme.strongText,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED PRIMITIVES
// ============================================================

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OperatorTheme.surface,
        borderRadius: OperatorTheme.cardRadius,
        border: Border.all(color: OperatorTheme.hairline),
        boxShadow: OperatorTheme.softShadow,
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _CardTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: OperatorTheme.mutedText),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            color: OperatorTheme.mutedText,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  const _SectionHeader(
      {required this.icon, required this.title, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: OperatorTheme.strongText),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: OperatorTheme.strongText,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: OperatorTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: OperatorTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: OperatorTheme.danger, size: 36),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OperatorTheme.strongText),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => onRetry(),
              style: ElevatedButton.styleFrom(
                backgroundColor: OperatorTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

class _StatusPalette {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusPalette({
    required this.label,
    required this.color,
    required this.icon,
  });

  static _StatusPalette of(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const _StatusPalette(
          label: 'Completed',
          color: OperatorTheme.success,
          icon: Icons.check_circle_rounded,
        );
      case 'in progress':
        return const _StatusPalette(
          label: 'In Progress',
          color: Color(0xFF0EA5E9),
          icon: Icons.directions_run_rounded,
        );
      case 'cancelled':
        return const _StatusPalette(
          label: 'Cancelled',
          color: OperatorTheme.danger,
          icon: Icons.cancel_rounded,
        );
      default:
        return const _StatusPalette(
          label: 'Scheduled',
          color: OperatorTheme.warning,
          icon: Icons.schedule_rounded,
        );
    }
  }
}

String _dateLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

String _formatTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);
  if (hh == null || mm == null) return raw;
  final amPm = hh >= 12 ? 'PM' : 'AM';
  final h12 = ((hh + 11) % 12) + 1;
  return '$h12:${mm.toString().padLeft(2, '0')} $amPm';
}

String _formatDateTime(DateTime dt) {
  final h12 = ((dt.hour + 11) % 12) + 1;
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h12:${dt.minute.toString().padLeft(2, '0')} $amPm';
}

String _durationText(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
