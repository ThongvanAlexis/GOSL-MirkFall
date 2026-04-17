# Feature Research — MirkFall

**Domain:** Real-world fog-of-war / exploration journal mobile app
**Researched:** 2026-04-17
**Confidence:** HIGH (multiple sources corroborated per claim; direct competitor docs + user-report evidence)

---

## Competitor Landscape

Research focused on the actual live competitors MirkFall will be compared to:

| Product | Genre | Model | Relevance |
|---------|-------|-------|-----------|
| **Fog of World** (Ollix) | The genre-defining "fog of war" app (since 2012, iOS+Android) | One-time purchase ~$29.99 | Direct competitor — closest to MirkFall |
| **World Uncovered** | Freemium fog-of-war clone (iOS) | Free + $3.99 unlock | Direct competitor |
| **FogOff / WonderWalkar / FogoftheWorld** (GitHub) | Indie open-source fog-of-war attempts | Free, mostly unfinished | Ecosystem signal — unmet demand |
| **Polarsteps** | Trip tracker / travel journal | Free + paid books €30-€80 | Adjacent — trip logging, good on data export |
| **Wanderlog** | Trip planner with offline maps | Free + Pro (offline maps paid) | Adjacent — POI management, offline |
| **Strava** (personal heatmap) | Activity tracker with heatmap | Subscription | Adjacent — revealed-area visualization reference |
| **Visited / Been** | Country-level check-in | Free + IAP | Adjacent — lighter-weight |
| **Map Notes / Mapstra** | Map journal with photo pins | Freemium | Adjacent — marker UX reference |
| **Google Maps Timeline** | Automatic location history | Free (Google owns the data) | Cultural reference — users expect "I can see where I've been" |

Key corroborating evidence captured throughout this document:
- Fog of World uses an **undocumented proprietary format** — the community had to reverse-engineer it (CaviarChen/Fog-of-World-Data-Parser on GitHub, archived 2021, "there are some parts I haven't figured out"). This is the single most important data point for MirkFall's positioning.
- An iOS user reported losing **56 levels and thousands of tracked miles** after a Fog of World update (went from level 296 to 240). Data loss in the category's flagship is a live issue.
- Fog of World **dropped Google Drive support** because Google introduced a mandatory $9,000/year CASA Tier 3 audit — a one-time-purchase indie app cannot absorb that. Users must manually copy files between cloud providers. This is the cloud-sync-fragility story MirkFall's local-first design specifically avoids.
- Fog of World has **no markers, no photos, no POIs** — just tracks and badges. MirkFall's marker+photo+category system is a feature gap in the flagship competitor, not a copy.

---

## Feature Landscape

### Table Stakes (Users Expect These — Missing = Product Feels Broken)

