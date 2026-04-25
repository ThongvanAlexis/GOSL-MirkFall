// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/revealed_tile_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/revealed_tile.dart';
import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';
import 'package:mirkfall/domain/revealed/tile_math.dart';

/// Observable in-memory [`RevealedTileStore`] for widget + provider tests
/// that need to assert which parent tiles get queried, when, and how
/// often — without spinning a Drift database.
///
/// Plan 09-08 Task 2 extends the Wave 0 forward-declaration with two new
/// observables (revision S3):
///
/// * [`findByParentCallCount`] — counter incremented on every
///   [`findByParent`] invocation. Backs the viewport-filter regression
///   test (SC#5): with 1000 tiles in the DB and a viewport covering ≈ 4
///   parent tiles, the call count must stay ≤ 20 per provider build.
/// * [`seed1000TilesEurope`] — one-shot deterministic seeder that fills
///   the in-memory map with 1000 tiles spread across Europe (lat 43-50,
///   lon 0-15) at z=14. The viewport-filter test pumps the
///   `MirkOverlay` with a Paris-sized bbox and confirms `findByParent`
///   stops short of all 1000 entries.
class FakeRevealedTileStore implements RevealedTileStore {
  /// Backing store keyed on `(sessionId, parentX, parentY)`. The Wave 0
  /// scaffold used a triple-record key; Plan 09-08 promotes that to a
  /// concrete record so callers can index without re-deriving the key.
  final Map<({SessionId sessionId, int parentX, int parentY}), RevealedTile> _rows = <({SessionId sessionId, int parentX, int parentY}), RevealedTile>{};

  /// Number of times [`findByParent`] has been invoked. The viewport
  /// filtering test asserts this stays ≤ 20 with a 1000-tile DB +
  /// 4-tile-sized viewport.
  int findByParentCallCount = 0;

  /// Number of [`mergeMask`] invocations. Lets tests assert the reveal
  /// streaming flush actually wrote.
  int mergeMaskCallCount = 0;

  /// Number of [`listBySession`] invocations.
  int listBySessionCallCount = 0;

  /// When non-null, the next [`findByParent`] / [`mergeMask`] /
  /// [`listBySession`] call throws [`throwOnNextCall`] (then resets it).
  Object? throwOnNextCall;

  /// Resets all counters + clears the in-memory map.
  void reset() {
    _rows.clear();
    findByParentCallCount = 0;
    mergeMaskCallCount = 0;
    listBySessionCallCount = 0;
    throwOnNextCall = null;
  }

  void _maybeThrow(String method) {
    final t = throwOnNextCall;
    if (t != null) {
      throwOnNextCall = null;
      throw t;
    }
  }

  @override
  Future<List<RevealedTile>> listBySession(SessionId sessionId) async {
    _maybeThrow('listBySession');
    listBySessionCallCount++;
    final List<RevealedTile> rows = _rows.entries.where((e) => e.key.sessionId == sessionId).map((e) => e.value).toList(growable: false);
    rows.sort((a, b) {
      final int xc = a.parentX.compareTo(b.parentX);
      if (xc != 0) return xc;
      return a.parentY.compareTo(b.parentY);
    });
    return rows;
  }

  @override
  Future<RevealedTile?> findByParent({required SessionId sessionId, required int parentX, required int parentY}) async {
    _maybeThrow('findByParent');
    findByParentCallCount++;
    return _rows[(sessionId: sessionId, parentX: parentX, parentY: parentY)];
  }

