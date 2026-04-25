// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-02 Task 1 RED test suite:
//
// Drives the Freezed extension of [MirkPaintContext] (3 → 6 fields) plus the
// rewrite of [MirkViewportBbox] + [VisibleMirkTile] from plain placeholder
// classes into Freezed types. Tests are written BEFORE the production
// rewrite — initial run will fail (the new required fields don't exist),
// turning green once the Freezed regen + lib edits land.
//
// Imports `package:mirkfall/domain/fixes/fix.dart` for the optional
// `currentFix` field — Phase 05 entity, no infrastructure dep.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

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

  group('09-02 — VisibleMirkTile', () {
    test('constructs with all 7 fields', () {
      final tile = VisibleMirkTile(
        parentX: 8400,
        parentY: 5500,
        bitmap: Uint8List(512),
        tileNorthLat: 44.0,
        tileWestLon: 5.0,
        tileSouthLat: 43.0,
        tileEastLon: 6.0,
      );
      expect(tile.parentX, 8400);
      expect(tile.parentY, 5500);
      expect(tile.bitmap.length, 512);
      expect(tile.tileNorthLat, 44.0);
      expect(tile.tileWestLon, 5.0);
      expect(tile.tileSouthLat, 43.0);
      expect(tile.tileEastLon, 6.0);
    });

    test('Freezed equality compares field-by-field', () {
      final bitmap = Uint8List(4)
        ..[0] = 1
        ..[1] = 2;
      final a = VisibleMirkTile(parentX: 1, parentY: 2, bitmap: bitmap, tileNorthLat: 1.0, tileWestLon: 2.0, tileSouthLat: 0.0, tileEastLon: 3.0);
      final b = VisibleMirkTile(parentX: 1, parentY: 2, bitmap: bitmap, tileNorthLat: 1.0, tileWestLon: 2.0, tileSouthLat: 0.0, tileEastLon: 3.0);
      // Same Uint8List instance → Freezed defaults to identical-by-reference
      // for collection-like fields, so equality holds when both reference
      // the exact same bitmap.
      expect(a, b);
    });
  });

  group('09-02 — MirkPaintContext (extended to 6 fields)', () {
    test('constructs with all 6 fields (currentFix null, visibleTiles const [])', () {
      final ctx = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: const Duration(seconds: 5),
        viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
        visibleTiles: const <VisibleMirkTile>[],
        // currentFix omitted on purpose — the field is nullable and defaults to null;
        // this test documents that the omitted form is the canonical "no fix yet" shape.
      );
      expect(ctx.currentFix, isNull);
      expect(ctx.visibleTiles, isEmpty);
      expect(ctx.viewportBbox.south, 43.0);
      expect(ctx.zoomLevel, 14.0);
      expect(ctx.pixelRatio, 3.0);
      expect(ctx.sessionElapsed, const Duration(seconds: 5));
    });

    test('visibleTiles non-empty round-trips with the tile preserved', () {
      final tile = VisibleMirkTile(
        parentX: 8400,
        parentY: 5500,
        bitmap: Uint8List(512),
        tileNorthLat: 44.0,
        tileWestLon: 5.0,
        tileSouthLat: 43.0,
        tileEastLon: 6.0,
      );
      final ctx = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: Duration.zero,
        viewportBbox: MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0),
        visibleTiles: [tile],
      );
      expect(ctx.visibleTiles.length, 1);
      expect(ctx.visibleTiles.first.parentX, 8400);
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
        visibleTiles: const <VisibleMirkTile>[],
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
          visibleTiles: const <VisibleMirkTile>[],
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
          visibleTiles: const <VisibleMirkTile>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Freezed equality: two identical contexts compare equal', () {
      final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final a = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: const Duration(seconds: 5),
        viewportBbox: bbox,
        visibleTiles: const <VisibleMirkTile>[],
      );
      final b = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 3.0,
        sessionElapsed: const Duration(seconds: 5),
        viewportBbox: bbox,
        visibleTiles: const <VisibleMirkTile>[],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
