// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:test/test.dart';

/// Wave-0 stub — covers QUAL-04 (no TODO markers left in Info.plist
/// GPS-related keys after Phase 05).
///
/// Statically scans `ios/Runner/Info.plist` for `NSLocationWhenInUseUsageDescription`
/// + `NSLocationAlwaysAndWhenInUseUsageDescription` and asserts the string
/// values do not contain "TODO". Lands in Plan 05-06.
void main() {
  test('placeholder', () {}, skip: 'stub — Info.plist final-copy assertion lands in Plan 05-06 (QUAL-04)');
}
