import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/logic/supervisor_bloc.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/supervisor_trip_map_screen.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_assignment_card.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_assignment_detail_sheet.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

enum _TripFilter { all, inProgress, completed }

/// Trips tab — today's zone-scoped trips with status filter chips. Tapping a
/// trip opens the detail sheet.
class SupervisorTripsScreen extends StatefulWidget {
  const SupervisorTripsScreen({super.key});

  @override
  State<SupervisorTripsScreen> createState() => _SupervisorTripsScreenState();
}

class _SupervisorTripsScreenState extends State<SupervisorTripsScreen> {
  _TripFilter _filter = _TripFilter.all;

  List<SupervisorAssignment> _apply(List<SupervisorAssignment> all) {
    switch (_filter) {
      case _TripFilter.inProgress:
        return all.where((a) => a.isInProgress).toList();
      case _TripFilter.completed:
        return all.where((a) => a.isCompleted).toList();
      case _TripFilter.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SupervisorTheme.background,
      child: SafeArea(
        bottom: false,
        child: SupervisorPatternBackground(
          child: BlocBuilder<SupervisorBloc, SupervisorState>(
            builder: (context, state) {
              return Column(
                children: [
                  _topBar(),
                  _filterChips(state),
                  Expanded(child: _buildBody(context, state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Trips today',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: SupervisorTheme.strongText,
          ),
        ),
      ),
    );
  }

  Widget _filterChips(SupervisorState state) {
    final all = state.assignments;
    final chips = <Widget>[
      SupervisorFilterChip(
        label: 'All (${all.length})',
        selected: _filter == _TripFilter.all,
        onTap: () => setState(() => _filter = _TripFilter.all),
      ),
      const SizedBox(width: 8),
      SupervisorFilterChip(
        label: 'In Progress (${state.inProgress.length})',
        selected: _filter == _TripFilter.inProgress,
        onTap: () => setState(() => _filter = _TripFilter.inProgress),
      ),
      const SizedBox(width: 8),
      SupervisorFilterChip(
        label: 'Completed (${state.completed.length})',
        selected: _filter == _TripFilter.completed,
        onTap: () => setState(() => _filter = _TripFilter.completed),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(children: chips),
    );
  }

  Widget _buildBody(BuildContext context, SupervisorState state) {
    if (state.status == SupervisorStatus.loading ||
        state.status == SupervisorStatus.initial) {
      return const SupervisorLoadingView();
    }
    if (state.status == SupervisorStatus.failure) {
      return SupervisorErrorView(
        message: state.errorMessage ?? 'Failed to load trips',
        onRetry: () =>
            context.read<SupervisorBloc>().add(const SupervisorLoadRequested()),
      );
    }

    final filtered = _apply(state.assignments);
    if (filtered.isEmpty) {
      return SupervisorEmptyView(
        message: state.assignments.isEmpty
            ? 'No trips scheduled in your zones today.'
            : 'No trips match this filter.',
        icon: Icons.route_rounded,
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
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => SupervisorAssignmentCard(
          assignment: filtered[i],
          onTap: () =>
              SupervisorAssignmentDetailSheet.show(context, filtered[i]),
          onNavigate: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SupervisorTripMapScreen(
                assignmentId: filtered[i].uniqueId,
                title: filtered[i].areaName,
                driverName: filtered[i].driverName,
                vehicleNo: filtered[i].vehicleNo,
                tripDate: filtered[i].tripDate,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
