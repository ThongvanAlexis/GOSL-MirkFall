// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Phase 06 Adversarial Test #1 — permanent regression guard for the
/// boot-watchdog MethodChannel literal `'app.gosl.mirkfall/boot_watchdog'`.
///
/// No compiler enforces cross-language string consistency for this channel;
/// a dev who renames it in one place can silently break the boot /
/// significant-change wake path without CI or runtime failure (the
/// native side no-ops on unknown channel names).
///
/// **File map scope (Plan 06-03 Agent #4 verification, verbatim):**
///
/// The Swift literal in `ios/Runner/AppDelegate.swift` was stripped when
/// the CI iOS runner moved to macos-26 / Xcode 26 — the scene-based
/// `FlutterImplicitEngineDelegate` wiring no longer compiles against the
/// Xcode 26 Flutter framework. Restoring the iOS MethodChannel is
/// tracked as Phase 15 polish (see `AppDelegate.swift` docstring + Phase
/// 05 STATE.md `FlutterImplicitEngineDelegate stripped post Xcode 26`).
///
/// Until Phase 15 lands the rewire, this test scans ONLY the two Dart
/// source-of-truth files and the Kotlin receiver — the iOS side is
/// intentionally absent; when the rewire lands, a future plan will add
/// the Swift entry back into `sourcePaths` below.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MethodChannel triple-source drift regression guard (Phase 06 Test #1)', () {
    const String channelLiteral = 'app.gosl.mirkfall/boot_watchdog';

    // Source-of-truth files. The Swift AppDelegate entry is deliberately
    // omitted (Phase 15 FlutterImplicitEngineDelegate rewire — see
    // docstring above). When the iOS MethodChannel is re-wired, add:
    //   'Swift (AppDelegate)': 'ios/Runner/AppDelegate.swift',
    final Map<String, String> sourcePaths = <String, String>{
      'Dart (boot_completed_watchdog)': 'lib/infrastructure/platform/boot_completed_watchdog.dart',
      'Dart (ios_significant_change_watchdog)': 'lib/infrastructure/platform/ios_significant_change_watchdog.dart',
      'Kotlin (BootCompletedReceiver)': 'android/app/src/main/kotlin/app/gosl/mirkfall/BootCompletedReceiver.kt',
    };

    test('all source files exist and contain the channel literal verbatim', () {
      // Inertness guard: file-existence check BEFORE content check. Without
      // this, a renamed source path would let `readAsStringSync` throw and
      // the test would fail in an opaque way — or worse, if the contains
      // check were mis-written, the test would silently report "no drift"
      // against an empty/missing file. This intermediate expect forces any
      // path move to surface LOUDLY with the missing path named.
      for (final MapEntry<String, String> entry in sourcePaths.entries) {
        expect(File(entry.value).existsSync(), isTrue, reason: '${entry.key} path moved or deleted — test would be silently inert. Path: ${entry.value}');
      }

      // Now the actual cross-language consistency assertion.
      final List<String> missing = <String>[];
      for (final MapEntry<String, String> entry in sourcePaths.entries) {
        final String contents = File(entry.value).readAsStringSync();
        if (!contents.contains(channelLiteral)) {
          missing.add('${entry.key} (${entry.value}) does not contain "$channelLiteral"');
        }
      }
      expect(missing, isEmpty, reason: 'MethodChannel name drifted across language sources:\n${missing.join('\n')}');
    });
  });
}
