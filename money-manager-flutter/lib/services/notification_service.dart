import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// System notifications for budget alerts (Android, iOS and Windows).
/// Failures are logged and ignored: the in-app warnings still work without them.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 0;

  static const _channel = AndroidNotificationDetails(
    'budget_alerts',
    'Budget alerts',
    channelDescription: 'Warnings when spending approaches or exceeds a budget',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    try {
      _ready = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(),
              windows: WindowsInitializationSettings(
                appName: 'Money Manager',
                appUserModelId: 'com.example.MoneyManager',
                guid: '6f0a4c1e-2b7d-4c8a-9e3f-5d1b2a7c9e40',
              ),
            ),
          ) ??
          false;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true);
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  Future<void> show({required String title, required String body}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _channel,
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Showing notification failed: $e');
    }
  }
}
