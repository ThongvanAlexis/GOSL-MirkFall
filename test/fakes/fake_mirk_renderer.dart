// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';

/// Observable fake `MirkRenderer` for widget + controller suites that
/// need to assert how many times paint/update/dispose were invoked
/// (and with what context) without exercising real GPU paths.
///
/// Wave 0 deliberately keeps the surface minimal — counters + the last
/// observed context — to avoid coupling against Wave 2+ Freezed types.
/// Downstream waves extend with whatever new observable callers need.
///
/// Example:
/// ```dart
/// final fake = FakeMirkRenderer();
/// // ... drive the system under test ...
/// expect(fake.paintCallCount, 1);
/// expect(fake.disposeCallCount, 1);
/// ```
class FakeMirkRenderer implements MirkRenderer {
  /// Number of times [paint] has been called.
  int paintCallCount = 0;

  /// Number of times [update] has been called.
  int updateCallCount = 0;

  /// Number of times [dispose] has been called (idempotent in callers,
  /// but observable here so tests can assert the renderer was actually
  /// disposed by the system under test rather than leaking).
  int disposeCallCount = 0;

  /// Every [MirkPaintContext] passed to [paint], in call order.
  /// Lets tests assert the SUT routed the right zoom + pixel ratio +
  /// session-elapsed values without inspecting private state.
  final List<MirkPaintContext> paintContexts = <MirkPaintContext>[];

  /// Every elapsed [Duration] passed to [update], in call order.
  final List<Duration> updateDurations = <Duration>[];

  /// When `true`, the next [paint] / [update] / [dispose] call throws
  /// [StateError]. Used by error-path tests to validate the SUT's
  /// surfacing behaviour without changing the renderer's surface.
  bool throwOnNextCall = false;

  /// Fake has no SDF — always returns null (BUG-014 contract stub).
  @override
  MirkViewportBbox? get sdfViewport => null;

  /// Resets all counters + recorded contexts. Helpful between sub-cases
  /// inside a single test that wants to share the fake instance.
  void reset() {
    paintCallCount = 0;
    updateCallCount = 0;
    disposeCallCount = 0;
    paintContexts.clear();
    updateDurations.clear();
    throwOnNextCall = false;
  }

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeMirkRenderer.paint forced throw');
    }
    paintCallCount++;
    paintContexts.add(context);
  }

  @override
  void update(Duration elapsed) {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeMirkRenderer.update forced throw');
    }
    updateCallCount++;
    updateDurations.add(elapsed);
  }

  @override
  Future<void> dispose() async {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeMirkRenderer.dispose forced throw');
    }
    disposeCallCount++;
  }
}
