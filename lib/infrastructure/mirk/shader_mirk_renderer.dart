// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';

/// GPU shader-backed fog renderer.
///
/// **Phase 13 implementation.** Phase 09 only registers the type so the
/// `MirkStyleConfig` sealed-union exhaustiveness check compiles; the
/// renderer body lands in Phase 13. Wave 4 (plan 09-05) wires the factory
/// to instantiate this class for `ShaderConfig` payloads — no V1.0 user
/// path reaches it (the burger menu only exposes the 4 atmospheric /
/// solid / candlelight / heavenly_clouds builtins), but the factory must
/// still wire it for sealed-switch exhaustiveness.
///
/// The constructor accepts the originating [ShaderConfig] so Phase 13
/// can read `shaderAssetPath` without a follow-up surface change. The
/// stored config is unused in Phase 09 but documented as part of the
/// surface contract.
//
// TODO(13): load the .frag asset referenced by `config.shaderAssetPath`,
// compile the FragmentProgram, and paint per-frame.
class ShaderMirkRenderer implements MirkRenderer {
  /// Constructs a stub renderer carrying [config]. Until Phase 13 lands
  /// the body, every method throws `UnimplementedError`.
  ShaderMirkRenderer(this.config);

  /// The originating shader-style config — `shaderAssetPath` is the
  /// asset Phase 13 will load.
  final ShaderConfig config;

  /// Shader stub has no SDF — always returns null (BUG-014 contract stub).
  @override
  MirkViewportBbox? get sdfViewport => null;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) => throw UnimplementedError('Phase 13 — ShaderConfig body');

  @override
  void update(Duration elapsed) => throw UnimplementedError('Phase 13 — ShaderConfig body');

  @override
  Future<void> dispose() async => throw UnimplementedError('Phase 13 — ShaderConfig body');
}
