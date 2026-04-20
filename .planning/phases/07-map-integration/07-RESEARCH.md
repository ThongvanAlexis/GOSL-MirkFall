// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

# Phase 07: Map Integration — Research

**Researched:** 2026-04-21
**Domain:** Offline vector map rendering (MapLibre + PMTiles) behind a domain-level `MapView` seam, with a robust GitHub-hosted per-country download pipeline (binary chunks + sha256 + concat + atomic commit) and a zero-network-for-tiles CI gate.
**Confidence:** HIGH on the critical path (maplibre_gl 0.25.0 PMTiles support, `pmtiles://file://…` URI, GitHub Releases range support, Protomaps basemaps-assets licensing). MEDIUM on a few specifics (exact iOS Documents vs. Application Support PMTiles pathing; whether `addSource` accepts a pre-built `VectorSource` with a `pmtiles://` URL without touching style JSON). See §Open Questions.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

> This section is copied verbatim from `07-CONTEXT.md`. The planner MUST honor these constraints; they are locked decisions, not suggestions.

### Locked Decisions

**Navigation & map entry**
- Route `/map` autonome dans `lib/presentation/screens/map_screen.dart` — carte full-screen, accessible depuis SessionListScreen une fois qu'au moins une session existe.
- Map aussi intégrée dans `SessionDetailScreen` (active + stoppée). Deux entrées vers le même widget `MapView`, DI des fakes en widget tests.
- Carte non accessible avant qu'une session n'existe (funnel vers création session, pattern Phase 05).
- Banner session active cross-route : pattern Phase 05 inchangé — tap = `/sessions/:id` (pas de deep-link vers `/map` depuis le banner).
- Section "Cartes" dans `/settings` : extend l'écran existant avec 2 ListTile — "Télécharger une carte" → `/maps/download`, "Gérer les cartes installées" → `/maps/manage`.
- Import/Export style dans `/settings` : 2 ListTile supplémentaires vers écrans placeholder `/styles/import`, `/styles/export` ("En construction — disponible Phase 13").

