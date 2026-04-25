// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';

/// GPU shader-backed fog renderer.
///
/// **Phase 13 implementation.** Phase 09 only registers the type so the
/// `MirkStyleConfig` sealed-union exhaustiveness check compiles; the
/// renderer body lands in Phase 13. Wave 4 (plan 09-05) wires the factory
/// to instantiate this class for `ShaderConfig` payloads — at that point
/// callers may choose to wrap the call in a try/catch fallback.
///
// TODO(13): accept `ShaderConfig config` and load the .frag asset.
class ShaderMirkRenderer implements MirkRenderer {
  ShaderMirkRenderer();

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) => throw UnimplementedError('Phase 13 — ShaderConfig body');

  @override
  void update(Duration elapsed) => throw UnimplementedError('Phase 13 — ShaderConfig body');

  @override
  Future<void> dispose() async => throw UnimplementedError('Phase 13 — ShaderConfig body');
}
