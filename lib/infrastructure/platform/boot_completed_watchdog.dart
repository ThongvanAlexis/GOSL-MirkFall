// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/db/app_database_factory.dart';
import 'package:mirkfall/infrastructure/logging/file_logger.dart';
import 'package:mirkfall/infrastructure/notifications/session_notification_service.dart';
import 'package:mirkfall/infrastructure/stores/drift_session_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

/// MethodChannel shared with the native platform glue (Android
/// `BootCompletedReceiver.kt`, iOS `AppDelegate.swift`). Do NOT change
/// without updating both native sides.
const MethodChannel _bootWatchdogChannel = MethodChannel('app.gosl.mirkfall/boot_watchdog');

/// Top-level entry point invoked by the native platform glue via
/// FlutterEngine warmup + MethodChannel on 'runWatchdog'.
///
/// Marked `@pragma('vm:entry-point')` so tree-shaking keeps it even in
/// obfuscated release builds (the native side looks it up by name).
///
/// The Dart runtime spun up by the Android `FlutterEngine` (inside the
/// BroadcastReceiver) does NOT share any state with the main isolate —
/// the Riverpod graph, logger, DB connection all have to be reconstructed
/// here. That is a feature: it means the watchdog path can run even when
/// the main app isolate was killed at reboot.
///
/// Shape: we register a MethodCallHandler that responds to `runWatchdog`,
/// does the DB lookup + notification work in [_runWatchdogOnce], and
/// returns `null` (success). The Kotlin side's `MethodChannel.Result`
/// callback then calls `engine.destroy()` + `pendingResult.finish()`.
@pragma('vm:entry-point')
Future<void> runBootWatchdogEntryPoint() async {
  // The engine spawned by the native receiver does not call
  // `ensureInitialized` for us — the Flutter framework runs a minimal
  // binding-less loop. Initialise it explicitly so plugin channels
  // (path_provider, shared_preferences, flutter_local_notifications) can
  // register their handlers.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FileLogger.bootstrap();
  } on Object catch (_) {
    // Logger bootstrap can fail on a device with no writable docs dir
    // (edge case). The watchdog must still reach the DB check, so the
    // failure is swallowed silently — there is no sink to emit onto
    // until the logger is up anyway. Any subsequent `_log.warning`
    // calls in [_runWatchdogOnce] degrade to print() via
    // `dart:developer`, which is safe in this minimal engine context.
  }

  _bootWatchdogChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method != 'runWatchdog') {
      throw MissingPluginException('runBootWatchdogEntryPoint: unknown method ${call.method}');
    }
    await _runWatchdogOnce();
    return null;
  });
}

/// One-shot watchdog execution: opens the DB with the same factory the
/// UI uses (schema singleton enforced), constructs the store + service,
/// runs [BootCompletedWatchdog.run], then closes the DB so the main
/// isolate can open it cleanly when the user taps the resume
/// notification.
Future<void> _runWatchdogOnce() async {
  final Logger log = Logger('infrastructure.platform.runBootWatchdogEntryPoint');

  AppDatabase? db;
  try {
    // Resolve the same DB path the UI uses — never open a separate
    // isolate DB or a custom filename, that would fork the schema
    // singleton and invite migration drift.
    final Directory supportDir = await getApplicationSupportDirectory();
    final String dbFilename = p.join(supportDir.path, kDbFilename);
    final Directory backupDir = Directory(p.join(supportDir.path, kDbBackupDirName));
    db = buildAppDatabase(dbFilename: dbFilename, backupDir: backupDir, maxBackups: kMaxDbBackups);

    final SessionStore sessionStore = DriftSessionStore(db);

    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
      // Tap handling is wired in the MAIN isolate's main.dart — the
      // mini-engine spawned by the receiver will no longer exist when
      // the user eventually taps the notification. The main isolate's
      // handler does the routing.
    );
    final SessionNotificationService notificationService = SessionNotificationService(FlutterLocalNotificationsAdapter(plugin));

    final BootCompletedWatchdog watchdog = BootCompletedWatchdog(sessionStore, notificationService);
    await watchdog.run();
  } on Object catch (e, st) {
    // Every exception is swallowed — the native side must complete
    // cleanly regardless of what the watchdog did or did not find.
    log.warning('runBootWatchdogEntryPoint execution failed (swallowed): $e', e, st);
  } finally {
    await db?.close();
  }
}
