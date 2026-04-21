// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import 'app.dart';
import 'application/providers/map_providers.dart';
import 'infrastructure/logging/file_logger.dart';
import 'presentation/router.dart';

/// Application entry point — bootstraps logging, error handling, and UI.
///
/// Invoked by the Flutter engine on Android, iOS, and desktop. Responsibilities:
/// 1. Open `runZonedGuarded` FIRST, before any Flutter binding call.
/// 2. Inside that guarded zone, call [WidgetsFlutterBinding.ensureInitialized]
///    and [runApp] — so both observe the SAME zone and Flutter 3.41+'s
///    `debugCheckZone` assertion in `_runWidget` is satisfied.
/// 3. Bootstrap [FileLogger] (opens today's JSONL file, prunes oldest, sets
///    [Logger.root.level]) + wire error channels, all inside the same zone.
///
/// Zone layout (post-Batch D option (b), finding #P4):
///
///   Root zone
///     runZonedGuarded(() async {
///       WidgetsFlutterBinding.ensureInitialized()  <-- guarded
///       FileLogger.bootstrap()                     <-- guarded
///       FlutterError.onError = ...                 <-- guarded
///       PlatformDispatcher.instance.onError = ...  <-- guarded
///       runApp(ProviderScope(...))                 <-- guarded, same as
///                                                      ensureInitialized
///     }, onUncaught)
///
/// Why option (b) over option (a) (both in root zone):
/// Option (a) — ensureInitialized + runApp in root, runZonedGuarded around
/// logger/handlers only — was attempted in commit `56b164f` but failed the
/// user walk (`flutter run -d windows` still emitted `Zone mismatch` at
/// `runApp` according to the stack trace `main.<anonymous closure>` at
/// `main.dart:71`). Option (b) keeps BOTH calls inside the guarded zone,
/// which is the canonical Flutter pattern for `runZonedGuarded` bootstraps
/// (Flutter docs, `zoned_guarded` recipe) and removes any ambiguity: there
/// is a single zone from binding-init through `runApp` through the whole
/// widget tree's microtask lifetime.
///
/// The uncaught-zone handler covers EVERY async error raised in the guarded
/// zone, including during bootstrap (logger init, binding) AND during the
/// app's async lifetime. `FlutterError.onError` still fans framework errors
/// back to our reporter; `PlatformDispatcher.instance.onError` still catches
/// platform-channel / isolate-promoted errors.
Future<void> main() async {
  // Open the guarded zone FIRST. Everything — binding init, logger bootstrap,
  // error-channel wiring, runApp — runs inside it. This guarantees a single
  // consistent zone across the bootstrap and the app lifetime, which is what
  // Flutter 3.41+'s `debugCheckZone` asserts on in `_runWidget`.
  //
  // Finding #P4 (Batch D option (b)) — Phase 04 Runtime Walk caught a
  // `Zone mismatch` crash at `runApp` when `ensureInitialized` was in the
  // root zone and `runApp` was inside the guarded zone. Commit `56b164f`
  // flipped the shape to put both in the root zone with `runZonedGuarded`
  // wrapping only the logger body, but the walk STILL reported a zone
  // mismatch on re-run. Option (b) — pin BOTH inside the guarded zone —
  // is the canonical Flutter recipe and removes ambiguity.
  await runZonedGuarded<Future<void>>(
    () async {
      // Initialise the Flutter binding IN the guarded zone so it matches
      // the zone `runApp` will be called in below. Phase 01 RESEARCH:349-354
      // flagged the Flutter 3.10+ zone-mismatch pitfall; option (b) resolves
      // it by making both calls share a single guarded zone.
      WidgetsFlutterBinding.ensureInitialized();

      // File-sink logger: opens today's JSONL file, prunes oldest, sets root
      // level from `--dart-define=DEBUG` or the SharedPreferences flag.
      // Phase 01 did a debugPrint listener; Phase 02 replaces it with this.
      await FileLogger.bootstrap();

      final log = Logger('main');

      // Shared error sink — every error channel funnels here so SHOUTs are
      // uniform across Framework / PlatformDispatcher / zone-escape origins.
      void reportError(String source, Object error, StackTrace? stack) {
        log.shout(source, error, stack);
      }

      FlutterError.onError = (FlutterErrorDetails details) {
        reportError('FlutterError', details.exception, details.stack);
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      // Catches async errors thrown outside the framework's error-handling
      // pipeline (plugin callbacks, platform channel errors, Isolate errors
      // promoted to the engine). Phase 01 RESEARCH flagged this as the known-
      // fragile combo with runZonedGuarded; wire it explicitly per Blocker #5.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        reportError('PlatformDispatcherError', error, stack);
        // Return true to indicate the error has been handled and should not
        // be propagated further (we already logged + will surface via ZE
        // channel if it escapes anyway).
        return true;
      };

      log.info('MirkFall starting — logger armed');

      // Phase 05 — wire the `flutter_local_notifications` tap callback so
      // the "tap to resume" notification (Plan 05-05 auto-resume path)
      // deep-links into `/sessions/:id` via the rootNavigatorKey. The
      // plugin fires `onDidReceiveNotificationResponse` OUTSIDE a widget
      // build context, so we navigate imperatively through the key that
      // the router is built with.
      //
      // Initialising the plugin here is idempotent with the separate
      // `SessionNotificationService.initialize()` call (which only creates
      // the Android channel + requests iOS permissions) — they operate on
      // the same singleton but on disjoint surfaces.
      await FlutterLocalNotificationsPlugin().initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );

      // Phase 07-05 — pre-initialise the FirstLaunchBootstrap provider
      // BEFORE runApp so the world basemap is on disk, the orphan
      // staging scan has run, and (on iOS) the backup-exclude flag is
      // set before the first widget frame paints. Parity with Phase 05
      // (synchronous `buildAppDatabase` pre-init) — keeps first-frame
      // UX clean at the cost of a ~1 s startup pause the first time the
      // app ever runs (subsequent launches hit the idempotent fast
      // path).
      //
      // Pattern: a standalone ProviderContainer reads the bootstrap
      // future, waits for completion, then the SAME container is
      // passed to ProviderScope(parent: ...) so `runApp` inherits the
      // already-warm bootstrap provider cache (no re-run).
      final rootContainer = ProviderContainer();
      try {
        await rootContainer.read(firstLaunchBootstrapProvider.future);
      } on Object catch (e, st) {
        // MapAssetMissingException here means the bundled asset is
        // corrupt — catastrophic but not silent. The UI shell will
        // render a fatal banner; we still launch the app so the
        // recovery screen can surface.
        log.shout('firstLaunchBootstrap failed — launching without world map', e, st);
      }

      // Phase 05 wiring note — `ActiveSessionController` is the first
      // productive consumer of `appDatabaseProvider` (Option A lazy
      // resolution per 05-CONTEXT.md). Mount the app in the SAME
      // guarded zone as ensureInitialized above — that is the whole
      // point of option (b). Flutter's `debugCheckZone` now sees
      // binding.rootZone == Zone.current at runApp time.
      runApp(UncontrolledProviderScope(container: rootContainer, child: const MirkFallApp()));
    },
    (Object error, StackTrace stack) {
      // Uncaught-zone handler — covers async errors raised during bootstrap
      // AND during the app's async lifetime (since runApp now runs inside
      // the same zone). Framework errors still flow through
      // FlutterError.onError; async-outside-framework errors still flow
      // through PlatformDispatcher.instance.onError. This handler is the
      // last-resort net.
      Logger('main').shout('uncaughtZoneError', error, stack);
    },
  );
}

