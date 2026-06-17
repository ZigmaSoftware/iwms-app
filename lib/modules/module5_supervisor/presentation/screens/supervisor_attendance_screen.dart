import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/logic/supervisor_bloc.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';

/// A staff member on duty in the supervisor's zones today, derived from the
/// day's trip assignments.
class _StaffRow {
  _StaffRow({
    required this.name,
    required this.role,
    required this.area,
    required this.onDuty,
  });

  final String name;
  final String role;
  final String area;
  final bool onDuty;
}

/// Attendance tab — read-only roster of operators & drivers on duty in the
/// supervisor's zones today. "On duty" = their trip is in progress.
class SupervisorAttendanceScreen extends StatelessWidget {
  const SupervisorAttendanceScreen({super.key});

  List<_StaffRow> _roster(List<SupervisorAssignment> assignments) {
    final seen = <String>{};
    final rows = <_StaffRow>[];
    for (final a in assignments) {
      void add(String name, String role) {
        if (name.trim().isEmpty) return;
        final key = '$role:$name';
        if (!seen.add(key)) return;
        rows.add(_StaffRow(
          name: name,
          role: role,
          area: a.areaName,
          onDuty: a.isInProgress,
        ));
      }

      add(a.driverName, 'Driver');
      add(a.operatorName, 'Operator');
    }
    rows.sort((x, y) {
      if (x.onDuty == y.onDuty) return x.name.compareTo(y.name);
      return x.onDuty ? -1 : 1;
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SupervisorTheme.background,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<SupervisorBloc, SupervisorState>(
          builder: (context, state) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Team on duty',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: SupervisorTheme.strongText,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SupervisorState state) {
    if (state.status == SupervisorStatus.loading ||
        state.status == SupervisorStatus.initial) {
      return const SupervisorLoadingView();
    }
    if (state.status == SupervisorStatus.failure) {
      return SupervisorErrorView(
        message: state.errorMessage ?? 'Failed to load team',
        onRetry: () =>
            context.read<SupervisorBloc>().add(const SupervisorLoadRequested()),
      );
    }

    final roster = _roster(state.assignments);
    if (roster.isEmpty) {
      return SupervisorEmptyView(
        message: 'No staff assigned to trips in your zones today.',
        icon: Icons.groups_rounded,
        onRefresh: () => context
            .read<SupervisorBloc>()
            .add(const SupervisorRefreshRequested()),
      );
    }

    return RefreshIndicator(
      color: SupervisorTheme.accent,
      onRefresh: () async {
        context.read<SupervisorBloc>().add(const SupervisorRefreshRequested());
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 220),
        itemCount: roster.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _staffTile(roster[i]),
      ),
    );
  }

  Widget _staffTile(_StaffRow r) {
    final statusColor =
        r.onDuty ? SupervisorTheme.success : SupervisorTheme.mutedText;
    final initials = r.name.isEmpty
        ? '?'
        : r.name.trim().split(' ').where((p) => p.isNotEmpty).map((p) => p[0])
            .take(2)
            .join()
            .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border: Border.all(color: SupervisorTheme.hairline),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: SupervisorTheme.surfaceMuted,
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: SupervisorTheme.primary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SupervisorTheme.strongText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${r.role} · ${r.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SupervisorTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: SupervisorTheme.chipRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  r.onDuty ? 'On duty' : 'Assigned',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
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
