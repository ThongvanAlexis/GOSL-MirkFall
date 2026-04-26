// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/tunables/mirk_fog_opacity_pref.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit tests for [MirkFogOpacityPref] — the persistence helper that
/// backs the user-facing burger-menu fog-density slider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MirkRuntimeTunables.instance.reset();
  });

  group('MirkFogOpacityPref.read', () {
    test('returns null when no value has been written yet', () async {
      final value = await MirkFogOpacityPref.read();
      expect(value, isNull);
    });

    test('returns the persisted value when one exists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{kMirkFogOpacityPrefsKey: 0.42});
      final value = await MirkFogOpacityPref.read();
      expect(value, closeTo(0.42, 1e-9));
    });

    test('clamps a stored out-of-range value into [min..max]', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{kMirkFogOpacityPrefsKey: 99.0});
      final value = await MirkFogOpacityPref.read();
      expect(value, equals(kMirkFogOpacityMax));
    });

    test('clamps a stored below-min value up to the floor', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{kMirkFogOpacityPrefsKey: 0.05});
      final value = await MirkFogOpacityPref.read();
      expect(value, equals(kMirkFogOpacityMin));
    });
  });

  group('MirkFogOpacityPref.write', () {
    test('round-trips a written value through SharedPreferences', () async {
      await MirkFogOpacityPref.write(0.75);
      final readBack = await MirkFogOpacityPref.read();
      expect(readBack, closeTo(0.75, 1e-9));
    });

    test('clamps an out-of-range write before persisting', () async {
      await MirkFogOpacityPref.write(2.5);
      final readBack = await MirkFogOpacityPref.read();
      expect(readBack, equals(kMirkFogOpacityMax));
    });
  });

  group('MirkFogOpacityPref.applyAndPersist', () {
    test('writes all three octaves AND persists', () async {
      await MirkFogOpacityPref.applyAndPersist(0.6);
      final t = MirkRuntimeTunables.instance;
      expect(t.opacityFar, closeTo(0.6, 1e-9));
      expect(t.opacityMid, closeTo(0.6, 1e-9));
      expect(t.opacityNear, closeTo(0.6, 1e-9));
      final stored = await MirkFogOpacityPref.read();
      expect(stored, closeTo(0.6, 1e-9));
    });

    test('clamps before applying so an out-of-range value never reaches the tunables', () async {
      await MirkFogOpacityPref.applyAndPersist(5.0);
      final t = MirkRuntimeTunables.instance;
      expect(t.opacityFar, equals(kMirkFogOpacityMax));
      expect(t.opacityMid, equals(kMirkFogOpacityMax));
      expect(t.opacityNear, equals(kMirkFogOpacityMax));
    });
  });

  group('MirkFogOpacityPref.applyOnBoot', () {
    test('no-op when nothing is persisted (tunables stay at kMirkFog* defaults)', () async {
      await MirkFogOpacityPref.applyOnBoot();
      final t = MirkRuntimeTunables.instance;
      expect(t.opacityFar, equals(kMirkFogOpacityFar));
      expect(t.opacityMid, equals(kMirkFogOpacityMid));
      expect(t.opacityNear, equals(kMirkFogOpacityNear));
    });

    test('restores a previously persisted value to all three octaves', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{kMirkFogOpacityPrefsKey: 0.33});
      await MirkFogOpacityPref.applyOnBoot();
      final t = MirkRuntimeTunables.instance;
      expect(t.opacityFar, closeTo(0.33, 1e-9));
      expect(t.opacityMid, closeTo(0.33, 1e-9));
      expect(t.opacityNear, closeTo(0.33, 1e-9));
    });
  });
}
