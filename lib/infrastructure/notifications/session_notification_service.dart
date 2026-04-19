// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';

/// Narrow port over [`FlutterLocalNotificationsPlugin`] — only the operations
/// [SessionNotificationService] actually needs. Isolates the static-factory
/// singleton from the service so tests can inject a capture-and-record fake
/// without having to reach into the plugin's platform-channel plumbing.
abstract class LocalNotificationsPort {
  /// Creates (or no-ops on) the Android notification channel.
  Future<void> createAndroidChannel(AndroidNotificationChannel channel);

  /// Requests iOS notification-delivery permission. Returns the user's choice
  /// (`null` when the platform does not apply, e.g. Android / desktop).
  Future<bool?> requestIosPermissions({required bool alert, required bool badge, required bool sound});

  /// Posts a notification. Mirrors
  /// [`FlutterLocalNotificationsPlugin.show`] but with our narrower
  /// interface.
  Future<void> show({required int id, required String title, required String body, required NotificationDetails details, String? payload});

  /// Cancels a specific notification by id.
  Future<void> cancel({required int id});
}

/// Default adapter over the real [`FlutterLocalNotificationsPlugin`]
/// singleton. Concentrates every `resolvePlatformSpecificImplementation`
/// call behind the narrow port so the service body stays free of
/// platform-channel plumbing.
class FlutterLocalNotificationsAdapter implements LocalNotificationsPort {
  FlutterLocalNotificationsAdapter(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> createAndroidChannel(AndroidNotificationChannel channel) async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
  }

  @override
  Future<bool?> requestIosPermissions({required bool alert, required bool badge, required bool sound}) async {
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return ios?.requestPermissions(alert: alert, badge: badge, sound: sound);
  }

  @override
  Future<void> show({required int id, required String title, required String body, required NotificationDetails details, String? payload}) async {
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details, payload: payload);
  }

  @override
  Future<void> cancel({required int id}) async {
    await _plugin.cancel(id: id);
  }
}

/// Owns the persistent-tracking notification channel lifecycle plus the
/// "tap to resume" notification fired by the Plan 05-06 auto-resume path
/// (Android `BOOT_COMPLETED` receiver, iOS significant-change watchdog).
///
/// The ACTIVE-tracking notification itself is emitted by `geolocator` via
/// `ForegroundNotificationConfig` (see
/// `lib/infrastructure/gps/location_settings_factory.dart`); this service
/// guarantees the channel exists with the correct importance BEFORE
/// geolocator's fg service posts into it, and owns the separate
/// tap-to-resume notification.
class SessionNotificationService {
  SessionNotificationService(this._notifications);

  final LocalNotificationsPort _notifications;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    kNotificationChannelId,
    'MirkFall session tracking',
    description: 'Notification persistante pendant une session active',
    importance: Importance.low,
    enableVibration: false,
    playSound: false,
  );

  /// Notification ID for the "tap to resume" local notification. Stable so
  /// [dismiss] can target it without tracking state in memory.
  static const int _resumeNotificationId = 1001;

  bool _initialized = false;

  /// Idempotent — creates the Android channel and requests the iOS
  /// notification permission. Safe to call on every app start.
  Future<void> initialize() async {
    if (_initialized) return;
    await _notifications.createAndroidChannel(_channel);
    await _notifications.requestIosPermissions(alert: true, badge: false, sound: false);
    _initialized = true;
  }

  /// Fires the "tap to resume tracking" notification (Plan 05-06
  /// BOOT_COMPLETED + iOS watchdog). Payload encodes the session id so the
  /// tap handler can route to the correct session.
  Future<void> showResumeNotification(SessionId sessionId, String sessionDisplayName) async {
    await initialize();
    await _notifications.show(
      id: _resumeNotificationId,
      title: 'Session "$sessionDisplayName" interrompue',
      body: 'Tap pour reprendre le suivi',
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          kNotificationChannelId,
          'MirkFall session tracking',
          // Resume notification is distinct from the ongoing fg-service
          // notification — higher importance so the user actually sees
          // it. `ongoing` is omitted (defaults to false — dismissible
          // on tap).
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'resume:${sessionId.value}',
    );
  }

  /// Dismisses the resume notification (called on Stop or when the user
  /// accepts the resume prompt). Idempotent — cancelling a non-existent
  /// notification is a no-op on both platforms.
  Future<void> dismiss() async {
    await _notifications.cancel(id: _resumeNotificationId);
  }

  /// Test hook — expose the canonical channel id so assertions do not
  /// have to replicate the [`kNotificationChannelId`] import.
  static String get channelId => _channel.id;

  /// Test hook — expose the resume-notification id so tests can assert
  /// [dismiss] targets the same id.
  static int get resumeNotificationId => _resumeNotificationId;
}
