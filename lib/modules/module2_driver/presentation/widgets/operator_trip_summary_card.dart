import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';

class OperatorTripSummaryCard extends StatelessWidget {
  const OperatorTripSummaryCard({
    super.key,
    required this.trip,
    this.onTap,
  });

  final OperatorTripHistorySummary trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = _StatusPalette.of(trip.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: CaptainTheme.cardRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: CaptainTheme.surface,
            borderRadius: CaptainTheme.cardRadius,
            border: Border.all(color: CaptainTheme.hairline),
            boxShadow: CaptainTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Icon(s.icon, size: 16, color: s.color),
                    const SizedBox(width: 6),
                    Text(
                      trip.status.toUpperCase(),
                      style: TextStyle(
                        color: s.color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: CaptainTheme.mutedText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dateLabel(trip.tripDate),
                      style: TextStyle(
                        color: CaptainTheme.mutedText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trip.areaName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: CaptainTheme.strongText,
                            ),
                          ),
                        ),
                        _wasteChip(trip.wasteType),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      trip.assignmentUniqueId,
                      style: TextStyle(
                        color: CaptainTheme.mutedText,
                        fontSize: 11.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (trip.vehicle != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 14,
                            color: CaptainTheme.mutedText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trip.vehicle!.vehicleNo,
                            style: TextStyle(
                              fontSize: 12,
                              color: CaptainTheme.mutedText,
                            ),
                          ),
                          if (trip.staff?.driver != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: CaptainTheme.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                trip.staff!.driver!.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CaptainTheme.mutedText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 13,
                          color: CaptainTheme.mutedText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.progress.collected}/${trip.progress.total} CPs',
                          style: TextStyle(
                            color: CaptainTheme.mutedText,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${trip.totalWeightKg.toStringAsFixed(2)} kg',
                          style: TextStyle(
                            fontSize: 13,
                            color: CaptainTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: trip.progress.fraction,
                        backgroundColor: CaptainTheme.hairline,
                        valueColor: AlwaysStoppedAnimation(s.color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wasteChip(OperatorTripWasteType waste) {
    final isWet = waste.isWet;
    final color = isWet ? const Color(0xFF0EA5E9) : CaptainTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: CaptainTheme.chipRadius,
      ),
      child: Text(
        waste.name,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;

  static _StatusPalette of(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _StatusPalette(
          color: CaptainTheme.success,
          icon: Icons.check_circle_rounded,
        );
      case 'in progress':
        return const _StatusPalette(
          color: Color(0xFF0EA5E9),
          icon: Icons.directions_run_rounded,
        );
      case 'cancelled':
        return _StatusPalette(
          color: CaptainTheme.danger,
          icon: Icons.cancel_rounded,
        );
      default:
        return _StatusPalette(
          color: CaptainTheme.warning,
          icon: Icons.schedule_rounded,
        );
    }
  }
}

String _dateLabel(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}
