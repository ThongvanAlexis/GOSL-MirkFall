// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/platform/oem_detector.dart';

/// Covers GPS-08 — OEM-family detection via `device_info_plus`.
///
/// Uses the `DeviceInfoPlugin` subclass-seam: `_FakeDeviceInfoPlugin`
/// overrides the `androidInfo` getter so every test controls `manufacturer`
/// + `brand` independently. `isIosOverride` / `isAndroidOverride` on
/// [OemDetector.detect] sidestep `Platform.isIOS` / `Platform.isAndroid`
/// so the suite is deterministic on every host.
void main() {
  test('detects XiaomiFamily from Redmi brand (belt-and-suspenders match)', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'Xiaomi', brand: 'Redmi'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: true);
    expect(family, isA<XiaomiFamily>());
  });

  test('detects XiaomiFamily from POCO brand even with bare manufacturer', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'Xiaomi', brand: 'POCO'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: true);
    expect(family, isA<XiaomiFamily>());
  });

  test('detects SamsungFamily from manufacturer=Samsung', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'Samsung', brand: 'samsung'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: true);
    expect(family, isA<SamsungFamily>());
  });

  test('detects HuaweiFamily from Honor brand (Honor spins out of Huawei)', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'HUAWEI', brand: 'HONOR'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: true);
    expect(family, isA<HuaweiFamily>());
  });

  test('detects OnePlusFamily from OnePlus manufacturer', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'OnePlus', brand: 'OnePlus'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: true);
    expect(family, isA<OnePlusFamily>());
  });

  test('detects OppoFamily from Realme brand (Realme sits under the OPPO battery-manager lineage)', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'Realme', brand: 'realme'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: true);
    expect(family, isA<OppoFamily>());
  });

  test('returns OtherOem for unknown brand (Google Pixel)', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'Google', brand: 'google'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: true);
    expect(family, isA<OtherOem>());
  });

  test('returns IosDevice when running on iOS regardless of any Android fixture', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'Xiaomi', brand: 'Redmi'));
    final family = await detector.detect(isIosOverride: true, isAndroidOverride: false);
    expect(family, isA<IosDevice>());
  });

  test('returns OtherOem when neither Android nor iOS (desktop dev flow)', () async {
    final detector = OemDetector(_FakeDeviceInfoPlugin(manufacturer: 'ignored', brand: 'ignored'));
    final family = await detector.detect(isIosOverride: false, isAndroidOverride: false);
    expect(family, isA<OtherOem>());
  });
}

/// Overrides the `androidInfo` getter with a fixture built from
/// `AndroidDeviceInfo.fromMap` (the only public path to construct one —
/// the real constructor is private). Every other field is populated with
/// placeholder data the suite does not observe.
class _FakeDeviceInfoPlugin implements DeviceInfoPlugin {
  _FakeDeviceInfoPlugin({required this.manufacturer, required this.brand});

  final String manufacturer;
  final String brand;

  @override
  Future<AndroidDeviceInfo> get androidInfo async => AndroidDeviceInfo.fromMap(<String, dynamic>{
    'id': 'id',
    'host': 'host',
    'tags': 'tags',
    'type': 'type',
    'model': 'model',
    'board': 'board',
    'brand': brand,
    'device': 'device',
    'product': 'product',
    'name': 'name',
    'display': 'display',
    'hardware': 'hardware',
    'isPhysicalDevice': true,
    'freeDiskSize': 0,
    'totalDiskSize': 0,
    'bootloader': 'bootloader',
    'fingerprint': 'fingerprint',
    'manufacturer': manufacturer,
    'supportedAbis': <String>[],
    'systemFeatures': <String>[],
    'version': <String, dynamic>{
      'sdkInt': 33,
      'baseOS': 'base',
      'previewSdkInt': 0,
      'release': '13',
      'codename': 'REL',
      'incremental': 'inc',
      'securityPatch': '2026-01-01',
    },
    'supported64BitAbis': <String>[],
    'supported32BitAbis': <String>[],
    'isLowRamDevice': false,
    'physicalRamSize': 0,
    'availableRamSize': 0,
  });

  // Other members are never exercised by the suite — the `implements` clause
  // forces us to satisfy them, so we return `noSuchMethod` defaults.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
