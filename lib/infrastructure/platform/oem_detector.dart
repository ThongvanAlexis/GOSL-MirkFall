// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Recognised OEM families that are documented battery-killers on
/// [dontkillmyapp.com](https://dontkillmyapp.com/).
///
/// `sealed` so the Phase 05-04 guidance-screen controller can `switch` over
/// every variant exhaustively (CLAUDE.md §is-checks: prefer sealed + pattern
/// match over `is TypeA / is TypeB` chains).
sealed class OemFamily {
  const OemFamily();
}

/// Xiaomi / Redmi / POCO — MIUI battery-saver is the most aggressive on the market.
final class XiaomiFamily extends OemFamily {
  const XiaomiFamily();
}

/// Samsung — "Adaptive battery" still kills FG services on some models.
final class SamsungFamily extends OemFamily {
  const SamsungFamily();
}

/// Huawei / Honor (EMUI + Magic UI). Separate from Xiaomi despite both
/// reporting as Chinese OEMs — the required user steps differ.
final class HuaweiFamily extends OemFamily {
  const HuaweiFamily();
}

/// OnePlus — "App startup manager" can kill any background process.
final class OnePlusFamily extends OemFamily {
  const OnePlusFamily();
}

/// OPPO / Realme — ColorOS shares the OPPO battery-manager lineage.
final class OppoFamily extends OemFamily {
  const OppoFamily();
}

/// Android device without a known-aggressive battery manager (Pixel, stock
/// AOSP, etc.). Guidance screen is skipped.
final class OtherOem extends OemFamily {
  const OtherOem();
}

/// iOS device — background-tracking contract is different; guidance is
/// not shown.
final class IosDevice extends OemFamily {
  const IosDevice();
}

/// Runtime OEM detector.
///
/// Takes a [`DeviceInfoPlugin`] via constructor for test injection
/// (CLAUDE.md §Dependency Injection). Tests substitute a fake plugin that
/// returns a controlled [`AndroidDeviceInfo`] per fixture row.
class OemDetector {
  OemDetector(this._plugin);

  final DeviceInfoPlugin _plugin;

  /// iOS platform sentinel — overridable in tests via [isIosOverride]
  /// (default `null` = use `Platform.isIOS`). Same seam pattern as Phase 03
  /// IdGenerator injection.
  Future<OemFamily> detect({bool? isIosOverride, bool? isAndroidOverride}) async {
    final bool iosNow = isIosOverride ?? Platform.isIOS;
    final bool androidNow = isAndroidOverride ?? Platform.isAndroid;

    if (iosNow) return const IosDevice();
    if (!androidNow) return const OtherOem();

    final info = await _plugin.androidInfo;
    // Lowercase match on manufacturer + brand for belt-and-suspenders —
    // some devices report the brand (POCO) while others report the
    // parent manufacturer (Xiaomi). Matching either catches re-brands.
    final String needle = '${info.manufacturer} ${info.brand}'.toLowerCase();
    if (RegExp(r'xiaomi|redmi|poco').hasMatch(needle)) return const XiaomiFamily();
    if (needle.contains('samsung')) return const SamsungFamily();
    if (RegExp(r'huawei|honor').hasMatch(needle)) return const HuaweiFamily();
    if (needle.contains('oneplus')) return const OnePlusFamily();
    if (RegExp(r'oppo|realme').hasMatch(needle)) return const OppoFamily();
    return const OtherOem();
  }
}
