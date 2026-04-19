// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_notification_service_provider.g.dart';

/// Production [SessionNotificationService] — wraps a
/// [`FlutterLocalNotificationsAdapter`] around the
/// [`FlutterLocalNotificationsPlugin`] singleton.
///
/// `keepAlive: true` — the Android notification channel is a
/// process-long singleton; re-creating the service on every consumer
/// subscription would be wasted work with no observable benefit.
@Riverpod(keepAlive: true)
SessionNotificationService sessionNotificationService(Ref ref) {
  return SessionNotificationService(FlutterLocalNotificationsAdapter(FlutterLocalNotificationsPlugin()));
}
