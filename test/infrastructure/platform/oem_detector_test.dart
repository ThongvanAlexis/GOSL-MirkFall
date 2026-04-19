// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:test/test.dart';

/// Wave-0 stub — covers GPS-08 (OEM brand matching).
///
/// Matches Xiaomi / Samsung / Huawei / OnePlus / OPPO / Realme via
/// `device_info_plus`'s Android `manufacturer` + `brand` fields (lowercased
/// substring match). Plan 05-02 implements the OemDetector + sealed
/// OemFamily hierarchy.
void main() {
  test('placeholder', () {}, skip: 'stub — OemDetector lands in Plan 05-02 (GPS-08)');
}