If MirkFall ships without these, users from Fog of World / Polarsteps / Visited will immediately perceive it as incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Fog reveal around current position** | Entire reason to install the app. Revealed by walking is the core mechanic. | M | Already in spec §3. Must feel responsive (update < 1-2s after GPS fix). |
| **Background GPS tracking** | Nobody wants to hold the phone in front of their face while walking. Fog of World users complain loudly when background breaks. | L | Needs iOS `UIBackgroundModes=location` + Android `ACCESS_BACKGROUND_LOCATION` + `FOREGROUND_SERVICE_LOCATION`. Flutter plugin (`geolocator` or `flutter_background_service`) — MIT/BSD. Validate on POC per spec §9. |
| **Persistent notification while tracking** | Platform requirement on Android (foreground service); iOS users expect a visible sign tracking is active (trust). | S | Spec §2.3. Standard Android `ForegroundService` pattern. |
| **Standard interactive map (pan / zoom / rotate)** | A map that doesn't pan/zoom smoothly is broken by 2026 standards. Mirk must not interfere with gestures. | S (map), M (mirk overlay integration) | `flutter_map` + OSM tiles is the lowest-friction option; see STACK.md. |
| **Persistent local storage** | Users expect the app to remember their progress between launches — obviously. | S | Spec §2.2. |
| **GPS permission request flow with rationale** | Modern OS store review requires a human-readable justification. iOS `Info.plist` strings, Android runtime dialog. | S | Must be written before first store submission — see CLAUDE.md `Info.plist` rules. |
| **Battery-conscious tracking** | Fog of World v2 was specifically praised for battery improvements over v1. Users *will* uninstall if battery drains fast. | M | Configurable GPS sampling, distance-based rather than time-based filters, pause when stationary. |
| **"Start / Stop session" UX** | Spec §2.2 — users need control; no always-on tracking without consent (aligns with GOSL privacy stance). | S | Bolted to spec; implementation trivial once tracking plumbing exists. |
| **Markers visible on the map with icons** | Table stake for any location-journaling app (Polarsteps, Mapstra, Map Notes all do this). | M | Spec §4. Custom renderer for RPG-style icons (`flutter_map` marker layer + custom widget). |
| **Marker detail view (title + notes + photos)** | Every travel journal competitor has this. | S | Spec §4.1. Standard detail page. |
| **Create multiple independent "worlds" / sessions** | Fog of World v2 added this as a headline feature ("Multiple Databases"). Users want separation between "daily commute" and "Italy roadtrip". | S | Spec §2. |
| **Zero telemetry / offline-by-default** | Paradoxically table-stakes for the target audience (ex-Fog-of-World users, privacy-minded hikers). Fog of World brags about it. | S (mostly "don't add SDKs") | Enforced by CLAUDE.md + GOSL. |
| **About / Legal screen** | App store submission requirement + GOSL header requirement (`CLAUDE.md`: "MirkFall is distributed under GOSL v1.0"). | S | Spec §Qualité. |

### Differentiators (Where MirkFall Competes)

These are what MirkFall can credibly claim over the competition. Ranked by strategic weight.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Versioned human-readable JSON import/export (sessions, markers, styles)** — PRIORITY #1 | Fog of World's format is undocumented and had to be reverse-engineered by the community. The competitor-flagship product lost users 56 levels in an update. MirkFall's pitch: "your progression is yours, in a format you can read in any text editor, forever." | L | Spec §5. Schema must carry `version`. Human-readable = no base64 blobs for mirk state (use a sparse tile index or similar — see ARCHITECTURE.md). Versioned = migrations are a solved problem by V2. |
| **Full marker model: photo galleries + notes + RPG-style custom category icons** | Fog of World has no markers at all. World Uncovered has none. MirkFall offers the "travel journal" layer on top of the fog mechanic — a combination none of the direct competitors ship. | L | Spec §4. Requires: photo picker (MIT `image_picker`), local photo storage under `<app_docs>/photos/<session_id>/`, icon pack abstraction. |
| **Atmospheric mirk rendering (not an opaque black overlay)** | Fog of World's mirk is a static grey/black overlay; World Uncovered similar. MirkFall's "living, moving, cloudy" mirk is a visual differentiator the author explicitly calls out in spec §3.2. | L | Custom `CustomPainter` or shader (Flutter 3.7+ fragment shaders). Architecture must be swappable (spec §3.2: "codé de manière générique"). |
| **Importable mirk style files** | No competitor has this. Turns the visual into a community-extensible system without bloating the app. | M | Spec §3.3. JSON-described style params (noise scale, base color, speed, etc.). |
| **Pre-seed a session by importing a marker-only JSON** | "I'm going to Rome next month; here's a JSON my friend sent me with 40 must-visit spots." No direct competitor supports this cleanly — Polarsteps wants you to plan inside their app, Wanderlog locks its exports behind Pro. | M | Spec §5.2. Reuses the import path; just a different payload shape. |
| **Markers visible in transparency under mirk** | Design decision from PROJECT.md. Lets users navigate toward unvisited pre-seeded spots without revealing the territory. Uniquely compatible with the pre-seed import use case. | S | Rendering choice in marker layer; mirk layer does not occlude markers but attenuates colors. |
| **Local-first, no account, no server** | Fog of World markets this too — but they still depend on Google/Dropbox/OneDrive APIs (and have been burned by Google). MirkFall takes it further: "no cloud at all, you own the files on disk." | S | Enforced by architecture; zero new code. |
| **GOSL license + published source on GitHub** | Users can audit what the app does, build it themselves, fork it. Fog of World is closed-source; the open-source alternatives (FogOff, WonderWalkar) are abandoned/unfinished. MirkFall credibly claims "the first complete open-source fog-of-war app with durable data portability." | S | Already the plan. |
| **Explicit per-session file share (send `.json` to a friend)** | Aligned with GOSL (no server, no account), aligned with core value. A friend sharing their "Kyoto 2025" session becomes a file attachment in Signal/email — no social feed, no cloud dependency. | S | Same code path as export, just invokes platform share sheet. |
| **Reveal radius configurable globally** | Fog of World exposes this in settings; not a differentiator vs them, but a differentiator vs World Uncovered / FogOff which have hardcoded radii. Cheap to add, expected by power users. | S | Spec §3.1. Already in scope. |

