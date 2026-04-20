// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Phase 06 Adversarial Test #5 — permanent regression guard for the
/// Android boot-receiver contract: the AndroidManifest `<receiver>`
/// declaration + Kotlin receiver class path + MethodChannel literal +
/// Dart-side constant must stay aligned at all times.
///
/// Android-scoped complement to Test #1 (`method_channel_sync_test.dart`).
/// Test #1 scans the literal across Dart + Kotlin in a cross-language
/// consistency check. This test locks the 3-way Android contract:
///
///   1. AndroidManifest declares `<receiver android:name=".BootCompletedReceiver">`
///      under the `app.gosl.mirkfall` package (resolves via applicationId).
///   2. Kotlin `BootCompletedReceiver.kt` exists in `app/gosl/mirkfall/`
///      with `package app.gosl.mirkfall` + `class BootCompletedReceiver`.
///   3. Kotlin `CHANNEL` constant extracted from the file matches the
///      Dart `MethodChannel` constant extracted from
///      `boot_completed_watchdog.dart` — BYTE-FOR-BYTE.
///
/// Why split from Test #1? Test #1 is a cheap "contains" scan for
/// anyone looking at the cross-platform cohesion. This test extracts
/// the constants from both files and compares the EXTRACTED values —
/// so if a dev ever introduced a second `MethodChannel(...)` on a
/// different name into one file, Test #1 would still pass (the
/// original literal still appears) but Test #5 would fail because
/// the extracted constant has a different value.
///
/// **Inertness guard (Phase 04 idiom):**
///
/// All 3 source files (manifest + Kotlin + Dart) must exist on disk
/// before the content extraction runs; a path move must surface loudly.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _androidManifestPath = 'android/app/src/main/AndroidManifest.xml';
const String _kotlinReceiverPath = 'android/app/src/main/kotlin/app/gosl/mirkfall/BootCompletedReceiver.kt';
const String _dartChannelPath = 'lib/infrastructure/platform/boot_completed_watchdog.dart';

const String _expectedChannelLiteral = 'app.gosl.mirkfall/boot_watchdog';

void main() {
  group('Android BootCompletedReceiver contract test (Phase 06 Test #5)', () {
    test('AndroidManifest declares receiver + Kotlin class + channel literal matches Dart constant', () {
      // Inertness guard: all 3 source files must exist BEFORE content
      // extraction. Without this, a path move would throw at readSync
      // rather than surface the missing file with a named reason.
      expect(
        File(_androidManifestPath).existsSync() && File(_kotlinReceiverPath).existsSync() && File(_dartChannelPath).existsSync(),
        isTrue,
        reason:
            'manifest or Kotlin receiver or Dart channel constant path moved — test silently inert. '
            'manifest=$_androidManifestPath kotlin=$_kotlinReceiverPath dart=$_dartChannelPath',
      );

      final String androidContents = File(_androidManifestPath).readAsStringSync();
      final String kotlinContents = File(_kotlinReceiverPath).readAsStringSync();
      final String dartContents = File(_dartChannelPath).readAsStringSync();

      // 1. AndroidManifest must declare the BootCompletedReceiver with
      //    the `.BootCompletedReceiver` relative class path (resolves
      //    against `app.gosl.mirkfall` via applicationId) + BOOT_COMPLETED
      //    intent-filter action.
      expect(
        RegExp(r'<receiver[^>]*android:name="\.BootCompletedReceiver"').hasMatch(androidContents),
        isTrue,
        reason: 'AndroidManifest.xml missing <receiver android:name=".BootCompletedReceiver"> declaration',
      );
      expect(
        RegExp(r'<action\s+android:name="android\.intent\.action\.BOOT_COMPLETED"').hasMatch(androidContents),
        isTrue,
        reason: 'AndroidManifest.xml BootCompletedReceiver missing BOOT_COMPLETED intent-filter action',
      );

      // 2. Kotlin file must declare `package app.gosl.mirkfall` and
      //    `class BootCompletedReceiver` — the applicationId resolution
      //    relies on this matching the manifest relative path.
      expect(
        RegExp(r'^\s*package\s+app\.gosl\.mirkfall\s*$', multiLine: true).hasMatch(kotlinContents),
        isTrue,
        reason: 'Kotlin file $_kotlinReceiverPath missing `package app.gosl.mirkfall` declaration',
      );
      expect(
        RegExp(r'class\s+BootCompletedReceiver\b').hasMatch(kotlinContents),
        isTrue,
        reason: 'Kotlin file $_kotlinReceiverPath missing `class BootCompletedReceiver` declaration',
      );

      // 3. Extract the Kotlin CHANNEL constant value + the Dart
      //    MethodChannel constant value — these must match each other
      //    and match the canonical expected literal.
      final RegExp kotlinChannelRegex = RegExp(r'private const val CHANNEL = "([^"]+)"');
      final RegExpMatch? kotlinMatch = kotlinChannelRegex.firstMatch(kotlinContents);
      expect(kotlinMatch, isNotNull, reason: 'Kotlin file $_kotlinReceiverPath does not declare `private const val CHANNEL = "…"` — regex anchor drifted');
      final String kotlinChannel = kotlinMatch!.group(1)!;

      final RegExp dartChannelRegex = RegExp(r"""MethodChannel\(\s*['"]([^'"]+)['"]\s*\)""");
      final RegExpMatch? dartMatch = dartChannelRegex.firstMatch(dartContents);
      expect(dartMatch, isNotNull, reason: 'Dart file $_dartChannelPath does not declare `MethodChannel("…")` — regex anchor drifted');
      final String dartChannel = dartMatch!.group(1)!;

      // Three-way consistency: Kotlin extracted == Dart extracted ==
      // expected canonical literal.
      expect(
        kotlinChannel,
        _expectedChannelLiteral,
        reason: 'Kotlin CHANNEL literal drifted from canonical: extracted="$kotlinChannel" expected="$_expectedChannelLiteral"',
      );
      expect(
        dartChannel,
        _expectedChannelLiteral,
        reason: 'Dart MethodChannel literal drifted from canonical: extracted="$dartChannel" expected="$_expectedChannelLiteral"',
      );
      expect(kotlinChannel, dartChannel, reason: 'Kotlin CHANNEL ("$kotlinChannel") and Dart MethodChannel ("$dartChannel") drifted from each other');
    });
  });
}
