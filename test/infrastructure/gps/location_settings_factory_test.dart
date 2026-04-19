// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:test/test.dart';

/// Wave-0 stub — covers GPS-05 (platform-specific `LocationSettings`).
///
/// Pattern 1 seam: factory returns `AndroidSettings` with
/// `foregroundNotificationConfig` on Android, `AppleSettings` with
/// `allowBackgroundLocationUpdates` on iOS. Plan 05-02 implements.
void main() {
  test(
    'placeholder',
    () {},
    skip: 'stub — LocationSettingsFactory lands in Plan 05-02 (GPS-05)',
  );
}