### Anti-Features (Deliberately Rejected — With Reasoning MirkFall Can Cite)

Critical for a GOSL project. Documenting these protects scope and gives the author talking points for refusing future feature requests.

| Anti-Feature | Why Users Request It | Why MirkFall Rejects It | Alternative Offered |
|--------------|----------------------|--------------------------|---------------------|
| **Cloud sync (built-in to a provider)** | "I want my progress on all my devices." | Pulls a live dependency on a third-party platform — *exactly* what burned Fog of World with Google Drive's $9k/year audit fee. Forces one of: accounts, server code, or brittle OAuth flows (violates "no telemetry/no account" from CLAUDE.md). | **Import/export JSON** covers the "I lost my phone" case. User can put files on any cloud they already use (iCloud Drive, Dropbox, Syncthing, a USB stick). |
| **Paid tiers / in-app purchases / ads** | Industry standard monetization. | **Explicitly forbidden by GOSL v1.0.** Also violates project philosophy ("projet-cadeau"). | None — the app is free, source is public, binaries are on GitHub Releases. |
| **Analytics / crash reporting / A/B testing / attribution SDKs** | "Helps improve the product." | **Explicitly forbidden by CLAUDE.md project rules and GOSL v1.0.** Any such SDK is disqualified at audit. | **Local logs** in `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` (per CLAUDE.md) — user can read / share them voluntarily if they want to report a bug. |
| **Badges / levels / achievements system** | Fog of World and World Uncovered both have this. Gamification seems engaging. | Out of scope per PROJECT.md ("pas dans l'esprit du projet"). Adds state to persist, migrate, compute, balance, and translate — non-trivial complexity. Fog of World's "level 296 → 240" data-loss incident shows the downside: the *gamified* progress is what users mourn. MirkFall stays focused: the map is the reward. | Keep the reward *intrinsic* (seeing the mirk clear). A later optional stats screen could show territory % without ranking. |
| **Global leaderboards / social feeds / friend graph** | World Uncovered integrates Game Center; Strava has "segments"; competitive instinct. | Requires an account, a server, moderation, ToS, GDPR handling — all contrary to GOSL "don't build infrastructure" philosophy. | Local file sharing of sessions (see differentiators) — friends compare maps if they want, peer-to-peer, without central infrastructure. |
| **Real-time track sharing with friends** | "Find my" / Life360 style. | Requires a persistent server, push infra, privacy nightmares. Explicitly out of scope in spec §8. | Deferred / permanently anti-feature. |
| **Automatic re-fog of stale zones (temporal decay)** | Some Fog of World users ask for it ("re-fog zones I visited 5 years ago"). | **Explicitly out of scope per spec §8** ("Re-brumage temporel des zones révélées — contraire au design"). The design promise is "explored stays explored." | None — this is a design stance, not a missing feature. |
| **Full-world exploration statistics (distance walked, %-of-world-revealed, streak tracking)** | Fog of World has elaborate stats per continent/country. | Out of scope per spec §8, likely post-V1. Risk of re-introducing gamification pressure; also requires offline reverse-geocoding (Fog of World ships a huge embedded database for this — complexity and APK bloat). | A simple area-revealed indicator could arrive in V1.1 without the geocoding heaviness. |
| **Third-party integrations (Strava import, Google Photos, Apple Photos auto-pin, Instagram)** | Convenience: "pull my existing data in." | Explicitly out of scope (spec §8, PROJECT.md) — violates GOSL on dependency audit and telemetry. | **GPX import** could be considered post-V1 as a plain-file import (read-only, no SDK, no OAuth) — it's the same spirit as JSON import. Not in V1 scope. |
| **Multi-user session sharing / real-time multiplayer** | "Play with my partner." | Explicitly out of scope (spec §8). Requires server + accounts — contrary to philosophy. | Share the `.json` file when the trip is done. |
| **Proprietary binary storage format for mirk state** | "It's smaller / faster." | Violates spec §5.3 ("lisible à la main, pas de blob binaire injustifié") and MirkFall's differentiator claim ("human-readable"). Fog of World went this way — and it's why a random GitHub user had to reverse-engineer the format in 2020. | Sparse-tile JSON representation (gzipped only at the on-disk boundary if needed). See ARCHITECTURE.md. |
| **Update-check / phone-home on launch** | Some apps prompt users about new versions. | **Forbidden by CLAUDE.md** ("Update checks automatiques — interdits sauf si explicitement demandés par l'utilisateur"). Distribution is via GitHub Releases — user pulls, not push. | Mention latest-version check only inside the "About" screen, triggered by an explicit button press (if ever). Not V1. |
| **Fine-grained photo cloud backup (embed photos in JSON export)** | "I want photos in the same file." | Makes JSON files huge, breaks the "human-readable" promise, and risks base64 bloat. Spec §9 explicitly leaves this to be decided. | Export as a **ZIP archive** containing `session.json` + `photos/` directory. Keeps JSON readable, photos as files. Decision to validate during roadmap. |

