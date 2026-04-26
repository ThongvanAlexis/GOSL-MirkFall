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

      MirkRuntimeTunables.instance.curlAmplitude = 1.0;
      MirkRuntimeTunables.instance.lightStrength = 2.0;
      MirkRuntimeTunables.instance.hueStrength = 1.5;
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
}