**Session map UX (in-session burger menu)**
- Carte full-screen sur `/map` + `/sessions/:id` (pas d'AppBar visible).
- Burger menu top-left, bouton rond ~48dp, vertical drawer slide-in depuis la gauche (Material `Drawer`).
- Contenu drawer : Changer le style / Prendre une photo (unwired) / Placer un marker (unwired) / séparateur / Position lat,lon / Distance parcourue / Durée session.
- Landscape ET portrait : drawer width responsive (75% portrait, 40% landscape).
- FAB follow-me crosshair bas-droit, défaut ON à l'ouverture de session. Pan manuel désactive auto.

**Session opening behavior**
- À l'ouverture de `/map` ou `/sessions/:id` (session active) : camera sur position courante, Z=13, follow-me ON.
- Reveal initial 20m autour de l'utilisateur **skippé Phase 07** (data-only intent capturé, Phase 09 livre via son premier fix).

**Catalog + world bundle + hosting**
- Catalog = asset bundlé `assets/maps/catalog.json` (132 KB, 192+ pays). **Pas de `kMapCatalogUrl`**.
- Schema catalog : `countries[].alpha3/name/parts[]/reassembled{sha256,size}`.
- Granularité pays = ISO 3166-1 alpha-3 (`fra`, `deu`, `usa`, `jpn`…). Pas de subdivisions V1.0.
- Version globale = tag du GitHub Release (ex `v20260419`). Stockée dans `installed.json` per-pays (champ `pmtiles_version`).
- World bundle = `assets/maps/world.pmtiles` copié vers `<app_support>/maps/world.pmtiles` au first launch (check existence + sha256 verify).
- `kMapCatalogUrl` supprimé → `kMapCatalogAssetPath = 'assets/maps/catalog.json'`.

**Pipeline download pays**
- Chunks = binaire brut, pas ZIP. Reassemblage = concat binaire. Pas d'`archive` package.
- Protocole atomique 7 étapes : download séquentiel / sha256 par chunk / concat / sha256 global / rename atomique / update `installed.json` / cleanup staging.
- Queue FIFO 1-à-la-fois, persistée dans `<app_support>/maps/download_queue.json`.
- UX download en arrière-plan (Riverpod keepAlive). Badge AppBar progress.
- Progress bar global + bytes, throttled 200–500 ms.
- Pause manuelle + reprise auto sur coupure réseau (backoff exp 1s/5s/30s, max 3 tentatives). HTTP Range si serveur le permet, sinon re-download du chunk entier.
- Check disk space avant download (refuse si free < sizeBytesTotal × 1.1).
- Détection d'update via badge "Mise à jour disponible" au bump du catalog tag.

**Map screen UX**
- Style Phase 07 = Protomaps basemaps officiel variante neutre (light ou white). `assets/maps/style.json`.
- Glyphs + sprites bundlés en asset (fonts .pbf + sprite sheet + sprite.json). Runtime rewrite pour pointer `asset:///` ou `file:///` URIs. Audit Protomaps basemaps-assets dans DEPENDENCIES.md.
- Runtime rewrite du placeholder `pmtiles://YOUR_TILES_URL.pmtiles` par `PmtilesSource` → path du pays courant (ou world).
- Follow-me toggle FAB crosshair bas-droit.
- Fallback non-installé = world bundle silencieusement + banner "Disponible dans Paramètres › Télécharger une carte". PAS de CTA deep-link.
- Attribution icon 'i' bas-droit ~32dp (opacity ~80%), tap → bottom-sheet (OSM + Protomaps).

**Country resolver (polygones)**
- Source of truth : GeoJSON fournis par user dans `C:\claude_checkouts\countries\data\<alpha3>.geo.json`.
- Ship en assets : `assets/maps/polygons/<alpha3>.geo.json` OU fichier agrégé `assets/maps/polygons.json`. Budget ≤ 5 MB total (simplification via mapshaper ou équivalent tool/, one-shot).
- Zoom < 3 → toujours world. Zoom ≥ 3 → point-in-polygon viewport center.
- Hot-swap source MapLibre via `mirkfall_map` nommée. Swap au franchissement du centre viewport.

**Installed maps state**
- Manifest filesystem `<app_support>/maps/installed.json` — PAS de table Drift (pas de migration V3→V4).
- Schema : `{schemaVersion, catalogVersion, installed:{alpha3:{installed_at_utc, file_size, pmtiles_version, sha256, file_path}}}`.
- Update = lire + modifier + rewrite atomique (tempfile + rename).
- First-launch world bundle copy = check existence + sha256 verify (auto-heal idempotent).

**Fog layer stub + custom lints**
- Interface `MirkRenderer` dans `lib/domain/mirk/mirk_renderer.dart` (placée maintenant, Phase 09 livre l'impl) — `paint(Canvas,Size,MirkPaintContext)` / `update(Duration)` / `dispose()`.
- Impl no-op dans `lib/infrastructure/mirk/noop_mirk_renderer.dart`. Registered as default via Riverpod.
- Layer déclaratif dans `style.json` — id `"mirk_fog"`, entre POIs et user_location. Phase 07 : `fill-opacity: 0` ou source vide.
- Ordre layers gelé + unit test — [background, landcover, water, boundaries, roads, pois, mirk_fog, user_location].
- **Lints custom via `tool/check_*.dart` scripts CI-only** (pas de plugin custom_lint). Exit 0/1/2. Tests paired dans `tool/test/`. Ci.yml gates.

**Tests strategy**
- `FakeMapView` in-memory state-tracking dans `test/fakes/fake_map_view.dart`.
- MockHTTPServer via `package:shelf` (dev_dependency, Apache-2.0 déjà transitif).
- HTTP interceptor unit test airplane-mode (subset Phase 07 de QUAL-05).
- Country resolver tests — fixtures 5 pays FR/DE/ES/UK/US + 10-20 lat/lon.

**Amendements documentaires upstream (pré-requis avant plan-phase)**
1. ROADMAP.md Phase 07 : "ZIPs multi-parts" → "chunks binaires multi-parts" (déjà appliqué ROADMAP.md 2026-04-20).
2. PROJECT.md Out of Scope : retirer "Rendu du mirk par session — le choix de style est global à l'app en V1.0" (TODO).
3. REQUIREMENTS.md MIRK-10 : "Le choix du style (carte + mirk) est par session" (déjà amendé REQUIREMENTS.md 2026-04-20).
4. (Optionnel) ROADMAP.md Phase 07 SC#6 : `kMapCatalogUrl` → `kMapCatalogAssetPath` (déjà texte-à-texte ROADMAP.md 2026-04-20).

### Claude's Discretion

- Exact layout du burger drawer (spacings, dividers, typo sizes).
- Icon exacte du bouton burger (3 tirets classiques vs icône custom).
- Icon exacte du FAB follow-me (crosshair material vs custom).
- Format exact des read-only lignes lat/long (decimals 6 ? DMS ? toggle ?).
- Format distance walked (km si > 1000 m, m sinon ? unités métriques uniquement V1.0).
- Copy exact français des tooltips + snackbars + banners.
- Stratégie de simplification polygones (mapshaper tolerance, budget taille).
- Choix exact du style Protomaps basemaps variant (light ou white).
- Layout `/maps/download` list — alphabétique, par continent, search (contains/starts-with/fuzzy).
- Layout `/maps/manage` list — affichage disk space par pays + total cumul.
- Exact channel name + ID de la notification persistante download (si elle arrive en Phase 07).
- Mécanique pause/reprendre — 1 bouton toggle ou 2 boutons séparés.
- Stratégie resolver (ray casting vs bbox-first + poly-confirm).
- Asset name convention polygons (1 fichier par pays vs agrégé).
- Shape exact de la `MirkRenderer` interface (signature de `paint`).
- Exact `MapView` domain interface signatures.
- Naming providers Riverpod.
- Format du schema `installed.json` (champs optionnels, flags futurs).
- Seuil de retry exacts + backoff.

### Deferred Ideas (OUT OF SCOPE for Phase 07)

- Style parchment "fantasy" fourni par user → Phase 13 (OPT-03/04).
- Boutons "take picture" + "place marker" câblés → Phase 11 (MARK-01, MARK-05).
- Boutons "import / export style" câblés → Phase 13 (MIRK-08, PORT-08).
- Génération systématique des ~200 pays PMTiles (tool/ + Protomaps CLI) → pas nécessaire Phase 07.
- Sub-divisions régionales (ISO 3166-2) → V1.x.
- Reveal initial 20m au session open → Phase 09.
- Notification persistante pendant download (Android) → Phase 15 polish.
- HTTP Range granulaire au byte près si GitHub ne le supporte pas → re-download chunk entier, optim deferable.
- Country resolver bbox-first optim → Phase 07 ship ray casting simple.
- Update auto-check au startup (badge agressif) → Phase 15.
- Multi-language (FR/EN) → V1.x (I18N-*).
- `tool/update_catalog.dart` automation → post-V1.0.
- Test airplane-mode device end-to-end (QUAL-05) → Phase 15.
- iOS Dynamic Island download progress → jamais.
- Storage quota UI global (graph / tendance) → Phase 15.
- Onboarding tutorial first download → Phase 15.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAP-01 | Carte s'affiche sur PMTiles local (`pmtiles:///<path>`). Zéro requête réseau tuiles. | §Standard Stack (maplibre_gl 0.25.0 pmtiles support), §Architecture Patterns (URI scheme `pmtiles://file://…`), §Common Pitfalls (glyphs/sprites HTTPS leakage). |
| MAP-02 | Carte reste interactive (pan, zoom) sous le mirk. | §Architecture Patterns (MapLibreMapController camera APIs). |
| MAP-03 | Attribution OSM + Protomaps visible (carte + À propos) avec liens copyright. | §Code Examples (attribution widget), §Standard Stack (Protomaps basemaps BSD + data ODbL). |
| MAP-04 | Overlay mirk s'intègre comme layer MapLibre natif, RepaintBoundary, sans référencer SDK depuis layer app. | §Architecture Patterns (layer-stack ordering, MirkRenderer seam), §Code Examples (stub layer declaration). |
| MAP-05 | `PmtilesSource` local-only. Lint `avoid_remote_pmtiles` interdit `pmtiles://https?://…`. Country resolver + fallback. | §Standard Stack (tool/check_avoid_remote_pmtiles.dart pattern), §Architecture Patterns (PmtilesSource seam + country resolver). |
| MAP-06 | `MapView` domain interface vocabulaire MirkFall. Lint `avoid_maplibre_leak` interdit imports maplibre_gl hors `lib/infrastructure/map/`. FakeMapView. | §Architecture Patterns (MapView interface), §Standard Stack (tool/check_avoid_maplibre_leak.dart pattern). |
| MAP-07 | World PMTiles z0-2 bundlé + copie first-launch vers `<app_support>/maps/world.pmtiles`. Non supprimable. | §Architecture Patterns (first-launch copier + sha256 verify), §Code Examples (asset-to-app_support copy). |
| MAP-08 | Écran "Télécharger une carte" lit catalog asset + liste pays + déclenche download avec progress. | §Standard Stack (catalog schema + Freezed entity), §Architecture Patterns (download controller Riverpod keepAlive). |
| MAP-09 | Download atomique : séquentiel parts / sha256 chunk / concat / sha256 global / rename atomique. Reprise + interruption sans état partiel. | §Architecture Patterns (7-step atomic protocol), §Common Pitfalls (partial state, race, mid-write crash), §Code Examples (atomic rename pattern). |
| MAP-10 | Écran gestion : liste pays installés + espace disque + version + delete. World non supprimable. | §Architecture Patterns (InstalledManifest + manage screen). |

</phase_requirements>

---

## Summary

Phase 07 converts the MirkFall skeleton (sessions + GPS shipped through Phase 06) into a functional offline mapping application. The three architectural decisions to freeze here — (1) the domain-level `MapView` interface, (2) the 100 %-offline PMTiles pipeline behind `PmtilesSource`, and (3) the chunk-based per-country download protocol — are each the single most expensive thing in the phase to revisit later, so everything below is aimed at arming the planner to land those decisions correctly on the first pass.

The research is un-blocked on the critical-path unknowns. **maplibre_gl 0.25.0** (released 2026-01-07, BSD-3-Clause, MapLibre Native Android 12.3.0 + iOS 6.14.0) has first-class PMTiles support with the URI syntax `pmtiles://file:///absolute/path.pmtiles` — no Dart-side protocol registration is needed, the native PMTiles reader is invoked directly through the existing `VectorSource` / `addSource` API. GitHub Releases serves asset downloads via `objects.githubusercontent.com` (an S3-backed CDN) which supports `Accept-Ranges: bytes` and `206 Partial Content`, making mid-chunk resume feasible with standard `dart:io HttpClient` `Range` headers. Protomaps basemaps-assets ships fonts under OFL (Open Font License — allowlist-compatible) and sprites under CC0 / BSD-3-Clause; bundling them is licence-clean. No ZIP extraction library is needed (chunks are raw binary concat), avoiding an `archive` audit entry.

**Primary recommendation:** ship a single-asset-style-rewrite design. One `style.json` file committed as `assets/maps/style.json` carries a `YOUR_TILES_URL` placeholder and `asset://` refs for glyphs/sprites; at runtime `lib/infrastructure/map/style_rewriter.dart` replaces the pmtiles placeholder with the resolved country/world path and hands the JSON-as-string to `MapLibreMapController.setStyle()`. This keeps 100 % of MapLibre API surface inside `lib/infrastructure/map/` (satisfies MAP-06 cleanly), lets the country resolver swap by re-calling `setStyle` (or the lighter-weight `removeSource`+`addSource` round-trip — see Open Question #2), and lets the Phase 09 fog layer arrive as a single `style.json` edit plus a `MirkRenderer` swap.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `maplibre_gl` | **0.25.0** (pinned) | Native MapLibre SDK bridge for Flutter — vector map rendering, style.json runtime control, runtime source/layer edits, camera control, annotations | BSD-3-Clause. Only production-grade MapLibre binding for Flutter (fork of archived flutter-mapbox-gl). 0.22.0 added PMTiles, 0.25.0 (2026-01-07) bumps to MapLibre Native Android 12.3.0 (synchronous GeoJSON source updates, fixes pattern image conversion). Runtime style switching via `setStyle()` without tearing down the map. Pub points 130, 77% likes, weekly ~3.5k downloads. |
| `path_provider` | 2.1.5 (already pinned Phase 01) | Resolve `<app_support>` / `<app_docs>` paths for `maps/` subtree | Already audited day-1. `getApplicationSupportDirectory()` returns a per-app directory that is **not** backed up to iCloud by default and is not user-visible in the iOS Files app — exactly the semantics for "app-managed data the user doesn't touch". |
| `path` | 1.9.1 (already pinned Phase 01) | `p.join()` for cross-platform path composition (CLAUDE.md §Structure) | Already audited day-1. Mandatory per CLAUDE.md. |
| `crypto` | **3.0.7** (already transitive via `build_runner`, will promote to direct dev/runtime dep) | sha256 verification of chunks + reassembled file | BSD-3-Clause, pure-Dart, already present as transitive (Phase 01 build_runner). Promote to direct `dependencies:` entry so runtime sha256 is explicit. |
| `flutter_riverpod` / `riverpod_annotation` | 3.3.1 / 4.0.2 (already pinned Phase 03/05) | State management for download queue, active country, installed manifest, FakeMapView injection | Project-wide singleton decision D5. `keepAlive: true` needed for download controller (survives screen navigation). |
| `drift` | 2.32.1 (already pinned) | **NOT USED for installed maps** — manifest is filesystem JSON per CONTEXT.md. Only mentioned here to confirm no V3→V4 migration. | Keep out of scope Phase 07. |
| `go_router` | 16.0.0 (already pinned) | New routes `/map`, `/maps/download`, `/maps/manage`, `/styles/import`, `/styles/export` | Already in use Phase 05. Use `context.push()` for forward navigation (CLAUDE.md §Navigation GoRouter). |
| `collection` | 1.19.1 (already pinned) | `ListEquality` for layer order asserts, `UnmodifiableListView` for `installed.json` in-memory view | Already audited day-1. |
| `freezed_annotation` / `json_annotation` | 3.1.0 / 4.11.0 (already pinned) | Freezed entities for `CountryCatalog`, `InstalledCountry`, `InstalledManifest`, `DownloadProgress`, `DownloadJob` | Project convention Phase 03. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `shelf` | already transitive via `test` 1.30.0 (1.4.2, BSD-3-Clause) | MockHTTPServer for download soak tests — kill after N bytes, serve ranges, simulate network hiccup | Dev-only. Already on the transitive graph; promote to **explicit** `dev_dependencies:` entry for `depend_on_referenced_packages` compliance (pattern Phase 03 re. `yaml` and `test`). |
| `vm_service` | already transitive (dev) | Not used Phase 07. | — |
| No disk-space package | — | Check free disk space before download | **Decision**: do NOT adopt `disk_space_plus` (MIT, "unverified uploader", last release ~10 months ago per pub.dev, reads OK but publisher unverified = CLAUDE.md audit risk). Instead, wrap a **narrow platform-channel** in `lib/infrastructure/platform/disk_space_checker.dart` calling `StatFs` on Android and `NSFileManager.attributesOfFileSystem(forPath:)` on iOS. ~40 lines of Kotlin + Swift, zero new Dart deps, zero audit surface. See §Don't Hand-Roll caveat. |
| **NOT using** `archive` | — | NOT needed — chunks are raw binary, concat-by-append. | Explicitly keep off pubspec. Saves an audit entry. |
| **NOT using** `http` package directly | — | Standard HTTP client needed. | `http` 1.6.0 already on the transitive graph (via `flutter_map`, `build_runner`). When `flutter_map` is removed from `pubspec.yaml`, verify `http` survives as a direct-or-transitive. **Recommendation**: use `dart:io HttpClient` directly (zero new deps; first-class support for `Range` headers via `HttpClientRequest.headers.add(HttpHeaders.rangeHeader, 'bytes=$offset-')`; first-class support for streaming body via `response.listen`). Avoid the `http` package for the download hot path (it buffers the whole body in memory — unusable for 1.5 GB chunks). |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `maplibre_gl 0.25.0` | `maplibre 0.6.x` (newer pure-Dart rewrite on pub.dev) | Rejected: still in 0.x with breaking changes every ~2 weeks, feature gap on Android (no attribution hooks, no annotation manager), not a safe V1.0 bet. `maplibre_gl` is the production-proven choice. |
| `maplibre_gl 0.25.0` | `flutter_map 8.3.0` (currently pinned) | Rejected per Phase 07 CONTEXT.md — `flutter_map` does not render vector PMTiles natively. Pure-Dart raster renderer with optional `flutter_map_tile_caching` / `flutter_map_mbtiles` plugins but no MapLibre-native vector tile path. Phase 07 REMOVES `flutter_map 8.3.0` + `latlong2 0.9.1` and all their transitives (`dart_earcut`, `dart_polylabel2`, `mgrs_dart`, `proj4dart`, `wkt_parser`, `simple_sparse_list`). Net DEPENDENCIES.md delta: -7 packages + 1 package (maplibre_gl). |
| raw `dart:io HttpClient` | `dio 5.x` | Rejected: `dio` adds ~14 transitive deps (cancel tokens, interceptors, adapters), audit surface disproportionate for a single range-GET. `HttpClient` gives us everything we need (range, streaming, timeout, cancellation via `request.abort()`). |
| platform-channel disk-space | `disk_space_plus 0.2.x` | Rejected: unverified publisher on pub.dev. Platform channel is ~40 lines of ours + zero audit surface. |
| `shelf` for MockHTTPServer | `flutter_mock_web_server`, `mockzilla`, `http-mock-adapter` | Rejected: `shelf` is already transitive via `test` (BSD-3-Clause, Dart-team), trivially promotable to explicit dev_dep, supports Range natively via headers manipulation. Other candidates add SDK weight or pull in GPL-adjacent deps. |
| Freezed `InstalledManifest` | hand-rolled class | Prefer Freezed (project convention Phase 03; immutability + copyWith + JSON round-trip). |
| `tool/check_*.dart` for lints | `custom_lint` package | Explicit user decision: `custom_lint` silently degraded since Phase 03 under analyzer-10 override; re-evaluating in Phase 15. Phase 07 lints go in `tool/` (pattern validated 5 times: headers, licenses, deps, domain purity, platform manifests). |

### Installation delta (pubspec.yaml)

```bash
# Phase 07 pubspec.yaml changes
#
# REMOVE (confirmed removable — consumed only by Phase 01 day-1 pin for later use,
# never imported by any lib/ or test/ file per grep — see §Existing Code Insights):
- flutter_map: 8.3.0
- latlong2: 0.9.1
# Transitive cleanup (7 packages auto-drop): dart_earcut, dart_polylabel2, mgrs_dart,
# proj4dart, wkt_parser, simple_sparse_list, intl (intl may be retained by
# flutter_local_notifications → re-verify with `flutter pub deps`)

# ADD (runtime):
+ maplibre_gl: 0.25.0
+ crypto: 3.0.7             # promote from transitive (build_runner)

# ADD (dev_dependency, explicit per depend_on_referenced_packages):
+ shelf: 1.4.2              # already transitive via test; promote for Phase 07 MockHTTPServer
```

**Audit rows to add in DEPENDENCIES.md (Direct + Dev + Transitive):**

- `maplibre_gl 0.25.0` — direct, BSD-3-Clause, no analytics, audit: source github.com/maplibre/flutter-maplibre-gl inspected 2026-04-21, publisher `maplibre.org` (verified), transitive graph: native MapLibre Native Android 12.3.0 (BSD-2-Clause) + iOS 6.14.0 (BSD-2-Clause), Dart-side only `collection`, `flutter`, `plugin_platform_interface` (already audited), `gl_ext` (NOT — re-verify), zero outbound HTTP beyond user-requested tile fetches (and Phase 07 will enforce `pmtiles://file://…` so zero fetches period).
- `crypto 3.0.7` — direct (promoted from transitive), BSD-3-Clause, pure Dart, no network.
- `shelf 1.4.2` — dev, BSD-3-Clause, Dart-team (already transitive via `test`). Promoted for MockHTTPServer soak tests.
- **Protomaps basemaps-assets** (glyphs + sprites bundled in `assets/maps/glyphs/` + `assets/maps/sprites/`) — not a pub package but a **bundled third-party asset**. Add a new section in DEPENDENCIES.md called "Bundled assets" (or extend "Tooling / GitHub Actions") with a row:
  - Source: `github.com/protomaps/basemaps-assets` (pinned by commit SHA)
  - Fonts: **OFL (SIL Open Font License 1.1)** — allowlist-compatible (functionally equivalent to BSD for redistribution — requires font source availability + no sale-as-font-only, neither constraint affects MirkFall).
  - Sprites: **CC0-1.0** (map design by Protomaps, released under CC0 per protomaps/basemaps README footer "Map Design visual copyright released under CC0").
  - Software code in protomaps/basemaps repo: BSD-3-Clause (not bundled — only the style.json layer skeleton is consulted).
  - Data tilesets (OSM-derived, inside the world.pmtiles + country pmtiles): **ODbL 1.0** (attribution required per MAP-03).

### Validation stack (Phase 07-specific)

| Layer | Framework | Command |
|-------|-----------|---------|
| Plain-Dart unit tests (pmtiles source, country resolver, installed manifest, sha256 verifier, binary concatenator, atomic renamer, download job machine) | `package:test` | `dart test test/domain/map/ test/domain/downloads/ test/domain/installed_maps/ test/infrastructure/map/ test/infrastructure/downloads/ test/infrastructure/installed_maps/` |
| Flutter widget tests (MapScreen, MapsDownloadScreen, MapsManageScreen, session burger menu, placeholders) — via `FakeMapView` in-memory injection | `flutter_test` | `flutter test test/presentation/screens/map_screen_test.dart test/presentation/screens/maps_*.dart test/presentation/widgets/session_burger_menu_test.dart` |
| Style JSON layer-order regression test (parse `assets/maps/style.json`, assert layer ID sequence) | `flutter_test` (assets access) or plain Dart if style.json is also at a fixture path | `flutter test test/presentation/map_style_layer_order_test.dart` |
| Download soak (MockHTTPServer via shelf, 1-part happy + N-part interrupt + sha256 mismatch) | `package:test` + `package:shelf` | `dart test test/infrastructure/downloads/download_soak_test.dart` (flagged `@Tags(['soak'])` per Phase 03 `dart_test.yaml` pattern, excluded from default suite if slow) |
| Airplane-mode interceptor (HttpClient overridden globally in `HttpOverrides`, assert zero GET beyond user-initiated catalog parse — which is asset load not HTTP) | `flutter_test` | `flutter test test/integration/airplane_mode_test.dart` |
| New lints | `package:test` sibling tests | `dart test tool/test/check_avoid_maplibre_leak_test.dart tool/test/check_avoid_remote_pmtiles_test.dart` |

---

## Architecture Patterns

### Recommended Project Structure (additive to existing Phase 01–06 layout)

```
lib/
├── domain/
│   ├── map/                          ← NEW (pure Dart — check_domain_purity gates it)
│   │   ├── map_view.dart             ← interface MapView (MAP-06)
│   │   ├── country_code.dart         ← extension type CountryCode(String) — alpha3
│   │   ├── map_theme.dart            ← sealed MapTheme { standard | rpgParchment }
│   │   ├── country_catalog.dart      ← Freezed CountryCatalog + CountryEntry + ChunkPart
│   │   └── map_errors.dart           ← MapAssetMissingException, PmtilesCorruptException,
│   │                                    CountryNotInstalledException, SchemaValidationException,
│   │                                    DiskSpaceInsufficientException, (impl Exception)
│   ├── downloads/                    ← NEW
│   │   ├── download_job.dart
│   │   ├── download_state.dart       ← sealed Idle|Downloading|Paused|Error|Completed|Cancelled
│   │   └── download_errors.dart      ← DownloadInterruptedException,
│   │                                    Sha256MismatchException, ConcatFailureException
│   ├── installed_maps/               ← NEW
│   │   ├── installed_country.dart    ← Freezed
│   │   └── installed_manifest.dart   ← Freezed + InstalledManifestRepository port
│   └── mirk/                         ← EXTENDED (interface shape only — no impl)
│       ├── mirk_renderer.dart        ← abstract interface (Phase 09 will impl)
│       └── mirk_paint_context.dart   ← Freezed DTO
├── infrastructure/
│   ├── map/                          ← NEW — ONLY dir allowed to import package:maplibre_gl
│   │   ├── maplibre_map_view.dart    ← adapter: MapView → MapLibreMapController (concrete)
│   │   ├── pmtiles_source.dart       ← PmtilesSource seam: pmtiles:///<local-path> only
│   │   ├── style_rewriter.dart       ← runtime substitution of placeholder URIs
│   │   ├── style_layer_order.dart    ← const list + assert helper
│   │   ├── country_resolver.dart     ← viewport center → alpha3 + swap decision
│   │   └── first_launch_world_copier.dart ← asset→app_support idempotent copy
│   ├── downloads/                    ← NEW
│   │   ├── pmtiles_download_controller.dart ← Riverpod @keepAlive
│   │   ├── http_chunk_downloader.dart       ← dart:io HttpClient + Range
│   │   ├── sha256_verifier.dart
│   │   ├── binary_concatenator.dart
│   │   ├── atomic_renamer.dart
│   │   └── download_queue_store.dart        ← JSON persistence <app_support>/maps/download_queue.json
│   ├── installed_maps/               ← NEW
│   │   └── installed_manifest_repository.dart  ← file-based impl of domain port
│   ├── platform/                     ← EXTENDED (exists from Phase 05)
│   │   └── disk_space_checker.dart   ← NEW: thin platform channel wrapper
│   └── mirk/                         ← NEW
│       └── noop_mirk_renderer.dart   ← no-op impl (Phase 09 swaps)
├── application/
│   ├── controllers/
│   │   ├── map_camera_controller.dart       ← NEW (follow-me, Z-on-open)
│   │   ├── country_resolver_controller.dart ← NEW
│   │   ├── download_queue_controller.dart   ← NEW — @keepAlive: true
│   │   └── installed_maps_controller.dart   ← NEW
│   └── providers/
│       └── map_providers.dart        ← NEW: mapViewProvider, countryCatalogProvider,
│                                       installedManifestProvider, styleJsonProvider,
│                                       firstLaunchWorldCopierProvider (tied to @riverpod)
└── presentation/
    ├── screens/
    │   ├── map_screen.dart                    ← NEW full-screen
    │   ├── maps_download_screen.dart          ← NEW
    │   ├── maps_manage_screen.dart            ← NEW
    │   ├── style_import_placeholder_screen.dart ← NEW
    │   └── style_export_placeholder_screen.dart ← NEW
    │   (settings_screen.dart and session_detail_screen.dart are EXTENDED, not new)
    └── widgets/
        ├── session_burger_menu.dart           ← NEW
        ├── map_follow_me_fab.dart             ← NEW
        ├── map_attribution_icon.dart          ← NEW (expandable)
        ├── map_country_banner.dart            ← NEW ("Disponible dans Paramètres…")
        └── map_download_progress_chip.dart    ← NEW (AppBar badge while downloading)
assets/
└── maps/                                      ← NEW
    ├── world.pmtiles                          ← 856 KB z0-2, copied from files_for_mirkfall/
    ├── catalog.json                           ← 132 KB, copied from files_for_mirkfall/
    ├── style.json                             ← Protomaps neutral (light or white)
    ├── glyphs/<fontstack>/<range>.pbf         ← bundled from protomaps/basemaps-assets
    ├── sprites/sprite.json + sprite.png + sprite@2x.png
    └── polygons/<alpha3>.geo.json (or polygons.json aggregate) ≤ 5 MB
tool/
├── check_avoid_maplibre_leak.dart             ← NEW — import scan outside lib/infrastructure/map/
├── check_avoid_remote_pmtiles.dart            ← NEW — scan pmtiles://http
└── prepare_style.dart                         ← NEW, one-shot: rewrite protomaps style.json to use asset:// URIs
```

### Pattern 1: `pmtiles://file:///` Local URI

**What:** PMTiles files consumed by MapLibre Native via a prefix-scheme URL.
**When to use:** Every MapLibre source backed by a local `.pmtiles` file — world bundle AND country files.
**Why:** Verified across MapLibre Native Android (11.9.0+) and iOS (6.14.0+) in the native CHANGELOGs — both support `pmtiles://file://…` where the inner `file://` URL is a filesystem path. The maplibre_gl 0.25.0 Flutter plugin passes this string through to the native layer unchanged.

**Example:**
```dart
// lib/infrastructure/map/pmtiles_source.dart
// Source: maplibre/flutter-maplibre-gl example + protomaps docs + maplibre-native Android 11.7.0 changelog

/// Returns the URI that MapLibre's native source reader can open for [pmtilesFilename].
/// All accepted values are LOCAL (file:// scheme) — remote URIs are forbidden by
/// `tool/check_avoid_remote_pmtiles.dart`. This seam is the only place the string
/// is assembled, so a single grep defends the invariant at the layer boundary.
String localPmtilesUri(String absolutePmtilesFilename) {
  // `pmtiles://file:///absolute/path.pmtiles`.
  // Note the `///` — `file://` + absolute path starting with `/`.
  // On Windows, absolutePmtilesFilename is like `C:\foo\bar.pmtiles`; MapLibre
  // Native does not ship a Windows backend (desktop builds use the web engine
  // path via mabplibre-gl-js under maplibre_gl flutter plugin's web platform),
  // so Windows handling is best-effort with forward-slash normalization.
  final String normalized = absolutePmtilesFilename.replaceAll('\\', '/');
  final String fileUri = normalized.startsWith('/') ? 'file://$normalized' : 'file:///$normalized';
  return 'pmtiles://$fileUri';
}
```

### Pattern 2: `MapView` Domain Interface (MAP-06)

**What:** Pure-Dart abstract class with MirkFall-vocabulary methods. Zero MapLibre types leak.
**When to use:** Every application-layer + presentation-layer call into the map.
**Why:** Locks SDK-swap optionality, enables `FakeMapView` for widget tests, enforceable mechanically via `tool/check_avoid_maplibre_leak.dart`.

**Example:**
```dart
// lib/domain/map/map_view.dart
// Source: decision D6/Phase 07 CONTEXT + MAP-06 spec.

import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:mirkfall/domain/gps/fix.dart';

/// Domain-level map interface. No reference to any third-party map SDK type.
abstract class MapView {
  /// Show the map for the supplied country bundle (or world fallback).
  Future<void> showMap(CountryCode? country);

  /// Move camera to [location] instantly. Animated variants are a presentation
  /// concern wrapped in [MapCameraController], which calls this.
  Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom});

  /// Swap the active theme (Phase 07 only ships MapTheme.standard; `rpgParchment` is Phase 13).
  Future<void> setTheme(MapTheme theme);

  /// Render the current GPS position — purely visual; no GPS source coupling
  /// (the subscribing controller pulls fixes from Phase 05's LocationStream
  /// and calls this).
  Future<void> setUserLocation(Fix? fix);

  /// Query current viewport center — used by the country resolver to decide
  /// when to hot-swap the pmtiles source.
  Future<({double latitude, double longitude, double zoom})> queryViewport();

  /// Listen to viewport changes (debounced by the adapter).
  Stream<({double latitude, double longitude, double zoom})> get viewportUpdates;

  /// Future-proof hooks — stubs in Phase 07.
  Future<void> markVisited(List<({double latitude, double longitude})> polygon);
  Future<void> addPointOfInterest({required String id, required double latitude, required double longitude, required String iconId});
  Future<void> removePointOfInterest(String id);

  Future<void> dispose();
}
```

Note: `Fix` already exists in `lib/domain/gps/fix.dart` (Phase 05) — reuse, don't duplicate.

### Pattern 3: `PmtilesSource` Seam (MAP-05)

**What:** Thin wrapper that emits only local URIs, enforced by lint.
**When to use:** Every MapLibre `addSource` / `style.json` pmtiles reference.
**Why:** Closes the "remote fallback creeps in during maintenance" attack surface.

```dart
// lib/infrastructure/map/pmtiles_source.dart
// A seam, not a type — generates URIs only. Two callers: style_rewriter (startup)
// and country_resolver (runtime swap). No remote impl exists.