### Edge/Clarification Cases

| Case | MirkFall's Posture |
|------|---------------------|
| **Offline map tile download** | V1 codes the abstraction (spec §6.2), UI for downloading tiles arrives in V1.1. Flutter ecosystem has `flutter_map_cache` (MIT) — the GPL-licensed `flutter_map_tile_caching` is **forbidden under CLAUDE.md** licensing rules. See STACK.md. |
| **Background GPS review argument (Apple/Play Store)** | App is not going through official stores (sideload + APK releases per PROJECT.md), so no review argument needed in V1. If MirkFall ever publishes to stores, `NSLocationAlwaysAndWhenInUseUsageDescription` needs a user-benefit string ("MirkFall reveals the map as you walk; background tracking lets it work with your phone in your pocket"). |
| **Photo permission on iOS** | `NSPhotoLibraryUsageDescription` in `Info.plist` required as soon as marker photo-pick is implemented. CLAUDE.md mandates keeping Info.plist current. |
| **Per-session mirk style** | V1 = app-global style (spec §3.3). Per-session would require style-id persisted on each session record — deferred to V2 candidates. |

---

## Feature Dependencies

Roadmap-critical. Feature X requires Feature Y means Y must land first.

```
                    [Local persistence layer]
                              |
                              v
             [Session CRUD] ------> [Start/Stop lifecycle]
                   |                         |
                   |                         v
                   |                  [GPS tracking]
                   |                         |
                   |                         v
                   |                  [Background tracking + notification]
                   |                         |
                   |                         v
                   |                   [Mirk reveal radius]
                   |                         |
                   |                         v
                   |                 [Mirk state storage (sparse tiles)]
                   |                         |
                   |                         v
                   |                 [Mirk rendering (strategy interface)]
                   |                         |
                   |                         +---> [Default atmospheric style]
                   |                         |
                   |                         +---> [Style import from JSON]
                   |
                   +---> [Marker CRUD]
                              |
                              +---> [Icon + category system]
                              |            |
                              |            +---> [Custom category creation]
                              |
                              +---> [Photo attachment]
                              |            |
                              |            +---> [Photo permission flow]
                              |            +---> [Local photo storage]
                              |
                              +---> [Marker list UI]
                              +---> [Marker detail UI (gallery)]

  [Session CRUD] + [Marker CRUD] + [Mirk state storage]
                              |
                              v
                [Versioned JSON schema (`version` field)]
                              |
                              v
                [Export single session] ---> [Export all sessions (ZIP)]
                              |
                              v
                [Import session JSON] ---> [Import markers-only JSON]
                              |
                              v
                       [Import style JSON]

  [Options screen]  depends on: [reveal radius setting], [active mirk style],
                                 [imported styles list], [category management],
                                 [global import/export entry point]

  [About/Legal screen]  depends on: nothing (can ship early).
```

