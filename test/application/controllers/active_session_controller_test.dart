// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

/// Wave-0 stub — covers SESS-04 / SESS-05 / GPS-02 / GPS-05.
///
/// ActiveSessionController orchestrates start/stop, location stream
/// consumption, fix filtering (accuracy reject, stationary dedup), and
/// DB writes. Landing plan: 05-02 (GPS wiring) + 05-04 (end-to-end UI).
void main() {
  test(
    'placeholder',
    () {},
    skip:
        'stub — ActiveSessionController lands in Plan 05-02 (GPS-02) '
        'and Plan 05-04 (SESS-05 end-to-end UI)',
  );
}
