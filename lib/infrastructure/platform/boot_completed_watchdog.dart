// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';

/// Pure-Dart watchdog invoked by platform glue on boot / significant-change.
///
/// The flow (GPS-06, 05-CONTEXT.md §Auto-resume post-kill):
///
///   device reboot OR iOS significant-change wake
///     -> Kotlin BootCompletedReceiver  (Android)  |
///     -> Swift AppDelegate CLLocationManagerDelegate  (iOS)  |
///     -> MethodChannel invokeMethod 'runWatchdog'
///     -> [runBootWatchdogEntryPoint] (Dart top-level, Task 2)
///     -> [BootCompletedWatchdog.run]
///     -> if DB shows status=active session:
///           fire "tap to resume" notification (stable id, dismissible)
///     -> user taps notification -> lib/main.dart tap handler parses
///         `resume:<sessionId>` payload -> routes to `/sessions/:id`
///     -> user presses Start manually (NO silent auto-resume — explicit
///         user control per CONTEXT.md).
///
/// The watchdog NEVER starts the geolocator foreground service directly:
/// Android 14 raises a SecurityException when a BroadcastReceiver tries
/// to start a location fg-service without
/// ACCESS_BACKGROUND_LOCATION-at-invocation-time permission
/// (05-RESEARCH.md Pitfall #5). Notification-only is the compliant path.
///
/// Error policy: any thrown object is logged at WARNING and swallowed.
/// The native side (BroadcastReceiver + CLLocationManagerDelegate) must
/// not observe an unhandled exception — they have already called
/// `goAsync()` / expect the Dart call to complete cleanly regardless.
class BootCompletedWatchdog {
  BootCompletedWatchdog(this._sessionStore, this._notificationService);

  final SessionStore _sessionStore;
  final SessionNotificationService _notificationService;

  static final Logger _log = Logger('infrastructure.platform.boot_completed_watchdog');

  /// Executes the watchdog: queries the DB, fires a resume notification
  /// if an active session is found, no-ops otherwise.
  ///
  /// Idempotent — calling multiple times on the same active session
  /// replaces the notification (notification id is stable, see
  /// [SessionNotificationService.resumeNotificationId]).
  Future<void> run() async {
    try {
      final List<Session> all = await _sessionStore.listAll();
      // SESS-06 DB invariant: at most one row with status='active'.
      final Iterable<Session> actives = all.where((s) => s.status == SessionStatus.active);
      if (actives.isEmpty) {
        _log.fine('No active session at watchdog wake-up; no-op.');
        return;
      }
      final Session session = actives.first;
      await _notificationService.showResumeNotification(session.id, session.displayName);
      _log.info('Resume notification scheduled for session ${session.id.value} "${session.displayName}"');
    } on Object catch (e, st) {
      // Deliberately swallow — native side must not see an unhandled
      // exception. The watchdog runs in a minimal engine (Android) or
      // an AppDelegate callback (iOS); a propagated throw can bring the
      // whole mini-engine down without producing a useful user signal.
      _log.warning('Watchdog run failed (swallowed, must not crash native side): $e', e, st);
    }
  }
}

/// Top-level entry point invoked by the native platform glue via
/// FlutterEngine warmup + MethodChannel on 'runWatchdog'.
///
/// Marked `@pragma('vm:entry-point')` so tree-shaking keeps it even in
/// obfuscated release builds (the native side looks it up by name).
///
/// Implementation is deferred to Task 2 — here we ship only the
/// [BootCompletedWatchdog] class and a stub entry point. Task 2 fills in
/// the DB + notification wiring that runs outside the Riverpod graph.
@pragma('vm:entry-point')
Future<void> runBootWatchdogEntryPoint() async {
  // Intentional stub — Task 2 wires FlutterEngine + MethodChannel + DB
  // + notification service here. Throwing is safe: the Kotlin side uses
  // goAsync() + pendingResult.finish() regardless of the Dart-side
  // result. See Task 2 for the fully-wired body.
  throw UnimplementedError('runBootWatchdogEntryPoint: wired in Plan 05-05 Task 2');
}
