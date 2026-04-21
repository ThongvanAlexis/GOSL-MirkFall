# lib/domain/mirk/

Pure-Dart domain layer for user-selectable fog rendering styles. No
`package:flutter` / `package:drift` imports (enforced by
`tool/check_domain_purity.dart`).

## Contents

- `mirk_style.dart` — Freezed `MirkStyle` entity (id + displayName +
  `config: MirkStyleConfig`). `@Assert` invariant: non-empty `displayName`.
- `mirk_style_config.dart` — Sealed `MirkStyleConfig` union:
  * `AtmosphericConfig` — base color + procedural noise.
  * `ShaderConfig` — GPU shader asset path.
  * `UnknownConfig` — forward-compatibility fallback that preserves the
    original JSON map verbatim.
- `mirk_style_store.dart` — Abstract `MirkStyleStore` port.
- `mirk_renderer.dart` — Abstract `MirkRenderer` interface (paint / update /
  dispose). Decision D6 seam — exposes `dart:ui` `Canvas` + `Size` only; no
  implementation details leak. Phase 09 supplies the first non-stub
  renderer; `test/domain/mirk/mirk_renderer_contract_test.dart` guards
  against surface growth.
- `mirk_paint_context.dart` — Freezed DTO passed to `MirkRenderer.paint`
  (zoom level, device pixel ratio, session elapsed). Deliberately narrow
  in Phase 07; Phase 09 expands as the real renderer materialises.

## `dart:ui` allowance

`mirk_renderer.dart` imports `dart:ui` for `Canvas` + `Size`. `dart:ui` is
part of the Dart SDK (not Flutter widgets) and is allowed in domain per
`tool/check_domain_purity.dart`'s rules (the gate forbids
`package:flutter/*` and `package:drift/*`, not `dart:ui`).

## Invariants

- `MirkStyleConfig.fromJson(payload)` NEVER throws on an unknown
  `rendererType` — it returns `UnknownConfig(raw: payload)` instead
  (decision D9 — forward compatibility via version-carrying envelopes).
  A malformed body on a KNOWN `rendererType` also falls back to
  `UnknownConfig` so imports from adversarial sources survive.
- Exhaustive `switch` at the render call site is safe because
  `MirkStyleConfig` is sealed; `UnknownConfig` carries enough information
  (the raw map) for a debug renderer to display a placeholder style.
