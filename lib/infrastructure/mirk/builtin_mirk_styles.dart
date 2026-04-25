// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

/// Descriptor for a built-in mirk style — id, French display name, and
/// a factory that produces a fresh default [MirkStyleConfig] on every
/// call.
///
/// Plain Dart class (NOT Freezed): this is an internal registry record,
/// not a serialised entity. Keeping it as a plain class avoids the
/// codegen tax for a type that has no JSON / equality / copyWith needs.
///
/// Why `MirkStyleConfig Function()` rather than a `const MirkStyleConfig`
/// literal? Two reasons:
/// * Freezed configs ARE `const` so any of `const AtmosphericConfig()`
///   etc. is a const expression, and a `MirkStyleConfig Function()`
///   wrapper around it costs nothing at runtime.
/// * Wrapping in a factory lets Phase 13 extend with runtime parameters
///   (e.g. user-imported shader byte sources) without breaking the
///   registry shape.
class BuiltinMirkStyleDescriptor {
  /// Constructs a descriptor with [id], [displayName], and the
  /// [defaultConfig] factory.
  const BuiltinMirkStyleDescriptor({
    required this.id,
    required this.displayName,
    required this.defaultConfig,
  });

  /// Deterministic id — `style_builtin_<variant>`. Doubles as a
  /// DB-layer marker of "built-in" for the Phase 13 OPT-04
  /// delete-if-not-builtin semantics.
  final String id;

  /// French display name surfaced by the burger-menu picker.
  final String displayName;

  /// Factory returning a fresh default [MirkStyleConfig] for the
  /// variant. Never returns a cached value.
  final MirkStyleConfig Function() defaultConfig;
}

/// Registry of the 4 built-in mirk styles in canonical display order.
///
/// Order matters — `builtinMirkStylesProvider` (plan 09-05 Task 2) seeds
/// `t_mirk_styles` in this order, and the burger-menu picker (plan
/// 09-07) lists them in this order. Atmospheric is the default first
/// item per CONTEXT.md §Identité visuelle.
///
/// Adding a 5th built-in requires editing exactly THREE files:
/// 1. `lib/domain/mirk/mirk_style_config.dart` — add the sealed variant.
/// 2. `lib/infrastructure/mirk/builtin_mirk_styles.dart` — append a
///    descriptor here.
/// 3. `lib/infrastructure/mirk/mirk_renderer_factory.dart` — extend the
///    sealed switch with the new case.
///
/// The factory's exhaustive switch is what enforces the third edit
/// structurally (analyzer error). MIRK-05 "ajouter un style = nouveau
/// fichier, zéro core modification" is satisfied: each variant ALSO
/// gets a new file in `lib/infrastructure/mirk/<variant>_mirk_renderer.dart`.
const List<BuiltinMirkStyleDescriptor> kBuiltinMirkStyles =
    <BuiltinMirkStyleDescriptor>[
      BuiltinMirkStyleDescriptor(
        id: 'style_builtin_atmospheric',
        displayName: 'Atmospheric (défaut)',
        defaultConfig: _atmosphericDefault,
      ),
      BuiltinMirkStyleDescriptor(
        id: 'style_builtin_solid',
        displayName: 'Solide',
        defaultConfig: _solidDefault,
      ),
      BuiltinMirkStyleDescriptor(
        id: 'style_builtin_candlelight',
        displayName: 'Lueur de bougie',
        defaultConfig: _candlelightDefault,
      ),
      BuiltinMirkStyleDescriptor(
        id: 'style_builtin_heavenly_clouds',
        displayName: 'Nuages célestes',
        defaultConfig: _heavenlyCloudsDefault,
      ),
    ];

// Top-level functions rather than closures so the descriptor's
// `defaultConfig` field can be `const`-friendly via tear-off and the
// registry list can stay a `const` literal at the top level.

MirkStyleConfig _atmosphericDefault() => const AtmosphericConfig();

MirkStyleConfig _solidDefault() => const SolidConfig();

MirkStyleConfig _candlelightDefault() => const CandlelightConfig();

MirkStyleConfig _heavenlyCloudsDefault() => const HeavenlyCloudsConfig();
