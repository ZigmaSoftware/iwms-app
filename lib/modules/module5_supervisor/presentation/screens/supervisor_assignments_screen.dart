import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/logic/supervisor_bloc.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_assignment_card.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_assignment_detail_sheet.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

/// Assignments tab — review list grouped by approval status. View-only this. 
/// phase (approve/reject is scaffolded in the detail sheet but disabled).

class SupervisorAssignmentsScreen extends StatelessWidget {
  const SupervisorAssignmentsScreen({super.key});

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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Assignment review',
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
        message: state.errorMessage ?? 'Failed to load assignments',
        onRetry: () =>
            context.read<SupervisorBloc>().add(const SupervisorLoadRequested()),
      );
    }
    if (state.assignments.isEmpty) {
      return SupervisorEmptyView(
        message: 'No assignments to review in your zones today.',
        icon: Icons.fact_check_rounded,
        onRefresh: () => context
            .read<SupervisorBloc>()
            .add(const SupervisorRefreshRequested()),
      );
    }

    final pending =
        state.assignments.where((a) => a.isPendingApproval).toList();
    final reviewed =
        state.assignments.where((a) => !a.isPendingApproval).toList();

    return RefreshIndicator(
      color: SupervisorTheme.accent,
      onRefresh: () async {
        context.read<SupervisorBloc>().add(const SupervisorRefreshRequested());
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 220),
        children: [
          if (pending.isNotEmpty) ...[
            _sectionHeader(
                'Awaiting review', pending.length, SupervisorTheme.warning),
            const SizedBox(height: 10),
            ..._cards(context, pending),
            const SizedBox(height: 18),
          ],
          if (reviewed.isNotEmpty) ...[
            _sectionHeader(
                'Reviewed', reviewed.length, SupervisorTheme.success),
            const SizedBox(height: 10),
            ..._cards(context, reviewed),
          ],
        ],
      ),
    );
  }

  List<Widget> _cards(
    BuildContext context,
    List<SupervisorAssignment> items,
  ) {
    return items
        .map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SupervisorAssignmentCard(
              assignment: a,
              onTap: () => SupervisorAssignmentDetailSheet.show(context, a),
            ),
          ),
        )
        .toList();
  }

  Widget _sectionHeader(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: SupervisorTheme.strongText,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SupervisorTheme.mutedText,
          ),
        ),
      ],
    );
  }
}













