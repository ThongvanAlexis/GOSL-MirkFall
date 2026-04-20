// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Phase 06 Adversarial Test #3 — permanent regression guard for
/// `OemDetector.detect()` resolution on ambiguous device-info fixtures.
///
/// `OemDetector.detect()` applies a fixed regex order :
///
///   Xiaomi (xiaomi|redmi|poco)
///   → Samsung (samsung)
///   → Huawei (huawei|honor)
///   → OnePlus (oneplus)
///   → Oppo (oppo|realme)
///   → OtherOem (fallback)
///
/// The existing `oem_detector_test.dart` suite covers the canonical
/// matches (e.g. Samsung-samsung, Xiaomi-Redmi, Realme) but does NOT
/// exercise AMBIGUOUS fixtures where multiple vendors appear in the
/// needle — the first matching regex short-circuits, which is the
/// deterministic tie-break. A regression that reshuffled the regex
/// order could silently pass the happy-path suite while breaking
/// devices that report multiple vendor tokens.
///
/// This test locks in the resolution priority with 6 ambiguous fixtures
/// (Plan 06-03 Agent #4 sketch). Each fixture asserts the EXPECTED
/// family given the current ordering; a future reorder would fail
/// loudly with the mismatched family name.
///
/// **Inertness guard (Phase 04 idiom):**
///
/// The fake `DeviceInfoPlugin` exposes a read-flag `androidInfoReadCount`
/// that increments on every `androidInfo` access. We intermediate-expect
/// `androidInfoReadCount == 1` BEFORE the family assertion — a future
/// refactor that short-circuited `detect()` before consuming the fixture
/// (e.g. cached a previous result) would silently pass the family check
/// on stale data without this guard.
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/platform/oem_detector.dart';

/// Fake `DeviceInfoPlugin` with instrumented `androidInfo` read-flag.
///
/// Every access to the `androidInfo` getter increments
/// [androidInfoReadCount] — used as the Phase 04 inertness-guard marker
/// (see file docstring). Tests assert `androidInfoReadCount == 1`
/// BEFORE the resolved-family assertion to guarantee the fixture was
/// actually consumed.
class _InstrumentedFakeDeviceInfoPlugin implements DeviceInfoPlugin {
  _InstrumentedFakeDeviceInfoPlugin({required this.manufacturer, required this.brand});

  final String manufacturer;
  final String brand;
  int androidInfoReadCount = 0;

