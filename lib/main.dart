// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app.dart';
import 'infrastructure/logging/file_logger.dart';

/// Application entry point — bootstraps logging, error handling, and UI.
///
/// Invoked by the Flutter engine on Android, iOS, and desktop. Responsibilities:
/// 1. Initialise the Flutter binding in the root zone (before runZonedGuarded)
///    to avoid the Flutter 3.10+ zone-mismatch pitfall.
/// 2. Bootstrap [FileLogger] inside a guarded zone (opens today's JSONL file,
///    prunes oldest, sets [Logger.root.level]) + wire error channels.
/// 3. Mount the app via [runApp] in the SAME root zone as the binding,
///    OUTSIDE `runZonedGuarded`, to satisfy Flutter 3.41+'s
///    `debugCheckZone` assertion.
///
/// Zone layout (post-Batch D, finding #P4):
///
///   Root zone
///     WidgetsFlutterBinding.ensureInitialized()  <-- root
///     runZonedGuarded(() async {
///       FileLogger.bootstrap()                   <-- guarded
///       FlutterError.onError = ...               <-- guarded handlers are
///       PlatformDispatcher.instance.onError = …     INSTALLED from the
///                                                   guarded zone but the
///                                                   framework dispatches
///                                                   them back in its own
///                                                   zone, so this is fine.
///     }, onUncaught)
///     runApp(ProviderScope(...))                 <-- root, matches binding
Future<void> main() async {
  // Initialise the Flutter binding in the ROOT zone, before runZonedGuarded.
  // Rationale (Phase 01 RESEARCH:349-354,987-989 — Flutter 3.10+ zone-mismatch
  // pitfall): ensureInitialized() must run in the same zone as the later
  // runApp() call, otherwise Flutter 3.41+ asserts `Zone mismatch` in
  // `_runWidget`'s `debugCheckZone` (binding#debugCheckZone).
  WidgetsFlutterBinding.ensureInitialized();

  // Finding #P4 (Batch D) — Phase 04 Runtime Walk caught a `Zone mismatch`
  // crash at `runApp`. The original shape was:
  //   ensureInitialized (root)
  //   runZonedGuarded(() async { … runApp(…); }, onUncaught)
  // Flutter observed `runApp` executing inside the guarded zone while
  // `ensureInitialized` had been called in the root zone, triggering the
  // `debugZoneErrorsAreFatal`-style assertion on Windows 3.41.7.
  //
  // Fix: keep `runApp` in the root zone (matching the binding) and scope
  // `runZonedGuarded` ONLY around the async bootstrap body (logger init +
  // error-channel wiring). The uncaught-error handler still covers any
  // async error raised during bootstrap; the framework installs its own
  // error boundary around `runApp` via `FlutterError.onError`, which we
  // DO assign from the guarded zone — but the callback runs via the
  // framework's own microtask scheduler, so the zone of assignment does
  // not matter.
  await runZonedGuarded<Future<void>>(
    () async {
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
    },
    (Object error, StackTrace stack) {
      // Uncaught-zone handler — covers async errors raised DURING bootstrap
      // only (logger init, error-channel wiring). Once `runApp` runs in the
      // root zone below, framework errors go through FlutterError.onError
      // and async errors outside the framework go through
      // PlatformDispatcher.instance.onError.
      Logger('main').shout('uncaughtZoneError', error, stack);
    },
  );

  // Mount the app in the ROOT zone — matches the zone in which
  // `WidgetsFlutterBinding.ensureInitialized()` ran, silencing Flutter's
  // `debugCheckZone` assertion. The framework's own error handling covers
  // widget-build errors from here on.
  runApp(const ProviderScope(child: MirkFallApp()));
}