class PmtilesSource {
  PmtilesSource(this._installedManifestPort);
  final InstalledManifestRepository _installedManifestPort;

  /// URI for the currently-selected country, or the world bundle fallback.
  String forCountry(CountryCode? code) {
    if (code == null) return localPmtilesUri(_worldBundleFilename);
    final InstalledCountry? installed = _installedManifestPort.currentSync().installed[code.value];
    if (installed == null) return localPmtilesUri(_worldBundleFilename); // silent fallback + banner upstream
    return localPmtilesUri(installed.resolvedFilename);
  }

  String get _worldBundleFilename =>
    p.join(_installedManifestPort.appSupportDir, 'maps', 'world.pmtiles');
}
```

### Pattern 4: Layer Order Freeze (MAP-04)

**What:** `style.json` declares a fixed ordered list of layer IDs. Unit test parses and asserts order. Fog layer stub is in-position at Phase 07 with `"fill-opacity": 0`, ready for Phase 09 to tune.

```jsonc
// assets/maps/style.json (excerpt — final layer list, ordered)
{
  "version": 8,
  "name": "MirkFall Standard (Protomaps neutral)",
  "glyphs": "asset:///assets/maps/glyphs/{fontstack}/{range}.pbf",
  "sprite": "asset:///assets/maps/sprites/sprite",
  "sources": {
    "mirkfall_map": {
      "type": "vector",
      "url": "pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER"
    }
  },
  "layers": [
    {"id": "background", "type": "background", "paint": {"background-color": "#fffbe9"}},
    {"id": "landcover", "type": "fill", "source": "mirkfall_map", "source-layer": "landcover"},
    {"id": "water", "type": "fill", "source": "mirkfall_map", "source-layer": "water"},
    {"id": "boundaries", "type": "line", "source": "mirkfall_map", "source-layer": "boundaries"},
    {"id": "roads", "type": "line", "source": "mirkfall_map", "source-layer": "transportation"},
    {"id": "pois", "type": "symbol", "source": "mirkfall_map", "source-layer": "pois"},
    {"id": "mirk_fog", "type": "fill", "paint": {"fill-color": "#000000", "fill-opacity": 0}},
    {"id": "user_location", "type": "circle", "paint": {"circle-color": "#1976d2"}}
  ]
}
```

Unit test (Phase 07 — locks Phase 09 invariants):

```dart
// test/presentation/map_style_layer_order_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('style.json layers ship in the frozen order', () async {
    final Map<String, dynamic> style = jsonDecode(await File('assets/maps/style.json').readAsString()) as Map<String, dynamic>;
    final List<String> ids = (style['layers'] as List<dynamic>).map((dynamic e) => (e as Map<String, dynamic>)['id'] as String).toList();
    expect(ids, ['background', 'landcover', 'water', 'boundaries', 'roads', 'pois', 'mirk_fog', 'user_location']);
  });
}
```

### Pattern 5: Atomic Country Download Protocol (MAP-09)

**What:** 7-step state machine on disk with the invariant *"a country is either absent or fully installed — never partial"*.
**When to use:** Every country install + re-install (catalog version bump).

**Example sketch (pseudo-Dart, distilled from Phase 07 CONTEXT.md §Pipeline download pays):**

```dart
// lib/infrastructure/downloads/pmtiles_download_controller.dart
Future<void> downloadCountry(CountryEntry entry) async {
  final Directory stagingDir = Directory(p.join(appSupportDir, 'maps', 'staging', entry.alpha3.value));
  final File reassembled = File(p.join(stagingDir.path, '${entry.alpha3.value}.pmtiles'));
  final File finalFile = File(p.join(appSupportDir, 'maps', 'countries', '${entry.alpha3.value}.pmtiles'));

  // 0. Pre-flight: disk space (MAP-09 + CONTEXT §Check disk space)
  final int free = await _diskSpaceChecker.freeBytes();
  if (free < entry.reassembled.size * kDiskSpaceSafetyMarginMultiplier) {
    throw DiskSpaceInsufficientException(needed: entry.reassembled.size, free: free);
  }

  // 1. Sequential download (Range-aware if server supports; otherwise chunk re-download on fail)
  await stagingDir.create(recursive: true);
  for (final ChunkPart part in entry.parts) {
    final File partFile = File(p.join(stagingDir.path, '${entry.alpha3.value}.${_partName(part.index)}'));
    await _httpChunkDownloader.downloadWithResume(part: part, destination: partFile);

    // 2. Per-chunk sha256 (fail-fast: abort + staging kept for resume)
    final String actualSha = await _sha256.hashFile(partFile);
    if (actualSha != part.sha256) {
      await partFile.delete(); // give the retry a clean slate
      throw Sha256MismatchException(expected: part.sha256, actual: actualSha);
    }
  }

  // 3. Concat (streaming — never load 5 GB in memory)
  await _binaryConcatenator.concat(
    parts: entry.parts.map((p) => File('${stagingDir.path}/${entry.alpha3.value}.${_partName(p.index)}')).toList(),
    destination: reassembled,
  );

  // 4. Global sha256 (the "did concat succeed?" gate)
  final String fullSha = await _sha256.hashFile(reassembled);
  if (fullSha != entry.reassembled.sha256) {
    throw Sha256MismatchException(expected: entry.reassembled.sha256, actual: fullSha);
  }

  // 5. Atomic rename (all target-dir creation must precede rename)
  await Directory(p.dirname(finalFile.path)).create(recursive: true);
  await reassembled.rename(finalFile.path);

  // 6. Update installed.json (atomic: tempfile + rename)
  await _installedManifest.insert(InstalledCountry(
    alpha3: entry.alpha3,
    installedAtUtc: DateTime.now().toUtc(),
    fileSize: entry.reassembled.size,
    pmtilesVersion: _catalog.catalogVersion, // tag of the GitHub Release
    sha256: entry.reassembled.sha256,
    filePath: p.relative(finalFile.path, from: appSupportDir),
  ));

  // 7. Cleanup staging
  await stagingDir.delete(recursive: true);
}
```

Key invariants documented in code + tested in MockHTTPServer soak tests:
- Partial part files under staging/<alpha3>/ are expected on kill mid-download; resume picks them up.
- `rename()` is atomic on POSIX + Android ext4/f2fs + APFS + Windows NTFS (same-volume) — validated by Phase 03 Plan 03-05 DbBackupService.
- The cleanup is deliberately *after* the manifest write. Ordering: commit visibility first, then cleanup — a crash between steps 6 and 7 leaves a harmless stale staging/ that the next startup can sweep.

### Pattern 6: First-Launch World Copy (MAP-07) — Idempotent with sha256 Verify

```dart
// lib/infrastructure/map/first_launch_world_copier.dart
/// Copies `assets/maps/world.pmtiles` to `<app_support>/maps/world.pmtiles` once,
/// then verifies sha256 on subsequent launches for auto-heal. Idempotent.
/// Budget <1 s on first launch (856 KB copy).
Future<void> ensureWorldBundleInstalled({required String expectedSha256}) async {
  final File target = File(p.join(_appSupportDir, 'maps', 'world.pmtiles'));
  await target.parent.create(recursive: true);

  if (await target.exists()) {
    final String actual = await _sha256.hashFile(target);
    if (actual == expectedSha256) return; // healthy
    await target.delete(); // auto-heal: corrupted → refresh
  }

  final ByteData bytes = await rootBundle.load(kWorldPmtilesAssetPath);
  await target.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));

  final String postCopy = await _sha256.hashFile(target);
  if (postCopy != expectedSha256) {
    throw MapAssetMissingException('world.pmtiles post-copy sha256 mismatch — asset corrupted in build?');
  }
}
```

Note: `expectedSha256` comes from a **build-time generated constant** (in `lib/config/world_bundle_sha256.dart`) rather than from `catalog.json`. Rationale: the world bundle is APK-local, not catalog-governed, so storing its hash in the catalog would create a drift path where `assets/maps/world.pmtiles` in the APK disagrees with the one the catalog claims. A `tool/generate_world_sha256.dart` one-shot run at APK build time writes the constant, which CI can freshen via a Plan-07-01 checkpoint.

### Pattern 7: Runtime Style Rewrite

```dart
// lib/infrastructure/map/style_rewriter.dart
/// Replaces placeholders in the bundled style.json with resolved local URIs.
/// Called once per country-swap. Output is passed to MapLibreMapController.setStyle(...).
Future<String> rewriteStyleForCountry({required CountryCode? activeCountry}) async {
  final String raw = await rootBundle.loadString(kStyleJsonAssetPath);
  final String pmtilesUri = _pmtilesSource.forCountry(activeCountry);
  return raw.replaceFirst('pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER', pmtilesUri);
}
```

### Anti-Patterns to Avoid

- **Anti-pattern: Style.json committed with a resolved absolute path** — absolute paths differ between dev machine, Android emulator, and iOS sim. The placeholder + runtime rewrite is the only portable approach.
- **Anti-pattern: Fetching `catalog.json` from a URL** — CONTEXT.md locks catalog as a bundled asset. A URL fetch would (a) need a telemetry audit entry, (b) add a network round-trip to app startup, (c) require a "no internet at first launch" error branch. Asset-only avoids all three.
- **Anti-pattern: Writing `installed.json` with `File.writeAsString` directly** — crash mid-write leaves the file truncated; next launch fails to parse. Use tempfile + rename atomic (same idiom as Phase 03 `DbBackupService.takeBackup`).
- **Anti-pattern: Loading the reassembled `.pmtiles` into memory for sha256** — 5 GB heap explosion. Always stream via `hashEvents` or `Chunker` (see `crypto` package docs). Sha256 of a 5 GB file on a mid-range Android takes ~15 s streamed.
- **Anti-pattern: `MapLibreMapController` in application-layer imports** — breaks MAP-06. `lib/application/controllers/map_camera_controller.dart` MUST only talk to the `MapView` interface, never directly to the SDK type. Enforced by `avoid_maplibre_leak` lint.
- **Anti-pattern: Background downloads using `setState` + `Future.microtask`** — loses on screen navigation. Use a `@Riverpod(keepAlive: true)` controller so the download survives screen rebuild.
- **Anti-pattern: `Stream<DownloadProgress>` from domain port that emits on every byte** — UI churn. Throttle at the seam (200–500 ms) using `StreamTransformer` or RxDart `throttleTime`. RxDart is NOT on the current pubspec — use a hand-rolled `StreamTransformer` (pure-Dart, 15 lines).
- **Anti-pattern: Hardcoding the GitHub Release tag in `constants.dart`** — catalog.json's `parts[].url` already encodes the tag in its path. Single source of truth: the catalog. No constant.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vector tile rendering | Custom Canvas/Skia vector renderer | `maplibre_gl 0.25.0` | MapLibre native Android+iOS already do this, battle-tested at web-map scale. Re-implementing means re-deriving Mercator projection, glyph rasterization, sprite atlasing, feature expressions — weeks of work for a worse outcome. |
| PMTiles format parsing | Custom PMTiles reader | Native MapLibre PMTiles support (0.22.0+) | MapLibre Native 11.9.0 (Android) / 6.14.0 (iOS) ship a native PMTiles directory reader with tile-decode + LRU cache. A Dart-side reader would have to duplicate all of it AND call back into MapLibre to paint — 2x the work for strictly worse performance. |
| sha256 streaming hash | Hand-rolled SHA256 | `package:crypto` 3.0.7 | BSD-3-Clause, already transitive, streamed via `AccumulatorSink` — 5 GB file hashes in one pass with constant memory. Hand-rolled = security audit surface + probable bugs. |
| Atomic file replace | `writeAsString` + retry/delete dance | `File.rename()` | Atomic on all MirkFall target platforms (ext4/f2fs/APFS/NTFS same-volume). Phase 03 already proved the pattern in `DbBackupService.takeBackup`. |
| Point-in-polygon | Hand-rolled ray casting | `point_in_polygon 1.0.7` (MIT) OR hand-rolled (~40 lines) | **Decision: hand-roll** — the `point_in_polygon` pub package has pub points 50, zero verified publisher, only 1 GitHub star. The algorithm is ~40 lines of pure Dart (Rosetta Code reference implementation). Hand-roll and unit-test exhaustively with the 5-country fixture. Keeps audit surface at 0 and removes a "unverified uploader" risk. Reuse Phase 03 convention: put in `lib/infrastructure/map/geo/point_in_polygon.dart` (pure Dart, unit-tested). |
| HTTP Range-request resume | Custom chunked downloader | `dart:io HttpClient` with `Range: bytes=N-` header | Standard. Single-call `HttpClientRequest.headers.add(HttpHeaders.rangeHeader, 'bytes=$resumeByte-')` + `response.statusCode == 206` check. |
| Disk free-space | `disk_space_plus` (unverified publisher) | Narrow platform channel (~40 LoC Kotlin + Swift) | Audit surface = 0; publisher-vetted. Same pattern Phase 05 used for `boot_completed_watchdog`. |
| Mock HTTP server | DIY socket listener | `package:shelf` | Already transitive via `test`, BSD-3-Clause, Dart-team. 20 lines of `shelf.serve(handler, host, port)` in a test fixture. |
| Runtime style switching | `setState` + re-instantiate `MapLibreMap` | `MapLibreMapController.setStyle(jsonString)` | 0.25.0 release notes: "Runtime style switching via controller `setStyle…` without tearing down the map." Re-instantiating would flash a black screen + lose camera position. |
| Binary concatenation | `File.readAsBytes()` + `File.writeAsBytes()` | Streamed `IOSink` with `await for` | 5 GB reassembled file = heap death if buffered. Stream each part as a `Stream<List<int>>` via `file.openRead()` and pipe to the destination sink. |

**Key insight:** MapLibre Native already solves 90% of the work in Phase 07 — the Phase 07 code is "glue code to a great piece of C++", not "a map renderer". Everywhere there's a temptation to implement something on the Dart side (sprite atlas, tile cache, glyph PBF parser, projection math), the answer is "don't — MapLibre Native already did it, call through the plugin".

---

## Common Pitfalls

### Pitfall 1: Mid-Write Crash During `installed.json` Update Leaves Truncated JSON
**What goes wrong:** `File.writeAsString(jsonEncode(manifest))` with the app killed mid-fsync produces a truncated file; next launch throws `FormatException` in `jsonDecode` and silently hides installed countries.
**Why it happens:** `writeAsString` is **not** atomic on Android / iOS — the file is opened `O_TRUNC`, bytes stream in, `close()` flushes. A crash at any point leaves a 0-byte-to-N-byte file.
**How to avoid:** Write to `installed.json.tmp`, fsync (`IOSink.flush()` + `close()`), then `rename` to `installed.json`. `rename` is atomic on all MirkFall target platforms. Phase 03 already established this idiom in `DbBackupService.takeBackup`.
**Warning signs:** Tests that never write the file > twice in a single test can't catch this. Fuzz test: write → kill process → re-read N times; every re-read must either see the old or the new value, never empty or partial.

### Pitfall 2: Glyphs / Sprites / Style Remote-Fetch Leak (MAP-01 violation)
**What goes wrong:** The stock Protomaps `style.json` at `docs.protomaps.com` references `https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf` for text rendering. If this URL ships untouched in `assets/maps/style.json`, MapLibre Native quietly fetches glyphs the moment the first POI label is rendered — airplane-mode test fails.
**Why it happens:** `style.json` in its published form assumes the MapLibre web example workflow where fonts/sprites come from CDN.
**How to avoid:** Bundle glyphs + sprite sheet in `assets/maps/glyphs/` + `assets/maps/sprites/` at build time (one-shot fetch via `tool/prepare_style.dart`). Rewrite `style.json` to use `asset:///assets/maps/glyphs/{fontstack}/{range}.pbf` and `asset:///assets/maps/sprites/sprite`. Verify with a test that greps the committed `style.json` for `https://` and `http://` — fails if any survive.
**Warning signs:** Small/medium-zoom maps render roads + polygons fine but labels disappear without internet. That's the glyphs fetch failing silently.

