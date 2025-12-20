import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';

const BorderRadius _kCardRadius = BorderRadius.all(Radius.circular(18));
const BorderRadius _kChipRadius = BorderRadius.all(Radius.circular(18));
const List<BoxShadow> _kSoftShadow = [
  BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 14,
    offset: Offset(0, 10),
  ),
];
const Color _historyPrimary = AppColors.primary;
const Color _historyAccent = Color(0xFF66BB6A);

class OperatorHistoryEntry {
  const OperatorHistoryEntry({
    required this.routeName,
    required this.location,
    required this.timestamp,
    required this.totalKg,
    required this.wetKg,
    required this.dryKg,
    this.otherKg = 0,
  });

  final String routeName;
  final String location;
  final String timestamp;
  final double totalKg;
  final double wetKg;
  final double dryKg;
  final double otherKg;
}

class OperatorHistoryTabData {
  const OperatorHistoryTabData({
    required this.label,
    required this.entries,
  });

  final String label;
  final List<OperatorHistoryEntry> entries;
}

class OperatorHistoryTabs extends StatelessWidget {
  const OperatorHistoryTabs({
    super.key,
    required this.tabs,
  });

  final List<OperatorHistoryTabData> tabs;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const Center(child: Text('No history found'));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _kChipRadius,
              boxShadow: _kSoftShadow,
            ),
            child: TabBar(
              labelColor: _historyPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              indicator: BoxDecoration(
                color: _historyPrimary.withOpacity(0.16),
                borderRadius: _kChipRadius,
              ),
              tabs: tabs
                  .map(
                    (tab) => Tab(
                      height: 52,
                      child: Text(
                        tab.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: tabs
                  .map(
                    (tab) => _OperatorHistoryList(entries: tab.entries),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorHistoryList extends StatelessWidget {
  const _OperatorHistoryList({required this.entries});

  final List<OperatorHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No records for this filter.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _OperatorHistoryCard(entry: entry);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: entries.length,
    );
  }
}

class _OperatorHistoryCard extends StatelessWidget {
  const _OperatorHistoryCard({required this.entry});

  final OperatorHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final vehicleLabel =
        entry.location.isNotEmpty ? entry.location : entry.routeName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _kCardRadius,
        boxShadow: _kSoftShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _historyPrimary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.recycling_rounded,
                    color: _historyPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Waste Collected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vehicle : $vehicleLabel',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total Collected :',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.totalKg.toStringAsFixed(1)} Kg',
                    style: const TextStyle(
                      color: _historyPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: _historyAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _historyAccent.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.dryKg.toStringAsFixed(1)} Kg',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Dry',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.black.withOpacity(0.1),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.wetKg.toStringAsFixed(1)} Kg',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Wet',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
