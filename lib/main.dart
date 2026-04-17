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

/// Application entry point.
///
/// Bootstraps the file-sink logger, wires three error channels to a single
/// shared handler (Flutter framework errors, platform/engine-level async
/// errors, and zone-escaped errors), then runs the app inside a guarded zone.
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
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
      runApp(const ProviderScope(child: MirkFallApp()));
    },
    (Object error, StackTrace stack) {
      Logger('main').shout('uncaughtZoneError', error, stack);
    },
  );
}
