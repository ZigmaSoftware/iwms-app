import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cards.dart';
import 'package:iwms_citizen_app/shared/models/collection_history.dart';
import 'package:iwms_citizen_app/shared/services/collection_history_service.dart';

const Color _wetTint = Color(0xFF2196F3);
const Color _dryTint = Color(0xFFFF9800);
const Color _mixedTint = Color(0xFFE53935);

class OperatorOverviewScreen extends StatefulWidget {
  const OperatorOverviewScreen({super.key});

  @override
  State<OperatorOverviewScreen> createState() => _OperatorOverviewScreenState();
}

class _OperatorOverviewScreenState extends State<OperatorOverviewScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final historyService = getIt<CollectionHistoryService>();

    return ValueListenableBuilder<List<CollectionHistoryEntry>>(
      valueListenable: historyService.entriesNotifier,
      builder: (context, entries, _) {
        final filtered = entries
            .where((e) => _isSameDay(e.collectedAt, _selectedDate))
            .toList()
          ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));

        if (filtered.isEmpty) {
          return _buildEmptyState(context);
        }

        final mapped = _mapTodayEntries(filtered);
        final summary = _calculateTotals(mapped);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _OverviewHeader(),
            Expanded(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: "Pick date",
                        icon: const Icon(Icons.calendar_today_rounded,
                            color: AppColors.primary),
                        onPressed: _pickDate,
                      ),
                    ),

                    // ------------------ SUMMARY METRICS ------------------
                    _buildSummaryMetrics(summary),

                    const SizedBox(height: 24),

                    // ------------------ TODAY’S PICKUPS LIST ------------------
                    Expanded(
                      child: ListView.separated(
                        itemCount: mapped.length,
                        physics: const BouncingScrollPhysics(),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final e = mapped[index];
                          return _PickupTile(entry: e);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  List<_OverviewEntry> _mapTodayEntries(List<CollectionHistoryEntry> entries) {
    final f = DateFormat('hh:mm a');

    return entries.map((e) {
      double wet = 0, dry = 0, other = 0;

      for (final s in e.sections) {
        final raw = (s.weight ?? '').toString();
        final cleaned = raw.replaceAll(RegExp('[^0-9.]'), '');
        final weight = double.tryParse(cleaned) ?? 0;

        switch (s.normalizedType) {
          case "wet":
            wet += weight;
            break;
          case "dry":
            dry += weight;
            break;
          default:
            other += weight;
        }
      }

      return _OverviewEntry(
        title: e.customerName.isNotEmpty ? e.customerName : "Customer",
        subtitle: e.customerId.isNotEmpty ? "ID ${e.customerId}" : null,
        wet: wet,
        dry: dry,
        mixed: other,
        time: f.format(e.collectedAt),
      );
    }).toList();
  }

  _SummaryTotals _calculateTotals(List<_OverviewEntry> list) {
    double wet = 0, dry = 0, mixed = 0;
    for (final e in list) {
      wet += e.wet;
      dry += e.dry;
      mixed += e.mixed;
    }
    return _SummaryTotals(wet: wet, dry: dry, mixed: mixed, count: list.length);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.recycling, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              "No collections recorded today.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics(_SummaryTotals t) {
    return Row(
      children: [
        Expanded(
          child: _SummaryPill(
            label: "Wet",
            value: "${t.wet.toStringAsFixed(1)} kg",
            color: const Color.fromARGB(255, 31, 150, 248),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryPill(
            label: "Dry",
            value: "${t.dry.toStringAsFixed(1)} kg",
            color: _dryTint,
          ),
        ),
        if (t.mixed > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryPill(
              label: "Mixed",
              value: "${t.mixed.toStringAsFixed(1)} kg",
              color: _mixedTint,
            ),
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------
// DATA MODELS FOR INTERNAL USE
// -------------------------------------------------------
class _OverviewEntry {
  final String title;
  final String? subtitle;
  final String time;
  final double wet, dry, mixed;

  _OverviewEntry({
    required this.title,
    required this.time,
    this.subtitle,
    this.wet = 0,
    this.dry = 0,
    this.mixed = 0,
  });
}

class _SummaryTotals {
  final double wet, dry, mixed;
  final int count;

  _SummaryTotals({
    required this.wet,
    required this.dry,
    required this.mixed,
    required this.count,
  });
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black.withOpacity(0.65),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// PICKUP TILE (UI)
// -------------------------------------------------------
class _PickupTile extends StatelessWidget {
  const _PickupTile({required this.entry});

  final _OverviewEntry entry;

  @override
  Widget build(BuildContext context) {
    return OperatorInfoCard(
      title: entry.title,
      titleStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      subtitle: entry.subtitle ?? "",
      trailing: Text(
        entry.time,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      child: Row(
        children: [
          if (entry.wet > 0)
            _Badge(
              icon: Icons.water_drop,
              label: "${entry.wet} kg",
              color: _wetTint,
            ),
          if (entry.dry > 0)
            _Badge(
              icon: Icons.layers,
              label: "${entry.dry} kg",
              color: _dryTint,
            ),
          if (entry.mixed > 0)
            _Badge(
              icon: Icons.inventory,
              label: "${entry.mixed} kg",
              color: _mixedTint,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.45)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color.withOpacity(.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Center(
        child: Text(
          "Collection overview",
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
