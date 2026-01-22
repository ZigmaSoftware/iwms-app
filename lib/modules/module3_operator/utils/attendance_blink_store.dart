import 'dart:async';

import 'package:flutter/foundation.dart';

class AttendanceBlinkStore {
  static final ValueNotifier<bool> _notifier = ValueNotifier(false);
  static Timer? _toggleTimer;
  static Timer? _durationTimer;
  static Timer? _cycleTimer;

  static ValueListenable<bool> get notifier => _notifier;

  static void triggerBlink({
    Duration duration = const Duration(minutes: 2),
  }) {
    _toggleTimer?.cancel();
    _durationTimer?.cancel();

    bool isOn = true;
    _notifier.value = isOn;

    _toggleTimer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) {
        isOn = !isOn;
        _notifier.value = isOn;
      },
    );

    _durationTimer = Timer(duration, () {
      _toggleTimer?.cancel();
      _notifier.value = false;
    });
  }

  static void startPeriodicReminder({
    Duration interval = const Duration(minutes: 45),
    Duration blinkDuration = const Duration(minutes: 2),
  }) {
    _cycleTimer?.cancel();
    triggerBlink(duration: blinkDuration);
    _cycleTimer = Timer.periodic(
      interval,
      (_) => triggerBlink(duration: blinkDuration),
    );
  }

  static void dispose() {
    _cycleTimer?.cancel();
    _toggleTimer?.cancel();
    _durationTimer?.cancel();
    _notifier.value = false;
  }
}