### Pitfall 3: `pmtiles://` URI Ambiguity — `pmtiles:///path` vs `pmtiles://file:///path`
**What goes wrong:** Docs are ambiguous. Early MapLibre Native Android snapshots accepted `pmtiles:///absolute/path` (triple-slash). Current 11.9.0+ docs and the official Android example use `pmtiles://file:///absolute/path` (prefix + file URL).
**Why it happens:** The prefix scheme was generalized in 11.9.0 to support `https://`, `asset://`, and `file://` — the triple-slash shorthand is undocumented behavior that may change.
**How to avoid:** Always generate `pmtiles://file://...` via the `localPmtilesUri()` helper (Pattern 1). Never concatenate the URI in two places. Single-seam enforcement.
**Warning signs:** On 0.25.0 both seem to work; relying on shorthand risks a breaking change on a future MapLibre Native upgrade.

### Pitfall 4: `pub.dev` "Unverified Publisher" Packages (CLAUDE.md §Audit obligatoire)
**What goes wrong:** `disk_space_plus` (MIT, unverified) looks like a drop-in; any "unverified" package is a supply-chain audit burden.
**Why it happens:** pub.dev lets anyone publish; "verified publisher" is opt-in.
**How to avoid:** For capabilities that need ~40 LoC of native code (disk space, point-in-polygon), hand-roll. For capabilities that need a real library (MapLibre, sha256), only accept verified publishers (maplibre.org is verified; `crypto` is Dart-team) and document the audit in DEPENDENCIES.md.
**Warning signs:** pub.dev page shows "Unverified uploader" banner + missing `homepage` key in pubspec.

