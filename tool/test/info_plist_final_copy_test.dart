// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Covers QUAL-04 — no TODO markers left in `ios/Runner/Info.plist` for the
/// GPS-related usage-description keys, and verbatim-enough final copy per
/// 05-CONTEXT.md §Permission + Store copy : FINAL en Phase 05.
///
/// Uses simple regex parsing rather than a full plist dependency — the
/// keys in `Info.plist` are flat `<key>X</key><string>Y</string>` pairs
/// on consecutive lines, same layout as the Phase 02 review-gate tests
/// that scan the same file.
void main() {
  final String infoPlistFilename = p.join(Directory.current.path, 'ios', 'Runner', 'Info.plist');

  late String contents;

  setUpAll(() {
    final file = File(infoPlistFilename);
    if (!file.existsSync()) {
      fail('Expected $infoPlistFilename to exist (repo layout changed?)');
    }
    contents = file.readAsStringSync();
  });

  test('NSLocationWhenInUseUsageDescription has no TODO marker', () {
    final String value = _extractStringForKey('NSLocationWhenInUseUsageDescription', contents);
    expect(value, isNot(contains('TODO')), reason: 'Phase 05 QUAL-04: final store-grade copy required');
  });

  test('NSLocationAlwaysAndWhenInUseUsageDescription has no TODO marker', () {
    final String value = _extractStringForKey('NSLocationAlwaysAndWhenInUseUsageDescription', contents);
    expect(value, isNot(contains('TODO')));
  });

  test('NSLocationWhenInUseUsageDescription contains the "révéler le brouillard" copy signature', () {
    final String value = _extractStringForKey('NSLocationWhenInUseUsageDescription', contents);
    expect(value, contains('révéler le brouillard'));
  });

  test('NSLocationAlwaysAndWhenInUseUsageDescription contains the "arrière-plan" copy signature', () {
    final String value = _extractStringForKey('NSLocationAlwaysAndWhenInUseUsageDescription', contents);
    expect(value, contains('arrière-plan'));
  });

  test('UIBackgroundModes array contains "location"', () {
    // Regex locates the <key>UIBackgroundModes</key> marker then captures the
    // immediately-following <array>...</array> block. Non-greedy to stop at
    // the first </array>.
    final RegExp bgModesPattern = RegExp(r'<key>UIBackgroundModes</key>\s*<array>\s*(.*?)\s*</array>', dotAll: true);
    final Match? match = bgModesPattern.firstMatch(contents);
    expect(match, isNotNull, reason: 'UIBackgroundModes array missing from Info.plist');
    final String arrayBody = match!.group(1)!;
    expect(arrayBody, contains('<string>location</string>'));
  });
}

/// Extracts the `<string>...</string>` value immediately following the
/// given `<key>...</key>` tag. Case-sensitive; whitespace-tolerant.
String _extractStringForKey(String key, String plist) {
  final RegExp pattern = RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>(.*?)</string>', dotAll: true);
  final Match? match = pattern.firstMatch(plist);
  if (match == null) {
    fail('Key $key not found in Info.plist');
  }
  return match.group(1)!;
}
