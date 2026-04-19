// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:device_info_plus/device_info_plus.dart';
import 'package:mirkfall/infrastructure/platform/oem_detector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'oem_detector_provider.g.dart';

/// Production [OemDetector] — wraps a fresh [`DeviceInfoPlugin`]. The
/// plugin is a stateless handle; re-constructing is ~free but
/// `keepAlive: true` keeps the detection result path consistent across
/// consumers (guidance screen + debug menu).
@Riverpod(keepAlive: true)
OemDetector oemDetector(Ref ref) {
  return OemDetector(DeviceInfoPlugin());
}
