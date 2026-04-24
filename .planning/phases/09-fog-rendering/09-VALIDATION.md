---
phase: 09
slug: fog-rendering
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `.planning/phases/09-fog-rendering/09-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dual: `dart test 1.30.0` (pure-Dart units) + `flutter_test` SDK (widget + render + perf) |
| **Config file** | `dart_test.yaml` at repo root (existing — Wave 0 extends with `mirk-perf` tag) |
| **Quick run command** | `dart test test/domain/mirk test/domain/revealed && flutter test test/infrastructure/mirk test/application/controllers` |
| **Full suite command** | `flutter test && dart test` |
| **Estimated runtime** | ~15 s quick / ~2 min full / +~1 min with `mirk-perf` |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/domain/mirk test/domain/revealed test/infrastructure/mirk` (excludes `mirk-perf`, `soak`, integration tags)
- **After every plan wave:** Run `flutter test && dart test` (full default suite, no perf)
- **Phase gate (pre `/gsd:verify-work`):** full suite + `flutter test --tags mirk-perf` + `flutter test integration_test/`
- **Max feedback latency:** 15 s (quick) — 120 s (full) — 180 s (phase gate)

---

## Per-Task Verification Map

> Populated by `gsd-planner` as tasks are authored. Each task ends with an `<automated>` verify command listed here. Plans name tasks `09-NN-MM`.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-00-01 | 00 | 0 | Wave 0 scaffold | scaffold | `dart analyze lib test tool` | ⬜ Wave 0 | ⬜ pending |
| 09-XX-YY | — | — | MIRK-01..07 | — | see §Requirements → Test Map below | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIRK-01 | GPS fix → reveal mask written within flush interval | integration | `flutter test test/application/controllers/reveal_streaming_controller_test.dart` | ❌ Wave 0 |
| MIRK-01 | `computeRevealMask` bbox-first intersect correctness | unit (Dart) | `dart test test/domain/revealed/reveal_calculator_test.dart` | ⚠️ partial (Phase 03 algebra tests extended) |
| MIRK-01 | Parent-tile boundary split produces two masks | unit (Dart) | `dart test test/domain/revealed/reveal_calculator_parent_boundary_test.dart` | ❌ Wave 0 |
| MIRK-01 | Feather renders at ~10% of radius | widget+golden | `flutter test test/presentation/widgets/mirk_overlay_feather_test.dart` | ❌ Wave 0 |
| MIRK-01 | Initial 20 m reveal at session start (with + without fix) | controller | `flutter test test/application/controllers/active_session_controller_initial_reveal_test.dart` | ❌ Wave 0 (extends existing file) |
| MIRK-02 | `kDefaultRevealRadiusMeters = 25` + flush constants consumed | unit | `dart test test/constants_test.dart` | ⚠️ existing file extended |
| MIRK-04 | Atmospheric is animated (paint output differs across frames) | widget | `flutter test test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart` | ❌ Wave 0 |
| MIRK-04 | Noise is deterministic under seed | unit | `dart test test/infrastructure/mirk/noise/simplex_noise_2d_test.dart` | ❌ Wave 0 |
| MIRK-05 | `MirkRenderer` contract frozen at 3 methods | contract | `flutter test test/domain/mirk/mirk_renderer_contract_test.dart` | ✅ existing (Phase 07) |
| MIRK-05 | Factory dispatches 6 variants exhaustively | unit | `flutter test test/infrastructure/mirk/mirk_renderer_factory_test.dart` | ❌ Wave 0 |
| MIRK-05 | Sealed union dispatch is exhaustive (compile-time) | contract | `flutter analyze --fatal-warnings` | ✅ existing CI gate |
| MIRK-06 | All 4 builtin renderers instantiate without throw | unit | `flutter test test/infrastructure/mirk/builtin_renderers_smoke_test.dart` | ❌ Wave 0 |
| MIRK-06 | Each builtin has a distinct paint output (no accidental dup) | widget+golden | `flutter test test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart` | ❌ Wave 0 |
| MIRK-06 | Each builtin lives in its own file (structural) | unit | `dart test tool/test/check_mirk_variant_file_count_test.dart` | ❌ Wave 0 (new tool script + test) |
| MIRK-07 | Burger menu picker shows 4 options + selects | widget | `flutter test test/presentation/widgets/session_burger_menu_style_selector_test.dart` | ❌ Wave 0 |
| MIRK-07 | Swap persists to `t_sessions.mirk_style_id` | controller | `flutter test test/application/controllers/mirk_style_session_controller_test.dart` | ❌ Wave 0 |
| MIRK-07 | Renderer swaps next-frame, no flash | widget+integration | `flutter test test/presentation/widgets/mirk_overlay_swap_test.dart` | ❌ Wave 0 |
| SC#3 (`MirkRenderer` surface) | `paint/update/dispose` only, no `ui.Image` forced | contract | `mirk_renderer_contract_test.dart` | ✅ existing |
| SC#4 (RepaintBoundary + ≤16 ms) | 50k fixture paint pass stays under budget | perf | `flutter test --tags mirk-perf test/performance/fog_50k_tiles_perf_test.dart` | ❌ Wave 0 |
| SC#4 (RepaintBoundary) | No rebuild cascades to other widgets | widget | `flutter test test/presentation/map_screen_repaint_boundary_test.dart` | ❌ Wave 0 |
| SC#5 (viewport filtering) | Only viewport-intersecting tiles painted | widget | `flutter test test/presentation/map_screen_viewport_filtering_test.dart` | ❌ Wave 0 |
| `kStyleLayerOrder` unchanged | mirk_fog position intact | regression | `flutter test test/presentation/map_style_layer_order_test.dart` | ✅ existing |
| MAP-04 conformance | `MirkOverlay` composites correctly with base map | widget | `flutter test test/presentation/mirk_overlay_composition_test.dart` | ❌ Wave 0 |

