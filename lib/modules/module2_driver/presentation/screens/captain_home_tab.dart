import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/data/repositories/operator_trip_repository.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/widgets/captain_glass.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/operator_trip_history_screen.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/widgets/bin_detail_sheet.dart';

/// Captain Home — the "today-first" dashboard of the merged driver app.
///
/// Everything the driver needs at a glance, ranked by how often they reach
/// for it on the road:
///   1. hero trip card (route, vehicle, progress ring, status)
///   2. quick actions (Navigate / Scan / History)
///   3. stop-by-stop timeline — tap a pending stop to open weight entry
///   4. crew card — the operator(s) riding this vehicle today
class CaptainHomeTab extends StatelessWidget {
  const CaptainHomeTab({
    super.key,
    required this.trip,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenMap,
    required this.onScan,
    this.onOpenTrips,
    this.driverName,
  });

  final OperatorTripToday? trip;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenMap;
  final VoidCallback onScan;

  /// Opens the trips view (current + history). Falls back to the shared
  /// trip-history screen when the host doesn't provide one.
  final VoidCallback? onOpenTrips;
  final String? driverName;

  @override
  Widget build(BuildContext context) {
    return CaptainBackground(
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: CaptainTheme.accent),
      );
    }
    if (error != null) {
      return _MessageView(
        icon: Icons.error_outline_rounded,
        iconColor: CaptainTheme.danger,
        title: 'Could not load your trip',
        message: error!,
        actionLabel: 'Retry',
        onAction: onRefresh,
      );
    }
    if (trip == null) {
      return _MessageView(
        icon: Icons.event_busy_rounded,
        iconColor: CaptainTheme.accent,
        title: 'No trip today',
        message:
            'No trip has been assigned to this vehicle yet. Pull to refresh or check with your supervisor.',
        actionLabel: 'Refresh',
        onAction: onRefresh,
      );
    }

    final t = trip!;
    return RefreshIndicator(
      color: CaptainTheme.accent,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          _TripHeroCard(trip: t, onOpenMap: onOpenMap),
          const SizedBox(height: 14),
          _QuickActionsRow(
            onOpenMap: onOpenMap,
            onScan: onScan,
            onHistory: onOpenTrips ??
                () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OperatorTripHistoryScreen(),
                      ),
                    ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Collection points',
            trailing: '${t.progress.collected}/${t.progress.total} done',
          ),
          const SizedBox(height: 10),
          _StopsTimeline(trip: t, onChanged: onRefresh),
          if (t.crew != null &&
              (t.crew!.operators.isNotEmpty || t.crew!.driver != null)) ...[
            const SizedBox(height: 18),
            const _SectionTitle(title: 'Your crew'),
            const SizedBox(height: 10),
            _CrewCard(crew: t.crew!),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero trip card
// ─────────────────────────────────────────────────────────────────────────────

class _TripHeroCard extends StatelessWidget {
  const _TripHeroCard({required this.trip, required this.onOpenMap});

  final OperatorTripToday trip;
  final VoidCallback onOpenMap;

  Color get _statusColor {
    switch (trip.status.toLowerCase()) {
      case 'completed':
        return CaptainTheme.success;
      case 'in progress':
        return CaptainTheme.gold;
      case 'cancelled':
        return CaptainTheme.danger;
      default:
        return CaptainTheme.info;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return raw;
    return DateFormat.jm().format(DateTime(2000, 1, 1, hh, mm));
  }

  @override
  Widget build(BuildContext context) {
    final progress = trip.progress;
    return CaptainGlassCard(
      onTap: onOpenMap,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  trip.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: _statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEE, d MMM').format(trip.tripDate),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: CaptainTheme.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.areaName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: CaptainTheme.strongText,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (trip.vehicle != null)
                      _HeroDetailRow(
                        icon: Icons.local_shipping_rounded,
                        text: trip.vehicle!.vehicleNo,
                      ),
                    if (trip.wasteType.name.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _HeroDetailRow(
                        icon: Icons.recycling_rounded,
                        text: trip.wasteType.name,
                      ),
                    ],
                    const SizedBox(height: 5),
                    _HeroDetailRow(
                      icon: Icons.schedule_rounded,
                      text: 'Starts ${_formatTime(trip.scheduledTime)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CaptainProgressRing(
                fraction: progress.fraction,
                completed: progress.completed,
                label: '${progress.collected}/${progress.total}',
                sublabel: progress.completed ? 'DONE' : 'STOPS',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDetailRow extends StatelessWidget {
  const _HeroDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CaptainTheme.accentDeep),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: CaptainTheme.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onOpenMap,
    required this.onScan,
    required this.onHistory,
  });

  final VoidCallback onOpenMap;
  final VoidCallback onScan;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    Widget action({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: CaptainGlassCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CaptainGlassChip(icon: icon, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: CaptainTheme.strongText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(
          icon: Icons.navigation_rounded,
          label: 'Navigate',
          color: CaptainTheme.success,
          onTap: onOpenMap,
        ),
        const SizedBox(width: 10),
        action(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Scan',
          color: CaptainTheme.accent,
          onTap: onScan,
        ),
        const SizedBox(width: 10),
        action(
          icon: Icons.history_rounded,
          label: 'History',
          color: CaptainTheme.gold,
          onTap: onHistory,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stops timeline
// ─────────────────────────────────────────────────────────────────────────────

class _StopsTimeline extends StatelessWidget {
  const _StopsTimeline({required this.trip, required this.onChanged});

  final OperatorTripToday trip;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final stops = [...trip.collectionPoints]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (stops.isEmpty) {
      return CaptainGlassCard(
        child: Text(
          'No collection points on this trip yet.',
          style: TextStyle(color: CaptainTheme.mutedText),
        ),
      );
    }

    // First pending stop is the "next up" highlight.
    final nextIndex = stops.indexWhere((s) => !s.isCollected);

    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          _StopTile(
            stop: stops[i],
            isFirst: i == 0,
            isLast: i == stops.length - 1,
            isNext: i == nextIndex,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.isNext,
    required this.onChanged,
  });

  final OperatorTripCollectionPoint stop;
  final bool isFirst;
  final bool isLast;
  final bool isNext;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final done = stop.isCollected;
    final nodeColor = done
        ? CaptainTheme.success
        : (isNext ? CaptainTheme.gold : CaptainTheme.hairline);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2.4,
                    color: isFirst
                        ? Colors.transparent
                        : CaptainTheme.hairline.withValues(alpha: 0.8),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? CaptainTheme.success : CaptainTheme.surface,
                    border: Border.all(color: nodeColor, width: 2.4),
                    boxShadow: isNext
                        ? [
                            BoxShadow(
                              color: CaptainTheme.gold.withValues(alpha: 0.45),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: done
                      ? Icon(Icons.check_rounded,
                          size: 14, color: CaptainTheme.onAccent)
                      : (isNext
                          ? Icon(Icons.arrow_downward_rounded,
                              size: 12, color: CaptainTheme.gold)
                          : null),
                ),
                Expanded(
                  child: Container(
                    width: 2.4,
                    color: isLast
                        ? Colors.transparent
                        : CaptainTheme.hairline.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: CaptainGlassCard(
                onTap: done ? null : () => _openWeightEntry(context),
                tint: done
                    ? CaptainTheme.success
                    : (isNext ? CaptainTheme.gold : null),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.collectionPoint.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CaptainTheme.strongText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            done
                                ? 'Collected'
                                    '${stop.collectedWeightKg != null ? ' • ${stop.collectedWeightKg!.toStringAsFixed(1)} kg' : ''}'
                                : (isNext
                                    ? 'Next stop — tap to enter weight'
                                    : 'Stop ${stop.sequence} • ${stop.bin.binName}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: done
                                  ? CaptainTheme.success
                                  : (isNext
                                      ? CaptainTheme.gold
                                      : CaptainTheme.mutedText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      done
                          ? Icons.verified_rounded
                          : Icons.chevron_right_rounded,
                      color: done
                          ? CaptainTheme.success
                          : CaptainTheme.mutedText,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validate this stop's bin against today's trip, open the weight-entry
  /// sheet, then refresh the dashboard when a collection is submitted.
  Future<void> _openWeightEntry(BuildContext context) async {
    final repo = GetIt.instance<OperatorTripRepository>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: CaptainTheme.accent),
      ),
    );

    BinScanValidateResult? validation;
    String? errorText;
    try {
      validation = await repo.validateBinQr(stop.bin.scanValue);
    } on OperatorTripException catch (e) {
      errorText = friendlyTripError(e);
    } catch (e) {
      errorText = 'Could not load bin: $e';
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture.catchError((_) {});

    if (errorText != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(errorText), backgroundColor: CaptainTheme.danger),
      );
      return;
    }
    if (validation == null || !context.mounted) return;

    final result = await showModalBottomSheet<BinScanSubmitResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BinDetailSheet(validation: validation!),
    );
    if (result != null) {
      if (result.tripCompleted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Trip completed — all stops collected. Great job!'),
            backgroundColor: CaptainTheme.success,
          ),
        );
      }
      await onChanged();
    }
  }
}

/// Human-friendly messages for the operator-mobile error codes.
String friendlyTripError(OperatorTripException e) {
  switch (e.code) {
    case 'WRONG_WASTE_TYPE':
      return e.message;
    case 'WRONG_PANCHAYAT':
      return 'This bin is outside your assigned area.';
    case 'ALREADY_COLLECTED':
      return 'This bin was already collected.';
    case 'BIN_NOT_FOUND':
      return 'Bin not found.';
    case 'CP_NOT_IN_TRIP':
      return 'This collection point is not in your trip.';
    case 'NO_ACTIVE_TRIP':
      return 'You have no active trip today.';
    case 'NETWORK_UNREACHABLE':
    case 'NETWORK_TIMEOUT':
    case 'NETWORK_ERROR':
      return 'Cannot reach the server. Check your connection.';
    default:
      return e.message.isEmpty ? 'Something went wrong.' : e.message;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Crew card
// ─────────────────────────────────────────────────────────────────────────────

class _CrewCard extends StatelessWidget {
  const _CrewCard({required this.crew});

  final OperatorTripCrew crew;

  @override
  Widget build(BuildContext context) {
    final members = <OperatorTripCrewMember>[
      if (crew.driver != null) crew.driver!,
      ...crew.operators,
    ];

    return CaptainGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (crew.isAltActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded,
                      size: 14, color: CaptainTheme.warning),
                  const SizedBox(width: 5),
                  Text(
                    'Substitute crew active today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: CaptainTheme.warning.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          for (final member in members) _CrewMemberRow(member: member),
        ],
      ),
    );
  }
}

class _CrewMemberRow extends StatelessWidget {
  const _CrewMemberRow({required this.member});

  final OperatorTripCrewMember member;

  bool get _isDriver =>
      (member.role ?? '').toLowerCase().contains('driver');

  @override
  Widget build(BuildContext context) {
    final roleColor = _isDriver ? CaptainTheme.accent : CaptainTheme.info;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  roleColor.withValues(alpha: 0.22),
                  roleColor.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: roleColor.withValues(alpha: 0.45)),
              image: (member.photoUrl != null && member.photoUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(member.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (member.photoUrl == null || member.photoUrl!.isEmpty)
                ? Text(
                    member.initials,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: roleColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: CaptainTheme.strongText,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isDriver ? 'Captain' : member.roleLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: roleColor,
                        ),
                      ),
                    ),
                    if (member.phone != null &&
                        member.phone!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone_rounded,
                          size: 11, color: CaptainTheme.mutedText),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          member.phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CaptainTheme.mutedText,
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: CaptainTheme.strongText,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CaptainTheme.mutedText,
            ),
          ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    // A ListView so pull-to-refresh still works on empty/error states.
    return RefreshIndicator(
      color: CaptainTheme.accent,
      onRefresh: onAction,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 90, 32, 32),
        children: [
          Center(
            child: CaptainGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CaptainGlassChip(icon: icon, color: iconColor, size: 30,
                      padding: const EdgeInsets.all(14)),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: CaptainTheme.strongText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: CaptainTheme.mutedText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onAction,
                    icon: Icon(Icons.refresh_rounded, size: 18),
                    label: Text(actionLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CaptainTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
