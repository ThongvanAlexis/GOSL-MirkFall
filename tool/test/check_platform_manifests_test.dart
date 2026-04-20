// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../check_platform_manifests.dart' as check_platform_manifests;

/// Paired tool unit test for `tool/check_platform_manifests.dart`.
///
/// Same shape as `tool/test/check_domain_purity_test.dart` (Phase 02
/// convention — paired tool tests live alongside the tool, discovered
/// by the existing `Tool scripts unit tests` CI step at ci.yml:76-77
/// running `dart test tool/test/`).
///
/// Covers all 3 exit codes from the Phase 01 CLI contract:
///   - exit 0 : clean fixture (both files contain all required entries)
///   - exit 1 : policy violation (synthetic fixture missing one
///              required entry class — one case per violation class)
///   - exit 2 : misconfiguration (manifest path doesn't exist)
///
/// Stderr wording is treated as implementation detail per Phase 02
/// convention — tests assert the return code + the specific violation
/// substring, not full stderr transcripts.

/// Synthetic clean AndroidManifest.xml content — every required Phase 05
/// + Phase 07 entry present, minimum structure for the regex anchors.
const String _cleanAndroidManifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:label="Test">
        <receiver android:name=".BootCompletedReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
    </application>
</manifest>
''';

/// Synthetic clean Info.plist content — every required Phase 05 key
/// present with non-empty, non-TODO values; UIBackgroundModes contains
/// location.
const String _cleanInfoPlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Rationale for when-in-use.</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>Rationale for always-in-background.</string>
    <key>UIBackgroundModes</key>
    <array>
        <string>location</string>
    </array>
</dict>
</plist>
''';

void main() {
  group('check_platform_manifests.runCheck', () {
    late Directory tempDir;
    late String androidPath;
    late String iosPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('check_platform_manifests_test_');
      androidPath = p.join(tempDir.path, 'AndroidManifest.xml');
      iosPath = p.join(tempDir.path, 'Info.plist');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns 0 when both manifests contain all required Phase 05 entries', () async {
      await File(androidPath).writeAsString(_cleanAndroidManifest);
      await File(iosPath).writeAsString(_cleanInfoPlist);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: iosPath);
      expect(code, 0);
    });

    test('returns 2 when AndroidManifest path does not exist (misconfiguration)', () async {
      final String missing = p.join(tempDir.path, 'nonexistent.xml');
      await File(iosPath).writeAsString(_cleanInfoPlist);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: missing, infoPlistPath: iosPath);
      expect(code, 2);
    });

    test('returns 2 when Info.plist path does not exist (misconfiguration)', () async {
      await File(androidPath).writeAsString(_cleanAndroidManifest);
      final String missing = p.join(tempDir.path, 'nonexistent.plist');

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: missing);
      expect(code, 2);
    });

    test('returns 1 when AndroidManifest is missing ACCESS_BACKGROUND_LOCATION', () async {
      // Clean manifest minus the ACCESS_BACKGROUND_LOCATION line.
      final String poisoned = _cleanAndroidManifest.replaceFirst('    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>\n', '');
      await File(androidPath).writeAsString(poisoned);
      await File(iosPath).writeAsString(_cleanInfoPlist);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: iosPath);
      expect(code, 1);
    });

    test('returns 1 when AndroidManifest is missing INTERNET '
        '(Phase 07 plan 07-01 — required for the per-country PMTiles download pipeline)', () async {
      // Strip the INTERNET uses-permission line; everything else stays clean.
      final String poisoned = _cleanAndroidManifest.replaceFirst('    <uses-permission android:name="android.permission.INTERNET"/>\n', '');
      await File(androidPath).writeAsString(poisoned);
      await File(iosPath).writeAsString(_cleanInfoPlist);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: iosPath);
      expect(code, 1);
    });

    test('returns 1 when AndroidManifest is missing the BootCompletedReceiver declaration', () async {
      // Strip the whole <receiver>…</receiver> block.
      final String poisoned = _cleanAndroidManifest.replaceFirst(RegExp(r'<receiver[\s\S]*?</receiver>'), '');
      await File(androidPath).writeAsString(poisoned);
      await File(iosPath).writeAsString(_cleanInfoPlist);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: iosPath);
      expect(code, 1);
    });

    test('returns 1 when Info.plist is missing NSLocationAlwaysAndWhenInUseUsageDescription', () async {
      final String poisoned = _cleanInfoPlist.replaceFirst(
        '    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>\n    <string>Rationale for always-in-background.</string>\n',
        '',
      );
      await File(androidPath).writeAsString(_cleanAndroidManifest);
      await File(iosPath).writeAsString(poisoned);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: iosPath);
      expect(code, 1);
    });

    test('returns 1 when Info.plist value still contains TODO placeholder', () async {
      final String poisoned = _cleanInfoPlist.replaceFirst('<string>Rationale for when-in-use.</string>', '<string>TODO: ship-time copy</string>');
      await File(androidPath).writeAsString(_cleanAndroidManifest);
      await File(iosPath).writeAsString(poisoned);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: iosPath);
      expect(code, 1);
    });

    test('returns 1 when Info.plist UIBackgroundModes does not contain <string>location</string>', () async {
      final String poisoned = _cleanInfoPlist.replaceFirst('<string>location</string>', '<string>fetch</string>');
      await File(androidPath).writeAsString(_cleanAndroidManifest);
      await File(iosPath).writeAsString(poisoned);

      final int code = await check_platform_manifests.runCheck(androidManifestPath: androidPath, infoPlistPath: iosPath);
      expect(code, 1);
    });
  });
}
