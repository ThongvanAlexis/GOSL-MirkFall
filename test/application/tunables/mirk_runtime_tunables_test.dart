// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';

void main() {
  // The tunables instance is a process-wide singleton; reset it before
  // every test so cases stay independent of execution order.
  setUp(() {
    MirkRuntimeTunables.instance.reset();
  });

  group('MirkRuntimeTunables defaults', () {
    test('every field starts at its kMirkFog* default', () {
      final t = MirkRuntimeTunables.instance;
      expect(t.atmosphericDriftZFar, kMirkFogAtmosphericDriftZFar);
      expect(t.atmosphericDriftZMid, kMirkFogAtmosphericDriftZMid);
      expect(t.atmosphericDriftZNear, kMirkFogAtmosphericDriftZNear);
      expect(t.atmosphericScaleFar, kMirkFogAtmosphericScaleFar);
      expect(t.atmosphericScaleMid, kMirkFogAtmosphericScaleMid);
      expect(t.atmosphericScaleNear, kMirkFogAtmosphericScaleNear);
      expect(t.heavenlyDriftZFar, kMirkFogHeavenlyDriftZFar);
      expect(t.heavenlyDriftZMid, kMirkFogHeavenlyDriftZMid);
      expect(t.heavenlyDriftZNear, kMirkFogHeavenlyDriftZNear);
      expect(t.heavenlyScaleFar, kMirkFogHeavenlyScaleFar);
      expect(t.heavenlyScaleMid, kMirkFogHeavenlyScaleMid);
      expect(t.heavenlyScaleNear, kMirkFogHeavenlyScaleNear);
      expect(t.opacityFar, kMirkFogOpacityFar);
      expect(t.opacityMid, kMirkFogOpacityMid);
      expect(t.opacityNear, kMirkFogOpacityNear);
      expect(t.curlAmplitude, kMirkFogCurlAmplitude);
      expect(t.curlScale, kMirkFogCurlScale);
      expect(t.lightDirRadians, kMirkFogLightDirRadians);
      expect(t.lightOffset, kMirkFogLightOffset);
      expect(t.lightStrength, kMirkFogLightStrength);
      expect(t.hueNoiseScale, kMirkFogHueNoiseScale);
      expect(t.hueStrength, kMirkFogHueStrength);
      expect(t.boundarySharpDistance, kMirkFogBoundarySharpDistance);
      expect(t.boundaryBleedDistance, kMirkFogBoundaryBleedDistance);
      expect(t.boundaryEdgeBand, kMirkFogBoundaryEdgeBand);
      expect(t.debugOutputDensity, kMirkFogDebugOutputDensity);
      expect(t.curlScaleAnimationEnabled, kMirkFogCurlScaleAnimationDefaultEnabled);
      expect(t.curlScaleAnimationPeriodSec, kMirkFogCurlScaleAnimationPeriodSec);
      expect(t.curlScaleAnimationMin, kMirkFogCurlScaleAnimationMin);
      expect(t.curlScaleAnimationMax, kMirkFogCurlScaleAnimationMax);
    });

    test('curlScaleAnimationEnabled defaults to true (UAT 2026-04-26 — animation on by default)', () {
      // Explicit assertion that the user-visible default flips animation
      // ON without any prefs/migration. The default flowing through the
      // tunables is the contract the renderers depend on.
      expect(MirkRuntimeTunables.instance.curlScaleAnimationEnabled, isTrue);
    });
  });

  group('MirkRuntimeTunables setters', () {
    test('setting a new value notifies listeners exactly once', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      MirkRuntimeTunables.instance.addListener(listener);
      addTearDown(() => MirkRuntimeTunables.instance.removeListener(listener));

      MirkRuntimeTunables.instance.atmosphericDriftZFar = 0.42;
      expect(MirkRuntimeTunables.instance.atmosphericDriftZFar, 0.42);
      expect(notifyCount, 1);
    });

    test('setting the same value does NOT notify listeners (no-op guard)', () {
      MirkRuntimeTunables.instance.atmosphericDriftZFar = 0.42;
      var notifyCount = 0;
      void listener() => notifyCount++;
      MirkRuntimeTunables.instance.addListener(listener);
      addTearDown(() => MirkRuntimeTunables.instance.removeListener(listener));

      MirkRuntimeTunables.instance.atmosphericDriftZFar = 0.42;
      expect(notifyCount, 0);
    });

    test('multiple distinct setters each notify once', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      MirkRuntimeTunables.instance.addListener(listener);
      addTearDown(() => MirkRuntimeTunables.instance.removeListener(listener));

      // Use values intentionally distinct from any kMirkFog* default so
      // the no-op guard doesn't accidentally suppress one of the three
      // notifications (the 2026-04-26 baking pass moved several
      // defaults; using the prior literals would have collided).
      MirkRuntimeTunables.instance.curlAmplitude = 0.123;
      MirkRuntimeTunables.instance.lightStrength = 2.71;
      MirkRuntimeTunables.instance.hueStrength = 0.987;
      expect(notifyCount, 3);
    });

    test('debugOutputDensity bool setter respects no-op guard', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      MirkRuntimeTunables.instance.addListener(listener);
      addTearDown(() => MirkRuntimeTunables.instance.removeListener(listener));

      MirkRuntimeTunables.instance.debugOutputDensity = true;
      MirkRuntimeTunables.instance.debugOutputDensity = true; // no-op
      expect(MirkRuntimeTunables.instance.debugOutputDensity, true);
      expect(notifyCount, 1);
    });

    test('curlScaleAnimationEnabled bool setter toggles + notifies', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      MirkRuntimeTunables.instance.addListener(listener);
      addTearDown(() => MirkRuntimeTunables.instance.removeListener(listener));

      // Default is true (kMirkFogCurlScaleAnimationDefaultEnabled). Flip
      // to false → notify; flip back → notify; same-value write → no-op.
      MirkRuntimeTunables.instance.curlScaleAnimationEnabled = false;
      MirkRuntimeTunables.instance.curlScaleAnimationEnabled = true;
      MirkRuntimeTunables.instance.curlScaleAnimationEnabled = true; // no-op
      expect(MirkRuntimeTunables.instance.curlScaleAnimationEnabled, isTrue);
      expect(notifyCount, 2);
    });
  });

  group('MirkRuntimeTunables.reset', () {
    test('reset returns every mutated field to its default', () {
      final t = MirkRuntimeTunables.instance;
      t.atmosphericDriftZFar = 0.99;
      t.curlAmplitude = 1.99;
      t.boundaryEdgeBand = 0.5;
      t.debugOutputDensity = !kMirkFogDebugOutputDensity;

      t.reset();

      expect(t.atmosphericDriftZFar, kMirkFogAtmosphericDriftZFar);
      expect(t.curlAmplitude, kMirkFogCurlAmplitude);
      expect(t.boundaryEdgeBand, kMirkFogBoundaryEdgeBand);
      expect(t.debugOutputDensity, kMirkFogDebugOutputDensity);
    });

    test('reset notifies listeners once (regardless of how many fields moved)', () {
      final t = MirkRuntimeTunables.instance;
      t.atmosphericDriftZFar = 0.99;
      t.curlAmplitude = 1.99;
      var notifyCount = 0;
      void listener() => notifyCount++;
      t.addListener(listener);
      addTearDown(() => t.removeListener(listener));

      t.reset();
      expect(notifyCount, 1);
    });
  });

  group('MirkRuntimeTunables.toJson', () {
    test('default state produces every kMirkFog* default keyed by camelCase field name', () {
      final Map<String, Object?> json = MirkRuntimeTunables.instance.toJson();
      expect(json['atmosphericDriftZFar'], kMirkFogAtmosphericDriftZFar);
      expect(json['atmosphericDriftZMid'], kMirkFogAtmosphericDriftZMid);
      expect(json['atmosphericDriftZNear'], kMirkFogAtmosphericDriftZNear);
      expect(json['atmosphericScaleFar'], kMirkFogAtmosphericScaleFar);
      expect(json['atmosphericScaleMid'], kMirkFogAtmosphericScaleMid);
      expect(json['atmosphericScaleNear'], kMirkFogAtmosphericScaleNear);
      expect(json['heavenlyDriftZFar'], kMirkFogHeavenlyDriftZFar);
      expect(json['heavenlyDriftZMid'], kMirkFogHeavenlyDriftZMid);
      expect(json['heavenlyDriftZNear'], kMirkFogHeavenlyDriftZNear);
      expect(json['heavenlyScaleFar'], kMirkFogHeavenlyScaleFar);
      expect(json['heavenlyScaleMid'], kMirkFogHeavenlyScaleMid);
      expect(json['heavenlyScaleNear'], kMirkFogHeavenlyScaleNear);
      expect(json['opacityFar'], kMirkFogOpacityFar);
      expect(json['opacityMid'], kMirkFogOpacityMid);
      expect(json['opacityNear'], kMirkFogOpacityNear);
      expect(json['curlAmplitude'], kMirkFogCurlAmplitude);
      expect(json['curlScale'], kMirkFogCurlScale);
      expect(json['lightDirRadians'], kMirkFogLightDirRadians);
      expect(json['lightOffset'], kMirkFogLightOffset);
      expect(json['lightStrength'], kMirkFogLightStrength);
      expect(json['hueNoiseScale'], kMirkFogHueNoiseScale);
      expect(json['hueStrength'], kMirkFogHueStrength);
      expect(json['boundarySharpDistance'], kMirkFogBoundarySharpDistance);
      expect(json['boundaryBleedDistance'], kMirkFogBoundaryBleedDistance);
      expect(json['boundaryEdgeBand'], kMirkFogBoundaryEdgeBand);
      expect(json['debugOutputDensity'], kMirkFogDebugOutputDensity);
      expect(json['curlScaleAnimationEnabled'], kMirkFogCurlScaleAnimationDefaultEnabled);
      expect(json['curlScaleAnimationPeriodSec'], kMirkFogCurlScaleAnimationPeriodSec);
      expect(json['curlScaleAnimationMin'], kMirkFogCurlScaleAnimationMin);
      expect(json['curlScaleAnimationMax'], kMirkFogCurlScaleAnimationMax);
    });

    test('mutating a field is reflected in toJson output', () {
      final t = MirkRuntimeTunables.instance;
      t.atmosphericDriftZFar = 0.42;
      t.curlAmplitude = 1.337;
      t.debugOutputDensity = !kMirkFogDebugOutputDensity;

      final Map<String, Object?> json = t.toJson();
      expect(json['atmosphericDriftZFar'], 0.42);
      expect(json['curlAmplitude'], 1.337);
      expect(json['debugOutputDensity'], !kMirkFogDebugOutputDensity);
    });

    test('emits at least 20 keys (covers the full ~25-field tunable surface)', () {
      final Map<String, Object?> json = MirkRuntimeTunables.instance.toJson();
      expect(json.length, greaterThanOrEqualTo(20));
    });

    test('keys are emitted in alphabetical order for diff-friendly exports', () {
      final List<String> keys = MirkRuntimeTunables.instance.toJson().keys.toList();
      final List<String> sortedKeys = <String>[...keys]..sort();
      expect(keys, equals(sortedKeys));
    });
  });
}
