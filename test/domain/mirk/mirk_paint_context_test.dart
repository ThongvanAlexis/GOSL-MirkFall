// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-02 / BUG-010 Option B Commit 5 — tests for the
// extension fields on [MirkPaintContext] and [MirkViewportBbox].
//
// Pre-Commit-5 this suite covered the now-deleted `VisibleMirkTile`
// transport too. Commit 5 retired that surface; the disc surface is
// covered by `reveal_disc_test.dart`.

import 'package:test/test.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

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

  group('09-02 — MirkPaintContext (extended to 6 fields, BUG-010 Commit 5)', () {
    RevealDisc disc({String id = 'rvd_test', double lat = 43.5, double lon = 5.5, double radiusMeters = 25.0}) {
      return RevealDisc(id: id, sessionId: 'sess_test', lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: DateTime.utc(2026, 4, 26));
    }

    test('constructs with discs (currentFix null defaults to null)', () {
      final ctx = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: const Duration(seconds: 5),
        viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
        discs: <RevealDisc>[disc()],
        // currentFix omitted on purpose — the field is nullable and defaults to null;
        // this test documents that the omitted form is the canonical "no fix yet" shape.
      );
      expect(ctx.currentFix, isNull);
      expect(ctx.discs, hasLength(1));
      expect(ctx.discs.first.id, 'rvd_test');
      expect(ctx.viewportBbox.south, 43.0);
      expect(ctx.zoomLevel, 14.0);
      expect(ctx.pixelRatio, 3.0);
      expect(ctx.sessionElapsed, const Duration(seconds: 5));
    });

    test('discs non-empty round-trips with the disc preserved', () {
      final ctx = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: Duration.zero,
        viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
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
      final ctx = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: Duration.zero,
        viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
        discs: const <RevealDisc>[],
      );
      expect(ctx.discs, isEmpty);
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
      final ctx = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: const Duration(seconds: 1),
        viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
        discs: const <RevealDisc>[],
        currentFix: fix,
      );
      expect(ctx.currentFix, isNotNull);
      expect(ctx.currentFix!.latitude, 43.5);
    });

    test('zoomLevel assertion fires on negative input (Phase 07 invariant retained)', () {
      expect(
        () => MirkPaintContext(
          zoomLevel: -1.0,
          pixelRatio: 3.0,
          sessionElapsed: Duration.zero,
          viewportBbox: MirkViewportBbox(south: 0.0, west: 0.0, north: 1.0, east: 1.0),
          discs: const <RevealDisc>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('pixelRatio assertion fires on zero input (Phase 07 invariant retained)', () {
      expect(
        () => MirkPaintContext(
          zoomLevel: 0.0,
          pixelRatio: 0.0,
          sessionElapsed: Duration.zero,
          viewportBbox: MirkViewportBbox(south: 0.0, west: 0.0, north: 1.0, east: 1.0),
          discs: const <RevealDisc>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Freezed equality: two identical contexts compare equal', () {
      final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final a = MirkPaintContext(zoomLevel: 14.0, pixelRatio: 3.0, sessionElapsed: const Duration(seconds: 5), viewportBbox: bbox, discs: const <RevealDisc>[]);
      final b = MirkPaintContext(zoomLevel: 14.0, pixelRatio: 3.0, sessionElapsed: const Duration(seconds: 5), viewportBbox: bbox, discs: const <RevealDisc>[]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
