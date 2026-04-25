// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_use_of_protected_member — PictureRecorder tests below
// exercise Canvas via dart:ui which is the standard Flutter testing idiom.

import 'dart:ui' show Canvas, PictureRecorder, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/infrastructure/mirk/noop_mirk_renderer.dart';

void main() {
  group('NoopMirkRenderer — surface conformance', () {
    test('implements MirkRenderer', () {
      const NoopMirkRenderer r = NoopMirkRenderer();
      expect(r, isA<MirkRenderer>());
    });
  });

  group('NoopMirkRenderer — trivial operation', () {
    test('100 iterations of paint/update do not throw', () {
      const NoopMirkRenderer r = NoopMirkRenderer();
      final MirkPaintContext ctx = MirkPaintContext(
        zoomLevel: 13.0,
        pixelRatio: 2.0,
        sessionElapsed: const Duration(minutes: 5),
        // Phase 09 plan 09-02: extended fields. Noop renderer ignores all of them; supplying the
        // narrowest valid values keeps this test focused on "100 paint/update iterations don't throw".
        viewportBbox: MirkViewportBbox(
          south: 0.0,
          west: 0.0,
          north: 1.0,
          east: 1.0,
        ),
        visibleTiles: const <VisibleMirkTile>[],
      );
      final PictureRecorder rec = PictureRecorder();
      final Canvas canvas = Canvas(rec);

      for (int i = 0; i < 100; i++) {
        r.update(Duration(milliseconds: i * 16));
        r.paint(canvas, const Size(200, 200), ctx);
      }

      // Ensure no exception propagated — the test is the assertion.
      expect(true, isTrue);

      rec.endRecording().dispose();
    });

    test('dispose returns a completed future', () async {
      const NoopMirkRenderer r = NoopMirkRenderer();
      await r.dispose();
      // Second dispose is idempotent (no internal flag needed — no state).
      await r.dispose();
      expect(true, isTrue);
    });
  });
}
