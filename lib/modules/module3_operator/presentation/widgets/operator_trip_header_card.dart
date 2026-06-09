import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';

class OperatorTripHeaderCard extends StatelessWidget {
  const OperatorTripHeaderCard({
    super.key,
    required this.tripDate,
    required this.status,
    required this.areaName,
    required this.wasteType,
    this.vehicle,
  });

  factory OperatorTripHeaderCard.fromToday(
    OperatorTripToday trip, {
    Key? key,
  }) {
    return OperatorTripHeaderCard(
      key: key,
      tripDate: trip.tripDate,
      status: trip.status,
      areaName: trip.areaName,
      wasteType: trip.wasteType,
      vehicle: trip.vehicle,
    );
  }

  factory OperatorTripHeaderCard.fromSummary(
    OperatorTripHistorySummary trip, {
    Key? key,
  }) {
    return OperatorTripHeaderCard(
      key: key,
      tripDate: trip.tripDate,
      status: trip.status,
      areaName: trip.areaName,
      wasteType: trip.wasteType,
      vehicle: trip.vehicle,
    );
  }

  final DateTime tripDate;
  final String status;
  final String areaName;
  final OperatorTripWasteType wasteType;
  final OperatorTripVehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(
                Icons.shield_moon_outlined,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'TODAY · ${_dateLabel(tripDate)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.location_city_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  areaName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _wasteChip(wasteType),
            ],
          ),
          if (vehicle != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${vehicle!.vehicleNo}  ·  cap ${vehicle!.capacity?.toStringAsFixed(0) ?? '-'} kg',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _wasteChip(OperatorTripWasteType waste) {
    final isWet = waste.isWet;
    final color = isWet ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: OperatorTheme.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        waste.name,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = OperatorTheme.success;
        break;
      case 'in progress':
        color = const Color(0xFF38BDF8);
        break;
      case 'cancelled':
        color = OperatorTheme.danger;
        break;
      default:
        color = OperatorTheme.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: OperatorTheme.chipRadius,
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
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
