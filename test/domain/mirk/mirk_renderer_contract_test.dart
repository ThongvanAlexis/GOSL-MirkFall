// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Interface-shape regression guard for [MirkRenderer].
//
// Phase 07 locks [MirkRenderer] at exactly 3 public methods (paint,
// update, dispose). Phase 09 supplies the first real renderer without
// expanding this surface — new inputs must ride through
// [MirkPaintContext] rather than as separate methods.
//
// Dart lacks a runtime reflection API under the flutter_test / pure-Dart
// runners (`dart:mirrors` is unavailable on AOT + Flutter). Instead, we
// use a **compile-time witness** [_MinimalWitness] that implements
// [MirkRenderer] by overriding exactly 3 methods. If a future dev adds a
// 4th abstract method to the interface, the analyzer refuses to compile
// the witness (`missing_concrete_implementation`) — the gate fires at
// compile time, not at test run time, which is strictly stronger.
//
// The test body itself calls each method on an instance of the witness
// and asserts the side-effects flipped the expected flags, proving the
// 3-method contract is exercisable end-to-end.

import 'dart:ui';

// `flutter_test` (not `package:test`) — this file imports `dart:ui`
// (`Canvas`, `Size`, `PictureRecorder`) which is only resolvable under
// the Flutter test runtime. Running `dart test test/domain/mirk/` fails
// at the `dart:ui` import boundary because pure-Dart has no Canvas
// surface. The plan-level verification uses `flutter test` for this
// subtree.
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

/// Compile-time witness that [MirkRenderer] has exactly 3 abstract
/// methods: `paint`, `update`, `dispose`. The analyzer enforces the
/// contract — if a 4th method is added to [MirkRenderer] upstream, this
/// class stops compiling with `missing_concrete_implementation`, which
/// fires inside `flutter analyze` and `dart test` before this test even
/// starts.
class _MinimalWitness implements MirkRenderer {
  int paintCalls = 0;
  int updateCalls = 0;
  int disposeCalls = 0;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    paintCalls++;
  }

  @override
  void update(Duration elapsed) {
    updateCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

void main() {
  group('MirkRenderer public surface', () {
    test('_MinimalWitness compiles — interface has exactly 3 abstract methods', () {
      // The compile-time guarantee is the analyzer refusing
      // `missing_concrete_implementation` if a 4th abstract method lands.
      // The runtime assertion below is a sanity check that the witness
      // instance is constructable — if the witness were missing an
      // override it would fail at compile time, not here.
      final _MinimalWitness w = _MinimalWitness();
      expect(w, isA<MirkRenderer>());
    });

    test('paint / update / dispose are the only methods exercised', () async {
      final _MinimalWitness w = _MinimalWitness();

      // Exercise each of the 3 methods with the narrowest valid inputs
      // the signatures allow. `Canvas` / `Size` come from `dart:ui`;
      // a test-only `PictureRecorder` gives us a live Canvas without a
      // Flutter widget tree.
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      w.paint(
        canvas,
        const Size(100, 100),
        MirkPaintContext(
          zoomLevel: 5.0,
          pixelRatio: 2.0,
          sessionElapsed: const Duration(seconds: 1),
          // Phase 09 plan 09-02: extended fields. Test-only minimal bbox + empty visible-tile list
          // exercise the SAME 3-method renderer surface — semantic stays "is there exactly 1 paint
          // call?", new fields just satisfy the now-required Freezed parameters.
          viewportBbox: MirkViewportBbox(south: 0.0, west: 0.0, north: 1.0, east: 1.0),
          visibleTiles: const <VisibleMirkTile>[],
        ),
      );
      w.update(const Duration(milliseconds: 16));
      await w.dispose();

      expect(w.paintCalls, equals(1));
      expect(w.updateCalls, equals(1));
      expect(w.disposeCalls, equals(1));

      // Release the picture so the recorder doesn't leak native resources.
      recorder.endRecording().dispose();
    });

    test('dispose is idempotent (calling twice is not an error)', () async {
      final _MinimalWitness w = _MinimalWitness();
      await w.dispose();
      await w.dispose();
      expect(w.disposeCalls, equals(2));
    });
  });

  group('MirkPaintContext @Assert invariants', () {
    test('rejects negative zoomLevel', () {
      expect(
        () => MirkPaintContext(
          zoomLevel: -0.1,
          pixelRatio: 1.0,
          sessionElapsed: Duration.zero,
          viewportBbox: MirkViewportBbox(south: 0.0, west: 0.0, north: 1.0, east: 1.0),
          visibleTiles: const <VisibleMirkTile>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects zero pixelRatio', () {
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
  });
}
