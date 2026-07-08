import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';

// ============================================================
// EVENTS
// ============================================================

abstract class SupervisorEvent {
  const SupervisorEvent();
}

/// Initial bootstrap: load the zone scope then today's assignments.
class SupervisorLoadRequested extends SupervisorEvent {
  const SupervisorLoadRequested();
}

/// Pull-to-refresh / FAB refresh — re-fetch assignments for the loaded scope.
class SupervisorRefreshRequested extends SupervisorEvent {
  const SupervisorRefreshRequested();
}

// ============================================================
// STATE
// ============================================================

enum SupervisorStatus { initial, loading, ready, empty, failure }

class SupervisorState {
  final SupervisorStatus status;
  final SupervisorZoneScope scope;
  final List<SupervisorAssignment> assignments;
  final SupervisorKpis kpis;
  final List<SupervisorAlert> alerts;
  final String? errorMessage;

  const SupervisorState({
    this.status = SupervisorStatus.initial,
    this.scope = SupervisorZoneScope.empty,
    this.assignments = const [],
    this.kpis = SupervisorKpis.empty,
    this.alerts = const [],
    this.errorMessage,
  });

  SupervisorState copyWith({
    SupervisorStatus? status,
    SupervisorZoneScope? scope,
    List<SupervisorAssignment>? assignments,
    SupervisorKpis? kpis,
    List<SupervisorAlert>? alerts,
    String? errorMessage,
  }) {
    return SupervisorState(
      status: status ?? this.status,
      scope: scope ?? this.scope,
      assignments: assignments ?? this.assignments,
      kpis: kpis ?? this.kpis,
      alerts: alerts ?? this.alerts,
      errorMessage: errorMessage,
    );
  }

  List<SupervisorAssignment> get inProgress =>
      assignments.where((a) => a.isInProgress).toList();
  List<SupervisorAssignment> get completed =>
      assignments.where((a) => a.isCompleted).toList();
  List<SupervisorAssignment> get pendingReview =>
      assignments.where((a) => a.isPendingApproval).toList();
}

// ============================================================
// BLOC
// ============================================================

class SupervisorBloc extends Bloc<SupervisorEvent, SupervisorState> {
  final SupervisorRepository _repo;

  SupervisorBloc({required SupervisorRepository repository})
      : _repo = repository,
        super(const SupervisorState()) {
    on<SupervisorLoadRequested>(_onLoad);
    on<SupervisorRefreshRequested>(_onRefresh);
  }

  Future<void> _onLoad(
    SupervisorLoadRequested event,
    Emitter<SupervisorState> emit,
  ) async {
    emit(state.copyWith(status: SupervisorStatus.loading));
    try {
      final scope = await _repo.fetchMyZoneScope();
      await _loadAssignments(scope, emit);
    } on SupervisorException catch (e) {
      emit(state.copyWith(
        status: SupervisorStatus.failure,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SupervisorStatus.failure,
        errorMessage: 'Failed to load supervisor data: $e',
      ));
    }
  }

  Future<void> _onRefresh(
    SupervisorRefreshRequested event,
    Emitter<SupervisorState> emit,
  ) async {
    try {
      await _loadAssignments(state.scope, emit);
    } on SupervisorException catch (e) {
      emit(state.copyWith(
        status: SupervisorStatus.failure,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SupervisorStatus.failure,
        errorMessage: 'Failed to refresh: $e',
      ));
    }
  }

  Future<void> _loadAssignments(
    SupervisorZoneScope scope,
    Emitter<SupervisorState> emit,
  ) async {
    // Show only THIS supervisor's assignments (trip plans they supervise),
    // scoped to today, not everything in their zones.
    final assignments =
        await _repo.fetchAssignments(mine: true, date: DateTime.now());
    final kpis = SupervisorKpis.fromAssignments(assignments);
    final alerts = SupervisorAlert.fromAssignments(assignments);

    emit(state.copyWith(
      status: assignments.isEmpty
          ? SupervisorStatus.empty
          : SupervisorStatus.ready,
      scope: scope,
      assignments: assignments,
      kpis: kpis,
      alerts: alerts,
    ));
  }
}