### Dependency Notes (the ones that matter for phase ordering)

- **Mirk state storage must precede export format.** The on-disk mirk representation *is* what gets serialized in the export — deciding a tile format late means rewriting the export later. Design both together in an early phase.
- **The "generic mirk renderer" interface must precede any concrete style.** Spec §3.2 explicitly mandates this. Getting this wrong is a rewrite in V1.1 when adding importable styles.
- **Icon/category system must precede marker creation UI.** You can't show an icon picker without an icon catalog.
- **Background tracking must precede anything that claims to "work while the phone is in your pocket."** iOS/Android permission flows, foreground service plumbing, and a validated POC (spec §9) gate every downstream feature. If the POC fails, the whole product premise collapses — this is the #1 project risk.
- **Versioned JSON schema must exist before V1 ships**, not in V1.1. Adding `"version": 1` after shipping V1 means every future migration must parse un-versioned files as a special case.
- **Photo storage layout must be decided before the first export.** If photos are referenced by relative path, export is a ZIP; if base64, JSON balloons. Choose before V1 export code, per spec §9 open question.

---

## MVP Definition

### Launch With (V1.0)

From PROJECT.md "Active" list and the spec — tightened to what's genuinely non-negotiable for a credible V1:

- [ ] **Session CRUD** (create / rename / delete / list)
- [ ] **Session lifecycle** (Start/Stop with exclusivity — one active at a time)
- [ ] **Local persistence** of session state (sessions, markers, revealed mirk)
- [ ] **GPS permission + background tracking** with persistent notification
- [ ] **Reveal circular around current position** with globally-configurable radius
- [ ] **Mirk rendering pipeline** — generic interface + at least 2 atmospheric styles
- [ ] **Import mirk style from JSON**
- [ ] **Marker CRUD** (position / title / notes / 0..n photos / category+icon)
- [ ] **Default RPG-icon category pack**
- [ ] **Custom category creation** (name + icon)
- [ ] **Markers visible in transparency under mirk** (design decision locked)
- [ ] **Marker detail view** (title / notes / photo gallery)
- [ ] **Versioned JSON schema** (`version` field, documented in a `SCHEMA.md`)
- [ ] **Export single session** (JSON/ZIP — decide during phase 1)
- [ ] **Export all sessions** (single archive)
- [ ] **Import session JSON**
- [ ] **Import markers-only JSON**
- [ ] **Options screen** (reveal radius / active style / imported styles / categories / global import-export)
- [ ] **About / Legal screen** with GOSL mention + link
- [ ] **Standard OSM map backdrop**, interactive under mirk
- [ ] **Local log file** (`<app_docs>/logs/…`) per CLAUDE.md
- [ ] **CI pipeline**: Android build (ubuntu-latest) + iOS unsigned build (macos-latest)
- [ ] **License header in every source file**
- [ ] **DEPENDENCIES.md** audit file

### Add After Validation (V1.1)

