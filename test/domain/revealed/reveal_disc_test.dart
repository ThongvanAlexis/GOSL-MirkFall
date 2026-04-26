// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;

import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:test/test.dart';

/// BUG-010 Option B Commit 1 — `RevealDisc` value-type contract:
///
///   * value equality on all six fields,
///   * Haversine `distanceMetersTo` correctness against known fixtures,
///   * conservative `intersectsBbox` per cardinal direction (incl. radius
///     extending into the bbox from a centre that is itself outside),
///   * `mergeWith` smallest-enclosing-disc algorithm with deterministic
///     tie-breaks (earlier-`fixedAtUtc` wins),
///   * cross-session merge is rejected (asserts).
///
/// No callers exist yet; this file is the only consumer of [RevealDisc] in
/// the tree. Subsequent commits in the BUG-010 series add the store, rewire
/// the SDF builder and drop the bitmap path.
void main() {
  // Stable timestamps used across the suite. UTC so the `isBefore`
  // tie-breaks in `mergeWith` are unambiguous.
  final tEarly = DateTime.utc(2026, 4, 26, 10);
  final tMiddle = DateTime.utc(2026, 4, 26, 10, 1);
  final tLate = DateTime.utc(2026, 4, 26, 10, 2);

  // Default identity used when the test does not care about the PK / FK
  // fields — kept as constants (not defaults on a builder) so a passing
  // call site explicitly mentions the value when it matters.
  const defaultId = 'rvd_01HVABCDEFGHJKMNPQRSTVWXY1';
  const defaultSessionId = 'sess_01HVABCDEFGHJKMNPQRSTVWXY1';

  // Test-scoped factory. All geometry fields and the timestamp are required
  // on every call site so the test reads as a self-contained spec; the
  // identity fields fall back to constants so identity-irrelevant tests
  // stay terse.
  RevealDisc disc({
    required double lat,
    required double lon,
    required double radiusMeters,
    required DateTime fixedAtUtc,
    String id = defaultId,
    String sessionId = defaultSessionId,
  }) {
    return RevealDisc(
      id: id,
      sessionId: sessionId,
      lat: lat,
      lon: lon,
      radiusMeters: radiusMeters,
      fixedAtUtc: fixedAtUtc,
    );
  }

  // Convenience builder for the equality suite (where a vanilla canonical
  // disc is the baseline). Picked to match Paris coords because the
  // distance suite reuses them — fewer magic literals across the file.
  RevealDisc parisCanonical() => disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly);

  group('RevealDisc — equality & hashCode', () {
    test('two instances with identical fields compare equal and hash equal', () {
      final a = parisCanonical();
      final b = parisCanonical();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing id breaks equality', () {
      final a = parisCanonical();
      final b = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly, id: 'rvd_other');
      expect(a, isNot(equals(b)));
    });

    test('differing sessionId breaks equality', () {
      final a = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly, sessionId: 'sess_AAA');
      final b = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly, sessionId: 'sess_BBB');
      expect(a, isNot(equals(b)));
    });

    test('differing lat / lon / radius breaks equality', () {
      final base = parisCanonical();
      expect(base, isNot(equals(disc(lat: base.lat + 0.0001, lon: base.lon, radiusMeters: base.radiusMeters, fixedAtUtc: tEarly))));
      expect(base, isNot(equals(disc(lat: base.lat, lon: base.lon + 0.0001, radiusMeters: base.radiusMeters, fixedAtUtc: tEarly))));
      expect(base, isNot(equals(disc(lat: base.lat, lon: base.lon, radiusMeters: base.radiusMeters + 0.5, fixedAtUtc: tEarly))));
    });

    test('differing fixedAtUtc breaks equality', () {
      final a = parisCanonical();
      final b = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tLate);
      expect(a, isNot(equals(b)));
    });

    test('identical objects are == to themselves', () {
      final a = parisCanonical();
      expect(a, equals(a));
    });
  });

  group('RevealDisc.distanceMetersTo — Haversine correctness', () {
    test('same point → 0 m', () {
      final d = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly);
      expect(d.distanceMetersTo(48.8566, 2.3522), closeTo(0.0, 1e-6));
    });

    test('1° latitude north of centre ≈ 111 km (within 1 km)', () {
      final d = disc(lat: 0.0, lon: 0.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      // Per WGS-84 mean radius (6371008.8 m) the arc length of 1° of
      // latitude is `R · (π/180) ≈ 111 195 m`. The 1 km tolerance leaves
      // headroom for any future radius refinement (mean → equatorial).
      expect(d.distanceMetersTo(1.0, 0.0), closeTo(111195.0, 1000.0));
    });

    test('Paris (48.8566, 2.3522) → London (51.5074, -0.1278) ≈ 343 km ± 1 km', () {
      final paris = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly);
      final distance = paris.distanceMetersTo(51.5074, -0.1278);
      // 343 km is the published great-circle distance for these well-known
      // city centres; tolerance ±1 km accommodates the inherent rounding
      // of 4-decimal-degree fixtures.
      expect(distance, closeTo(343000.0, 1000.0));
    });

    test('symmetry: A→B == B→A within ULP tolerance', () {
      final paris = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly);
      final london = disc(lat: 51.5074, lon: -0.1278, radiusMeters: 25.0, fixedAtUtc: tEarly);
      final ab = paris.distanceMetersTo(london.lat, london.lon);
      final ba = london.distanceMetersTo(paris.lat, paris.lon);
      // Haversine is symmetric to floating-point ULP; 1e-6 m is generous.
      expect(ab, closeTo(ba, 1e-6));
    });
  });

  group('RevealDisc.intersectsBbox — bbox overlap predicate', () {
    // Bbox at lat 45° / lon 5° with ~1° span — small but well clear of the
    // poles, the equator and the antimeridian.
    final bbox = MirkViewportBbox(south: 44.5, west: 4.5, north: 45.5, east: 5.5);

    test('disc centred inside bbox → true', () {
      final d = disc(lat: 45.0, lon: 5.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      expect(d.intersectsBbox(bbox), isTrue);
    });

    test('disc completely outside bbox to the north → false', () {
      final d = disc(lat: 60.0, lon: 5.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      expect(d.intersectsBbox(bbox), isFalse);
    });

    test('disc completely outside bbox to the south → false', () {
      final d = disc(lat: 30.0, lon: 5.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      expect(d.intersectsBbox(bbox), isFalse);
    });

    test('disc completely outside bbox to the east → false', () {
      final d = disc(lat: 45.0, lon: 20.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      expect(d.intersectsBbox(bbox), isFalse);
    });

    test('disc completely outside bbox to the west → false', () {
      final d = disc(lat: 45.0, lon: -10.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      expect(d.intersectsBbox(bbox), isFalse);
    });

    test('disc centre outside bbox but radius extends into bbox → true', () {
      // Centre 200 m WEST of the bbox west edge with a 500 m radius — the
      // disc's eastern lobe reaches into the bbox. cos(45°) ≈ 0.7071 →
      // 200 m ≈ 0.00254° lon at this latitude.
      final cos45 = math.cos(45.0 * math.pi / 180.0);
      final lonOffsetDeg = 200.0 / (111320.0 * cos45);
      final d = disc(lat: 45.0, lon: 4.5 - lonOffsetDeg, radiusMeters: 500.0, fixedAtUtc: tEarly);
      expect(d.intersectsBbox(bbox), isTrue, reason: 'radius should bridge the centre→west-edge gap');
    });

    test('antimeridian-wrapping bbox: discs in either half overlap, far-side disc does not', () {
      // Bbox covers `[170° east, +180°] ∪ [-180°, -170°]` — the wrap case.
      final wrapBbox = MirkViewportBbox(south: 60.0, west: 170.0, north: 65.0, east: -170.0);
      final discInWestHalf = disc(lat: 62.0, lon: -175.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      final discInEastHalf = disc(lat: 62.0, lon: 175.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      final discFarFromWrap = disc(lat: 62.0, lon: 0.0, radiusMeters: 25.0, fixedAtUtc: tEarly);
      expect(discInWestHalf.intersectsBbox(wrapBbox), isTrue);
      expect(discInEastHalf.intersectsBbox(wrapBbox), isTrue);
      expect(discFarFromWrap.intersectsBbox(wrapBbox), isFalse);
    });
  });

  group('RevealDisc.mergeWith — smallest enclosing disc', () {
    test('A entirely contains B → returns A unchanged', () {
      final a = disc(lat: 0.0, lon: 0.0, radiusMeters: 100.0, fixedAtUtc: tEarly, id: 'rvd_AAA');
      final b = disc(lat: 0.0, lon: 0.0, radiusMeters: 5.0, fixedAtUtc: tLate, id: 'rvd_BBB');
      final merged = a.mergeWith(b);
      expect(merged, equals(a));
    });

    test('B entirely contains A, A is earlier → returns A verbatim (earlier-fixedAtUtc wins)', () {
      // Containment short-circuit returns the EARLIER input on a hit. With
      // A earlier than B and B geometrically containing A, the contract
      // says: return A. Implementation: `if (d + r1 <= r2) return
      // _earlierOf(other, this);` — `_earlierOf` selects the earlier
      // timestamp.
      final a = disc(lat: 0.0, lon: 0.0, radiusMeters: 5.0, fixedAtUtc: tEarly, id: 'rvd_AAA');
      final b = disc(lat: 0.0, lon: 0.0, radiusMeters: 100.0, fixedAtUtc: tLate, id: 'rvd_BBB');
      final merged = a.mergeWith(b);
      expect(merged, equals(a), reason: 'earlier-fixedAtUtc wins; A had tEarly');
    });

    test('B entirely contains A, B is earlier → returns B unchanged', () {
      final a = disc(lat: 0.0, lon: 0.0, radiusMeters: 5.0, fixedAtUtc: tLate, id: 'rvd_AAA');
      final b = disc(lat: 0.0, lon: 0.0, radiusMeters: 100.0, fixedAtUtc: tEarly, id: 'rvd_BBB');
      final merged = a.mergeWith(b);
      expect(merged, equals(b), reason: 'B contains A AND B is earlier → return B verbatim');
    });

    test('two identical discs → returns one of them with earlier-fixedAtUtc id', () {
      final a = disc(lat: 1.0, lon: 2.0, radiusMeters: 25.0, fixedAtUtc: tEarly, id: 'rvd_AAA');
      final b = disc(lat: 1.0, lon: 2.0, radiusMeters: 25.0, fixedAtUtc: tLate, id: 'rvd_BBB');
      final mergedAB = a.mergeWith(b);
      final mergedBA = b.mergeWith(a);
      expect(mergedAB.id, equals(a.id), reason: 'earlier-fixedAtUtc wins on identical-geometry tie');
      expect(mergedAB.fixedAtUtc, equals(a.fixedAtUtc));
      expect(mergedBA.id, equals(a.id), reason: 'order independence: same merged id either way');
      expect(mergedBA.fixedAtUtc, equals(a.fixedAtUtc));
    });

    test('two disjoint discs → new radius = (d + r1 + r2) / 2 and centre on the line', () {
      // A at the equator, B exactly 1° east — `d ≈ 111 195 m`.
      // r1 = r2 = 1000 m → newRadius = (d + 2000) / 2 ≈ 56 597 m.
      final a = disc(lat: 0.0, lon: 0.0, radiusMeters: 1000.0, fixedAtUtc: tEarly, id: 'rvd_AAA');
      final b = disc(lat: 0.0, lon: 1.0, radiusMeters: 1000.0, fixedAtUtc: tLate, id: 'rvd_BBB');
      final d = a.distanceMetersTo(b.lat, b.lon);
      final expectedRadius = (d + a.radiusMeters + b.radiusMeters) / 2.0;
      final merged = a.mergeWith(b);
      // 1 cm tolerance — equirectangular vs Haversine drift at ~111 km is
      // sub-metre; allow headroom for the floating-point chain.
      expect(merged.radiusMeters, closeTo(expectedRadius, 0.01));
      // Earlier-fixedAtUtc preserved.
      expect(merged.id, equals(a.id));
      expect(merged.fixedAtUtc, equals(a.fixedAtUtc));
      // Equal radii → midpoint on the equator.
      expect(merged.lat, closeTo(0.0, 1e-6));
      expect(merged.lon, closeTo(0.5, 1e-3));
    });

    test('disjoint discs at compaction scale (< 100 m): centre on the line', () {
      // Discs ~50 m apart at lat 45°, both r = 25 m → properly disjoint.
      const lat = 45.0;
      final cos45 = math.cos(lat * math.pi / 180.0);
      final lonOffsetMetersToDeg = 1.0 / (111320.0 * cos45);
      final a = disc(lat: lat, lon: 0.0, radiusMeters: 25.0, fixedAtUtc: tEarly, id: 'rvd_AAA');
      final b = disc(
        lat: lat,
        lon: 50.0 * lonOffsetMetersToDeg,
        radiusMeters: 25.0,
        fixedAtUtc: tLate,
        id: 'rvd_BBB',
      );
      final d = a.distanceMetersTo(b.lat, b.lon);
      final merged = a.mergeWith(b);
      final expectedRadius = (d + 50.0) / 2.0;
      expect(merged.radiusMeters, closeTo(expectedRadius, 0.01));
      // Centre must lie on the equator-aligned line between A and B —
      // same lat, lon strictly between A's and B's. 1e-6° ≈ 11 cm; well
      // below GPS accuracy.
      expect(merged.lat, closeTo(lat, 1e-6));
      expect(merged.lon, inInclusiveRange(a.lon, b.lon));
    });

    test('mergeWith preserves the earlier-fixedAtUtc on the merged disc (non-trivial centre)', () {
      // 0.001° apart at the equator ≈ 111 m, r = 25 m → properly disjoint
      // so the algorithm runs the full smallest-enclosing branch (NOT a
      // containment short-circuit). B is earlier → merged disc inherits
      // B's id and timestamp.
      final a = disc(lat: 0.0, lon: 0.0, radiusMeters: 25.0, fixedAtUtc: tMiddle, id: 'rvd_AAA');
      final b = disc(lat: 0.0, lon: 0.001, radiusMeters: 25.0, fixedAtUtc: tEarly, id: 'rvd_BBB');
      final merged = a.mergeWith(b);
      expect(merged.fixedAtUtc, equals(tEarly));
      expect(merged.id, equals(b.id), reason: 'b is earlier → b.id wins on the merged disc');
    });

    test('cross-session merge asserts (debug build)', () {
      final a = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly, sessionId: 'sess_AAA');
      final b = disc(lat: 48.8566, lon: 2.3522, radiusMeters: 25.0, fixedAtUtc: tEarly, sessionId: 'sess_BBB');
      // `assert` only fires in debug; `flutter test` runs in checked mode
      // so this throws an `AssertionError`. Production builds skip the
      // check by design — the upstream compaction caller never crosses
      // sessions, so this assert is the contract guard for future
      // callers, not a runtime safety net.
      expect(() => a.mergeWith(b), throwsA(isA<AssertionError>()));
    });
  });
}
