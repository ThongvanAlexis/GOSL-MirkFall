// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

/// Factory mapping a [MirkStyleConfig] sealed variant to a concrete
/// [MirkRenderer] implementation.
///
/// Phase 09 Wave 0 scaffold. Wave 4 (plan 09-05) rewrites [create] with a
/// sealed switch that exhaustively dispatches AtmosphericConfig →
/// AtmosphericMirkRenderer, SolidConfig → SolidFillMirkRenderer,
/// CandlelightConfig → CandlelightMirkRenderer, HeavenlyCloudsConfig →
/// HeavenlyCloudsMirkRenderer, ShaderConfig → ShaderMirkRenderer,
/// UnknownConfig → fallback (NoopMirkRenderer or AtmosphericMirkRenderer
/// with default config — Wave 4 decides).
class MirkRendererFactory {
  const MirkRendererFactory();

  /// Builds the [MirkRenderer] matching [config].
  ///
  /// TODO(09-05): replace this stub with the sealed-switch dispatch.
  MirkRenderer create(MirkStyleConfig config) => throw UnimplementedError('Wave 4 — plan 09-05');
}
