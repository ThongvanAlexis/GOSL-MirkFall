// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Interface-shape regression guard for [MirkRenderer].
//
// Phase 07 locked [MirkRenderer] at exactly 3 public methods (paint, update,
// dispose). BUG-014 iteration 6 added a 4th member (an SDF-viewport getter) so
// the overlay could compensate camera movement with an a-posteriori Canvas
// transform; Phase 09.1 plan 09.1-03 removed it again — the same-canvas
// `FogLayer` compensates the camera by construction (FOG-07), so the port is
// back to its frozen 3-member shape.
//
// Dart lacks a runtime reflection API under the flutter_test / pure-Dart
// runners (`dart:mirrors` is unavailable on AOT + Flutter). Two guards
// instead:
//
//   1. A **compile-time witness** [_MinimalWitness] that implements
//      [MirkRenderer] by overriding exactly 3 abstract members. If a future
//      dev adds a 4th abstract member, the analyzer refuses to compile the
//      witness (`missing_concrete_implementation`) — the gate fires inside
//      `flutter analyze`, strictly stronger than a runtime check.
//   2. A **source-reflection** test that reads `mirk_renderer.dart` and
//      counts the abstract declarations, so the "exactly 3" number is also
//      asserted at runtime (a witness alone cannot detect a member that
//      gained a default implementation in the abstract class).

import 'dart:io';
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

import '../../_helpers/mirk_paint_context_builder.dart';

/// Compile-time witness that [MirkRenderer] has exactly 3 abstract
/// members: `paint`, `update`, `dispose`. The analyzer enforces the
/// contract — if a 4th member is added to [MirkRenderer] upstream, this
/// class stops compiling with `missing_concrete_implementation`, which
/// fires inside `flutter analyze` and `flutter test` before this test
/// even starts.
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

/// Matches one abstract member declaration line of the port: a return type (possibly
/// generic / nullable), a name, then either a parameter list or a getter, ending in `;`.
final RegExp _abstractMemberPattern = RegExp(r'^\s+[A-Za-z_<>?,\s]+\s(?:get\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:\([^;]*\))?\s*;\s*$', multiLine: true);

void main() {
  group('MirkRenderer public surface', () {
    test('_MinimalWitness compiles — interface has exactly 3 abstract members', () {
      // The compile-time guarantee is the analyzer refusing
      // `missing_concrete_implementation` if a 4th abstract member lands.
      // The runtime assertion below is a sanity check that the witness
      // instance is constructable.
      final _MinimalWitness w = _MinimalWitness();
      expect(w, isA<MirkRenderer>());
    });

    test('source reflection: mirk_renderer.dart declares exactly {paint, update, dispose} and no viewport getter', () {
      final String source = File('lib/domain/mirk/mirk_renderer.dart').readAsStringSync();
      final int classStart = source.indexOf('abstract class MirkRenderer');
      expect(classStart, greaterThanOrEqualTo(0));
      final String classBody = source.substring(classStart);
      final Set<String> memberNames = _abstractMemberPattern.allMatches(classBody).map((RegExpMatch m) => m.group(1)!).toSet();
      expect(memberNames, <String>{'paint', 'update', 'dispose'});
      // The BUG-014 getter surfaced `MirkViewportBbox` through the port; neither the type nor
      // its import may reappear (the same-canvas FogLayer owns camera compensation).
      expect(classBody, isNot(contains('MirkViewportBbox')));
      final Iterable<String> importLines = source.split('\n').where((String line) => line.startsWith('import '));
      expect(importLines, isNot(contains(contains('mirk_viewport_bbox.dart'))));
    });

    test('paint / update / dispose are the only members exercised', () async {
      final _MinimalWitness w = _MinimalWitness();

      // Exercise each of the 3 abstract members with the narrowest valid
      // inputs the signatures allow. `Canvas` / `Size` come from `dart:ui`;
      // a test-only `PictureRecorder` gives us a live Canvas without a
      // Flutter widget tree.
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      w.paint(canvas, const Size(100, 100), buildTestMirkPaintContext(zoomLevel: 5.0, pixelRatio: 2.0, sessionElapsed: const Duration(seconds: 1)));
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
      expect(() => buildTestMirkPaintContext(zoomLevel: -0.1), throwsA(isA<AssertionError>()));
    });

    test('rejects zero pixelRatio', () {
      expect(() => buildTestMirkPaintContext(pixelRatio: 0.0), throwsA(isA<AssertionError>()));
    });

    test('rejects non-positive zoomScale (Phase 09.1 extension)', () {
      expect(() => buildTestMirkPaintContext(zoomScale: 0.0), throwsA(isA<AssertionError>()));
    });
  });
}
