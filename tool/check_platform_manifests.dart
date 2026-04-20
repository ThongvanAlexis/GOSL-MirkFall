// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

/// Platform-manifest gate for the Phase 05 GPS contract + Phase 07 download pipeline.
///
/// `android/app/src/main/AndroidManifest.xml` MUST contain (Phase 05
/// GPS-01..08 + auto-resume per Plan 05-02 + 05-06, extended Phase 07
/// Plan 07-01 with INTERNET for the per-country PMTiles download flow):
///
///   - android.permission.ACCESS_FINE_LOCATION
///   - android.permission.ACCESS_COARSE_LOCATION
///   - android.permission.ACCESS_BACKGROUND_LOCATION
///   - android.permission.FOREGROUND_SERVICE
///   - android.permission.FOREGROUND_SERVICE_LOCATION
///   - android.permission.WAKE_LOCK
///   - android.permission.POST_NOTIFICATIONS
///   - android.permission.RECEIVE_BOOT_COMPLETED
///   - android.permission.INTERNET (Phase 07 — HTTP downloads for
///     per-country PMTiles bundles; without it, the download controller
///     throws SecurityException on the first GET)
///   - `<receiver android:name=".BootCompletedReceiver">` with the
///     BOOT_COMPLETED intent-filter action.
///
/// `ios/Runner/Info.plist` MUST contain (Phase 05 QUAL-04):
///
///   - NSLocationWhenInUseUsageDescription (non-empty, no TODO placeholder)
///   - NSLocationAlwaysAndWhenInUseUsageDescription (non-empty, no TODO)
///   - `UIBackgroundModes` array containing `<string>location</string>`
///
/// Pure-Dart regex scan — no `package:xml` / `package:plist_parser`
/// dev_dependency added (RESEARCH recommendation: minimise new deps for
/// a simple family-consistent gate script).
///
/// CLI contract (Phase 01 convention, same as `tool/check_domain_purity.dart`):
///   - exit 0 = clean
///   - exit 1 = policy violation (missing entry, TODO placeholder, etc.)
///   - exit 2 = misconfiguration (file missing, unreadable)
const String _androidManifestPath = 'android/app/src/main/AndroidManifest.xml';
const String _infoPlistPath = 'ios/Runner/Info.plist';

const List<String> _requiredAndroidPermissions = <String>[
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_LOCATION',
  'android.permission.WAKE_LOCK',
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.RECEIVE_BOOT_COMPLETED',
  'android.permission.INTERNET',
];

const List<String> _requiredInfoPlistKeys = <String>['NSLocationWhenInUseUsageDescription', 'NSLocationAlwaysAndWhenInUseUsageDescription'];

/// Runs the scan against [androidManifestPath] + [infoPlistPath]
/// (defaults to project-root locations).
///
/// Public so unit tests drive the scanner against synthetic fixture
/// files built with `Directory.systemTemp.createTemp`. Same shape as
/// `tool/check_domain_purity.dart`'s `runCheck` for family consistency.
Future<int> runCheck({String? androidManifestPath, String? infoPlistPath}) async {
  final String resolvedAndroid = androidManifestPath ?? _androidManifestPath;
  final String resolvedIos = infoPlistPath ?? _infoPlistPath;

  // Misconfiguration — exit 2 (Phase 01 convention).
  if (!File(resolvedAndroid).existsSync()) {
    stderr.writeln('check_platform_manifests: AndroidManifest.xml not found at $resolvedAndroid');
    return 2;
  }
  if (!File(resolvedIos).existsSync()) {
    stderr.writeln('check_platform_manifests: Info.plist not found at $resolvedIos');
    return 2;
  }

  final List<String> violations = <String>[];

  // AndroidManifest — per-permission scan.
  final String androidContents = File(resolvedAndroid).readAsStringSync();
  for (final String perm in _requiredAndroidPermissions) {
    final RegExp r = RegExp('<uses-permission\\s+android:name="${RegExp.escape(perm)}"');
    if (!r.hasMatch(androidContents)) {
      violations.add('AndroidManifest.xml missing required uses-permission: $perm');
    }
  }
  // BootCompletedReceiver declaration.
  if (!RegExp(r'<receiver[^>]*android:name="\.BootCompletedReceiver"').hasMatch(androidContents)) {
    violations.add('AndroidManifest.xml missing <receiver android:name=".BootCompletedReceiver"> declaration');
  }
  // BOOT_COMPLETED intent-filter action.
  if (!RegExp(r'<action\s+android:name="android\.intent\.action\.BOOT_COMPLETED"').hasMatch(androidContents)) {
    violations.add('AndroidManifest.xml BootCompletedReceiver missing BOOT_COMPLETED intent-filter action');
  }

  // Info.plist — required string keys with non-empty + non-TODO values.
  final String infoPlistContents = File(resolvedIos).readAsStringSync();
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

  if (violations.isEmpty) {
    stdout.writeln('check_platform_manifests: OK (Android + iOS manifests contain all required Phase 05 + Phase 07 entries)');
    return 0;
  }

  stderr.writeln('check_platform_manifests: ${violations.length} violation(s):');
  for (final String v in violations) {
    stderr.writeln('  - $v');
  }
  stderr.writeln();
  stderr.writeln('Rule: Phase 05 GPS contract + Phase 07 download pipeline require the listed manifest entries on both platforms.');
  stderr.writeln('Restore the missing entries; see lib/infrastructure/gps/ + Phase 05 SUMMARY + Phase 07 plan 07-01 SUMMARY for context.');
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