  @override
  Future<void> mergeMask({required SessionId sessionId, required int parentX, required int parentY, required Uint8List mask}) async {
    _maybeThrow('mergeMask');
    mergeMaskCallCount++;
    if (mask.length != kRevealedTileBitmapBytes) {
      throw ArgumentError.value(mask.length, 'mask.length', 'Expected $kRevealedTileBitmapBytes bytes');
    }
    final key = (sessionId: sessionId, parentX: parentX, parentY: parentY);
    final RevealedTile? existing = _rows[key];
    if (existing == null) {
      int popcount = 0;
      for (final b in mask) {
        popcount += _popcount8(b);
      }
      _rows[key] = RevealedTile(
        id: RevealedTileId('rvt_fake_${parentX}_$parentY'),
        sessionId: sessionId,
        parentX: parentX,
        parentY: parentY,
        bitmap: Uint8List.fromList(mask),
        setBitCount: popcount,
        updatedAtUtc: DateTime.utc(2026),
      );
    } else {
      final Uint8List merged = Uint8List(kRevealedTileBitmapBytes);
      int popcount = 0;
      for (int i = 0; i < kRevealedTileBitmapBytes; i++) {
        merged[i] = existing.bitmap[i] | mask[i];
        popcount += _popcount8(merged[i]);
      }
      _rows[key] = RevealedTile(
        id: existing.id,
        sessionId: sessionId,
        parentX: parentX,
        parentY: parentY,
        bitmap: merged,
        setBitCount: popcount,
        updatedAtUtc: DateTime.utc(2026),
      );
    }
  }

  /// Test-only direct insert that bypasses the call counter — lets
  /// seeders pre-populate the store without inflating
  /// [`mergeMaskCallCount`].
  void primeRow(RevealedTile tile) {
    _rows[(sessionId: tile.sessionId, parentX: tile.parentX, parentY: tile.parentY)] = tile;
  }

  /// Seeds 1000 deterministic tiles across Europe (lat 43..50, lon
  /// 0..15) at parent zoom 14. Each tile carries a sparse bitmap (≈ 5 %
  /// of bits set) — enough that `setBitCount` is non-zero but the
  /// per-tile data stays compact in memory.
  ///
  /// Used by [`map_screen_viewport_filtering_test`]
  /// (`test/presentation/map_screen_viewport_filtering_test.dart`) to
  /// prove that only viewport-intersecting tiles are queried — a
  /// regression guard against accidental "scan all rows" implementations
  /// of [`visibleMirkTilesProvider`].
  void seed1000TilesEurope({required SessionId sessionId}) {
    final math.Random rng = math.Random(0xE05EED);
    int seeded = 0;
    final Set<({int parentX, int parentY})> seen = <({int parentX, int parentY})>{};
    while (seeded < 1000) {
      final double lat = 43.0 + rng.nextDouble() * 7.0;
      final double lon = 0.0 + rng.nextDouble() * 15.0;
      final TilePosition tile = TileMath.latLonToTile(lat: lat, lon: lon, zoom: kRevealedTileParentZoom);
      final coord = (parentX: tile.x, parentY: tile.y);
      if (!seen.add(coord)) continue;
      final Uint8List bitmap = Uint8List(kRevealedTileBitmapBytes);
      int popcount = 0;
      for (int b = 0; b < kRevealedTileBitmapBytes * 8; b++) {
        if (rng.nextDouble() < 0.05) {
          bitmap[b >> 3] |= 1 << (b & 7);
          popcount++;
        }
      }
      _rows[(sessionId: sessionId, parentX: tile.x, parentY: tile.y)] = RevealedTile(
        id: RevealedTileId('rvt_fake_seed_$seeded'),
        sessionId: sessionId,
        parentX: tile.x,
        parentY: tile.y,
        bitmap: bitmap,
        setBitCount: popcount,
        updatedAtUtc: DateTime.utc(2026),
      );
      seeded++;
    }
  }

  /// Number of rows currently held — useful in tests for sanity-checking
  /// the seeder.
  int get rowCount => _rows.length;

  static int _popcount8(int b) {
    int x = b & 0xFF;
    x = x - ((x >> 1) & 0x55);
    x = (x & 0x33) + ((x >> 2) & 0x33);
    x = (x + (x >> 4)) & 0x0F;
    return x;
  }
}
