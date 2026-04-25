---
phase: 09-fog-rendering
type: phase-aggregate
plans-complete: 10
plans-total: 10
status: closed
started: 2026-04-25
completed: 2026-04-25
duration: ~6 hours wall-clock (10 plans, 7 waves)
requirements-completed: [MIRK-01, MIRK-02, MIRK-04, MIRK-05, MIRK-06, MIRK-07]
---

# Phase 09 — Fog Rendering — Phase Summary

**Phase 09 closed 2026-04-25. 10/10 plans complete (revision B5 split: original 09-01 → 09-01 + 09-01b + 09-01c). End-to-end visual loop closed: GPS fix → reveal mask → DB → Riverpod provider chain → MirkOverlay paints fog. 4 builtin renderers shipped (atmospheric default + solid + candlelight + heavenly_clouds). MirkRenderer surface frozen at 3 methods. Hand-rolled simplex held — zero new dependencies. RepaintBoundary isolation + viewport filtering + 50k-tile perf probe regression-tested.**

## Requirements coverage

| REQ-ID | Description | Delivered by |
|--------|-------------|--------------|
| MIRK-01 | Reveal streaming + initial 20 m + computeRevealMask body | 09-03 (computeRevealMask), 09-06 (RevealStreamingController + 20 m initial reveal hook), 09-07 (MirkInitialRevealFade visual fade-in) |
| MIRK-02 | `kDefaultRevealRadiusMeters` constant (25 m) | 09-01 (constants), 09-06 (consumed by RevealStreamingController) |
| MIRK-04 | Animated atmospheric default renderer | 09-04 (`AtmosphericMirkRenderer`), 09-05 (factory + `kBuiltinMirkStyles` registry default = atmospheric) |
| MIRK-05 | Factory + registry + sealed exhaustiveness | 09-05 (`MirkRendererFactory` + `kBuiltinMirkStyles` + `UnknownConfig` fallback) |
| MIRK-06 | 4 concrete renderer files, each visually distinct | 09-04 (atmospheric / solid / candlelight / heavenly_clouds) + 09-08 (CI gate `check_mirk_variant_file_count.dart`) |
| MIRK-07 | Burger-menu picker + `MirkStyleSessionController` | 09-06 (`MirkStyleSessionController`), 09-07 (`MirkStylePickerSheet` + burger-menu wire-up) |

Phase 09 deferred items (still deferred at close) :