---

## Dimensional Coverage

| Dimension | Coverage | Count |
|-----------|----------|-------|
| unit (pure Dart) | `computeRevealMask`, `SimplexNoise2D`, constants, `MirkRendererFactory`, variant file-count tool | 5 |
| widget (flutter_test) | 4 variant renderers, `MirkOverlay` feather + swap + composition, `MapScreen` RepaintBoundary + viewport filter, burger menu picker | ≥8 |
| integration | reveal streaming e2e, `ActiveSessionController` initial reveal, swap+persist+re-read | 3 |
| perf | 50k tiles frame budget ≤16 ms | 1 (tagged `mirk-perf`) |
| contract | `MirkRenderer` 3-method surface, factory exhaustive dispatch, `kStyleLayerOrder` frozen | 3 |
| regression (inertness-guarded) | style-order regression (existing), `kDefaultRevealRadiusMeters` consumed, variant file-count | 3 |

---

## Wave 0 Requirements

New test files and fixtures Phase 09 Wave 0 must scaffold (all stubs + skip markers, bodies filled in later waves):

- [ ] `test/domain/revealed/reveal_calculator_test.dart` — extend (Phase 03 has algebra only)
- [ ] `test/domain/revealed/reveal_calculator_parent_boundary_test.dart` — new
- [ ] `test/infrastructure/mirk/noise/simplex_noise_2d_test.dart` — new
- [ ] `test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/candlelight_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/heavenly_clouds_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/mirk_renderer_factory_test.dart` — new
- [ ] `test/infrastructure/mirk/builtin_renderers_smoke_test.dart` — new
- [ ] `test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart` — new
- [ ] `test/application/controllers/reveal_streaming_controller_test.dart` — new
- [ ] `test/application/controllers/active_session_controller_initial_reveal_test.dart` — extend existing (add group)
- [ ] `test/application/controllers/mirk_style_session_controller_test.dart` — new
- [ ] `test/presentation/widgets/session_burger_menu_style_selector_test.dart` — new
- [ ] `test/presentation/widgets/mirk_overlay_feather_test.dart` — new
- [ ] `test/presentation/widgets/mirk_overlay_swap_test.dart` — new
- [ ] `test/presentation/widgets/mirk_overlay_composition_test.dart` — new
- [ ] `test/presentation/map_screen_repaint_boundary_test.dart` — new
- [ ] `test/presentation/map_screen_viewport_filtering_test.dart` — new
- [ ] `test/performance/fog_50k_tiles_perf_test.dart` — new (tagged `mirk-perf`)
- [ ] `test/fixtures/mirk/fifty_k_tiles_seed.sql` — new (generated by builder)
- [ ] `test/fixtures/mirk/builtin_styles.json` — new (round-trip cross-check)
- [ ] `test/fixtures/mirk/imported_style_valid.json` — new (Phase 13 prep)
- [ ] `test/fixtures/mirk/imported_style_unknown_type.json` — new (Phase 13 prep)
- [ ] `test/fakes/fake_mirk_renderer.dart` — new
- [ ] `test/fakes/fake_reveal_streaming_controller.dart` — new
- [ ] `test/fakes/fake_mirk_style_session_controller.dart` — new
- [ ] `tool/fixtures/build_50k_tiles.dart` — new (fixture generator)
- [ ] `tool/check_mirk_fixture_fresh.dart` — new (CI gate: committed SQL matches builder output)
- [ ] `tool/test/check_mirk_fixture_fresh_test.dart` — new (paired test)
- [ ] `tool/check_mirk_variant_file_count.dart` — new (CI gate: structural enforcement of "1 file per variant")
- [ ] `tool/test/check_mirk_variant_file_count_test.dart` — new (paired test)
- [ ] `dart_test.yaml` — extend with `mirk-perf` tag

*Framework install: none needed; all infrastructure exists.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Atmospheric drift feels "alive" (not distracting, not static) | MIRK-04 | Subjective visual feel; thresholds unprovable in golden | Run on Pixel 4a, open a session, confirm drift at ~10-20s period reads as "mouvant" not jittery; adjust `kMirkNoiseSpeedDefault` until user approves |
| Candlelight warm glow feel | MIRK-06 | Subjective | Night-mode scenario + warm hue approval |
| Heavenly clouds airy feel | MIRK-06 | Subjective | Exploration scenario + light density approval |
| Solid is visibly distinct from atmospheric | MIRK-06 | Structurally enforced via distinct-paint test but visual parity is subjective | Side-by-side comparison during review gate |
| `RepaintBoundary` isolation on real device | SC#4 | DevTools "Highlight Repaints" can only be verified hands-on | Pixel 4a + DevTools overlay; confirm mirk animation does not flash other layers |
| `user_location` puck z-order under mirk | PROJECT.md feel | Platform-view composite order only measurable on real device | Phase 10 review gate checks on real device |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180 s at phase gate
- [ ] `nyquist_compliant: true` set in frontmatter after planner finalizes task map

**Approval:** pending
