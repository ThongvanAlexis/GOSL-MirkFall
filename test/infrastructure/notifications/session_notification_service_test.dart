// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';

/// Covers GPS-04 — session-tracking notification channel lifecycle +
/// "tap to resume" notification payload. Uses the `LocalNotificationsPort`
/// seam so the tests never touch `flutter_local_notifications`' platform
/// channels (which would require a real Android/iOS engine).
void main() {
  late _CapturingNotificationsPort notifications;
  late SessionNotificationService service;

  setUp(() {
    notifications = _CapturingNotificationsPort();
    service = SessionNotificationService(notifications);
  });

  test('initialize is idempotent — calling twice creates the channel once', () async {
    await service.initialize();
    await service.initialize();

    expect(notifications.createAndroidChannelCallCount, 1);
    expect(notifications.requestIosPermissionsCallCount, 1);
    expect(notifications.lastCreatedChannel?.id, kNotificationChannelId);
  });

  test('initialize creates a LOW-importance channel with vibration + sound off', () async {
    await service.initialize();

    final AndroidNotificationChannel channel = notifications.lastCreatedChannel!;
    expect(channel.id, kNotificationChannelId);
    expect(channel.importance, Importance.low);
    expect(channel.enableVibration, isFalse);
    expect(channel.playSound, isFalse);
  });

  test('showResumeNotification uses the canonical channel id + encodes the session in the payload', () async {
    final id = SessionId('sess_${'B' * 26}');
    await service.showResumeNotification(id, 'Balade au parc');

    expect(notifications.shownNotifications, hasLength(1));
    final _ShowCall call = notifications.shownNotifications.single;
    expect(call.id, SessionNotificationService.resumeNotificationId);
    expect(call.title, contains('Balade au parc'));
    expect(call.payload, 'resume:${id.value}');

    final AndroidNotificationDetails? android = call.details.android;
    expect(android, isNotNull);
    expect(android!.channelId, kNotificationChannelId);
    expect(android.importance, Importance.high);
    expect(android.ongoing, isFalse);
  });

  test('showResumeNotification initialises the channel on first call (pre-ambles resume notif)', () async {
    // Must not require the caller to have explicitly called initialize().
    final id = SessionId('sess_${'C' * 26}');
    await service.showResumeNotification(id, 'Courses');

    expect(notifications.createAndroidChannelCallCount, 1);
    expect(notifications.shownNotifications, hasLength(1));
  });

  test('dismiss cancels the fixed resume-notification id', () async {
    await service.dismiss();

    expect(notifications.cancelledIds, [SessionNotificationService.resumeNotificationId]);
  });

  test('SessionNotificationService.channelId matches kNotificationChannelId', () {
    expect(SessionNotificationService.channelId, kNotificationChannelId);
  });
}

/// Capture-and-record fake — records every invocation so tests can assert
/// exact call shapes without binding to `flutter_local_notifications`'
/// platform-channel plumbing. Same pattern as Phase 03's `FakeIdGenerator`.
class _CapturingNotificationsPort implements LocalNotificationsPort {
  AndroidNotificationChannel? lastCreatedChannel;
  int createAndroidChannelCallCount = 0;
  int requestIosPermissionsCallCount = 0;
  final List<_ShowCall> shownNotifications = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> createAndroidChannel(AndroidNotificationChannel channel) async {
    createAndroidChannelCallCount += 1;
    lastCreatedChannel = channel;
  }

  @override
  Future<bool?> requestIosPermissions({required bool alert, required bool badge, required bool sound}) async {
    requestIosPermissionsCallCount += 1;
    return true;
  }

  @override
  Future<void> show({required int id, required String title, required String body, required NotificationDetails details, String? payload}) async {
    shownNotifications.add(_ShowCall(id: id, title: title, body: body, details: details, payload: payload));
  }

  @override
  Future<void> cancel({required int id}) async {
    cancelledIds.add(id);
  }
}

class _ShowCall {
  _ShowCall({required this.id, required this.title, required this.body, required this.details, required this.payload});

  final int id;
  final String title;
  final String body;
  final NotificationDetails details;
  final String? payload;
}
