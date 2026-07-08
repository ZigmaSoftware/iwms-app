import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_assignment_card.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_assignment_detail_sheet.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

/// History — this supervisor's daily trip assignments across all dates,
/// grouped by date (newest first).
class SupervisorHistoryScreen extends StatefulWidget {
  const SupervisorHistoryScreen({super.key});

  @override
  State<SupervisorHistoryScreen> createState() =>
      _SupervisorHistoryScreenState();
}

class _SupervisorHistoryScreenState extends State<SupervisorHistoryScreen> {
  final SupervisorRepository _repo = getIt<SupervisorRepository>();

  bool _loading = true;
  String? _error;
  List<SupervisorAssignment> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchAssignmentHistory();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load history';
        _loading = false;
      });
    }
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return 'Undated';
    return DateFormat('EEE, dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupervisorTheme.background,
      appBar: AppBar(
        backgroundColor: SupervisorTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Trip history'),
      ),
      body: SupervisorPatternBackground(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const SupervisorLoadingView();
    if (_error != null) {
      return SupervisorErrorView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return SupervisorEmptyView(
        message: 'No trip history yet.',
        icon: Icons.history_rounded,
        onRefresh: _load,
      );
    }

    // Group by date label, preserving the newest-first order already applied
    // by the repository.
    final groups = <String, List<SupervisorAssignment>>{};
    for (final a in _items) {
      groups.putIfAbsent(_dateLabel(a.tripDate), () => []).add(a);
    }

    return RefreshIndicator(
      color: SupervisorTheme.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: SupervisorTheme.mutedText,
                ),
              ),
            ),
            ...entry.value.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SupervisorAssignmentCard(
                    assignment: a,
                    onTap: () =>
                        SupervisorAssignmentDetailSheet.show(context, a),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