  @override
  Future<AndroidDeviceInfo> get androidInfo async {
    androidInfoReadCount++;
    return AndroidDeviceInfo.fromMap(<String, dynamic>{
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
  }

  @override
  // ignore: no_duplicate_case_values, provide_deprecation_message
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('OemDetector ambiguous match regression guard (Phase 06 Test #3)', () {
    // Helper to assert inertness-guard BEFORE the family-type assertion.
    // The helper is inline-duplicated per-test (not factored out) so the
    // inertness expect sits visibly next to the detect() call in every
    // case — auditor eye-scan clarity > DRY here.
    //
    // Fixture #1: manufacturer="Google" brand="aosp" — no regex match →
    // OtherOem fallback. Regression guard against a future aosp matcher
    // that silently assigned to a vendor family.
    test('generic manufacturer=Google brand=aosp resolves to OtherOem (regression vs future aosp matchers)', () async {
      final _InstrumentedFakeDeviceInfoPlugin fake = _InstrumentedFakeDeviceInfoPlugin(manufacturer: 'Google', brand: 'aosp');
      final OemDetector detector = OemDetector(fake);

      final OemFamily family = await detector.detect(isIosOverride: false, isAndroidOverride: true);

      expect(
        fake.androidInfoReadCount,
        1,
        reason:
            'OemDetector did not consume the device-info fixture — test would silently pass on detection short-circuit regression. readCount=${fake.androidInfoReadCount}',
      );
      expect(family, isA<OtherOem>(), reason: 'aosp alone must NOT match any vendor family; future matcher regression must fail here');
    });

    // Fixture #2: manufacturer="Xiaomi" brand="Redmi" — first regex
    // (xiaomi|redmi|poco) short-circuits → XiaomiFamily. Order guard
    // (vs a reorder that put Samsung ahead of Xiaomi).
    test('manufacturer=Xiaomi brand=Redmi resolves to XiaomiFamily (first-regex-wins order guard)', () async {
      final _InstrumentedFakeDeviceInfoPlugin fake = _InstrumentedFakeDeviceInfoPlugin(manufacturer: 'Xiaomi', brand: 'Redmi');
      final OemDetector detector = OemDetector(fake);

      final OemFamily family = await detector.detect(isIosOverride: false, isAndroidOverride: true);

      expect(fake.androidInfoReadCount, 1, reason: 'fixture unread — test silently inert. readCount=${fake.androidInfoReadCount}');
      expect(family, isA<XiaomiFamily>(), reason: 'Xiaomi regex ordered first; reorder regression must fail here');
    });

    // Fixture #3: manufacturer="HUAWEI" brand="HONOR" — Honor is a
    // Huawei sub-brand; `huawei|honor` regex matches either. Parent
    // and sub-brand both present.
    test('manufacturer=HUAWEI brand=HONOR resolves to HuaweiFamily (parent + sub-brand both present)', () async {
      final _InstrumentedFakeDeviceInfoPlugin fake = _InstrumentedFakeDeviceInfoPlugin(manufacturer: 'HUAWEI', brand: 'HONOR');
      final OemDetector detector = OemDetector(fake);

      final OemFamily family = await detector.detect(isIosOverride: false, isAndroidOverride: true);

      expect(fake.androidInfoReadCount, 1, reason: 'fixture unread — test silently inert. readCount=${fake.androidInfoReadCount}');
      expect(family, isA<HuaweiFamily>(), reason: 'Huawei parent + Honor sub-brand must both resolve to HuaweiFamily');
    });

    // Fixture #4: manufacturer="OPPO" brand="Realme" — Realme is under
    // the OPPO battery-manager lineage; `oppo|realme` regex must win
    // over OnePlus despite OnePlus being ordered BEFORE Oppo (OnePlus
    // regex must NOT shadow Oppo's match since `oneplus` doesn't
    // appear in the needle).
    test('manufacturer=OPPO brand=Realme resolves to OppoFamily (OnePlus must not shadow Oppo)', () async {
      final _InstrumentedFakeDeviceInfoPlugin fake = _InstrumentedFakeDeviceInfoPlugin(manufacturer: 'OPPO', brand: 'Realme');
      final OemDetector detector = OemDetector(fake);

      final OemFamily family = await detector.detect(isIosOverride: false, isAndroidOverride: true);

      expect(fake.androidInfoReadCount, 1, reason: 'fixture unread — test silently inert. readCount=${fake.androidInfoReadCount}');
      expect(family, isA<OppoFamily>(), reason: 'OPPO/Realme must resolve to OppoFamily; OnePlus must not match');
    });

    // Fixture #5: manufacturer="OnePlus" brand="OnePlus" — canonical
    // OnePlus match.
    test('manufacturer=OnePlus brand=OnePlus resolves to OnePlusFamily (canonical)', () async {
      final _InstrumentedFakeDeviceInfoPlugin fake = _InstrumentedFakeDeviceInfoPlugin(manufacturer: 'OnePlus', brand: 'OnePlus');
      final OemDetector detector = OemDetector(fake);

      final OemFamily family = await detector.detect(isIosOverride: false, isAndroidOverride: true);

      expect(fake.androidInfoReadCount, 1, reason: 'fixture unread — test silently inert. readCount=${fake.androidInfoReadCount}');
      expect(family, isA<OnePlusFamily>());
    });

    // Fixture #6: manufacturer="samsung" brand="xiaomi" — impossible in
    // the real world but the test locks deterministic tie-break:
    // Xiaomi is ordered BEFORE Samsung in the regex chain, so any
    // needle containing both short-circuits to Xiaomi. Documents the
    // priority rule in case an OEM ever ships a white-label device.
    test('manufacturer=samsung brand=xiaomi resolves to XiaomiFamily (Xiaomi ordered first, deterministic tie-break)', () async {
      final _InstrumentedFakeDeviceInfoPlugin fake = _InstrumentedFakeDeviceInfoPlugin(manufacturer: 'samsung', brand: 'xiaomi');
      final OemDetector detector = OemDetector(fake);

      final OemFamily family = await detector.detect(isIosOverride: false, isAndroidOverride: true);

      expect(fake.androidInfoReadCount, 1, reason: 'fixture unread — test silently inert. readCount=${fake.androidInfoReadCount}');
      expect(family, isA<XiaomiFamily>(), reason: 'Xiaomi regex ordered first — regex-chain reorder regression must fail here');
    });
  });
}
