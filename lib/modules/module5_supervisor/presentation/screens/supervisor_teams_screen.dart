import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

/// Teams — the staff template list (driver + operator + extra operators).
class SupervisorTeamsScreen extends StatefulWidget {
  const SupervisorTeamsScreen({super.key});

  @override
  State<SupervisorTeamsScreen> createState() => _SupervisorTeamsScreenState();
}

class _SupervisorTeamsScreenState extends State<SupervisorTeamsScreen> {
  final SupervisorRepository _repo = getIt<SupervisorRepository>();

  bool _loading = true;
  String? _error;
  List<SupervisorTeam> _teams = [];

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
      final teams = await _repo.fetchTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load teams';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupervisorTheme.background,
      appBar: AppBar(
        backgroundColor: SupervisorTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Teams'),
      ),
      body: SupervisorPatternBackground(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const SupervisorLoadingView();
    if (_error != null) {
      return SupervisorErrorView(message: _error!, onRetry: _load);
    }
    if (_teams.isEmpty) {
      return SupervisorEmptyView(
        message: 'No staff templates found.',
        icon: Icons.groups_2_rounded,
        onRefresh: _load,
      );
    }

    return RefreshIndicator(
      color: SupervisorTheme.accent,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        itemCount: _teams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _TeamCard(team: _teams[i], index: i),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.index});

  final SupervisorTeam team;
  final int index;

  Color get _statusColor {
    switch (team.status.toUpperCase()) {
      case 'ACTIVE':
        return SupervisorTheme.success;
      case 'INACTIVE':
        return SupervisorTheme.mutedText;
      default:
        return SupervisorTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border: Border.all(color: SupervisorTheme.hairline.withValues(alpha: 0.6)),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SupervisorTheme.accent.withValues(alpha: 0.12),
                  borderRadius: SupervisorTheme.chipRadius,
                ),
                child: const Icon(Icons.groups_2_rounded,
                    color: SupervisorTheme.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Team ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SupervisorTheme.strongText,
                  ),
                ),
              ),
              if (team.status.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: _statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    team.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _statusColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _memberRow(
            icon: Icons.local_shipping_rounded,
            label: 'Driver',
            value: team.driverName.isNotEmpty ? team.driverName : 'Unassigned',
          ),
          const SizedBox(height: 8),
          _memberRow(
            icon: Icons.engineering_rounded,
            label: 'Operator',
            value:
                team.operatorName.isNotEmpty ? team.operatorName : 'Unassigned',
          ),
          if (team.extraCount > 0) ...[
            const SizedBox(height: 8),
            _memberRow(
              icon: Icons.group_add_rounded,
              label: 'Extra operators',
              value: '${team.extraCount}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: SupervisorTheme.mutedText),
        const SizedBox(width: 8),
        Text(
          '$label:  ',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: SupervisorTheme.mutedText,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SupervisorTheme.strongText,
            ),
          ),
        ),
      ],
    );
  }
}