- **MIRK-08, MIRK-09** — Import/delete of user mirk styles → Phase 13.
- **MIRK-10** — Per-session mirk style selection (already partially landed via Phase 09's `mirkStyleSessionControllerProvider` and the `t_sessions.mirk_style_id` schema column added in plan 09-05; Phase 13 completes the JSON-import side).
- **OPT-02, OPT-03, OPT-04** — Global options screen (reveal radius, active style, imported-style management) → Phase 13.
- **MARK-07** — Marker under-mirk alpha 30 % composite → Phase 11 (architecture documented in `lib/infrastructure/map/style_layer_order.dart` docstring).
- **ShaderMirkRenderer body** — Phase 13 target (currently `UnimplementedError` stub satisfying sealed-switch exhaustiveness).

## Architectural decisions log

(Final outcomes — see individual plan SUMMARYs for the full rationale chain.)

| Decision | Outcome | Plan |
|----------|---------|------|
| Rendering strategy: Flutter `CustomPainter` overlay vs MapLibre `fill` layer | Flutter overlay above MapLibre platform view (sibling in Stack, not interleaved). Trade-off: full Canvas API + `MaskFilter.blur` at the cost of one extra composition. | 09-RESEARCH §Rendering Strategy Decision; mounted in MapScreen by 09-07 |
| Noise function | Hand-rolled `SimplexNoise2D` (Ken Perlin 2001 algorithm, public-domain port). Zero new dependency. | 09-02 |
| Registration pattern | Registry + factory + sealed exhaustiveness. New variant = 4-file edit (sealed config + new renderer file + factory case + registry entry). | 09-05 |
| Sub-tile grid size | 64 × 64 (4096 cells = 512 bytes per parent tile). Inherited from Phase 03 D3 decision. | constants.dart `kRevealedTileSubgridSize` |
| Reveal flush cadence | 2 s OR 20 fixes (first-to-fire). Lower than ROADMAP's 5 s / 50 — favours fog freshness over write-batching efficiency. | 09-06 (`kRevealFlushIntervalSeconds = 2`, `kRevealFlushMaxFixes = 20`) |
| Default reveal radius | 25 m around current position; 20 m initial disc on session start. | constants.dart (`kDefaultRevealRadiusMeters = 25.0`, `kInitialRevealRadiusMeters = 20`) |
| `MirkRenderer` surface | 3 methods exactly (`paint`, `update`, `dispose`). Compile-time-witnessed by contract test. | Phase 07 lock; preserved across all of Phase 09 |
| `MirkPaintContext` extension | Single Wave 2 extension event (3 → 6 fields). `viewportBbox`, `visibleTiles`, nullable `currentFix` added; downstream plans 09-04 / 09-07 consume verbatim, no second re-extension. | 09-02 (revision B3) |
| `MirkViewportBbox` shape | 4 doubles (`south`, `west`, `north`, `east`). Zoom NOT carried (lives on `MirkPaintContext.zoomLevel` via `MapViewportZoom`). Antimeridian wrap permitted via `east < west` when `west > 0 && east < 0`. | 09-02, 09-07 (revision S4 rejected re-extension) |
| Reveal pipeline circular-dep avoidance | `revealStreamingControllerProvider` is family-style on `SessionId`. The earlier "watch active session" design produced `CircularDependencyError` since `ActiveSessionController._onFix` reads the reveal provider too. Caller resolves the active id at the call site. | 09-06 |
| `t_sessions.mirk_style_id` FK semantics | `ON DELETE SET NULL` — deleting an imported style degrades the session to renderer-side default (atmospheric) rather than orphaning or cascade-deleting the session. Built-in styles protected from deletion at app layer in Phase 13 (OPT-04). | 09-05 V3→V4 migration |
| Built-in style IDs | Deterministic literal IDs (`style_builtin_atmospheric`, `style_builtin_solid`, `style_builtin_candlelight`, `style_builtin_heavenly_clouds`) NOT ULIDs. The `style_builtin_` prefix doubles as a Phase 13 OPT-04 "delete-if-not-builtin" marker. | 09-05 |
| Active renderer lifecycle | `activeMirkRendererProvider` is NOT `keepAlive: true`. `ref.onDispose(renderer.dispose)` fires on session change OR style swap. `MirkStyleSessionController.select()` invalidates the provider after a successful DB write to force a fresh renderer. | 09-05, 09-06 |
| `MirkInitialRevealFade` controller | Dedicated `AnimationController` decoupled from the main `MirkOverlay` Ticker. Triggered by Idle → Tracking transition via `ref.listenManual` + `_hasFadedIn` idempotence guard. 500 ms `Curves.easeOut`. | 09-07 (revision B4) |
| `RepaintBoundary` placement | Wraps `MirkInitialRevealFade(MirkOverlay)` directly in `MapScreen`'s Stack — narrowest legal scope around the moving widget. NOT around the whole Stack (would not isolate the platform view's display list). | 09-07 |
| Test pump cadence vs `MirkOverlay` Ticker | `pumpAndSettle` deadlocks on the always-on Ticker. ALL test sites pumping a tree containing `MirkOverlay` use `tester.pump() + tester.pump(Duration)` — documented in-tree. | 09-07 (deviation #3 propagated to 09-08 perf test) |
| 50k-fixture format | Gzipped `.sql.gz` (~4 MB). Bitmap density 1 % keeps gzip ratio high while preserving full per-cell iteration cost in the renderer's hot loop. Plan-anticipated fallback (RESEARCH §Format) when raw SQL > 20 MB. | 09-08 |
| Frame-budget assertion | 150 ms widget-test ceiling (not 25 ms quoted in the plan). CPU `MaskFilter.blur` dominates per-frame cost in widget-test env without Impeller / GPU. Real-device 16 ms target validated by Phase 10 review gate. | 09-08 (deviation #3) |

## Test counts

| Suite | Phase 09 added | Phase 09 close total |
|-------|----------------|---------------------|
| Unit (`flutter test test/domain/`, `test/application/`, `test/infrastructure/`) | ~80 new (across plans 09-02, 09-03, 09-05, 09-06) | included in 918 default-suite green |
| Widget (`test/presentation/widgets/`, `test/presentation/screens/`) | ~22 new (mirk_overlay_*, mirk_initial_reveal_fade, mirk_style_picker_sheet, session_burger_menu_style_selector, map_screen_repaint_boundary, map_screen_viewport_filtering) | included in 918 default-suite green |
| Contract (`test/domain/mirk/mirk_renderer_contract_test.dart`) | preserved verbatim (Phase 07 lock) | 1 |
| Perf (`test/performance/fog_50k_tiles_perf_test.dart`) | 2 new tests (avg ≤ 150 ms + viewport filter ≤ 20 calls) | runs under `--tags mirk-perf` |
| Integration (`integration_test/`) | unchanged from Phase 07 baseline | 14 |
| **Default suite** | — | **918 / 918 pass** at Phase 09 close |

## File layout — `lib/infrastructure/mirk/` (final)

```
lib/infrastructure/mirk/
├── README.md                          (rewritten 09-08)
├── atmospheric_mirk_renderer.dart     (09-04)
├── solid_fill_mirk_renderer.dart      (09-04)
├── candlelight_mirk_renderer.dart     (09-04)
├── heavenly_clouds_mirk_renderer.dart (09-04)
├── shader_mirk_renderer.dart          (Phase 07 stub, unchanged)
├── noop_mirk_renderer.dart            (Phase 07, unchanged)
├── mirk_renderer_factory.dart         (09-05)
├── builtin_mirk_styles.dart           (09-05)
├── mirk_projection.dart               (09-04)
├── tile_cell_iteration.dart           (09-04)
└── noise/
    └── simplex_noise_2d.dart          (09-02)
```

## Revision ledger

(B = blocker; S = should; N = nit; numbering per individual plan reviews.)

| Revision | Resolution | Plan |
|----------|------------|------|
| **B1** — `MirkPaintContext` extended twice | Resolved by single Wave 2 extension (3 → 6 fields). 09-04/07 consume verbatim. | 09-02 |
| **B2** — `MirkStyleConfig` 6-variant union not landed | Resolved — atmospheric extended (2 → 8 params, all `@Default`-guarded) + solid + candlelight + heavenly_clouds + shader + unknown. | 09-02 |
| **B3** — `VisibleMirkTile` deferred to Wave 3 | Promoted to Wave 2 alongside MirkPaintContext, single Freezed extension event. | 09-02 |
| **B4** — Initial reveal fade-in not split off | `MirkInitialRevealFade` widget shipped as a separate ConsumerStatefulWidget with dedicated AnimationController. | 09-07 |
| **B5** — 09-01 too large for one plan | Split into 09-01 (constants + dart_test.yaml + style_layer_order docstring + constants_test) + 09-01b (lib/ scaffolds) + 09-01c (test/ + tool/ scaffolds). | 09-01, 09-01b, 09-01c |
| **S1** — `LocationStream.lastKnownFix` cache absent | Port extended with `Fix? get lastKnownFix`; `GeolocatorLocationStream` populates on every accepted emission, survives `dispose()`. | 09-06 |
| **S2** — `mapViewportProvider` did not exist | Created as new class-based `@Riverpod(keepAlive: true)` notifier publishing `MirkViewportBbox?` with 50 ms debounce. | 09-07 |
| **S3** — Test harness + fake extensions | `test/presentation/_harness.dart` (TestMapScreenHarness) + `test/fakes/fake_revealed_tile_store.dart` extensions (`seed1000TilesEurope` + `findByParentCallCount`). | 09-08 |
| **S4** — `MirkViewportBbox` re-extension with zoom | REJECTED — zoom lives on `MirkPaintContext.zoomLevel` via `MapViewportZoom`. No second Freezed re-open. | 09-07 |
| **S6** — Per-task perf-test sampling | (no specific finding logged at this level — folded into S7) | — |
| **S7** — Perf-test sampling latency exceeds 09-VALIDATION 180 s | Documented as phase-gate artefact (NOT per-task sampling). Runs once at phase close + once at Phase 10 review gate. `@Tags(['mirk-perf'])` excludes from default suite when filtered. | 09-08 |
| **S8** — (no specific finding logged) | — | — |
| **N2** — `heavenly_clouds` filename vs `heavenly` JSON discriminator | Intentional asymmetry documented in mirk README. Filename uses long form for clarity; JSON discriminator matches user-facing UI label. | 09-02, 09-08 |

## Handoff to Phase 10 review gate

Phase 10 will audit:

1. **Real-device perf probe** — Pixel 4a (Android 13) + iPhone 17 Pro (iOS 18). Frame time on the same 50k fixture (16 ms target). Compare against the Phase 09 widget-test baseline of ~90 ms (CPU MaskFilter.blur).
2. **DevTools RepaintBoundary validation** — visual confirmation via "Highlight Repaints" overlay during a live session that the overlay's Ticker isolation actually holds across the platform view boundary.
3. **Visual approval of 4 builtin variants** — atmospheric / solid / candlelight / heavenly_clouds rendered on real hardware. Identifying which variant is currently painted via the burger-menu picker.
4. **Marker under-mirk composite architecture** — Phase 11 MARK-07 alpha-30 % composite path documented in `style_layer_order.dart` docstring. No code change in Phase 10; just architectural review.
5. **Seam non-leakage** — `MirkRenderer` 3-method surface preserved (compile-time witness `mirk_renderer_contract_test.dart`). `MirkPaintContext` not extended outside Phase 09 (single Wave 2 event). `MirkViewportBbox` stays at 4 doubles.
6. **50k-fixture freshness gate** — committed `fifty_k_tiles_seed.sql.gz` byte-stable across CI runners. Builder determinism + gzip mtime=0 contract.
7. **Battery impact (POC)** — qualitative observation during a 30 min walk session on Pixel 4a with the atmospheric renderer running. No quantitative regression-test.

## Known Phase 09 deferrals confirmed still deferred

- **`ShaderMirkRenderer` body** — Phase 13 target. Currently `UnimplementedError` stub satisfying sealed-switch exhaustiveness.
- **MIRK-08, MIRK-09** — Import/delete of user-imported mirk styles → Phase 13.
- **OPT-02, OPT-03, OPT-04** — Global options screen (reveal radius, active style, imported-style list) → Phase 13.
- **MARK-07** — Marker under-mirk alpha 30 % composite → Phase 11 (architecture documented in `style_layer_order.dart`).

## Performance metrics (per plan)

| Plan | Duration | Tasks | Files | Commits |
|------|----------|-------|-------|---------|
| 09-01 | 6 min | 3 | 4 | — |
| 09-01b | ~12 min | 3 | 21 | — |
| 09-01c | 17 min | 3 + 1 chore | 31 created + 3 modified | — |
| 09-02 | 28 min | 3 (TDD) | 13 | — |
| 09-03 | 6 min | 2 | 4 | — |
| 09-04 | 12 min | 4 | 14 | — |
| 09-05 | 33 min | 4 (Task 0 + TDD on Task 1) | 21 | 6 atomic |
| 09-06 | ~34 min | 4 (TDD on Task 1) | 23 | 4 atomic |
| 09-07 | 24 min | 5 (all TDD-tagged) | 22 | 6 atomic |
| 09-08 | ~32 min | 3 (TDD on Task 1) | 11 | 3 atomic |

**Phase 09 total wall-clock: ~3.5-4 hours active execution time** (with research + planning + review-gate prep folded into earlier phases not counted here).

---
*Phase: 09-fog-rendering*
*Type: phase aggregate*
*Closed: 2026-04-25*
