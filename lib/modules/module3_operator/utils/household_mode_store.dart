import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted on/off flag for the operator "Household" collection mode.
///
/// When enabled, the central QR FAB scans a *customer* QR and opens the
/// household waste-entry flow (`OperatorQRScanner` → `OperatorDataScreen`,
/// with wet/dry/mixed weights, photos and Bluetooth scale support). When
/// disabled, the operator follows the default bin/trip flow
/// (`OperatorTripScanScreen`).
///
/// The flag survives app restarts (stored via shared_preferences) and is
/// exposed as a [ValueListenable] so widgets — e.g. the profile toggle and
/// the tab bar's scanner launcher — stay in sync without manual plumbing.
class HouseholdModeStore {
  HouseholdModeStore._();

  static const String _prefKey = 'operator_household_mode_enabled';

  static final ValueNotifier<bool> _notifier = ValueNotifier<bool>(false);
  static bool _loaded = false;

  /// Listenable mirror of the current mode. Defaults to `false` until
  /// [load] resolves the persisted value.
  static ValueListenable<bool> get listenable => _notifier;

  /// Current value (synchronous). Reflects the last loaded/saved state.
  static bool get isEnabled => _notifier.value;

  /// Hydrate the in-memory value from disk. Safe to call multiple times;
  /// only the first call hits storage. Call once on operator entry.
  static Future<bool> load() async {
    if (_loaded) return _notifier.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      _notifier.value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      // Fall back to the in-memory default on any storage error.
    }
    _loaded = true;
    return _notifier.value;
  }

  /// Persist and broadcast a new value.
  static Future<void> setEnabled(bool value) async {
    _notifier.value = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {
      // Best-effort persistence; the in-memory value still updated.
    }
  }
}