- [ ] **Offline tile download UI** (abstraction exists in V1; this is the UI + per-region selection)
- [ ] **Simple exploration stats** (area revealed, # of sessions, # of markers) — no gamification, just a status screen
- [ ] **Per-session mirk style** (override the global choice per session)
- [ ] **Icon pack import** (extend the custom-category system to bulk-import a pack)
- [ ] **GPX import** as a read-only alternative to JSON session import (feed it legacy data from hiking apps)
- [ ] **Multi-language support** (FR/EN at minimum — author is francophone)

### Future Consideration (V2+)

- [ ] **Track-editor** (fix GPS drift manually) — Fog of World markets this; could make sense for MirkFall too, but requires UI work orthogonal to V1.0
- [ ] **Richer export formats** (KML/GPX export of the *path*, not just the fog state — useful for sharing with other apps)
- [ ] **iOS Siri Shortcuts / Android intents** (start/stop a session by voice)
- [ ] **Widget (home screen)** showing current session + small map
- [ ] **Custom base map tiles** (user-provided MBTiles file) — aligns with "bring your own cartography" philosophy

---

## Feature Prioritization Matrix (V1.0)

| Feature | User Value | Impl. Cost | Priority | Rationale |
|---------|------------|------------|----------|-----------|
| Session CRUD | HIGH | LOW | **P1** | Container for everything. |
| GPS + background tracking | HIGH | HIGH | **P1** | Core mechanic. Project-killer if it fails on one platform. |
| Mirk reveal + storage | HIGH | HIGH | **P1** | The reason the app exists. |
| Mirk renderer (generic + 2 styles) | HIGH | MEDIUM | **P1** | Visual quality is half the product; architecture lock-in risk is high if it's rushed. |
| Versioned JSON export (session) | HIGH | MEDIUM | **P1** | *The* differentiator. Cannot ship without it. |
| Import session JSON | HIGH | MEDIUM | **P1** | Symmetry with export; "I lost my phone" story only works round-trip. |
| Marker CRUD + detail | HIGH | MEDIUM | **P1** | Users from Polarsteps/Mapstra will expect this. |
| Photo attachment to markers | HIGH | MEDIUM | **P1** | Markers without photos feel thin. |
| Category + RPG icon system | MEDIUM | MEDIUM | **P1** | Author-specified design; also underpins custom categories. |
| Custom category creation | MEDIUM | LOW | **P1** | Trivial once the icon system exists. |
| Style import JSON | MEDIUM | LOW | **P1** | Cheap lever; extends the "JSON is the API" story. |
| Export all sessions | MEDIUM | LOW | **P1** | Users backing up "everything" before a phone migration. |
| Import markers-only JSON | MEDIUM | LOW | **P1** | Unlocks the "pre-seed your trip" use case — cheap enabler of a differentiator. |
| Options screen | MEDIUM | LOW | **P1** | Glues all settings together. |
| About / Legal screen | LOW | LOW | **P1** | Mandatory per GOSL / CLAUDE.md. |
| Offline tile download UI | MEDIUM | HIGH | **P2** | Nice-to-have V1 (spec §6.2), explicitly OK to defer; must leave abstraction in V1. |
| Area-revealed stat | LOW | LOW | **P2** | Cheap once mirk-tile storage exists; consciously kept dumb (no leaderboard). |
| Per-session style | LOW | LOW | **P3** | Minor polish. |
| Automatic photo import from gallery | LOW | MEDIUM | **P3** | Adjacent to anti-features (GPS metadata scraping) — user can add photos manually V1. |

---

## Competitor Feature Matrix (MirkFall's Talking Points)

| Feature | Fog of World | World Uncovered | Polarsteps | Wanderlog | **MirkFall (V1.0)** |
|---------|--------------|-----------------|------------|-----------|---------------------|
| Real-world fog of war | Yes | Yes | No | No | **Yes** |
| Atmospheric / animated mirk | No (static) | No (static) | — | — | **Yes (differentiator)** |
| Multiple independent sessions | Yes ("databases") | Partial ("trips") | Yes ("trips") | Yes | **Yes** |
| Markers with photos + notes | **No** | No | Yes (auto) | Yes | **Yes (differentiator vs Fog of World)** |
| Custom category icons | No | No | No | Limited | **Yes (RPG pack — differentiator)** |
| Background GPS tracking | Yes | Yes | Yes | Partial | **Yes** |
| Offline map tiles | Paid (premium) | Limited | No | **Pro (paid)** | **V1.1 (free)** |
| Import tracks (GPX / KML) | Yes | Yes (+ FoW backups) | No | No | V1.1 (GPX post-V1) |
| **Export to open / portable format** | **Only proprietary blob (reverse-engineered)** | **GPX only** | JSON + GPX | Paid (Google Maps) | **Versioned human-readable JSON — differentiator #1** |
| Import session from another device | Manual file copy (undocumented format) | Limited | Via cloud | Via cloud | **Direct file import (core value)** |
| Import markers-only (pre-seed trip) | **No** | No | No | No | **Yes (unique)** |
| Importable mirk styles | **No** | No | — | — | **Yes (unique)** |
| Cloud sync dependency | Yes (iCloud / Dropbox / OneDrive) — **lost Google Drive in 2024** | Yes (Dropbox) | Mandatory (has account) | Mandatory (has account) | **No (local-first, by design)** |
| Requires account | No | No | **Yes** | **Yes** | **No** |
| Telemetry / analytics SDKs | Claims none | Unknown | **Yes (expected for a social app)** | **Yes** | **None (GOSL-enforced)** |
| Gamification (badges/levels) | **Yes (65 badges)** | **Yes (points + Game Center leaderboard)** | No | No | **No (anti-feature, differentiator by omission)** |
| Social sharing feed | No | Facebook / Twitter | Yes | Yes | **No (anti-feature)** |
| Open-source | **No** | No | No | No | **Yes (GOSL v1.0 — unique)** |
| Price | $29.99 one-time | Free + $3.99 | Free + paid books | Free + Pro subscription | **Free forever** |

**Headline positioning MirkFall can credibly use:**

1. **"Lose your phone, not your progression."** Import/export of versioned, human-readable JSON. Fog of World users had to reverse-engineer the format themselves (CaviarChen/Fog-of-World-Data-Parser) — MirkFall publishes the schema.
2. **"Your map, your markers, your files."** Zero cloud dependency. Fog of World lost Google Drive to a $9k/year audit fee; MirkFall can't — it doesn't depend on anything external.
3. **"The first fog-of-war app with a real marker system."** Photos, notes, RPG-style custom icons, and pre-seed by JSON — all features the genre-defining competitor simply doesn't have.
4. **"Zero ads, zero telemetry, zero subscriptions. Forever."** Enforced by GOSL v1.0; auditable in the source on GitHub.

---

## Decisions Locked by This Research

| Decision | Supported By |
|----------|--------------|
| Data portability is the #1 marketing claim, not a bonus | Fog of World's $9k CASA incident + undocumented-format reverse-engineering + 56-level data loss report |
| No built-in cloud sync in V1 (anti-feature) | Same evidence as above |
| Keep JSON human-readable (no base64 mirk blob) | Spec §5.3 + differentiator promise |
| Photos exported as ZIP archive with `photos/` folder | Keeps JSON readable; Polarsteps' `locations.json` + photos-as-files model validates the pattern |
| Gamification (badges/levels/leaderboards) is a permanent anti-feature | Spec §8 + GOSL philosophy + "level 296 → 240" cautionary tale |
| Background tracking is V1 P1 and needs a POC early | Spec §9 explicitly flags it as a risk to validate |
| Atmospheric mirk rendering is a differentiator worth the complexity | Author-specified in spec §3.2, competitors ship static overlays |
| Offline tiles UI deferred to V1.1; abstraction present in V1 | Spec §6.2 + CLAUDE.md forbids GPL `flutter_map_tile_caching` |

---

## Open Questions for Roadmap Planning

(Items the roadmap agent / requirements phase must resolve — mostly covered in spec §9 but called out here because they touch feature design.)

1. **Photo embedding format.** Embed base64 in JSON vs. ZIP archive vs. references-only. Affects size, portability, and the "human-readable" claim. Recommendation: **ZIP archive** with `manifest.json` + `photos/` dir.
2. **Mirk tile representation.** Sparse grid, H3/geohash cells, or coordinate polygon? Affects export size and rendering perf. Must be decided *before* export format is frozen. Recommendation: research phase output — see ARCHITECTURE.md.
3. **Default reveal radius.** Spec §3.1 says "e.g., 50 m" — needs a field decision. Consider 25-50 m for urban walking.
4. **Markers-under-mirk visual treatment.** "Visible in transparency" — how much transparency? Subtler / more transparent as mirk opacity increases? UX decision.
5. **OSM tile policy compliance.** `flutter_map`'s built-in caching is OSM-policy-compliant; alternative providers require evaluation. See STACK.md.
6. **Locale / units.** Meters vs. feet. Default to device locale; expose override in options post-V1 (spec §7).

---

## Sources

### Primary Competitor Data
- [Fog of World App Store (iOS)](https://apps.apple.com/us/app/fog-of-world/id505367096) — pricing, feature list, in-app purchases verified
- [Fog of World Google Play](https://play.google.com/store/apps/details?id=com.ollix.fogofworld) — Android availability
- [Fog of World official site](https://fogofworld.app/en/) — features, privacy claims
- [Fog of World is Dropping Google Drive Support (Medium, Ollix)](https://medium.com/fogofworld/fog-of-world-is-dropping-google-drive-support-df5016f85da4) — CASA $9k/year evidence
- [How Sync Works in Fog of World (Medium)](https://medium.com/fogofworld/how-sync-works-in-fog-of-world-b29f73172b7e) — sync mechanism details
- [Fog of World 2 review — Brian Mitchell](https://brianm.me/posts/fog-of-world-2/) — feature breakdown, battery improvements
- [CaviarChen/Fog-of-World-Data-Parser (GitHub)](https://github.com/CaviarChen/Fog-of-World-Data-Parser) — evidence of undocumented proprietary format requiring reverse-engineering
- [World Uncovered (App Store)](https://apps.apple.com/us/app/world-uncovered/id1119505618) — pricing, features
- [World Uncovered FAQ (official)](http://www.worlduncovered.com/faq.html) — features confirmed

### Adjacent / Reference Competitors
- [Polarsteps data export help](https://support.polarsteps.com/hc/en-us/articles/24266264821138) — `locations.json`, `trip.json` format, GPX export
- [niekvleeuwen/polarsteps-data-parser (GitHub)](https://github.com/niekvleeuwen/polarsteps-data-parser) — third-party parser evidence
- [Wanderlog free trip planner](https://wanderlog.com/blog/2024/10/14/is-there-a-free-trip-planner/) — free vs. Pro feature split
- [Strava Personal Heatmaps](https://support.strava.com/hc/en-us/articles/216918467-Personal-Heatmaps) — subscription-gated heatmap
- [Visited App](https://visitedapp.com/) — country-level check-in reference

### Open-Source / Ecosystem Signals
- [mxvlk/FogOff (GitHub)](https://github.com/mxvlk/FogOff) — indie fog-of-war GPS app
- [quentinchaignaud/fog-of-war (GitHub)](https://github.com/quentinchaignaud/fog-of-war) — Flutter fog-of-war library on top of flutter_map
- [mmichaud93/FogoftheWorld (GitHub)](https://github.com/mmichaud93/FogoftheWorld) — Android fog-of-war app

### Platform / Technical Context
- [flutter_map offline mapping docs](https://docs.fleaflet.dev/tile-servers/offline-mapping) — OSM policy + caching
- [flutter_map_cache (pub.dev)](https://pub.dev/packages/flutter_map_cache) — MIT caching option
- [flutter_background_geolocation (pub.dev)](https://pub.dev/packages/flutter_background_geolocation) — heavyweight background tracking plugin
- [geolocator (pub.dev)](https://pub.dev/packages/geolocator) — standard Flutter GPS plugin

---

*Feature research for: MirkFall — fog-of-war Flutter mobile app*
*Researched: 2026-04-17*
*Next consumer: REQUIREMENTS.md + roadmap phase structuring*
