import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/data/repositories/operator_trip_repository.dart';

// ============================================================
// EVENTS
// ============================================================

abstract class OperatorTripEvent {
  const OperatorTripEvent();
}

class OperatorTripLoadRequested extends OperatorTripEvent {
  const OperatorTripLoadRequested();
}

class OperatorTripRefreshRequested extends OperatorTripEvent {
  const OperatorTripRefreshRequested();
}

class OperatorTripBinScanFinalized extends OperatorTripEvent {
  final BinScanSubmitResult result;
  const OperatorTripBinScanFinalized(this.result);
}

// ============================================================
// STATE
// ============================================================

enum OperatorTripStatus { initial, loading, ready, empty, failure }

class OperatorTripState {
  final OperatorTripStatus status;
  final OperatorTripToday? trip;
  final String? errorMessage;

  const OperatorTripState({
    this.status = OperatorTripStatus.initial,
    this.trip,
    this.errorMessage,
  });

  OperatorTripState copyWith({
    OperatorTripStatus? status,
    OperatorTripToday? trip,
    String? errorMessage,
  }) {
    return OperatorTripState(
      status: status ?? this.status,
      trip: trip ?? this.trip,
      errorMessage: errorMessage,
    );
  }
}

// ============================================================
// BLOC
// ============================================================

class OperatorTripBloc extends Bloc<OperatorTripEvent, OperatorTripState> {
  final OperatorTripRepository _repo;

  OperatorTripBloc({required OperatorTripRepository repository})
      : _repo = repository,
        super(const OperatorTripState()) {
    on<OperatorTripLoadRequested>(_onLoad);
    on<OperatorTripRefreshRequested>(_onLoad);
    on<OperatorTripBinScanFinalized>(_onBinScanFinalized);
  }

  Future<void> _onLoad(
    OperatorTripEvent event,
    Emitter<OperatorTripState> emit,
  ) async {
    emit(state.copyWith(status: OperatorTripStatus.loading));
    try {
      final trip = await _repo.fetchMyTripToday();
      if (trip == null) {
        emit(const OperatorTripState(status: OperatorTripStatus.empty));
        return;
      }
      emit(OperatorTripState(status: OperatorTripStatus.ready, trip: trip));
    } on OperatorTripException catch (e) {
      if (e.code == 'NO_ACTIVE_TRIP') {
        emit(const OperatorTripState(status: OperatorTripStatus.empty));
        return;
      }
      emit(
        OperatorTripState(
          status: OperatorTripStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        OperatorTripState(
          status: OperatorTripStatus.failure,
          errorMessage: 'Failed to load trip: $e',
        ),
      );
    }
  }

  Future<void> _onBinScanFinalized(
    OperatorTripBinScanFinalized event,
    Emitter<OperatorTripState> emit,
  ) async {
    // Easiest: reload the trip so the UI reflects all server-side state changes
    // (status flip to In Progress / Completed, child collected flags, etc.).
    add(const OperatorTripRefreshRequested());
  }
}
