import 'package:flutter/foundation.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';

import '../models/citizen_alert.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this._service);

  final NotificationService _service;

  final List<CitizenAlert> alerts = [];
  bool hasUnread = false;

  void addAlert(CitizenAlert alert) {
    alerts.insert(0, alert);
    hasUnread = true;
    notifyListeners();
    _service.showCollectorNearbyNotification(
      title: alert.title,
      message: alert.message,
    );
  }

  void markRead() {
    if (!hasUnread) return;
    hasUnread = false;
    notifyListeners();
  }
}
