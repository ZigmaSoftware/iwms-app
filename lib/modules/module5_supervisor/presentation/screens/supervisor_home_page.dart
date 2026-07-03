import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/logic/supervisor_bloc.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/supervisor_grievance_screen.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_cards.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_header.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

/// Dashboard tab — header + zone KPIs + activity/alerts feed.
class SupervisorHomePage extends StatelessWidget {
  const SupervisorHomePage({
    super.key,
    required this.name,
    required this.onLogout,
    this.onOpenTrips,
    this.onOpenAssignments,
    this.onOpenTeam,
  });

  final String name;
  final VoidCallback onLogout;
  final VoidCallback? onOpenTrips;
  final VoidCallback? onOpenAssignments;
  final VoidCallback? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupervisorBloc, SupervisorState>(
      builder: (context, state) {
        final kpis = state.kpis;
        return Container(
          color: SupervisorTheme.background,
          child: Column(
            children: [
              SupervisorHeader(
                name: name,
                onLogout: onLogout,
                zoneCount: state.scope.zoneIds.length,
              ),
              Expanded(
                // Static dotted background: painted once behind the scroll view
                // so it stays fixed while the content scrolls. The KPI cards are
                // transparent tints (very low fill + near-zero blur), so the
                // dots show through them via normal compositing — no need to put
                // the pattern inside the viewport.
                child: SupervisorPatternBackground(
                  child: _buildBody(context, state, kpis),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    SupervisorState state,
    SupervisorKpis kpis,
  ) {
    if (state.status == SupervisorStatus.loading ||
        state.status == SupervisorStatus.initial) {
      return const SupervisorLoadingView();
    }
    if (state.status == SupervisorStatus.failure) {
      return SupervisorErrorView(
        message: state.errorMessage ?? 'Something went wrong',
        onRetry: () =>
            context.read<SupervisorBloc>().add(const SupervisorLoadRequested()),
      );
    }

    return RefreshIndicator(
      color: SupervisorTheme.accent,
      onRefresh: () async {
        context.read<SupervisorBloc>().add(const SupervisorRefreshRequested());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          SupervisorKpiAreaChart(kpis: kpis),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: SupervisorTimeChip(label: 'Trips')),
              SizedBox(width: 8),
              Expanded(child: SupervisorTimeChip(label: 'Review')),
              SizedBox(width: 8),
              Expanded(
                child: SupervisorTimeChip(label: 'Today', selected: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Today at a glance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SupervisorTheme.strongText,
            ),
          ),
          const SizedBox(height: 10),
          _kpiGrid(kpis),
          const SizedBox(height: 12),
          _grievanceTile(context),
          if (onOpenTeam != null) ...[
            const SizedBox(height: 12),
            _teamTile(),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'Activity & alerts',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SupervisorTheme.strongText,
                ),
              ),
              const Spacer(),
              if (onOpenAssignments != null)
                TextButton(
                  onPressed: onOpenAssignments,
                  child: const Text('Review',
                      style: TextStyle(
                        color: SupervisorTheme.accent,
                        fontWeight: FontWeight.w700,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.alerts.isEmpty)
            _allClearTile()
          else
            ...state.alerts.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SupervisorAlertTile(alert: a),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiGrid(SupervisorKpis kpis) {
    final cards = [
      SupervisorKpiCard(
        value: '${kpis.total}',
        label: 'Trips today',
        icon: Icons.route_rounded,
        color: SupervisorTheme.info,
        onTap: onOpenTrips,
      ),
      SupervisorKpiCard(
        value: '${kpis.inProgress}',
        label: 'In progress',
        icon: Icons.directions_run_rounded,
        color: const Color(0xFF0EA5E9),
        onTap: onOpenTrips,
      ),
      SupervisorKpiCard(
        value: '${kpis.completed}',
        label: 'Completed',
        icon: Icons.check_circle_rounded,
        color: SupervisorTheme.success,
        onTap: onOpenTrips,
      ),
      SupervisorKpiCard(
        value: '${kpis.pendingReview}',
        label: 'Pending review',
        icon: Icons.hourglass_bottom_rounded,
        color: SupervisorTheme.warning,
        onTap: onOpenAssignments,
      ),
    ];
    // Laid out as plain Rows rather than a nested GridView on purpose: a
    // GridView is itself a scroll viewport (its own compositing layer), which
    // would isolate the cards from the dotted background and stop their
    // BackdropFilter from frosting it. Keeping the cards in the same layer as
    // the background makes the liquid-glass effect consistent at all times.
    const spacing = 12.0;
    const aspect = 1.02;

    Widget cell(Widget card) =>
        Expanded(child: AspectRatio(aspectRatio: aspect, child: card));

    Widget row(Widget a, Widget b) => Row(
          children: [
            cell(a),
            const SizedBox(width: spacing),
            cell(b),
          ],
        );

    return Column(
      children: [
        row(cards[0], cards[1]),
        const SizedBox(height: spacing),
        row(cards[2], cards[3]),
      ],
    );
  }

  Widget _grievanceTile(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SupervisorTheme.cardRadius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SupervisorGrievanceScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SupervisorTheme.primary,
            borderRadius: SupervisorTheme.cardRadius,
            boxShadow: SupervisorTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: SupervisorTheme.chipRadius,
                ),
                child: const Icon(Icons.report_problem_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grievances',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'View & act on citizen complaints for your department',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SupervisorTheme.cardRadius,
        onTap: onOpenTeam,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SupervisorTheme.surface,
            borderRadius: SupervisorTheme.cardRadius,
            border: Border.all(color: SupervisorTheme.hairline),
            boxShadow: SupervisorTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SupervisorTheme.accent.withValues(alpha: 0.12),
                  borderRadius: SupervisorTheme.chipRadius,
                ),
                child: const Icon(Icons.groups_rounded,
                    color: SupervisorTheme.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Team on duty',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SupervisorTheme.strongText,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: SupervisorTheme.mutedText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allClearTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SupervisorTheme.accentSoft,
        borderRadius: SupervisorTheme.cardRadius,
        border:
            Border.all(color: SupervisorTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.task_alt_rounded,
            color: SupervisorTheme.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All clear — no pending alerts in your zones.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SupervisorTheme.accentDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
