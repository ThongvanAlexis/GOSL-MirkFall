// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Phase 06 Adversarial Test #4 — permanent regression guard for the
/// Phase 05 GPS contract at the platform-manifest layer.
///
/// AndroidManifest.xml + Info.plist encode the OS-level permissions and
/// background modes that Phase 05 depends on. A dev who deletes
/// `ACCESS_BACKGROUND_LOCATION` or removes `<string>location</string>`
/// from `UIBackgroundModes` would silently break background tracking
/// WITHOUT any compile error — the geolocator plugin would fail at
/// runtime only on a real device, long after the change shipped.
///
/// This test enforces the full Phase 05 required-entries list at every
/// `flutter test` invocation + CI run. Pure-Dart regex (no `package:xml`
/// or `package:plist_parser` dep — per RESEARCH recommendation : avoid
/// adding new direct deps for a simple scan).
///
/// **Inertness guard (Phase 04 idiom, two-part):**
///
///   1. `File.existsSync` on both manifests BEFORE any content scan — a
///      path move must surface loudly rather than let a missing file
///      silently degrade the content regex to "no match".
///   2. `RegExp(<uses-permission).allMatches` returns non-empty on the
///      AndroidManifest — if the regex library ever changed semantics
///      or the file structure changed such that the anchor no longer
///      matches, the test would silently pass with 0 violations
///      detected. This second guard catches that.
///
/// Relation to `tool/check_platform_manifests.dart`: that script is the
/// CI-gate version of this test — same Phase 05 contract, enforced at
/// push-time via `.github/workflows/ci.yml` `gates` job. This test is
/// the unit-test complement, picked up by the existing `flutter test`
/// step; both guard the same invariant from different angles.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _androidManifestPath = 'android/app/src/main/AndroidManifest.xml';
const String _infoPlistPath = 'ios/Runner/Info.plist';

/// Phase 05 required AndroidManifest `uses-permission` entries (verbatim
/// from Plan 05-02 Android manifest + Plan 05-06 boot watchdog).
const List<String> _requiredAndroidPermissions = <String>[
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_LOCATION',
  'android.permission.WAKE_LOCK',
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.RECEIVE_BOOT_COMPLETED',
];

/// Phase 05 required Info.plist `<key>` strings (location usage
/// descriptions; UIBackgroundModes handled separately — see test body).
const List<String> _requiredInfoPlistKeys = <String>['NSLocationWhenInUseUsageDescription', 'NSLocationAlwaysAndWhenInUseUsageDescription'];

void main() {
  group('Platform manifest drift regression guard (Phase 06 Test #4)', () {
    test('AndroidManifest.xml + Info.plist contain all required Phase 05 GPS entries', () {
      // Inertness guard part 1 — file existence. Without this, a path
      // rename would throw at `readAsStringSync` below rather than
      // surface the missing path with a readable reason.
      expect(
        File(_androidManifestPath).existsSync() && File(_infoPlistPath).existsSync(),
        isTrue,
        reason: '1 of 2 platform manifests moved — test silently inert. android=$_androidManifestPath ios=$_infoPlistPath',
      );

      final String androidContents = File(_androidManifestPath).readAsStringSync();
      final String infoPlistContents = File(_infoPlistPath).readAsStringSync();

      // Inertness guard part 2 — regex sanity. If the manifest structure
      // ever stopped containing <uses-permission> elements (new Android
      // XML format, etc.), the per-permission regex below would return
      // false for every entry and the test would report "missing all"
      // when the real problem is the anchor regex became stale.
      final List<RegExpMatch> usesPermissionMatches = RegExp(r'<uses-permission').allMatches(androidContents).toList();
      expect(
        usesPermissionMatches.isNotEmpty,
        isTrue,
        reason: 'AndroidManifest.xml parsed but contained zero <uses-permission> elements — test silently inert on regex regression',
      );

      final List<String> violations = <String>[];

      // AndroidManifest — per-permission scan.
      for (final String perm in _requiredAndroidPermissions) {
        final RegExp r = RegExp('<uses-permission\\s+android:name="${RegExp.escape(perm)}"');
        if (!r.hasMatch(androidContents)) {
          violations.add('AndroidManifest.xml missing required uses-permission: $perm');
        }
      }
      // BootCompletedReceiver declaration (anchored by android:name attribute).
      if (!RegExp(r'<receiver[^>]*android:name="\.BootCompletedReceiver"').hasMatch(androidContents)) {
        violations.add('AndroidManifest.xml missing <receiver android:name=".BootCompletedReceiver"> declaration');
      }
      // BOOT_COMPLETED intent-filter action.
      if (!RegExp(r'<action\s+android:name="android\.intent\.action\.BOOT_COMPLETED"').hasMatch(androidContents)) {
        violations.add('AndroidManifest.xml BootCompletedReceiver missing BOOT_COMPLETED intent-filter action');
      }

      // Info.plist — required key + value checks.
      for (final String key in _requiredInfoPlistKeys) {
        final RegExp r = RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>', dotAll: true);
        final RegExpMatch? m = r.firstMatch(infoPlistContents);
        if (m == null) {
          violations.add('Info.plist missing required key: $key');
        } else if ((m.group(1)?.trim().isEmpty) ?? true) {
          violations.add('Info.plist key $key has empty value');
        } else if (m.group(1)!.toUpperCase().contains('TODO')) {
          violations.add('Info.plist key $key still has TODO placeholder: "${m.group(1)}"');
        }
      }
      // UIBackgroundModes must contain <string>location</string>.
      final RegExp bgModesRegex = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>', dotAll: true);
      final RegExpMatch? bgMatch = bgModesRegex.firstMatch(infoPlistContents);
      if (bgMatch == null) {
        violations.add('Info.plist missing UIBackgroundModes array');
      } else if (!bgMatch.group(1)!.contains('<string>location</string>')) {
        violations.add('Info.plist UIBackgroundModes array does not contain <string>location</string>');
      }

      expect(violations, isEmpty, reason: 'Phase 05 platform-manifest contract drift detected:\n  ${violations.join('\n  ')}');
    });
  });
}