### Pitfall 5: iOS `Application Support` Is NOT in the iOS Files App — Good for Us, Bad for Debugging
**What goes wrong:** During Phase 07 dev, you want to inspect `<app_support>/maps/installed.json` to debug a failed download. On iOS, `getApplicationSupportDirectory()` returns `<Library>/Application Support/` which is **not** exposed in the Files app (unlike `<Documents>`). Debugging requires Xcode Device → Download Container.
**Why it happens:** iOS UX default; the trade-off is no user tampering.
**How to avoid:** Keep the decision — don't switch to `<Documents>` for convenience. Document the Xcode procedure in `docs/map-debugging.md` (add a Phase-07 note). The Android debugger shows `<internal_storage>/Android/data/app.gosl.mirkfall/files/` via `adb pull`, but iOS requires the device download path.
**Warning signs:** "How do I see `installed.json` on iOS?" question during dev — answer now, not later.

### Pitfall 6: Missing `INTERNET` Permission on Android 13+ Targets
**What goes wrong:** App compiles fine, but `HttpClient` request throws `SocketException: Software caused connection abort`.
**Why it happens:** Apps now require `<uses-permission android:name="android.permission.INTERNET"/>` declared in `AndroidManifest.xml`; previously inferred on older Android.
**How to avoid:** Add the permission in Phase 07 Plan 01 (same wave that bumps pubspec.yaml). Verify with `tool/check_platform_manifests.dart` by extending its allowlist + required list.
**Warning signs:** Android downloads fail with SocketException; iOS works.

### Pitfall 7: GitHub Releases `objects.githubusercontent.com` CDN Returns `301 → S3 URL` on First GET
**What goes wrong:** First GET to `https://github.com/…/releases/download/v20260419/fra.part01` returns **302 Found** to a short-lived `objects.githubusercontent.com` URL. `HttpClient` with `followRedirects: true` (default) handles this transparently; `HttpClient` with `followRedirects: false` returns 302 and your download stalls.
**Why it happens:** GitHub lives behind a CDN; the release asset URLs are indirection.
**How to avoid:** Ensure `HttpClient.autoUncompress = false` (no gzip on already-compressed binary) but leave `followRedirects` at default `true`. Also: on the **resume** path, the second GET may hit the CDN directly with an expired token — server may return 403. Solution: never cache the redirect target; always re-resolve from the canonical GitHub URL every resume attempt.
**Warning signs:** Happy-path download works; resume-after-kill fails with 403 the second time.

### Pitfall 8: Range-Request Support Is Observed-Not-Guaranteed on GitHub Releases
**What goes wrong:** GitHub Releases serves via CloudFront-like CDN that **does** support `Range: bytes=N-` in practice (returns 206 Partial Content + `Accept-Ranges: bytes`), but GitHub does not officially document this guarantee. A future CDN migration could remove it.
**Why it happens:** Range support is an S3 / CloudFront feature. GitHub's release storage sits on S3 which supports Range natively.
**How to avoid:** Design the download pipeline to **fall back gracefully**: request `Range: bytes=$resume-`, check `response.statusCode`. If `206` → resume byte-accurate. If `200` → server ignored Range; restart chunk from byte 0, truncate the partial file. Log the branch to the file logger so Phase 15 CI test can assert branch distribution.
**Warning signs:** Resume test succeeds but the resumed file's sha256 is wrong — the CDN quietly returned a full 200 and your download appended instead of overwrote.

