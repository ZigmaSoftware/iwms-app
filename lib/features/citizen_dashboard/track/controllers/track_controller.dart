import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/waste_period.dart';
import '../models/waste_summary.dart';
import '../services/track_service.dart';

class TrackController extends ChangeNotifier {
  TrackController(this._service);

  final TrackService _service;

  final DateFormat displayFormat = DateFormat('EEEE, dd MMM yyyy');
  final DateFormat monthFormat = DateFormat('MMMM yyyy');
  final DateFormat shortDisplayFormat = DateFormat('d MMM');
  final NumberFormat weightFormatter = NumberFormat.decimalPattern();
  final NumberFormat averageFormatter = NumberFormat('#,##0.00');

  WastePeriod selectedPeriod = WastePeriod.monthly;
  DateTime selectedDate = DateTime.now();
  bool loading = false;
  String? error;
  WastePeriod? _lastPeriod;
  DateTime? _lastReferenceDate;
  WasteSummary? _currentSummary;

  WasteSummary? get currentSummary => _currentSummary;

  Future<void> refresh({bool force = false}) async {
    final reference = _referenceDateForPeriod();
    if (!force &&
        _currentSummary != null &&
        _lastPeriod == selectedPeriod &&
        _lastReferenceDate == reference) {
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      final summary = await _service.fetchCitizenSummary(
        period: selectedPeriod,
        referenceDate: reference,
      );
      _currentSummary = summary ?? WasteSummary.zero(reference);
      _lastPeriod = selectedPeriod;
      _lastReferenceDate = reference;
      loading = false;
      notifyListeners();
    } catch (e) {
      loading = false;
      error = 'Unable to load collected waste. Pull down to retry.';
      notifyListeners();
    }
  }

  void setPeriod(WastePeriod period) {
    if (selectedPeriod == period) return;
    selectedPeriod = period;
    notifyListeners();
  }

  Future<void> pickDate(DateTime date) async {
    selectedDate = _normalize(date);
    await refresh();
    notifyListeners();
  }

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _referenceDateForPeriod() {
    switch (selectedPeriod) {
      case WastePeriod.daily:
        return _normalize(selectedDate);
      case WastePeriod.monthly:
        return DateTime(selectedDate.year, selectedDate.month, 1);
      case WastePeriod.total:
        return _normalize(selectedDate);
    }
  }

  String periodLabel(WastePeriod period) {
    switch (period) {
      case WastePeriod.daily:
        return 'Daily';
      case WastePeriod.monthly:
        return 'Monthly';
      case WastePeriod.total:
        return 'Total';
    }
  }
}
