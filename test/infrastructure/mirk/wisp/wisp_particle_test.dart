// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-05 — `WispParticle` in world coordinates (POC WISP-01 / WISP-02 port).
// `position` is a `GeoPoint` record (NOT a screen-pixel Offset, NOT a latlong2 LatLng);
// `age` = `1 - life / maxLife` clamped to [0, 1]; `isDead` at `life <= 0`.

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle.dart';

const GeoPoint _parisCentre = (latitude: 48.8566, longitude: 2.3522);

WispParticle _wisp({double life = 2.5, double maxLife = 2.5}) =>
    WispParticle(position: _parisCentre, velocityMetersPerSecond: Offset.zero, life: life, maxLife: maxLife);

void main() {
  group('09.1-05 — WispParticle (WISP-01 / WISP-02)', () {
    test('position is a GeoPoint record — WISP-01 world basis', () {
      final WispParticle wisp = WispParticle(position: _parisCentre, velocityMetersPerSecond: const Offset(1.5, 0.0), life: 2.5, maxLife: 2.5);
      expect(wisp.position, isA<GeoPoint>());
      expect(wisp.position.latitude, 48.8566);
      expect(wisp.position.longitude, 2.3522);
      expect(wisp.velocityMetersPerSecond, const Offset(1.5, 0.0));
    });

    test('position and velocity are mutable (integration hot path, no copyWith allocation)', () {
      final WispParticle wisp = _wisp();
      wisp.position = (latitude: 48.86, longitude: 2.36);
      wisp.velocityMetersPerSecond = const Offset(0.0, -0.5);
      expect(wisp.position, (latitude: 48.86, longitude: 2.36));
      expect(wisp.velocityMetersPerSecond.dy, -0.5);
    });

    test('isDead at life <= 0 — WISP-02', () {
      expect(_wisp().isDead, isFalse);
      expect(_wisp(life: 0.0).isDead, isTrue);
      expect(_wisp(life: -0.1).isDead, isTrue);
    });

    test('age follows 1 - life/maxLife clamped to [0, 1] — WISP-02', () {
      expect(_wisp().age, closeTo(0.0, 1e-9));
      expect(_wisp(life: 1.25).age, closeTo(0.5, 1e-9));
      expect(_wisp(life: 0.0).age, closeTo(1.0, 1e-9));
      expect(_wisp(life: -1.0).age, closeTo(1.0, 1e-9), reason: 'over-aged wisps report exactly 1.0');
    });
  });
}