### Pitfall 9: maplibre_gl Platform-View Rebuild on State Change
**What goes wrong:** Wrapping `MapLibreMap` inside a widget that rebuilds on each `ActiveSessionState` change (e.g. position update) flashes black. The underlying `AndroidView`/`UiKitView` is destroyed+recreated on every tree identity change.
**Why it happens:** `MapLibreMap` constructor registers a platform view; `build()` re-invocation with a new parent key = new platform view.
**How to avoid:** Keep `MapLibreMap` in a `StatefulWidget` with `const` constructor inputs where possible; route state changes through the `MapLibreMapController` via post-build callbacks. Use `KeyedSubtree(key: ValueKey('mirkfall_map_view'), child: MapLibreMap(…))` if parent-key churn is a concern.
**Warning signs:** Screen flashes black when burger menu drawer opens or position updates; camera snaps back to default.

### Pitfall 10: iOS `pod install` Needed After Adding `maplibre_gl` to `pubspec.yaml`
**What goes wrong:** First iOS build after adding maplibre_gl fails in CI with "No such module 'MapLibre'" because `ios/Podfile.lock` wasn't regenerated.
**Why it happens:** The iOS native backend is a CocoaPods pod; adding a plugin requires `pod install` which on our Windows-dev bootstrap requires the CI-Mac to trigger (Phase 01 Option A pattern).
**How to avoid:** Delete `ios/Podfile.lock` in the same commit that adds `maplibre_gl: 0.25.0`. CI's existing "Remove placeholder Podfile.lock (Windows-dev bootstrap)" step will regenerate from scratch. Phase 01 Option A already handles this cleanly.
**Warning signs:** gates + android jobs green, iOS job fails on "pod install" with unresolvable pod or mismatched Podfile.lock.

### Pitfall 11: Large Chunk Download Bypasses Android Foreground Service Notification
**What goes wrong:** User starts a 5 GB France download, screen goes off, Android killer (Xiaomi) suspends the `HttpClient` in 30 s. No foreground-service = no Android protection, download stalls silently.
**Why it happens:** Foreground service is declared for GPS in Phase 05 but not for downloads. Downloads are classed as "data operations" by Doze.
**How to avoid Phase 07:** Accept the trade-off — downloads must be foreground (user on `/maps/download` screen or in-app active) to guarantee completion. Document the constraint in the download screen UX ("Garde MirkFall ouverte pendant le téléchargement"). Phase 15 can add a download-specific foreground service if user feedback warrants.
**Warning signs:** Night downloads on Xiaomi never complete; user reports "it paused at 30%".

### Pitfall 12: Protomaps `style.json` Layers Reference Source Layers That Differ Between PMTiles Versions
**What goes wrong:** `style.json` says `"source-layer": "landcover"` but the particular PMTiles was built with `"source-layer": "landuse"` — layer renders empty.
**Why it happens:** Different Protomaps base-map generation tooling emits different layer names. The user's PMTiles set was built with a specific pipeline.
**How to avoid:** Before freezing `style.json`, run `pmtiles show <country.pmtiles>` via the `pmtiles` CLI (available separately, not bundled in-app) to dump the vector layer names. Audit that the style's source-layer refs match. Phase 07 Plan 01 wave-0 task.
**Warning signs:** Map renders background + water but nothing else (landuse, roads missing) — source-layer name mismatch.

---

## Code Examples

Verified patterns from Context7 + official MapLibre/Protomaps docs + existing Phase 01–06 code.

### Example 1: Instantiating `MapLibreMap` with a Runtime-Rewritten Style

```dart
// lib/infrastructure/map/maplibre_map_view.dart (concrete adapter — only file that imports package:maplibre_gl)
// Source: maplibre_gl API surface (pub.dev/documentation/maplibre_gl/latest/MapLibreMapController-class.html)
//         + maplibre_gl 0.25.0 CHANGELOG (runtime setStyle without teardown)

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mirkfall/domain/map/map_view.dart';

class MapLibreMapView extends StatefulWidget {
  const MapLibreMapView({super.key, required this.onMapReady, required this.initialStyleJson});
  final ValueChanged<MapView> onMapReady;
  final String initialStyleJson;

  @override
  State<MapLibreMapView> createState() => _MapLibreMapViewState();
}

class _MapLibreMapViewState extends State<MapLibreMapView> {
  MapLibreMapController? _controller;

  @override
  Widget build(BuildContext context) => MapLibreMap(
    styleString: widget.initialStyleJson,
    initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 2),
    onMapCreated: (MapLibreMapController c) => _controller = c,
    onStyleLoadedCallback: () => widget.onMapReady(_MapViewAdapter(_controller!)),
    // Hide the default attribution — Phase 07 ships a custom widget (MAP-03).
    attributionButtonMargins: const Point(-100, -100),
  );
}

// _MapViewAdapter implements the pure-Dart MapView interface against the MapLibreMapController.
// No MapLibre type leaks OUT of this file — the class itself is imported by Riverpod providers
// but consumers only see `MapView`.
class _MapViewAdapter implements MapView {
  _MapViewAdapter(this._c);
  final MapLibreMapController _c;

  @override
  Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom}) =>
    _c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(latitude, longitude), zoom: zoom)));

  @override
  Future<void> showMap(CountryCode? country) async {
    final String rewritten = await _styleRewriter.rewriteStyleForCountry(activeCountry: country);
    await _c.setStyle(rewritten);
  }

  // … (rest elided; follow the MapView interface)
}
```

### Example 2: Streamed SHA256 over 5 GB File

```dart
// lib/infrastructure/downloads/sha256_verifier.dart
// Source: package:crypto 3.0.7 docs — AccumulatorSink pattern for streaming hashes.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

Future<String> sha256OfFile(File file) async {
  final AccumulatorSink<Digest> output = AccumulatorSink<Digest>();
  final ByteConversionSink input = sha256.startChunkedConversion(output);
  await for (final List<int> chunk in file.openRead()) {
    input.add(chunk);
  }
  input.close();
  return output.events.single.toString();
}
```

### Example 3: HTTP Chunk Downloader with Range Resume

```dart
// lib/infrastructure/downloads/http_chunk_downloader.dart
// Source: dart:io HttpClient API + MDN HTTP Range spec.

import 'dart:io';

class HttpChunkDownloader {
  HttpChunkDownloader({Duration timeout = const Duration(seconds: 60)})
    : _client = HttpClient()..connectionTimeout = timeout;
  final HttpClient _client;

  Future<void> downloadWithResume({
    required Uri url,
    required File destination,
    void Function(int bytesDelta, int totalBytes)? onProgress,
  }) async {
    final int resumeByte = await destination.exists() ? await destination.length() : 0;
    final HttpClientRequest req = await _client.getUrl(url);
    if (resumeByte > 0) {
      req.headers.add(HttpHeaders.rangeHeader, 'bytes=$resumeByte-');
    }
    final HttpClientResponse res = await req.close();

    // Validate server behavior: 206 = honored range, 200 = server ignored (restart).
    final bool gotPartial = res.statusCode == HttpStatus.partialContent;
    if (!gotPartial && resumeByte > 0) {
      await destination.delete(); // server ignored Range; restart
    }

    final IOSink sink = destination.openWrite(mode: gotPartial ? FileMode.append : FileMode.write);
    try {
      await for (final List<int> chunk in res) {
        sink.add(chunk);
        onProgress?.call(chunk.length, res.contentLength);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  void dispose() => _client.close(force: true);
}
```

### Example 4: Streamed Binary Concat

```dart
// lib/infrastructure/downloads/binary_concatenator.dart
// Never load the 5 GB reassembled file into memory.

Future<void> concat({required List<File> parts, required File destination}) async {
  final IOSink sink = destination.openWrite();
  try {
    for (final File part in parts) {
      await for (final List<int> chunk in part.openRead()) {
        sink.add(chunk);
      }
    }
  } finally {
    await sink.flush();
    await sink.close();
  }
}
```

### Example 5: Atomic JSON Manifest Update

```dart
// lib/infrastructure/installed_maps/installed_manifest_repository.dart

Future<void> writeAtomically(InstalledManifest manifest) async {
  final String jsonStr = const JsonEncoder.withIndent('  ').convert(manifest.toJson());
  final File target = File(_manifestFilename);
  final File tmp = File('${target.path}.tmp');
  await tmp.writeAsString(jsonStr, flush: true); // flush=true calls fsync before close
  await tmp.rename(target.path);                  // atomic on ext4/APFS/NTFS
}
```

### Example 6: `tool/check_avoid_maplibre_leak.dart` (new CI gate)

```dart
// Pattern: tool/check_domain_purity.dart (Phase 03) adapted for a forward import rule.
// Source: existing tool/check_domain_purity.dart — same CLI contract, same exit codes.

final RegExp _leakPattern = RegExp(r"""^\s*import\s+['"]package:maplibre_gl(/|['"])""");
final RegExp _allowedDirPattern = RegExp(r'^lib[\\/]infrastructure[\\/]map[\\/]');

Future<int> runCheck({String? rootPath}) async {
  final String root = rootPath ?? p.join(Directory.current.path, 'lib');
  // scan lib/ recursively; exclude the allowed dir; report any match of _leakPattern
}
```

### Example 7: `tool/check_avoid_remote_pmtiles.dart`

```dart
// Scans all *.dart (lib/ + test/) + all *.json (assets/) for pmtiles:// followed by http(s).
// Catches style.json leaks AND accidental Dart-side "remote fallback" snippets.

final RegExp _remote = RegExp(r'pmtiles://https?:');
```

### Example 8: Lazy Freezed `CountryCatalog`

```dart
// lib/domain/map/country_catalog.dart
// Parsed once at app start from assets/maps/catalog.json, cached in a provider.

@freezed
class CountryCatalog with _$CountryCatalog {
  const factory CountryCatalog({
    required String catalogVersion, // e.g. "v20260419" — derived from the first URL
    required List<CountryEntry> countries,
  }) = _CountryCatalog;

  factory CountryCatalog.fromJson(Map<String, dynamic> json) => _$CountryCatalogFromJson(json);
}

@freezed
class CountryEntry with _$CountryEntry {
  const factory CountryEntry({
    required CountryCode alpha3,
    required String name,
    required List<ChunkPart> parts,
    required ReassembledMeta reassembled,
  }) = _CountryEntry;

  factory CountryEntry.fromJson(Map<String, dynamic> json) => _$CountryEntryFromJson(json);
}
```

---

## State of the Art

