import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles all push / local notification responsibilities for the citizen app.
///
/// The concrete implementation is intentionally left as placeholders so the
/// real notification plumbing (Firebase Cloud Messaging, local notifications,
/// etc.) can be wired up later without impacting the rest of the codebase.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'iwms_default_channel',
    'General',
    description: 'General notifications for IWMS citizen app',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings darwinInit =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const LinuxInitializationSettings linuxInit = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      linux: linuxInit,
    );

    await _plugin.initialize(initSettings);

    // Android 13+ runtime permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Create default channel on Android
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);

    _initialized = true;
    debugPrint('[NotificationService] initialized');
  }

  Future<void> showCollectorNearbyNotification({
    String title = 'Collection Alert',
    String message = 'A collection vehicle is near. Please segregate waste.',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _kAndroidChannelId,
      'General',
      channelDescription: 'General notifications for IWMS citizen app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(101, title, message, details);
  }

  Future<void> scheduleCollectorReminder({
    required DateTime triggerAt,
    String title = 'Upcoming pickup',
    String message = 'Waste collection scheduled soon. Prepare your waste.',
  }) async {
    // NOTE: For timezone-accurate scheduling, integrate flutter_native_timezone
    // and use zonedSchedule. Keeping immediate show as a safe fallback.
    await showCollectorNearbyNotification(title: title, message: message);
  }

  Future<void> cancelCollectorNotifications() async {
    await _plugin.cancelAll();
  }

  Future<void> showAssignmentNotification({
    required String title,
    required String message,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _kAndroidChannelId,
      'General',
      channelDescription: 'General notifications for IWMS citizen app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _plugin.show(notificationId, title, message, details);
  }
}

const String _kAndroidChannelId = 'iwms_default_channel';
