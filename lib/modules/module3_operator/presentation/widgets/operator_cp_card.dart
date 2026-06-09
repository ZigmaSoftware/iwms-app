import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';

/// A card showing one collection point in the operator's daily trip.
///
/// Displays sequence, CP name, bin name, status (Pending/Collected), and weight
/// once collected. Uses an accent gradient strip on pending cards and a soft
/// success treatment when collected.
class OperatorCpCard extends StatelessWidget {
  final OperatorTripCollectionPoint cp;
  final VoidCallback? onTap;

  const OperatorCpCard({super.key, required this.cp, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCollected = cp.isCollected;
    final statusColor = isCollected ? OperatorTheme.success : OperatorTheme.warning;
    final statusLabel = isCollected ? 'Collected' : 'Pending';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: OperatorTheme.cardRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: OperatorTheme.surface,
            borderRadius: OperatorTheme.cardRadius,
            boxShadow: OperatorTheme.softShadow,
            border: Border.all(color: OperatorTheme.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sequenceBadge(isCollected),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cp.collectionPoint.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: OperatorTheme.strongText,
                              ),
                            ),
                          ),
                          _statusChip(statusLabel, statusColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded,
                              size: 16, color: OperatorTheme.mutedText),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cp.bin.binQr,
                              style: const TextStyle(
                                color: OperatorTheme.mutedText,
                                fontSize: 12.5,
                                letterSpacing: 0.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cp.bin.binName} · ${cp.bin.binCapacity} L',
                        style: const TextStyle(
                          color: OperatorTheme.mutedText,
                          fontSize: 12,
                        ),
                      ),
                      if (isCollected) ...[
                        const SizedBox(height: 10),
                        _collectedFooter(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sequenceBadge(bool isCollected) {
    final gradient = isCollected
        ? const LinearGradient(
            colors: [OperatorTheme.success, OperatorTheme.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : OperatorTheme.accentGradient;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: isCollected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
          : Text(
              '${cp.sequence}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: OperatorTheme.chipRadius,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _collectedFooter() {
    final weight = cp.collectedWeightKg ?? 0;
    final at = cp.collectedAt;
    final time = at != null
        ? '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
        : '--:--';
    return Row(
      children: [
        Icon(Icons.scale_rounded,
            size: 14, color: OperatorTheme.success),
        const SizedBox(width: 4),
        Text('${weight.toStringAsFixed(2)} kg',
            style: const TextStyle(
              fontSize: 12.5,
              color: OperatorTheme.success,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(width: 10),
        Icon(Icons.schedule_rounded,
            size: 14, color: OperatorTheme.mutedText),
        const SizedBox(width: 4),
        Text(time,
            style: const TextStyle(
              fontSize: 12,
              color: OperatorTheme.mutedText,
            )),
      ],
    );
  }
}