| Old Approach (pre-2023) | Current Approach (2026) | When Changed | Impact for MirkFall |
|-------------------------|-------------------------|--------------|---------------------|
| Raster tile servers + Mapnik | Vector tiles + client-side styling (MapLibre / MapBox) | Circa 2019; mobile-ready 2021+ | We use the current approach. |
| Hosted PMTiles on S3 with range requests every tile fetch | PMTiles as **local file**; native PMTiles directory reader | MapLibre Native 11.9.0 (Android) / 6.14.0 (iOS) ~2024 | Unblocks 100 %-offline. Without this, MirkFall would need a custom PMTiles decoder or a bundled tile server (unthinkable for a mobile app). |
| `flutter_map` (Dart-side raster) | `maplibre_gl` (native vector) | Phase 07 pivot 2026-04-19 | ~20 MB APK size increase (native SDK) but vector rendering, proper attribution hooks, runtime style switching — required for MAP-04 fog layer. |
| MBTiles (SQLite-backed) | PMTiles (flat-file, directory-based) | Protomaps 2022 spec | Smaller on-disk footprint, no SQLite parse, mmap-friendly on mobile. |
| Server-side style.json | Client-bundled style.json | Long-standing; reaffirmed by offline-first apps | Style is a first-class asset; swap = re-bundle + hot-reload. |
| `custom_lint` / analyzer plugin | `tool/check_*.dart` CLI scripts | Phase 07 CONTEXT decision (user) | 7 scripts after Phase 07 (headers, licenses, deps, domain-purity, platform-manifests, avoid-maplibre-leak, avoid-remote-pmtiles). Pattern: pure-Dart, exit 0/1/2, paired tool/test/, CI step per script. |

**Deprecated / outdated signals to watch:**

- `latlong2` — deprecated in favor of MapLibre's native `LatLng`. Phase 07 removes alongside `flutter_map`.
- `flutter_map: 8.x` — still actively maintained but not a MirkFall fit post-pivot.
- `pmtiles:///<absolute-path>` triple-slash shorthand — works on current MapLibre Native but undocumented; prefer `pmtiles://file:///...`.

---

## Open Questions

1. **Does `MapLibreMapController.setStyle()` lose camera position when called mid-session?**
   - What we know: 0.25.0 release notes say "runtime style switching without tearing down the map" — the map widget survives. But the camera on a fresh style may reset if the style's `center`/`zoom` defaults differ.
   - What's unclear: Whether Phase 07 needs to capture `queryCameraPosition()` before `setStyle` and re-apply `animateCamera` after `onStyleLoadedCallback` fires.
   - Recommendation: Defensive — always capture + re-apply. 10 LoC, no downside. The `FakeMapView` test can't cover this (it doesn't have a real camera), but a real-device smoke test in Plan-07-early can.

2. **Should country swap use `setStyle()` (re-parse whole style.json) or `removeSource()` + `addSource()` (preserves sprite/glyph cache)?**
   - What we know: `addSource`/`removeSource` both exist on `MapLibreMapController`. A source swap is lighter-weight than a full style reload.
   - What's unclear: Whether `VectorSource` construction in 0.25.0 accepts a `url: 'pmtiles://file:///...'` field directly, or requires a `VectorSourceProperties.url` wrapping. API doc excerpt from research says `addSource(String id, SourceProperties properties)`.
   - Recommendation: Plan both paths in Plan-07-04 (country resolver). Prefer source swap if the API accepts the pmtiles URI; fall back to full `setStyle` if not. Both are behind the `MapView.showMap(CountryCode)` contract — implementation choice doesn't leak.

3. **iOS: does `<app_support>/maps/` survive OTA updates and app re-installs preserving data?**
   - What we know: `Application Support` is preserved across app updates and is backed up to iCloud by default (unless excluded via `NSURLIsExcludedFromBackupKey`).
   - What's unclear: Whether we want 5 GB of PMTiles in iCloud backup. Likely no.
   - Recommendation: Apply `NSURLIsExcludedFromBackupKey` to the `maps/` subtree on iOS via a platform channel. ~20 LoC Swift. Prevents iCloud auto-backup of several GB per user. Defer decision to planner; captured here as a must-discuss item.

