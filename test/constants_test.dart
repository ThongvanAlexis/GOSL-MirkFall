// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';

/// Guards the FOUND-07 requirement: the 5 canonical Phase 01 constants exist
/// in `lib/config/constants.dart` with the expected values and types.
void main() {
  test('kAppName is the MirkFall display name', () {
    expect(kAppName, equals('MirkFall'));
  });

  test('kBundleId matches Android + iOS bundle identifier', () {
    expect(kBundleId, equals('app.gosl.mirkfall'));
  });

  test('kMaxLogsDirBytes caps logs directory at 10 MB', () {
    expect(kMaxLogsDirBytes, equals(10 * 1024 * 1024));
  });

  test('kAboutTapsToTriggerDebugMenu is 7', () {
    expect(kAboutTapsToTriggerDebugMenu, equals(7));
  });

  test('kAboutTapWindowMilliseconds is 3000', () {
    expect(kAboutTapWindowMilliseconds, equals(3000));
  });
}