/// Phase 05 notification-tap handler.
///
/// Parses the `resume:<sessionId>` payload emitted by
/// [SessionNotificationService.showResumeNotification] and routes to
/// `/sessions/:id`. Reached only on user tap — no silent auto-resume
/// (CONTEXT.md §Auto-resume post-kill: explicit user control).
///
/// Runs OUTSIDE a BuildContext (plugin callback), so navigation goes
/// through [rootNavigatorKey]. The router may not yet be fully mounted
/// when the tap fires on a cold-start launch; in that case we no-op and
/// let the user navigate manually — the resume notification stays in
/// the status bar so they can re-tap once the app is ready.
void _handleNotificationTap(NotificationResponse response) {
  final String? payload = response.payload;
  if (payload == null || !payload.startsWith('resume:')) return;
  final String sessionId = payload.substring('resume:'.length);
  if (sessionId.isEmpty) return;

  final BuildContext? context = rootNavigatorKey.currentContext;
  if (context == null) {
    // Router not mounted yet — cold-start race. The notification is
    // still visible in the status bar; a second tap after the app
    // finishes launching will fire this handler again with the
    // router ready.
    Logger('main').info('Notification tap arrived before router mount; ignoring. payload=$payload');
    return;
  }
  GoRouter.of(context).go('/sessions/$sessionId');
}