4. **Is the user's `world-z2.pmtiles` (z0-2, 856 KB) sufficient for the "Day-1 UX map" promise?**
   - What we know: Zoom 0-2 is planet-level (~256 to 1024 pixel tiles per full Earth). Good enough for a "you're somewhere on Earth" marker but not for any city/street context.
   - What's unclear: Whether user actually wants the Day-1 UX to show planet-zoom or a bigger bundle (z0-5) before any country download.
   - Recommendation: Ask user in Plan-07-01 wave-0. Planner decision point. Fallback: Phase 07 ships z0-2 as-is (respects user's asset), Phase 15 polish can bump to z0-5 if feedback warrants (~5-10 MB APK increase).

5. **How is the world bundle's sha256 delivered?**
   - What we know: CONTEXT.md mentions "stored in a special catalog entry or hardcoded in a Dart constant at build time."
   - Recommendation (see Pattern 6 above): hardcoded constant generated by `tool/generate_world_sha256.dart`, committed at Phase-07-01. Keeps world bundle verification completely independent of the catalog (avoids drift path). Planner to ratify.

6. **Do we need `disk_space_plus` at all, or is Android `StatFs` + iOS `NSFileManager.attributesOfFileSystem` trivially accessible via platform channel?**
   - What we know: Yes — both APIs are ~10 LoC each on the native side. The Phase 05 `boot_completed_watchdog` pattern is directly reusable.
   - Recommendation: **Hand-roll** (see §Don't Hand-Roll). Zero new Dart deps + zero audit surface.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (widget-level, Phase 07 presentation layer) + `package:test 1.30.0` (plain-Dart, pure domain + infrastructure) — already pinned |
| Config file | `dart_test.yaml` at repo root (existing from Phase 03) — extend with `@Tags(['soak'])` for the long-running download soak test so default `dart test` runs remain fast |
| Quick run command | `flutter test test/presentation/ test/application/ && dart test test/domain/map/ test/domain/downloads/ test/domain/installed_maps/ test/infrastructure/map/ test/infrastructure/downloads/ test/infrastructure/installed_maps/` |
| Full suite command | The above PLUS `dart test --tags soak test/infrastructure/downloads/download_soak_test.dart` PLUS `dart test tool/test/check_avoid_maplibre_leak_test.dart tool/test/check_avoid_remote_pmtiles_test.dart` |
| Lint gates | `dart run tool/check_avoid_maplibre_leak.dart` + `dart run tool/check_avoid_remote_pmtiles.dart` (exit 0/1/2 contract) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| MAP-01 | Map renders from local `pmtiles://file:///...`. Zero network for tiles. | integration | `flutter test test/integration/airplane_mode_test.dart` (HttpOverrides.runZoned fail-all + MapScreen widget pump) | ❌ Wave 0 |
| MAP-01 | Localized URI helper produces expected `pmtiles://file://...` format | unit | `dart test test/infrastructure/map/pmtiles_source_test.dart -x` | ❌ Wave 0 |
| MAP-02 | `MapLibreMapController.animateCamera` / `moveCamera` round-trips through `MapView.moveCameraTo` | widget | `flutter test test/presentation/screens/map_screen_test.dart -x -n pan_zoom` (via FakeMapView: assert `camerasMoves` list populated) | ❌ Wave 0 |
| MAP-03 | Attribution icon visible; tap opens bottom-sheet with OSM + Protomaps links; liens externes présents dans À propos | widget | `flutter test test/presentation/widgets/map_attribution_icon_test.dart -x` | ❌ Wave 0 |
| MAP-04 | `style.json` layer order is locked to the 8-layer spec; fog layer in position | unit | `flutter test test/presentation/map_style_layer_order_test.dart -x` (reads bundled asset) | ❌ Wave 0 |
| MAP-04 | `noop_mirk_renderer` implements `MirkRenderer` without throwing; paint is empty | unit | `dart test test/domain/mirk/noop_mirk_renderer_test.dart -x` | ❌ Wave 0 |
| MAP-05 | No `pmtiles://http…` URI anywhere in repo (Dart + json) | lint (CI-only) | `dart run tool/check_avoid_remote_pmtiles.dart` (exit 0) | ❌ Wave 0 |
| MAP-05 | Mock test: PmtilesSource returns local URI for installed country, world fallback otherwise | unit | `dart test test/infrastructure/map/pmtiles_source_test.dart -x -n fallback` | ❌ Wave 0 |
| MAP-05 | Country resolver selects correct alpha3 for test fixtures (FR/DE/ES/UK/US + edge cases) | unit | `dart test test/infrastructure/map/country_resolver_test.dart -x` | ❌ Wave 0 |
| MAP-06 | No `package:maplibre_gl` import outside `lib/infrastructure/map/` | lint (CI-only) | `dart run tool/check_avoid_maplibre_leak.dart` (exit 0) | ❌ Wave 0 |
| MAP-06 | `FakeMapView` fully implements `MapView` interface (in-memory state tracking) | unit | `dart test test/fakes/fake_map_view_test.dart -x` | ❌ Wave 0 |
| MAP-06 | MapScreen widget test uses FakeMapView via Riverpod override | widget | `flutter test test/presentation/screens/map_screen_test.dart -x` | ❌ Wave 0 |
| MAP-07 | First-launch copy from asset succeeds + sha256 matches | unit | `flutter test test/infrastructure/map/first_launch_world_copier_test.dart -x` (uses `rootBundle` → needs flutter_test) | ❌ Wave 0 |
| MAP-07 | Re-launch is idempotent (no re-copy when file healthy) | unit | Same file, `-n idempotent` | ❌ Wave 0 |
| MAP-07 | Auto-heal triggers re-copy on sha256 mismatch | unit | Same file, `-n auto_heal` | ❌ Wave 0 |
| MAP-07 | MapsManageScreen renders world as read-only (no delete button) | widget | `flutter test test/presentation/screens/maps_manage_screen_test.dart -x -n world_readonly` | ❌ Wave 0 |
| MAP-08 | Catalog parses successfully from bundled asset | unit | `flutter test test/domain/map/country_catalog_test.dart -x -n parses_bundled` (rootBundle access) | ❌ Wave 0 |
| MAP-08 | MapsDownloadScreen lists countries from catalog | widget | `flutter test test/presentation/screens/maps_download_screen_test.dart -x -n list` | ❌ Wave 0 |
| MAP-08 | Progress bar updates from `DownloadProgress` stream | widget | Same file, `-n progress_updates` | ❌ Wave 0 |
| MAP-09 | Happy path: 1-part download (Aruba 4 MB) → sha256 pass → atomic install | integration | `dart test test/infrastructure/downloads/download_soak_test.dart -x -n happy_1part` (MockHTTPServer via shelf, serves fixture bytes) | ❌ Wave 0 |
| MAP-09 | Multi-part download (stub 4-part 12 MB) → concat → sha256 → atomic | integration | Same file, `-n multi_part` | ❌ Wave 0 |
| MAP-09 | Mid-chunk kill → staging survives → resume picks up via Range | integration | Same file, `-n resume_range` | ❌ Wave 0 |
| MAP-09 | Server ignores Range (returns 200) → restart chunk | integration | Same file, `-n resume_restart` | ❌ Wave 0 |
| MAP-09 | Sha256 mismatch → chunk re-download → second mismatch → abort | integration | Same file, `-n sha_retry` | ❌ Wave 0 |
| MAP-09 | Disk-space-insufficient → DiskSpaceInsufficientException before download | unit | `dart test test/infrastructure/downloads/download_preflight_test.dart -x` | ❌ Wave 0 |
| MAP-09 | Atomic rename → kill between rename and manifest update → next startup sweeps staging | integration | `-n atomic_cleanup` | ❌ Wave 0 |
| MAP-09 | Installed manifest atomic write (tempfile + rename) | unit | `dart test test/infrastructure/installed_maps/installed_manifest_repository_test.dart -x -n atomic` | ❌ Wave 0 |
| MAP-10 | MapsManageScreen lists installed countries with disk size + version | widget | `flutter test test/presentation/screens/maps_manage_screen_test.dart -x -n list_installed` | ❌ Wave 0 |
| MAP-10 | Delete country removes pmtiles + installed.json entry + frees disk | integration | `dart test test/infrastructure/installed_maps/country_delete_test.dart -x` | ❌ Wave 0 |
| MAP-10 | World bundle shows "read-only — cannot be deleted" | widget | `test_n world_readonly_ui` | ❌ Wave 0 |
| MAP-10 | Update-available badge when catalog tag differs from installed.pmtiles_version | widget | Same file, `-n update_badge` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter analyze --fatal-infos --fatal-warnings && dart run tool/check_headers.dart && dart run tool/check_avoid_maplibre_leak.dart && dart run tool/check_avoid_remote_pmtiles.dart && flutter test test/presentation/ && dart test test/domain/map/ test/domain/downloads/ test/infrastructure/map/`
- **Per wave merge:** Full quick suite + `dart test --tags soak test/infrastructure/downloads/download_soak_test.dart`
- **Phase gate:** Full suite green before `/gsd:verify-work` — adds `flutter test test/integration/airplane_mode_test.dart` (airplane-mode subset of QUAL-05) and a real-device manual smoke (Pixel 4a) of map rendering from `world.pmtiles` + 1-part country (Aruba).

### Wave 0 Gaps

All Phase 07 test files are new. Gaps to open as Wave 0 scaffold tasks in Plan-07-01:

- [ ] `assets/maps/world.pmtiles` — copy from `C:\claude_checkouts\files_for_mirkfall\world-z2.pmtiles`
- [ ] `assets/maps/catalog.json` — copy from `C:\claude_checkouts\files_for_mirkfall\catalog.json`
- [ ] `assets/maps/style.json` — Protomaps neutral, rewritten to `asset://` URIs + `pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER`
- [ ] `assets/maps/glyphs/<fontstack>/<range>.pbf` — bundled one-shot from `github.com/protomaps/basemaps-assets`
- [ ] `assets/maps/sprites/sprite.{json,png,@2x.png}` — bundled one-shot same source
- [ ] `assets/maps/polygons/<alpha3>.geo.json` (or `polygons.json` aggregate) — simplified via `mapshaper` tool (one-shot, hors audit, not runtime)
- [ ] `test/fakes/fake_map_view.dart` — FakeMapView in-memory impl
- [ ] `test/fakes/fake_pmtiles_source.dart` — returns deterministic URIs
- [ ] `test/fakes/fake_installed_manifest_repository.dart` — in-memory manifest store
- [ ] `test/fakes/fake_download_controller.dart` — deterministic queue state
- [ ] `test/fakes/fake_country_resolver.dart`
- [ ] `test/fixtures/catalogs/mini_catalog.json` — 5-country subset (FR/DE/ES/UK/US)
- [ ] `test/fixtures/polygons/<alpha3>.geo.json` — simplified 5-country polygons
- [ ] `test/fixtures/pmtiles/tiny.pmtiles` — 1 KB stub with valid header (enough for MapLibre to not crash on load, no actual tiles)
- [ ] `tool/check_avoid_maplibre_leak.dart` + `tool/test/check_avoid_maplibre_leak_test.dart`
- [ ] `tool/check_avoid_remote_pmtiles.dart` + `tool/test/check_avoid_remote_pmtiles_test.dart`
- [ ] `tool/prepare_style.dart` — one-shot glyphs/sprites + style.json rewrite
- [ ] `tool/generate_world_sha256.dart` — one-shot; emits `lib/config/world_bundle_sha256.dart` constant
- [ ] `tool/simplify_polygons.dart` (optional) — wrapper around mapshaper for the 192 polygons
- [ ] `.github/workflows/ci.yml` — 2 new lint steps under `gates` job (after `Check platform manifests`)
- [ ] `android/app/src/main/AndroidManifest.xml` — add `<uses-permission android:name="android.permission.INTERNET"/>` (Plan-07-01 wave-0)
- [ ] `lib/config/constants.dart` — Phase 07 slots per CONTEXT.md §constants (kHttpTimeout, kMapCatalogAssetPath, kWorldPmtilesAssetPath, kWorldPmtilesInternalPath, kCountriesDir, kStagingDir, kInstalledManifestPath, kCountryPolygonsAssetPath, kStyleJsonAssetPath, kInitialSessionMapZoom = 13, kInitialRevealRadiusMeters = 20, kDiskSpaceSafetyMarginMultiplier = 1.1, kDownloadRetryAttempts = 3, kDownloadRetryBaseDelayMs = 1000)
- [ ] `pubspec.yaml` — remove flutter_map + latlong2, add maplibre_gl + crypto promotion, add shelf dev-dep
- [ ] `DEPENDENCIES.md` — audit rows for maplibre_gl 0.25.0, crypto (promote), shelf (promote), Protomaps basemaps-assets (new bundled-assets section)

---

## Sources

### Primary (HIGH confidence)

- maplibre_gl 0.25.0 package: [pub.dev/packages/maplibre_gl](https://pub.dev/packages/maplibre_gl) — BSD-3-Clause, publisher maplibre.org (verified)
- maplibre_gl changelog: [pub.dev/packages/maplibre_gl/changelog](https://pub.dev/packages/maplibre_gl/changelog) — 0.25.0 released 2026-01-07, MapLibre Native Android 12.3.0
- MapLibre Native Android CHANGELOG: [github.com/maplibre/maplibre-native/blob/main/platform/android/CHANGELOG.md](https://github.com/maplibre/maplibre-native/blob/main/platform/android/CHANGELOG.md)
- MapLibre Native iOS CHANGELOG: [github.com/maplibre/maplibre-native/blob/main/platform/ios/CHANGELOG.md](https://github.com/maplibre/maplibre-native/blob/main/platform/ios/CHANGELOG.md)
- MapLibre Android PMTiles example: [maplibre.org/maplibre-native/android/examples/data/PMTiles/](https://maplibre.org/maplibre-native/android/examples/data/PMTiles/)
- Protomaps basemaps: [github.com/protomaps/basemaps](https://github.com/protomaps/basemaps) — BSD-3-Clause (software), CC0 (map design), ODbL (data)
- Protomaps basemaps-assets: [github.com/protomaps/basemaps-assets](https://github.com/protomaps/basemaps-assets) — OFL fonts, BSD sprites
- Protomaps PMTiles for MapLibre: [docs.protomaps.com/pmtiles/maplibre](https://docs.protomaps.com/pmtiles/maplibre)
- MapLibreMapController API: [pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController-class.html](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController-class.html)
- MDN HTTP Range Requests: [developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Range_requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Range_requests)
- `crypto` package: [pub.dev/packages/crypto](https://pub.dev/packages/crypto) — BSD-3-Clause, Dart-team
- Existing MirkFall Phase 03 `DbBackupService.takeBackup` atomic pattern (project code, validated over 3 review gates)
- Existing Phase 01/02/03/04/05/06 `tool/check_*.dart` CLI contract (5 reference implementations)
- 07-CONTEXT.md (all user decisions for Phase 07, confirmed 2026-04-20)

### Secondary (MEDIUM confidence)

- Flutter MapLibre GL issue #338 (asset:// sprites/glyphs) — [github.com/maplibre/flutter-maplibre-gl/issues/338](https://github.com/maplibre/flutter-maplibre-gl/issues/338) — open issue 2023-11-27; workaround is to bundle assets and use `asset:///` prefix as per Phase 07 CONTEXT decision
- MapLibre Native issue #3562 (addProtocol for custom URL schemes) — [github.com/maplibre/maplibre-native/issues/3562](https://github.com/maplibre/maplibre-native/issues/3562) — confirms `pmtiles://` is special-cased, not generic protocol hook
- Source added by Style.addSource destroyed on MapView destroy: [github.com/maplibre/maplibre-native/issues/3269](https://github.com/maplibre/maplibre-native/issues/3269) — informs Pitfall 9 (platform-view rebuild)
- MapTiler Flutter guide: [docs.maptiler.com/flutter/maplibre-gl-js/get-started/](https://docs.maptiler.com/flutter/maplibre-gl-js/get-started/)
- Stadia Maps Flutter example: [github.com/stadiamaps/flutter-maplibre-gl-example](https://github.com/stadiamaps/flutter-maplibre-gl-example)
- Medium article on MBTiles rendering with MapLibre GL Flutter: [medium.com/@pranimsingh7/offline-mapping-in-flutter-rendering-mbtiles-with-maplibre-gl-e63e7a7ec52d](https://medium.com/@pranimsingh7/offline-mapping-in-flutter-rendering-mbtiles-with-maplibre-gl-e63e7a7ec52d) — pattern adapted to PMTiles
- DeepWiki on offline maps: [deepwiki.com/maplibre/flutter-maplibre-gl/5.3-offline-maps](https://deepwiki.com/maplibre/flutter-maplibre-gl/5.3-offline-maps)
- Rosetta Code ray-casting algorithm: [rosettacode.org/wiki/Ray-casting_algorithm](https://rosettacode.org/wiki/Ray-casting_algorithm) — basis for hand-rolled `point_in_polygon.dart`

### Tertiary (LOW confidence — flagged for validation)

- Community claim that GitHub Releases `objects.githubusercontent.com` supports Range requests (S3-backed CloudFront). Widespread but not documented officially. Validation plan: a Phase 07 Plan-01 wave-0 `curl -I -H "Range: bytes=0-1024" <catalog.parts[0].url>` smoke check recording the response in `docs/phase-07-smoke.md` for posterity.
- Protomaps `basemaps-assets` exact SPDX for sprite PNG sheets — OFL for fonts verified by direct repo inspection of `fonts/OFL.txt`; sprite license is inherited from the parent project's "CC0" map-design release but the repo does not carry a top-level LICENSE — add explicit inspection step to Phase 07 Plan-01 DEPENDENCIES.md audit row.
- Exact `VectorSource` constructor signature in maplibre_gl 0.25.0 for `pmtiles://file://` URI (whether it's `VectorSource(url: ...)` or wraps in `VectorSourceProperties`). Validation plan: author `lib/infrastructure/map/maplibre_map_view.dart` with both paths and let the compiler + smoke test arbitrate.

---

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — maplibre_gl 0.25.0 licensing + PMTiles support verified via pub.dev + native CHANGELOG + Protomaps docs.
- Architecture: **HIGH** — patterns 1, 2, 3, 5, 6 mirror Phase 03/05 patterns already shipping in `main`. Pattern 4 (layer order) is inherent to Protomaps style convention. Patterns 7–8 are lint mechanics validated 5 times before.
- Pitfalls: **MEDIUM-HIGH** — 12 pitfalls catalogued; the top 4 (mid-write, glyphs leak, URI ambiguity, iOS Files opacity) are directly actionable. Pitfalls 7-8 (GitHub Releases CDN behaviour) are community-confirmed but not GitHub-documented — marked as Tertiary source.
- Code examples: **HIGH** for Dart-side idiom (the crypto, atomic-rename, range-header, point-in-polygon patterns are textbook). **MEDIUM** for exact maplibre_gl 0.25.0 API signatures on `VectorSource` (needs compile-time validation — see Open Question #2).
- Validation architecture: **HIGH** — leverages existing `flutter_test` + `package:test` infra, `@Tags` convention from Phase 03, tool/test/ convention from Phase 02–06.

**Research date:** 2026-04-21
**Valid until:** 2026-05-21 (30 days — maplibre_gl 0.25.0 is stable, unlikely to churn. Re-verify before Plan-07-01 if > 30 days pass.)

---

*Research complete for Phase 07: Map Integration. Ready for /gsd:plan-phase 07.*
*Author: gsd-researcher (Claude Opus 4.7 1M).*
