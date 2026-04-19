# lib/infrastructure/platform/

Native-platform detection + OEM classification helpers.

## Contents

- `oem_detector.dart` — runtime detection of battery-killer OEM
  families (Xiaomi, Samsung, Huawei, OnePlus, OPPO) via
  `device_info_plus`. Returns a sealed `OemFamily` so the Phase 05-04
  guidance-screen controller can pattern-match over every variant.

## Imports

Allowed:
- `dart:io` (for `Platform.isAndroid` / `Platform.isIOS` sentinels).
- `package:device_info_plus/` — audited in DEPENDENCIES.md
  (BSD-3-Clause, no telemetry, no HTTP imports).

Forbidden:
- UI / presentation packages.
- Any package that calls out to a network or analytics endpoint.
