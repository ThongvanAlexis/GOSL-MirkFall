// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-03 — the single Phase 09.1 extension of [MirkPaintContext]
// (six camera-derived fields) on top of the Phase 09 plan 09-02 / BUG-010 Commit 5
// shape, plus the [MirkViewportBbox] invariants that ride along with it.
//
// `flutter_test` (not `package:test`): `mirk_paint_context.dart` now imports `dart:ui`
// (`Offset`, return type of `ScreenProjector`) which the plain-Dart runner cannot load —
// same situation as `mirk_renderer_contract_test.dart`.
//
// The "old 6-field call no longer compiles" behaviour is enforced by Freezed's `required`
// named parameters at compile time; it cannot be asserted at runtime and is not repeated
// here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import '../../_helpers/mirk_paint_context_builder.dart';

void main() {
  group('09-02 — MirkViewportBbox', () {
    test('constructs with valid Marseille-area bbox', () {
      final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      expect(bbox.south, 43.0);
      expect(bbox.west, 5.0);
      expect(bbox.north, 44.0);
      expect(bbox.east, 6.0);
    });

    test('throws when south > north', () {
      expect(() => MirkViewportBbox(south: 44.0, west: 5.0, north: 43.0, east: 6.0), throwsA(isA<AssertionError>()));
    });

    test('allows antimeridian wrap (west > 0 && east < 0)', () {
      final bbox = MirkViewportBbox(south: 60.0, west: 170.0, north: 65.0, east: -170.0);
      expect(bbox.east, -170.0);
      expect(bbox.west, 170.0);
    });

    test('rejects non-wrap east < west (both same sign)', () {
      expect(() => MirkViewportBbox(south: 60.0, west: 10.0, north: 65.0, east: 5.0), throwsA(isA<AssertionError>()));
    });

    test('Freezed equality: identical bboxes compare equal', () {
      final a = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final b = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('09-02 — MirkPaintContext Phase 09 fields (retained through the 09.1 extension)', () {
    RevealDisc disc({String id = 'rvd_test', double lat = 43.5, double lon = 5.5, double radiusMeters = 25.0}) {
      return RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: DateTime.utc(2026, 4, 26));
    }

    test('constructs with discs (currentFix omitted defaults to null)', () {
      final ctx = buildTestMirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: const Duration(seconds: 5),
        viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
        discs: <RevealDisc>[disc()],
      );
      expect(ctx.currentFix, isNull);
      expect(ctx.discs, hasLength(1));
      expect(ctx.discs.first.id, 'rvd_test');
      expect(ctx.viewportBbox.south, 43.0);
      expect(ctx.zoomLevel, 14.0);
      expect(ctx.pixelRatio, 3.0);
      expect(ctx.sessionElapsed, const Duration(seconds: 5));
    });

    test('discs non-empty round-trips with order preserved', () {
      final ctx = buildTestMirkPaintContext(
        discs: <RevealDisc>[
          disc(id: 'rvd_one'),
          disc(id: 'rvd_two', lat: 43.6),
        ],
      );
      expect(ctx.discs.length, 2);
      expect(ctx.discs.first.id, 'rvd_one');
      expect(ctx.discs.last.id, 'rvd_two');
    });

    test('discs empty list is the canonical "nothing revealed yet" shape', () {
      expect(buildTestMirkPaintContext().discs, isEmpty);
    });

    test('currentFix accepts a real Fix instance', () {
      final fix = Fix(
        id: const FixId('fix_01HXYZ0000000000000000000'),
        sessionId: const SessionId('sess_01HXYZ0000000000000000000'),
        recordedAtUtc: DateTime.utc(2026, 4, 25, 12),
        recordedAtOffsetMinutes: 120,
        latitude: 43.5,
        longitude: 5.5,
        accuracyMeters: 8.0,
      );
      final ctx = buildTestMirkPaintContext(currentFix: fix);
      expect(ctx.currentFix, isNotNull);
      expect(ctx.currentFix!.latitude, 43.5);
    });

    test('zoomLevel assertion fires on negative input (Phase 07 invariant retained)', () {
      expect(() => buildTestMirkPaintContext(zoomLevel: -1.0), throwsA(isA<AssertionError>()));
    });

    test('pixelRatio assertion fires on zero input (Phase 07 invariant retained)', () {
      expect(() => buildTestMirkPaintContext(pixelRatio: 0.0), throwsA(isA<AssertionError>()));
    });
  });

  group('09.1-03 — MirkPaintContext single Phase 09.1 extension (6 camera-derived fields)', () {
    test('buildTestMirkPaintContext() with no argument yields the documented neutral defaults', () {
      final ctx = buildTestMirkPaintContext();
      expect(ctx.pixelOrigin, (x: 0.0, y: 0.0));
      expect(ctx.zoomScale, 1.0);
      expect(ctx.sdfRect, (0.0, 0.0, 1.0, 1.0));
      expect(ctx.canvasOffset, (dx: 0.0, dy: 0.0));
      expect(ctx.viewportBbox, parisTestViewport());
      expect(ctx.zoomLevel, 15.0);
      expect(ctx.pixelRatio, 1.0);
      expect(ctx.sessionElapsed, Duration.zero);
    });

    test('default projectToScreen is the linear projection of the Paris viewport onto the 256×256 canvas', () {
      final ctx = buildTestMirkPaintContext();
      // Viewport centre → canvas centre; north-west corner → (0, 0).
      final Offset centre = ctx.projectToScreen((latitude: 48.85, longitude: 2.35));
      expect(centre.dx, closeTo(128.0, 1e-6));
      expect(centre.dy, closeTo(128.0, 1e-6));
      final Offset northWest = ctx.projectToScreen((latitude: 48.86, longitude: 2.34));
      expect(northWest.dx, closeTo(0.0, 1e-6));
      expect(northWest.dy, closeTo(0.0, 1e-6));
    });

    test('default metersToPixels scales by the viewport latitude span (0.02° ≈ 2226 m over 256 px)', () {
      final ctx = buildTestMirkPaintContext();
      // 0.02° × 111 320 m/° = 2226.4 m across 256 px → 1 m ≈ 0.115 px.
      const double latSpanMeters = 0.02 * 111320.0;
      expect(ctx.metersToPixels(latSpanMeters, atLatitude: 48.85), closeTo(256.0, 1e-6));
      expect(ctx.metersToPixels(25.0, atLatitude: 48.85), closeTo(25.0 * 256.0 / latSpanMeters, 1e-9));
    });

    test('every extension field is overridable by named parameter', () {
      final ctx = buildTestMirkPaintContext(
        pixelOrigin: (x: 4255934.927218, y: -1234567.890123),
        zoomScale: 4.0,
        sdfRect: (0.0, 1.0, 1.0, -1.0),
        canvasOffset: (dx: -12.5, dy: 33.0),
      );
      expect(ctx.pixelOrigin.x, 4255934.927218);
      expect(ctx.pixelOrigin.y, -1234567.890123);
      expect(ctx.zoomScale, 4.0);
      expect(ctx.sdfRect, (0.0, 1.0, 1.0, -1.0));
      expect(ctx.canvasOffset, (dx: -12.5, dy: 33.0));
    });

    test('zoomScale must be > 0 (@Assert)', () {
      expect(() => buildTestMirkPaintContext(zoomScale: 0.0), throwsA(isA<AssertionError>()));
      expect(() => buildTestMirkPaintContext(zoomScale: -1.0), throwsA(isA<AssertionError>()));
      expect(buildTestMirkPaintContext(zoomScale: 0.25).zoomScale, 0.25);
    });

    test('sdfRect accepts both the iOS identity and the Android V-flip (FOG-21)', () {
      expect(buildTestMirkPaintContext().sdfRect, (0.0, 0.0, 1.0, 1.0));
      expect(buildTestMirkPaintContext(sdfRect: (0.0, 1.0, 1.0, -1.0)).sdfRect, (0.0, 1.0, 1.0, -1.0));
    });

    test('projectToScreen returns the injected closure result verbatim', () {
      const Offset sentinel = Offset(17.5, -3.25);
      GeoPoint? observed;
      final ctx = buildTestMirkPaintContext(
        projectToScreen: (GeoPoint point) {
          observed = point;
          return sentinel;
        },
      );
      expect(ctx.projectToScreen((latitude: 48.85, longitude: 2.35)), sentinel);
      expect(observed, (latitude: 48.85, longitude: 2.35));
    });

    test('metersToPixels returns the injected closure result verbatim', () {
      double? observedMeters;
      double? observedLatitude;
      final ctx = buildTestMirkPaintContext(
        metersToPixels: (double meters, {required double atLatitude}) {
          observedMeters = meters;
          observedLatitude = atLatitude;
          return 42.0;
        },
      );
      expect(ctx.metersToPixels(25.0, atLatitude: 48.85), 42.0);
      expect(observedMeters, 25.0);
      expect(observedLatitude, 48.85);
    });

    test('equality is by closure identity: same closure instances → equal, different → not equal', () {
      Offset projector(GeoPoint point) => Offset(point.longitude, point.latitude);
      double scale(double meters, {required double atLatitude}) => meters;
      final viewport = parisTestViewport();
      final a = buildTestMirkPaintContext(viewportBbox: viewport, projectToScreen: projector, metersToPixels: scale);
      final b = buildTestMirkPaintContext(viewportBbox: viewport, projectToScreen: projector, metersToPixels: scale);
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      // A structurally identical but distinct closure is a different value — closures have
      // no structural equality in Dart, and the context does not try to invent one.
      final c = buildTestMirkPaintContext(
        viewportBbox: viewport,
        projectToScreen: (GeoPoint point) => Offset(point.longitude, point.latitude),
        metersToPixels: scale,
      );
      expect(a, isNot(equals(c)));
    });

    test('two builder calls without injected closures are NOT equal (fresh default closures each call)', () {
      // Documents the identity semantics from the fixture side: suites that need two equal
      // contexts must share closure instances explicitly.
      expect(buildTestMirkPaintContext(), isNot(equals(buildTestMirkPaintContext())));
    });

    test('GeoPoint is a record: positional-free, structurally equal', () {
      const GeoPoint a = (latitude: 48.85, longitude: 2.35);
      const GeoPoint b = (latitude: 48.85, longitude: 2.35);
      expect(a, b);
      expect(a.latitude, 48.85);
      expect(a.longitude, 2.35);
    });
  });

  group('09.1-03 — domain purity of the extended seam (source reflection)', () {
    test('mirk_paint_context.dart imports no flutter_map / latlong2 / package:flutter library', () {
      final String source = File('lib/domain/mirk/mirk_paint_context.dart').readAsStringSync();
      // Only `import` directives count — the class docstring legitimately names the
      // forbidden packages in prose when explaining the purity rule.
      final List<String> importLines = source.split('\n').where((String line) => line.startsWith('import ')).toList();
      expect(importLines, isNotEmpty);
      for (final String line in importLines) {
        expect(line, isNot(contains('package:flutter_map')), reason: line);
        expect(line, isNot(contains('package:latlong2')), reason: line);
        expect(line, isNot(contains('package:flutter/')), reason: line);
      }
      expect(source, contains('typedef ScreenProjector'));
      expect(source, contains('typedef MetersToPixels'));
    });
  });
}
