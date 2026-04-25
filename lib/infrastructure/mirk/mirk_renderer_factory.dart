// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'atmospheric_mirk_renderer.dart';
import 'candlelight_mirk_renderer.dart';
import 'heavenly_clouds_mirk_renderer.dart';
import 'shader_mirk_renderer.dart';
import 'solid_fill_mirk_renderer.dart';

final Logger _log = Logger('infrastructure.mirk.factory');

/// Resolves a [MirkStyleConfig] to its concrete [MirkRenderer].
///
/// The switch is exhaustive at compile time — adding a new sealed
/// variant to [MirkStyleConfig] triggers a "missing case" analyzer
/// error here. This is the load-bearing structural enforcement for
/// MIRK-05 "adding a style = editing 3 core files" — the sealed union,
/// the registry constant ([kBuiltinMirkStyles]), and THIS factory.
///
/// ## Fallback semantics
///
/// * [ShaderConfig] — Phase 13 body. Returns a [ShaderMirkRenderer]
///   stub whose `paint()` throws `UnimplementedError`. No V1.0 user
///   path reaches this branch (the burger menu only surfaces the 4
///   builtins; user-imported shaders ship with Phase 13's MIRK-08), but
///   the factory must wire it for sealed-switch exhaustiveness.
/// * [UnknownConfig] — cross-version forward-compat fallback (Phase 03,
///   decision D9). The local app cannot render what it does not
///   understand, so we degrade to the default atmospheric experience
///   rather than crash. Logged at creation time via
///   `Logger('infrastructure.mirk.factory')` so debug builds surface
///   the degradation in `<app_documents_dir>/logs/`.
class MirkRendererFactory {
  const MirkRendererFactory();

  /// Builds the [MirkRenderer] matching [config].
  ///
  /// The sealed-switch is exhaustive — `flutter analyze` rejects this
  /// file when a new variant is added to [MirkStyleConfig] without a
  /// corresponding case here.
  MirkRenderer create(MirkStyleConfig config) {
    return switch (config) {
      AtmosphericConfig() => AtmosphericMirkRenderer(config),
      SolidConfig() => SolidFillMirkRenderer(config),
      CandlelightConfig() => CandlelightMirkRenderer(config),
      HeavenlyCloudsConfig() => HeavenlyCloudsMirkRenderer(config),
      ShaderConfig() => ShaderMirkRenderer(config),
      UnknownConfig() => _atmosphericFallback(config),
    };
  }

  /// Forward-compat fallback — logs the unknown payload before handing
  /// back a default-atmospheric renderer so the user still sees the
  /// fog rather than a black/empty screen.
  AtmosphericMirkRenderer _atmosphericFallback(UnknownConfig config) {
    _log.warning(
      'UnknownConfig encountered (rendererType not recognized by this app '
      'version) — degrading to default AtmosphericMirkRenderer. '
      'raw=${config.raw}',
    );
    return AtmosphericMirkRenderer(const AtmosphericConfig());
  }
}
