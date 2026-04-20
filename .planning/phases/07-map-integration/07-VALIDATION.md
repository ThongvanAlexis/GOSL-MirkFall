---
phase: 07
slug: map-integration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-21
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source of truth for detail: `.planning/phases/07-map-integration/07-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (widget + unit) + `package:test` (pure Dart under `tool/test/`) |
| **Config file** | `analysis_options.yaml`, `pubspec.yaml` (`dev_dependencies`) |
| **Quick run command** | `flutter test --reporter=expanded --exclude-tags=soak` |
| **Full suite command** | `flutter test --reporter=expanded` + `dart test tool/test/` + `dart run tool/check_avoid_maplibre_leak.dart` + `dart run tool/check_avoid_remote_pmtiles.dart` |
| **Estimated runtime** | ~45 s quick / ~3 min full (soak tests tagged `@Tags(['soak'])`, opt-in) |

---

## Sampling Rate

- **After every task commit:** `flutter test --reporter=expanded --exclude-tags=soak` (widget/unit only, ~45 s)
- **After every plan wave:** Full suite including `tool/test/` + both lint checks (~3 min)
- **Before `/gsd:verify-work`:** Full suite green, both `tool/check_*` scripts exit 0, soak test green at least once
- **Max feedback latency:** 45 s

---

## Per-Task Verification Map

*The full Req → Test Type → File → Command matrix (35+ rows) lives in `07-RESEARCH.md` §Validation Architecture. Planner consumes that matrix to fill each task's `<automated>` block and to emit this summary below. Each task MUST reference one row either by filename or by `dart run tool/check_*.dart` invocation.*

| Layer | Covers | Typical Command | File Convention |
|-------|--------|-----------------|-----------------|
| Unit (pure Dart) | MAP-04 resolver logic, MAP-07 sha256 + concat, catalog parse, alpha3 math | `flutter test test/unit/<name>_test.dart` | `test/unit/` |
| Widget (`flutter_test`) | MAP-01 MapScreen, MAP-02 attribution, MAP-06 download screen, MAP-08 manage screen, MAP-03 FakeMapView | `flutter test test/widget/<name>_test.dart` | `test/widget/` |
| Integration (on-device) | MAP-01 asset-copy first launch, MAP-07 atomic commit soak | `flutter test integration_test/<name>_test.dart` | `integration_test/` |
| Custom lint | MAP-03 (`avoid_maplibre_leak`), MAP-04 (`avoid_remote_pmtiles`) | `dart run tool/check_avoid_maplibre_leak.dart`, `dart run tool/check_avoid_remote_pmtiles.dart` | `tool/check_*.dart` + `tool/test/check_*_test.dart` |
| Doc audit | MAP-09 `DEPENDENCIES.md` audit entries | `dart run tool/check_dependencies.dart` (existing from Phase 01) | `tool/` |
| Soak (`@Tags(['soak'])`) | MAP-07 kill-during-write invariant | `flutter test --tags=soak integration_test/download_soak_test.dart` | `integration_test/` |

*Status per task: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky — tracked in `07-STATE.md` during execution.*

---

## Wave 0 Requirements

Wave 0 must create test stubs, fake doubles, and the lint scaffolding BEFORE any production code lands. Matches Phase 03/05 convention.

- [ ] `lib/infrastructure/map/fake_map_view.dart` — `FakeMapView` in-memory implementation of `MapView` (MAP-03)
- [ ] `test/fakes/fake_pmtiles_source.dart` — in-memory `PmtilesSource` double (MAP-04)
- [ ] `test/fakes/fake_http_client.dart` — recording/replay `HttpClient` double with configurable Range support (MAP-07)
- [ ] `test/fixtures/world.pmtiles` — 1 KB synthetic PMTiles header fixture
- [ ] `test/fixtures/catalog_sample.json` — 2-country catalog fixture (FRA + USA, 3 parts each, stable sha256)
- [ ] `test/fixtures/chunks/` — synthetic binary chunks with recorded sha256
- [ ] `tool/check_avoid_maplibre_leak.dart` — lint script (exit 0/1/2 contract)
- [ ] `tool/check_avoid_remote_pmtiles.dart` — lint script (exit 0/1/2 contract)
- [ ] `tool/test/check_avoid_maplibre_leak_test.dart` — paired test
- [ ] `tool/test/check_avoid_remote_pmtiles_test.dart` — paired test
- [ ] `.github/workflows/ci.yml` `gates` job — add both `dart run tool/check_*.dart` steps
- [ ] `pubspec.yaml` — add `maplibre_gl: 0.25.0` and `crypto: <pinned>` exact-pin, run `flutter pub get`, commit `pubspec.lock`
- [ ] `DEPENDENCIES.md` — audit entries for `maplibre_gl 0.25.0` and `crypto <version>` (MAP-09)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Airplane-mode visual check: carte visible sans réseau | MAP-01 | Requires physical radio shutoff, device-level | Lancer app sur device, activer mode avion, reboot app, vérifier que la carte s'affiche z0-5 et que le pan/zoom reste fluide |
| Attribution visibility on MapScreen + À propos | MAP-02 | Visual/typographic check | Screenshot MapScreen bas-droite : `© OpenStreetMap contributors · © Protomaps` ; ouvrir À propos et confirmer liens copyright cliquables |
| Mirk overlay layer order (stub present, paints nothing) | MAP-05 | Visual absence-of-rendering check | Inspecter style.json via debug menu, confirmer ordre des layers: `base_* → pois → mirk_fog (background, transparent) → user_location`. Aucune teinte visible à l'écran. |
| Disk space freed after country delete | MAP-08 | OS-level filesystem check | Install FRA, note disk usage ; supprimer FRA depuis écran gestion ; vérifier que `<app_support>/maps/countries/fra.pmtiles` a disparu et espace libéré (via Settings natif) |
| iOS sideload smoke (CI iOS IPA) | MAP-01, MAP-07 | Requires physical iOS device via SideStore | Sideload IPA après merge, premier lancement: world map copié ; télécharger FRA mini (stub), vérifier commit atomique |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (fakes + lints + fixtures + deps audit)
- [ ] No watch-mode flags (`--watch` forbidden)
- [ ] Feedback latency < 45 s (quick suite)
- [ ] Custom lint scripts exit 0 on green tree; exit 1 on violation; exit 2 on invocation error
- [ ] Soak test tagged `@Tags(['soak'])` and excluded from quick run
- [ ] `nyquist_compliant: true` set in frontmatter after planner ratifies

**Approval:** pending
