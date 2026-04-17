// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Phase 02 will replace this with FileLogger bootstrap.
      // Phase 01 uses a minimal console handler gated on kDebugMode so
      // production builds stay silent.
      Logger.root.level = Level.INFO;
      Logger.root.onRecord.listen((LogRecord rec) {
        if (kDebugMode) {
          // Workaround: `avoid_print` is `error` in analysis_options.yaml, so
          // we use `debugPrint` here. Phase 02 replaces this listener with
          // FileLogger writing JSONL.
          debugPrint('[${rec.level.name}] ${rec.loggerName}: ${rec.message}');
        }
      });

      final log = Logger('main');

      FlutterError.onError = (FlutterErrorDetails details) {
        log.shout('FlutterError', details.exception, details.stack);
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      runApp(const ProviderScope(child: MirkFallApp()));
    },
    (Object error, StackTrace stack) {
      Logger('main').shout('uncaughtZoneError', error, stack);
    },
  );
}
