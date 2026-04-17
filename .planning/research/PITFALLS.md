# Pitfalls Research — MirkFall

**Domain:** Flutter mobile app (iOS + Android) — fog-of-war map with background GPS, markers with photos, local JSON import/export, GOSL v1.0 license, no telemetry, no paid Apple Developer account
**Researched:** 2026-04-17
**Confidence:** HIGH on platform/store policy pitfalls (verified against Apple & Google official docs), HIGH on dependency-license pitfalls (directly tied to STACK.md audit), MEDIUM on OEM battery killing (observed behavior, not formally documented by OEMs), MEDIUM on fog-rendering performance (architecture-dependent)

---

## Reading Guide

Every pitfall below carries four tags:

- **Category** — thematic bucket (background GPS, data loss, UX, etc.)
- **Severity** — Critical (ship-blocker), High (major rework if missed), Medium (fixable in place), Low (cosmetic / polish)
- **Phase to address** — which roadmap phase owns prevention. Phase names are indicative; the roadmap agent will assign final numbers. Candidates: *Foundation* (Flutter bootstrap, analyzer, logging, DI, license headers), *Persistence* (Drift schema, photo storage, migrations), *GPS & Session* (tracking service, permissions, foreground service), *Map & Fog* (flutter_map + MirkRenderer), *Markers* (CRUD, photos, categories), *Import/Export* (JSON schema, versioning, ZIP), *Polish & Release* (App Store / Play justification, CI sideload, About/Legal screen)
- **Warning signs** — how to detect early

---

## Critical Pitfalls

### 1. Google Play rejection for "unjustified background location"

**Category:** Permissions / Store policy
**Severity:** Critical (ship-blocker for Play, and we're distributing via GitHub Releases APK but people will still sideload — the principle matters and a future Play release is not foreclosed)
**Phase to address:** Polish & Release, reinforced by GPS & Session

**What goes wrong:**
Google Play rejects apps that request `ACCESS_BACKGROUND_LOCATION` unless the justification is tightly coupled to a feature users would intuitively expect to need continuous background location. Generic phrasing ("to improve user experience", "for analytics", "to track location") is rejected on sight.

**Why it happens:**
- Google's 2026 policy update (April 15, 2026) tightened the Location Permissions policy: background access requires "compelling justification" and features beneficial to the user *relevant to the core functionality of the app.*
- Apps get rejected when the same feature could be delivered with foreground location only.
- Rejected language from real cases: "Your Declaration form indicates that your app uses background location, however, the core functionality declared can be completed without background location access."

**How to avoid:**
- **Make the exploration-session semantic explicit in-app**: explicit Start / Stop button, screen copy "Background tracking stops when you press Stop", no ambient tracking without an active session.
- **Write the Play Console Data Safety form defensively** — list the feature as: "Reveal the fog-of-war on the user's personal map while they are physically walking/driving through an area. The background access runs only while a session is actively started by the user and is always paired with a persistent notification."
- **Show a full-screen rationale screen** before the runtime prompt explaining exactly why background location is needed and that no data leaves the device.
- **Ship a short demo video** in the Play Console review notes showing: (1) create session, (2) press Start, (3) walk/drive, (4) fog clears, (5) press Stop, (6) tracking stops.
- **Do NOT request `ACCESS_BACKGROUND_LOCATION` on app launch.** Only request it when the user presses Start on their first session, with a clear rationale dialog.

**Warning signs:**
- Any dev thinking "we'll request background location at startup for convenience"
- Play Console pre-launch report flagging `ACCESS_BACKGROUND_LOCATION` with "sensitive permission"
- The manifest permission being requested without a corresponding UI explanation screen

**Precedent:** [Google Play policy update 2026-04-15](https://support.google.com/googleplay/android-developer/answer/16926792?hl=en), [understanding background location permissions](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en)

---

### 2. App Store rejection under Guideline 2.5.4 (background mode without persistent-location feature)

**Category:** Permissions / Store policy
**Severity:** Critical for any iOS distribution (sideload via SideStore also requires proper entitlements in the IPA to behave correctly)
**Phase to address:** Polish & Release, GPS & Session

**What goes wrong:**
Apple rejects apps declaring `UIBackgroundModes: location` whose core feature doesn't **require** persistent location. Reviewers interpret "require" strictly — if the feature could plausibly work with `whenInUse` (foreground only), background is denied.

**Why it happens:**
- Guideline 2.5.4: "Multitasking apps may only use background services for their intended purposes: VoIP, audio playback, location, task completion, local notifications, etc."
- Reviewer-confusion rejections: if `NSLocationAlwaysAndWhenInUseUsageDescription` is vague ("for better experience"), reviewer will reject.
- Common rejection phrase: "Apps declaring support for location in the UIBackgroundModes key must have features that require persistent location."

**How to avoid:**
- **Usage description copy must be specific, user-facing, and tied to the session concept**:
  - `NSLocationAlwaysAndWhenInUseUsageDescription`: *"MirkFall reveals the map as you explore — even when your phone is in your pocket or the screen is off. Tracking runs only while a session is active and stops when you press Stop."*
  - `NSLocationWhenInUseUsageDescription`: *"MirkFall needs your location to reveal the map around you."*
- **Include NSLocationTemporaryUsageDescriptionDictionary** only if using precise/reduced switching (not needed for V1.0).
- **Submit App Review Notes explaining the exploration-session model** word-for-word, including: "A session must be started manually. Tracking automatically stops when the user presses Stop or when the session is deleted. No location data leaves the device."
- **Demo video** showing Start/Stop, background mode kicking in with phone locked, data staying local.
- Reject `backgroundFetch` and `backgroundProcessing` entitlements unless actually used (Apple reviewers flag unused entitlements).

**Warning signs:**
- Generic `NSLocationAlways...UsageDescription` strings copy-pasted from tutorials
- `UIBackgroundModes` containing entries we don't actually use (`fetch`, `processing`)
- No written review-notes justification prepared before submission

**Precedent:** [Apple App Review Guidelines 2.5.4](https://developer.apple.com/app-store/review/guidelines/), [Expo forum: iOS rejection for `location` background mode](https://forums.expo.dev/t/ios-app-store-rejections-with-the-location-background-mode/25537), [Apple Developer Forums thread #108641](https://developer.apple.com/forums/thread/108641)

---

### 3. "Lost my progression" catastrophic data loss on app update (the Fog of World precedent)

**Category:** Data integrity — directly attacks the stated *core value* of MirkFall
**Severity:** Critical — this is literally what MirkFall promises to fix vs. the incumbent
**Phase to address:** Persistence, Import/Export (both prevention layers)

**What goes wrong:**
An app update introduces a schema migration bug, a serialization change, or a silent data-format shift, and on first launch of the new version the user finds their sessions truncated, missing, corrupted, or downgraded (real reported case: user lost 56 levels and thousands of miles of tracked data in a Fog of World update — the competitor we're differentiating against).

**Why it happens:**
- Schema migration tested on a clean DB or a small fixture, never on a real 6-months-old user DB.
- Silent `ON CONFLICT REPLACE` clauses during migration.
- Photo-reference model changes (e.g., path → relative-path) without a migration step → images become orphans.
- No backup before migration.
- Error handler catches migration failure silently (generic `try/catch` with `log()` only).

**How to avoid:**
- **Drift migrations are mandatory and versioned explicitly** — each version has a unit test that starts from a fixture DB of version N and verifies the migrated state matches the expected N+1 shape. Never skip this test.
- **Before any migration runs, copy the DB file to `<docs>/backups/pre_migration_<fromVersion>_<timestamp>.sqlite`** and keep the last 3 backups. The backup operation is idempotent and runs inside Drift's `onUpgrade` callback BEFORE any DDL. This is a ship-blocker — enforce it in code review.
- **After every successful migration, run a sanity check**: row counts per table must be >= pre-migration counts (we never delete user data on a migration). Log the counts. If counts drop, surface a recovery prompt to the user pointing at the backup file path.
- **Never catch migration failures silently.** A failed migration is a crash — escalate to the top-level handler (`runZonedGuarded` as mandated in CLAUDE.md) and on next launch offer recovery from the most recent backup.
- **The export format is the ground truth**: a user who has exported their session to JSON is immune to any migration bug. Promote export-before-update in a non-annoying way (first-launch tip after any major-version bump).

**Warning signs:**
- Migration code is just `m.addColumn(...)` calls with no corresponding fixture test
- The phrase "we'll fix it in the next release" for a data-layer bug — it's too late, data is already gone
- Absence of `<docs>/backups/` directory content after a schema bump

**Precedent:** [Fog of World data loss — HN-class community complaint](https://fogofworld.app/en/), multiple App Store reviews document 50+ lost levels after an update; user also reported their live location stopped being tracked. The developer of Fog of World went silent — MirkFall's GitHub-public promise is to not do that, AND to prevent the loss in the first place.

---

### 4. SQLite corruption from app-killed-mid-write without WAL / safe shutdown

**Category:** Data integrity
**Severity:** Critical
**Phase to address:** Persistence

**What goes wrong:**
A background GPS tracker is writing revealed-tile updates to SQLite. Android kills the process (Doze, OEM battery saver, OOM). The journal is left in an inconsistent state, on next start the DB reports `database disk image is malformed` (SQLite code 11) or `attempt to write a readonly database` (code 776).

**Why it happens:**
- Default journal mode is `DELETE`, not `WAL`. A kill mid-write in `DELETE` mode can corrupt.
- App uses a single long-lived write transaction that holds the lock across GPS ticks.
- No `PRAGMA synchronous=FULL` or `NORMAL`, or `synchronous=OFF` for perceived "speed".
- Multiple processes (Flutter foreground service isolate + UI isolate) open the same DB without `sqlite3_busy_timeout` handling.

**How to avoid:**
- **Enable WAL mode on open**: drift exposes `NativeDatabase.createInBackground` with custom pragmas. Set `journal_mode = WAL`, `synchronous = NORMAL`, `busy_timeout = 5000`.
- **Checkpoint periodically** (every 1000 writes or every 5 minutes of active session): `PRAGMA wal_checkpoint(PASSIVE)` to cap WAL file growth (unbounded WAL hurts read perf).
- **Small, bounded write transactions** — GPS fix → tiles delta → commit — not a 30-minute-long open transaction.
- **Single-writer invariant**: tracking service isolate is the only writer to sessions + revealed_tiles tables. UI reads via Drift's reactive streams (safe under WAL).
- **Never set `synchronous=OFF`** — a single power loss corrupts.
- **On DB open, verify integrity**: `PRAGMA integrity_check;` on first open after a suspected crash (detect via a "clean shutdown" flag written on normal app close and cleared on open). If corrupted, restore from the most recent backup (see Pitfall 3).

**Warning signs:**
- Default Drift `openConnection()` without explicit pragma setup
- Integration tests that never kill the process mid-write
- Test fixtures that don't include a "simulate crash" scenario

**Precedent:** [Drift issue #3031 — database locked with WAL](https://github.com/simolus3/drift/issues/3031), [SQLite WAL doc — "older versions will not know how to recover a crashed WAL DB"](https://sqlite.org/wal.html), [Drift issue #2990 — "database disk image is malformed" under concurrent access](https://github.com/simolus3/drift/issues/2990)

---

### 5. Orphaned photos (marker deleted → photo file stays, or vice versa)

**Category:** Data integrity / storage bloat
**Severity:** Critical (storage bloat + export-size explosion)
**Phase to address:** Markers, reinforced by Persistence

**What goes wrong:**
User deletes a marker. The row in `markers` is removed, but the photo files in `<docs>/photos/<markerId>/*.jpg` remain. Over 6 months of usage with routine marker edits, hundreds of MB of dead photos accumulate. Worst case: DB is restored from backup, backup references photos that no longer exist → broken image placeholders on marker detail view.

**Why it happens:**
- File-system state and DB state are not in a single transaction.
- Delete flow: `db.delete(marker)` first, then `File(path).delete()`. Crash in between → orphan.
- No reconciliation job that walks the photos dir and prunes files not referenced in the DB.
- Photo paths stored as **absolute** paths, making them invalid after iOS sandbox UUID rotation (yes, this happens on re-installs).

**How to avoid:**
- **Photo paths stored as RELATIVE paths** from `getApplicationDocumentsDirectory()`. Compute absolute at read time with `p.join(docsDir, relativePath)`. Survives sandbox path rotation, makes export portable.
- **Delete order: file first, DB second** (if file delete fails, DB row still points at a file that happens to no longer exist — detectable and recoverable). The reverse (DB first) leaves dead-weight files with no pointer. Wrap both in a `try/finally` that re-enqueues orphan-cleanup on failure.
- **Scheduled reconciliation job** on app start (cheap, runs on a background isolate):
  - Walk `<docs>/photos/`
  - For each file, query DB for a marker referencing it
  - If none, and file is older than 24h (avoids race with in-progress marker-create), delete
  - Log removals count
- **On export**: resolve all photo paths and verify they exist BEFORE writing the export archive. If any missing, surface "Export completed with warnings: 3 photos missing" and log the list — do NOT silently drop them.
- **Hash the photo content** (sha256, short) into the filename: `marker_<id>_<sha8>.jpg`. Cheap dedup if the user attaches the same photo to multiple markers, and gives us a check for corruption (hash mismatch).

**Warning signs:**
- Photos dir size ≠ sum of photo-field lengths * reasonable-factor after heavy marker editing
- DB has photo paths that start with `/data/user/0/...` or `/var/mobile/Containers/...` (absolute) — fix immediately
- No `integrity` / `reconcile` command in the debug menu

**Phase-to-phase coupling:** reconciliation function lives in Persistence layer, UI in Markers phase.

---

### 6. Naive GPS point storage → gigabytes in months (the "don't store 10 TB of GPS" directive from PROJECT.md)

**Category:** Storage / performance
**Severity:** Critical — PROJECT.md explicitly calls this out as a design constraint
**Phase to address:** GPS & Session, Persistence

**What goes wrong:**
Naive "one row per GPS fix" approach: with a 1 Hz tracker running 4 hours/day, that's 14 400 points/day, ~5 million/year, ~50 million after a few years. Each row is ~50 bytes → multi-gigabyte DB. App becomes sluggish, exports balloon, backup/restore times explode.

**Why it happens:**
- Developer thinks "we'll optimize later" and lays down a `gps_fixes` table indexed poorly.
- The revealed-mirk model is conflated with the GPS history — two distinct concerns merged.
- No deduplication at the tile level (each fix reveals the same ~4–9 tiles as the previous fix if the user is walking slowly).

**How to avoid:**
- **Separate concerns rigorously:**
  - `revealed_tiles` table — the *truth* of what's revealed. One row per (session_id, z, x, y). Deduped. This is ~100 bytes per unique tile. At zoom 15, a day of walking covers maybe 500–2000 unique tiles. A full year of exploration by an active user: 50k–200k rows. Manageable.
  - No `gps_fixes` table at all in V1.0. We don't need the trajectory, we need the reveal state. If we ever want "show my path", it's a V2 feature with opt-in storage.
- **At each GPS fix**: compute the tile set revealed (center tile + tiles within revealRadius), do a `INSERT OR IGNORE` batch insert into `revealed_tiles`. Idempotent, deduplicated by the unique index `(session_id, z, x, y)`.
- **Store at a single canonical zoom level** (e.g., z=16 — 9m tile size at the equator, fine for walking granularity). Renderer can derive coarser zooms on the fly by union. Prevents storing 10 copies (z=0..z=19) of the same data.
- **Quantize to a tile-coord integer pair**, not float lat/lon. Integers compress well and are exactly comparable (no float equality issues).

**Warning signs:**
- Schema has a `gps_fixes` or `location_points` table with raw lat/lon per fix
- DB size grows linearly with tracking time instead of with *unique area* explored
- Debug log shows duplicate tile inserts (if seeing > 20 inserts per fix at low speed, the dedup is broken)

**Precedent:** this is explicitly flagged in PROJECT.md §9 "Stratégie de représentation pour le mirk revelé — on ne veut pas 10 TB de points GPS." The pitfall is the solution.

---

### 7. OEM background killing — the 70% of Android market problem

**Category:** Background GPS / reliability
**Severity:** Critical — silently breaks the core feature on a majority of real devices
**Phase to address:** GPS & Session

**What goes wrong:**
User starts a session, puts phone in pocket, walks 2 km. Xiaomi/Huawei/OPPO battery optimizer silently kills the foreground service. User returns home, opens app, sees a tiny fraction of their walk revealed, concludes MirkFall is broken, uninstalls.

**Why it happens:**
- Xiaomi MIUI/HyperOS has AutoStart permission *off by default* for sideloaded apps AND resets it after OTA updates.
- Huawei/Honor has PowerGenie that kills apps not on its whitelist.
- Samsung kills apps with no foreground Activity for 3 days AND has "put apps to sleep" per-app toggles.
- OnePlus "Deep Optimization" kills foreground services at ~12% battery silently.
- Foreground service + persistent notification + `FOREGROUND_SERVICE_LOCATION` is *necessary but insufficient* on these OEMs.

**How to avoid:**
- **Persistent notification IS still required** (AOSP compliance + User transparency signal) but we must assume it's not sufficient.
- **Request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`** with an opt-in flow explaining the tradeoff. Don't sneak it — spec out a "Reliable tracking" setup screen shown the first time a session is started, with device-family specific guidance (Xiaomi → AutoStart, Huawei → Protected apps, Samsung → Never sleeping apps).
- **Detect OEM via `Build.MANUFACTURER`** and show manufacturer-specific deep-links where available (`Intent("miui.intent.action.POWER_MANAGER_SETTINGS")`, etc.) — known deep-links exist on dontkillmyapp.com; implement defensively behind try/catch since OEMs change them.
- **Detect silent kills on next launch**: store "expected tracking end time" vs "last observed tracking tick". On launch, if session is "active" but last tick > 5 min old and no stop was recorded, surface a "Tracking was interrupted — here's how to fix it for next time" banner linking back to the OEM settings help.
- **Log all service-lifecycle events** to the file logger so users reporting bugs can share actionable diagnostic data.
- **Point users at [dontkillmyapp.com](https://dontkillmyapp.com/)** in the About / Help screen with OEM-specific instructions.

**Warning signs:**
- Test device: only Pixel / stock Android. Broken assumption.
- No "interrupted tracking" detection on launch.
- User reports "app stopped working after 10 minutes" with no actionable debug info.

**Precedent:** [Beyond Doze — OEM realities (ProAndroidDev, March 2026)](https://proandroiddev.com/beyond-doze-building-reliable-background-execution-on-modern-android-including-oem-realities-5fa0a6e05672), [DEV Community — 11 layers to survive OEMs](https://dev.to/stoyan_minchev/what-android-oems-do-to-background-apps-and-the-11-layers-i-built-to-survive-it-28bb). At least 70% of global Android market has an OEM-specific killer.

---

### 8. OSM tile server ban / User-Agent block

**Category:** Legal / Ops / Integration
**Severity:** Critical — map becomes unusable overnight, no alternative pre-configured
**Phase to address:** Map & Fog

**What goes wrong:**
Flutter-map's default `NetworkTileProvider` sends Dart's default User-Agent (`Dart/3.x (dart:io)`). OSM Operations Working Group blocks UAs that look like generic library defaults without warning. Map tiles return 403s, app shows grey squares, user thinks app is broken.

**Why it happens:**
- Developer doesn't set `additionalOptions` / `tileProvider: NetworkTileProvider(headers: {'User-Agent': 'MirkFall/1.0 (...)'})`.
- Developer pre-caches tiles or fetches multi-zoom levels in bulk for a "smoother UX" — that's textbook *bulk downloading*, which OSM's Tile Usage Policy explicitly prohibits.
- Developer triggers rapid zoom in/out that spams tiles.

**How to avoid:**
- **Set a unique, identifying User-Agent** in a single place in config: `MirkFall/{app.version} (+https://github.com/<user>/GOSL-MirkFall; contact: <email>)`. Never a generic name. Never impersonate another browser or app.
- **Never bulk-download tiles** from tile.openstreetmap.org. The V1.1 offline feature MUST use a different source (user-supplied MBTiles, Stadia Maps within their 100MB free cap, or OpenFreeMap) — codified in STACK.md.
- **Respect Cache-Control headers** (flutter_map v8 does this via its built-in provider; verify on first integration).
- **Attribution required**: display "© OpenStreetMap contributors" linked to https://www.openstreetmap.org/copyright on the map AND on the About screen. Failure to attribute is a license violation of OSM data (ODbL).
- **Show a graceful fallback** when tiles 403: a small banner "Map tiles unavailable — see Help" with a link to explain OSM policy.

**Warning signs:**
- HTTP inspector shows User-Agent `Dart/...` or `flutter_map/...` default
- Code containing `for (var z in zooms) { for (var x in ...) { fetch(tileUrl) } }` — that's bulk prefetch, ban-bait
- Production app serving > 1 req/sec per device sustained — rate-limit trigger

**Precedent:** [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/), [OSM Wiki — Blocked tiles](https://wiki.openstreetmap.org/wiki/Blocked_tiles), [Community thread: access blocked due to policy](https://community.openstreetmap.org/t/access-blocked-tile-usage-policy/133862). Multiple apps have been blocked with no prior warning.

---

### 9. Dependency-transitive GPL contamination

**Category:** Legal / License compliance
**Severity:** Critical — violates GOSL v1.0 rules and contaminates the project
**Phase to address:** Foundation (tooling), enforced in every phase

**What goes wrong:**
A PR or a `flutter pub upgrade` adds a direct dep whose LICENSE is MIT, but one of its transitive deps is GPL-3.0 or AGPL. `flutter analyze` doesn't catch it. The project silently becomes license-incompatible with GOSL.

**Why it happens:**
- Developers audit direct deps only.
- `pub.dev` shows the direct license, not the transitive graph.
- No automated license scan in CI.

**How to avoid:**
- **CI step on every PR**: run `dart_license_checker --show-transitive-dependencies` or `very_good check-licenses --allowed="MIT,BSD,BSD-2-Clause,BSD-3-Clause,Apache-2.0,Unlicense,CC0-1.0,ISC,Zlib"`. Fail the build on any license outside the allowlist.
- **Pin every version** per CLAUDE.md (no carets), commit `pubspec.lock` — this makes the transitive set deterministic and `flutter pub outdated` a deliberate, auditable event.
- **Before adding any dep**: run `flutter pub deps --json` in a scratch branch first, diff the transitive set, manually check any new licenses. Document in `DEPENDENCIES.md`.
- **Maintain a forbidden-list** in CI: explicit regex for `GPL`, `AGPL`, `LGPL` (including LGPL-static-link ambiguous cases that CLAUDE.md calls out), `SSPL`, `CC-BY-NC-*` (non-commercial).
- **STACK.md already documented** `flutter_map_tile_caching` is GPL-3.0 and forbidden. Every researcher/roadmap step must re-check alternatives don't drag FMTC in transitively.

**Warning signs:**
- `pubspec.lock` diff contains a package not discussed in the PR
- CI has no license-check step
- `DEPENDENCIES.md` is out of sync with actual `pubspec.yaml` content

**Precedent:** [CLAUDE.md §Licences interdites](../../CLAUDE.md) — project-level blocker. [Very Good CLI license check](https://cli.vgv.dev/docs/commands/check_licenses), [dart_license_checker](https://github.com/redsolver/dart_license_checker).

---

### 10. Silent telemetry introduction via dependency update

**Category:** Legal / Privacy / GOSL violation
**Severity:** Critical
**Phase to address:** Foundation (CI tooling), enforced in every phase

**What goes wrong:**
A dependency's minor version bump (we prevent this by pinning, but a deliberate upgrade happens eventually) adds a "helpful" analytics SDK, crash reporter, or "auto-update check" call. It's buried in release notes. No user impact visible. GOSL violated silently.

**Why it happens:**
- Flutter packages are notorious for "adding analytics by default, opt-out via config" (Facebook SDK ecosystem, some notification libs).
- Release-note reading is inconsistent.
- No network-traffic monitoring in dev.

**How to avoid:**
- **Upgrade audits mandatory**: every bump of any dep triggers a CLAUDE.md audit row: license check, changelog read, source grep for `http`, `dio`, `analytics`, `crashlytics`, `sentry`, `firebase_analytics`, `mixpanel`, `amplitude`, `segment`, `attribution`, `appsflyer`, `adjust`.
- **CI traffic-monitor test**: smoke-test `flutter test integration_test/no_telemetry_test.dart` runs the app under an HTTP-interceptor proxy and asserts that no outbound HTTP is made in the "idle" flow (launch → open map → add marker → export → exit). Any outbound request in that flow fails the build. Real requests (tile fetches) happen only when the user is actively viewing the map — that's scoped to a separate test.
- **Forbid packages from STACK.md's "What NOT to Use"** via a lint (`very_good_analysis` or custom rule) that errors on import of `package:firebase_*`, `package:sentry_flutter`, etc.
- **Document in `DEPENDENCIES.md`** a telemetry section per dep, re-audited on every update.

**Warning signs:**
- A dep update PR with no corresponding `DEPENDENCIES.md` update
- New HTTP traffic observed in idle app (via Charles/mitmproxy on dev device)
- A direct or transitive dep named `*_analytics`, `*_crashlytics`, `sentry`, `firebase_core`, etc.

**Precedent:** CLAUDE.md forbids this category outright. The point of the test is to make the forbidden impossible.

---

### 11. Missing license header in new source files

**Category:** Legal / Project hygiene
**Severity:** High (accumulates invisibly, review cost balloons late)
**Phase to address:** Foundation (tooling)

**What goes wrong:**
Developers add a new file without the mandated copyright + GOSL header. Over time dozens of files lack attribution. On release, a manual audit is required and painful.

**Why it happens:**
- Header is a manual copy-paste step.
- No lint or pre-commit check.
- IDE templates not configured.

**How to avoid:**
- **Pre-commit hook** (Git hook or CI check) that verifies every new or modified `.dart`, `.kt`, `.swift` file starts with the header `// Copyright (c) 2026 THONGVAN Alexis\n// Licensed under the Good Old Software License v1.0\n// See LICENSE file for details`. Exact match. Fail the build on violation.
- **IDE file templates** configured for VS Code / IntelliJ so new files start with the header automatically.
- **License-check script** runnable locally: `bash scripts/check_license_headers.sh`. Enforced in CI.

**Warning signs:**
- No CI step called `license-headers` or `license-headers-check`
- `git log --diff-filter=A` shows new .dart files without the header in the diff
- Developers asking "do I need to add the header to this file?" — means tooling is missing

---

## High-Severity Pitfalls

### 12. Permission UX: asking background location before explaining why

**Category:** UX / Permissions
**Severity:** High (leads to permanent-deny, no recovery without Settings intervention)
**Phase to address:** GPS & Session

**What goes wrong:**
First-launch app: immediate system prompt for "Always Allow" location. User taps "Deny" (or "Only this time" on iOS, or "Ask next time" temporary grant). `ACCESS_BACKGROUND_LOCATION` now requires an extra trip to Settings → Apps → MirkFall → Location → Allow all the time, which Android hides behind a disclosure. ~70% of users never recover that path. App is uninstalled.

**Why it happens:**
- Copy-paste permission flow from a tutorial.
- `permission_handler.requestPermissions([Permission.location, Permission.locationAlways])` called at startup.
- No pre-request rationale screen.

**How to avoid:**
- **Permission flow is a UX design problem, not a technical problem.** Sequence:
  1. App launches → show onboarding explaining the fog-of-war concept, no permissions prompted.
  2. User creates first session → session screen visible, no tracking active yet.
  3. User presses Start → **rationale screen** (modal): "MirkFall needs to know where you are to reveal the map. Tracking runs only while a session is active. No data leaves your device. [Continue] [Cancel]".
  4. Continue → request `locationWhenInUse` first.
  5. Granted → session starts with foreground tracking.
  6. After N seconds of active tracking OR first app-background event, prompt for `locationAlways` with a second rationale: "MirkFall keeps revealing the map when your phone is locked. Allow background access?"
- **Handle `permanentlyDenied`**: if the user has denied twice (Android) or selected "Don't Allow" (iOS), show a screen pointing at Settings with deep-link via `openAppSettings()` from permission_handler.
- **Handle iOS "Ask Next Time Or When I Share" (provisional)**: treat as `denied` for the session — the grant is ephemeral and pulls back. Don't rely on it persisting.
- **Android 14+: if targeting SDK 34+, explicitly declare `FOREGROUND_SERVICE_LOCATION`** in manifest. Permission request flow must include it before starting the service, else service fails to start silently.

**Warning signs:**
- System permission dialog appears on first-launch cold start
- Single `requestPermissions` call requesting everything at once
- No `openAppSettings` handler for permanently denied state

**Precedent:** [permission_handler Baseflow docs](https://pub.dev/packages/permission_handler), [Radar — guide to Play Store background-location approval](https://radar.com/blog/guide-to-play-store-background-location-approval).

---

### 13. 1 Hz polling when user is stationary → battery drain complaint

**Category:** Battery / UX
**Severity:** High (real-world case: geolocator at default settings = 10–14%/hour battery drain)
**Phase to address:** GPS & Session

**What goes wrong:**
geolocator default is "update on every reading available." On modern phones with GPS always-on, this is effectively 1 Hz. User leaves phone on the nightstand with active session, loses 10%/hr battery overnight. Posts a 1-star review: "DESTROYS MY BATTERY."

**Why it happens:**
- Dev copy-paste of `Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high))` with no `distanceFilter`.
- No movement detection — GPS noise (±3–10m at standstill) keeps triggering "updates."
- Service keeps the GPS radio spun up continuously.

**How to avoid:**
- **distanceFilter is mandatory** — set it to a function of the reveal radius. For default 50m radius, `distanceFilter: 10` is reasonable (don't emit a fix if < 10m moved). Config in `lib/config/constants.dart`.
- **Movement-detection layer above geolocator**: if the last N=5 fixes are within `gpsNoiseToleranceMeters` (say 15m) of each other AND speed reported < 0.5 m/s, enter "low-power mode": switch to `LocationAccuracy.medium` or even significant-location-change and poll every 30–60s. Exit low-power when a fix jumps > noise tolerance.
- **Pause the GPS stream** during extended stationary periods (> 5 min no movement). Re-subscribe on next accelerometer bump (optional — `sensors_plus` adds a dep, evaluate).
- **Instrument battery use in debug**: log timestamp of every fix, compute fixes-per-minute metric, surface in debug menu. During QA, simulate 30-min stationary and verify fix rate drops.
- **Expose "Tracking precision" setting** to power users (Balanced / Precise / Battery Saver) with tuned distanceFilter + accuracy + polling per mode.

**Warning signs:**
- `getPositionStream` call with no `distanceFilter` or `distanceFilter: 0`
- No stationary-detection logic
- Beta-tester report "phone hot after 30 min tracking"

**Precedent:** [Medium — "I Benchmarked Every Background Location Plugin" (March 2026)](https://medium.com/@kiranbjm/i-benchmarked-every-background-location-plugin-for-flutter-android-ios-heres-why-most-of-them-5e46ba8fe472) — geolocator 10–14%/hr without tuning.

---

### 14. iOS: app suspended in background despite `UIBackgroundModes: location`

**Category:** Background GPS / iOS
**Severity:** High (session appears broken, user assumes bug)
**Phase to address:** GPS & Session

**What goes wrong:**
iOS suspends the MirkFall process after some minutes of background. Location stream dries up. Revealed area stops updating. User returns and sees a gap.

**Why it happens:**
- `allowsBackgroundLocationUpdates` on CLLocationManager not set to true (geolocator exposes this via `LocationSettings.showBackgroundLocationIndicator` on iOS 14+ and implicit behavior on earlier).
- Low `desiredAccuracy` + `distanceFilter` combination triggers the iOS 16.4+ behavior that suspends apps requesting only low-precision updates (Apple's 2023 restriction).
- User has disabled Background App Refresh globally or for MirkFall specifically — which silently disables all background location re-launch.
- Background indicator (blue pill top of screen on iOS 16+) not shown — often a sign updates aren't really flowing.

**How to avoid:**
- **geolocator iOS settings**: `AppleSettings(accuracy: LocationAccuracy.best, activityType: ActivityType.fitness, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true, allowBackgroundLocationUpdates: true)`.
- **Do NOT combine `startUpdatingLocation` with `startMonitoringSignificantLocationChanges`** in low-accuracy mode — iOS 16.4+ will suspend (verified via Apple forums). Pick one.
- **Detect and surface Background App Refresh status**: on session start, check (via method channel or the `background_app_refresh` package if available under compatible license) and warn the user if BAR is off.
- **On app relaunch after system-killed process**: re-instantiate the tracking service cleanly (iOS can cold-relaunch your app for a location event; the app state must be re-buildable from disk). Never assume in-memory state survives.
- **Test on a real device with screen off for 30+ min** — simulator does NOT behave like a real background.

**Warning signs:**
- `allowsBackgroundLocationUpdates = false` in geolocator init
- `LocationAccuracy.low` or `.kilometer` in iOS config
- No method-channel call to check BAR status

**Precedent:** [Apple Developer Forums thread #726945 — background location stops in iOS 16.4](https://developer.apple.com/forums/thread/726945), [Apple docs — handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background).

---

### 15. Sideload certificate expiry breaks user's active session

**Category:** iOS distribution
**Severity:** High (user-facing "app locked" experience mid-exploration)
**Phase to address:** Polish & Release

**What goes wrong:**
Free Apple ID sideload certs expire in 7 days. User is mid-exploration, session active, phone locked, cert expires → iOS kills MirkFall. Session state may be partially persisted. User's session ends unceremoniously.

**Why it happens:**
- Free Apple ID + SideStore provides 7-day signing only.
- SideStore refresh requires the user's phone to be connected to a specific VPN / pair and ideally on wifi with the pairing device active. Not always the case.
- Free account: 3 apps max per device, 10 unique apps per week.

**How to avoid:**
- **Document the constraint clearly** in README and About screen: "iOS sideload via SideStore/AltStore requires re-signing every 7 days. We recommend setting up AltServer / SideStore refresh daily."
- **App-side mitigation**: persist `isSessionActive`, revealed tiles, markers, atomically on every significant event (not just on "Stop"). If the app is killed mid-session, on next launch the user sees their session is still "active" (with the correct last-known state) and can resume without loss.
- **Session recovery flow**: on cold launch, if an active session is found and the app was not cleanly stopped, offer "Continue session" / "Stop and save" — don't silently restart tracking.
- **No build-date stamp in the binary** that hard-fails after N days — let iOS's native cert expiry be the only mechanism.

**Warning signs:**
- In-memory-only session state (will be lost on kill)
- No "continue session" UI path
- Documentation doesn't mention the 7-day constraint

**Precedent:** [SideStore FAQ — 7-day expiry, 3-app limit, 10/week limit](https://docs.sidestore.io/docs/faq), [AltStore Classic FAQ](https://faq.altstore.io/altstore-classic/your-altstore).

---

### 16. Partial JSON import leaves DB in inconsistent state

**Category:** Import/Export / Data integrity
**Severity:** High (destroys trust in the core value)
**Phase to address:** Import/Export

**What goes wrong:**
User imports a 50MB JSON session. Mid-way, a validation error on marker #237 aborts the import. Sessions table has the new session row, revealed_tiles has 12k rows, markers has 236 rows, categories has partial data. No way to tell what's half-imported. User re-imports, gets duplicate-key errors or duplicate content.

**Why it happens:**
- Import runs INSERT-by-INSERT without a transaction.
- No "staging" area — writes go straight to production tables.
- No idempotency key (import-id, or session-id-as-natural-key).

**How to avoid:**
- **All-or-nothing transaction**: the entire import runs inside a single Drift transaction. Any failure rolls back to pre-import state.
- **Deterministic session IDs**: exported JSON contains a UUID per session. On import, if the UUID already exists, show a conflict dialog: "A session with this ID already exists. [Replace] [Import as copy (new ID)] [Cancel]". Default is cancel.
- **Strict validation pass FIRST, import SECOND**: parse entire JSON, validate all refs (marker.categoryId exists, marker.sessionId matches, photo paths exist in archive if ZIP) before touching DB. Report all errors at once, don't fail-fast on the first.
- **Photo extraction into a staging dir**, then atomic rename into production dir after DB transaction commits. On rollback, delete staging.
- **Envelope schema version check FIRST**: `{"schemaVersion": N}` — if N > current, show "This export was created by a newer MirkFall. Update the app to import it." If N < current, route through the migration chain in STACK.md.
- **"Dry run" option** in advanced import UI: validate but don't commit, report row counts.

**Warning signs:**
- `for (var marker in json) { await db.insert(...) }` outside a transaction
- No schema-version check at import start
- No way to tell "what would this import change" before committing

---

### 17. Version field present but not honored (the "version is theater" trap)

**Category:** Import/Export
**Severity:** High — PROJECT.md promises versioned JSON for forward compat; if we only write the field but don't consume it, we break the promise silently on V1.1
**Phase to address:** Import/Export, reinforced in Foundation (set up the migration framework on day 1, not V1.1)

**What goes wrong:**
V1.0 writes `{"schemaVersion": 1}` but the import code just does `Session.fromJson(payload)` directly, ignoring the version. On V1.1 we add a `Marker.altitude` field, export v2 starts writing it. V1.0 users with a pre-V1.1 build try to import a V2 export → `altitude` is silently ignored OR missing, markers have subtly wrong data OR the import crashes with an obscure parse error.

**Why it happens:**
- Version plumbing is boring and forward-looking; devs defer it.
- No migration framework exists at V1.0 because "we don't need it yet."
- Tests validate only round-trip at the current version.

**How to avoid:**
- **Build the migration chain on day 1**: `ImportMigration` interface with `int fromVersion; int toVersion; Map<String, Object?> migrate(Map<String, Object?> input);`. Register migrations by version. Even at V1.0 with only `V1 → V1` (identity), the plumbing exists and is exercised in tests.
- **On import, switch on `schemaVersion` first**:
  - `version == current` → parse directly
  - `version < current` → apply migrations in sequence to bring to current
  - `version > current` → error with clear user message
- **Test matrix**: round-trip export → import AT EACH VERSION, plus cross-version (v1 export → v1.1 import succeeds with migration, v1.1 export → v1 import fails clearly).
- **Changelog discipline**: any export-schema change bumps the version AND adds a migration AND adds a cross-version test. Enforced in code review.

**Warning signs:**
- `json['version']` or `json['schemaVersion']` not referenced anywhere in import code
- No file named `migrations.dart` or `import_migrations/`
- Only one version of fixture JSONs in `test/fixtures/`

---

### 18. Photo references broken on cross-device import (absolute paths, UUIDs)

**Category:** Import/Export
**Severity:** High
**Phase to address:** Import/Export, Markers

**What goes wrong:**
User exports a session from phone A. Export JSON contains photo references like `/data/user/0/com.thongvan.mirkfall/files/photos/abc.jpg`. Imports to phone B. All marker photos are broken — that absolute path doesn't exist on phone B.

**Why it happens:**
- Photos stored as absolute paths (see Pitfall 5).
- Photos not bundled in the export — only references.
- iOS sandbox UUIDs change per install anyway.

**How to avoid:**
- **Export format is a ZIP archive** (`.mirkfall` extension or `.zip`) containing:
  - `manifest.json` — the versioned envelope with all sessions, markers, categories, revealed tiles
  - `photos/<marker_uuid>/<photo_uuid>.jpg` — binary photos bundled in the archive
- **All photo references in JSON are RELATIVE archive paths**: `photos/abc123/def456.jpg`. Resolved on import to a safe destination dir.
- **On export, verify every referenced photo exists** before zipping (see Pitfall 5).
- **On import**, extract photos to a `staging/` dir, verify integrity (hashes match manifest), only then commit DB transaction + rename `staging/` to production path.
- **Base64-in-JSON alternative rejected**: for a user with 100+ photos, a single JSON file becomes 100+ MB and parsing it doubles that in RAM. ZIP streams cleanly.
- **Fallback for "JSON only" imports** (markers-pre-populate case from PROJECT.md §5.2): markers may reference no photos. That's the documented-only-markers use case. The schema distinguishes `photos: []` (no photos) from `photos: ['...relative path...']` (expects archive).

**Warning signs:**
- Export produces a `.json` file only
- Photo paths in JSON are absolute
- Integration test doesn't exercise cross-device import (simulated by two test DBs with different mock-`docsDir`s)

---

### 19. Export "succeeds" with incomplete data (user thinks they're safe, they're not)

**Category:** Import/Export / Data integrity
**Severity:** High — violates the *core value* of MirkFall
**Phase to address:** Import/Export

**What goes wrong:**
User taps Export. File is produced. User saves to Google Drive / iCloud. Later, the phone dies. User imports from backup — and discovers 17 photos are missing, 2 categories weren't exported, a session's revealed tiles are half the expected count.

**Why it happens:**
- Export loop does best-effort: `try { serialize } catch { skip }`.
- No pre-export integrity check.
- No post-export verification (the exported archive is not round-tripped through the importer before being shown as "done").

**How to avoid:**
- **Pre-export integrity check**: walk all sessions, all markers, all photo refs. Verify each photo file exists. Verify each marker references an existing category. If any broken, surface BEFORE export starts: "3 photos are missing on disk. [Export anyway (and note them)] [Cancel and investigate]".
- **Post-export round-trip check** (mandatory, non-skippable): after writing the archive, re-open it in the import pipeline in "dry run" mode, verify row counts match, verify photo hashes match. Only then report "Export complete" to the user.
- **Export produces a report**: the archive contains a `report.txt` with: session count, marker count per session, photos count, checksums. User can verify at a glance.
- **Never catch-and-swallow in export code**. Any failure aborts the export with a clear message.

**Warning signs:**
- Export UI shows a "Success!" dialog with no row counts / verification signal
- No `validateExport()` method in export service
- try/catch in export that logs and continues

---

### 20. Jank / dropped frames when revealed area is huge (10k+ tiles)

**Category:** Performance / Rendering
**Severity:** High
**Phase to address:** Map & Fog

**What goes wrong:**
User with 6 months of daily exploration has 50k revealed tiles. Opens the map. `CustomPainter.paint()` iterates the full set each frame. Pan/zoom drops to 20 fps. "Laggy map" complaint.

**Why it happens:**
- Naive painter iterates all revealed tiles per frame instead of just those intersecting the viewport.
- Revealed tiles stored as `List<LatLng>` (unsorted, non-indexed) making viewport filtering O(n).
- `RepaintBoundary` either missing (repaint triggered by the whole map tree) or misapplied (memory ballooning from many layer boundaries).
- `Canvas` operations not batched (N draw calls instead of 1 path).

**How to avoid:**
- **Spatial index on revealed tiles**: store as `Map<(int x, int y), RevealedTile>` keyed on tile coord at canonical zoom. Viewport query is O(tileCount in viewport) = typically < 500 even at low zoom.
- **Only paint tiles intersecting the current viewport** — the painter knows flutter_map's current `MapCamera`; compute viewport tile bounds, iterate only those.
- **Single RepaintBoundary** around the FogOfWarLayer, not per-tile.
- **Batch into one Path**: build one `Path` per frame of the union of covered-tile rects, fill once with the renderer's paint. Avoids per-tile draw calls.
- **At very low zooms (z < 10)**: draw tile-union polygons (merged Path.combine) rather than 4096 individual rects. Done once per camera event (cached), not per frame.
- **Profile early**: in the first Map & Fog code phase, generate a fixture with 50k revealed tiles and run DevTools performance-overlay. Ship fix before shipping the feature.
- **Never call `setState` from a 60fps listener**. Use `ValueListenableBuilder` or a custom `Listenable` that `CustomPaint` subscribes to directly.

**Warning signs:**
- DevTools overlay shows raster thread consistently > 16ms
- Revealed-tiles data structure is a `List` not a spatial `Map`
- No fixture test with > 10k tiles in perf-sensitive test suite

**Precedent:** [Flutter issue #72066 — CustomPainter perf with many paths](https://github.com/flutter/flutter/issues/72066), [Saropa — RepaintBoundary misuse](https://saropa.com/articles/why-flutters-repaintboundary-is-your-secret-weapon-against-jank/).

---

### 21. setState / BuildContext use after async-gap or dispose (background callback)

**Category:** Flutter idioms / crash
**Severity:** High (crash pattern, spotty coverage possible)
**Phase to address:** Foundation (lint config), enforced in every phase

**What goes wrong:**
GPS background callback completes. The StatefulWidget that initiated the request has been disposed (user navigated away). `setState(() { ... })` throws "setState called after dispose". Or `Navigator.of(context).push` after `await` — context.mounted is false, exception propagates.

**Why it happens:**
- Async gaps in UI code, especially around long-running service results.
- `mounted` check forgotten.
- Riverpod Notifier not using `ref.mounted` where needed (Riverpod 3 introduces this).

**How to avoid:**
- **Lint enforcement**: `use_build_context_synchronously` is default in `very_good_analysis` — keep it at `error` level, no exceptions.
- **Riverpod `ref.mounted` on every async-resumed path in a Notifier** (Riverpod 3.x). `riverpod_lint` catches most cases.
- **No direct `BuildContext` in services**: services return values/streams, widgets consume them via providers. This sharply limits where `context.mounted` checks are needed.
- **Review pattern**: after every `await` in a widget, the NEXT line must be `if (!context.mounted) return;`. Enforced in code-review checklist (per CLAUDE.md already).
- **Timers and streams cancelled in `dispose`**: never leave a Timer.periodic or StreamSubscription hanging after widget disposal.

**Warning signs:**
- `flutter analyze` warnings about `use_build_context_synchronously`
- Stack traces containing "setState called after dispose" in logs
- `StreamSubscription` fields without corresponding `cancel()` in dispose

**Precedent:** [Flutter issue #73000 — setState called after dispose](https://github.com/flutter/flutter/issues/73000), [transistorsoft/flutter_background_fetch issue #42](https://github.com/transistorsoft/flutter_background_fetch/issues/42).

---

### 22. Drift migration without fixture test suite

**Category:** Persistence / Data integrity
**Severity:** High (directly feeds Pitfall 3)
**Phase to address:** Persistence

**What goes wrong:**
Schema version bump 1→2 adds a column. Migration code compiles. Runs on dev machine starting from nothing. Ships. On real user DB with data, one of the many edge cases (indexes, constraints, partial data) breaks. Data loss or migration crash.

**Why it happens:**
- Drift migrations tested only manually on dev.
- No schema-snapshot fixtures in the repo.
- "Migration works on my machine."

**How to avoid:**
- **Drift provides `schema_test` tooling** — adopt it. Per version, snapshot the schema, run the migration, assert the resulting schema matches the next version's snapshot.
- **Data-level migration tests**: fixtures directory `test/fixtures/db_v1.sqlite`, `db_v2.sqlite`, etc. Test `migrate(v1_fixture) == expected_v2_contents`. Include edge cases: empty DB, DB with only sessions, DB with tons of markers, DB near the storage limit.
- **Never delete a migration** — once shipped, it's forever. Chain them.
- **CI runs the full migration chain** from v1 fixture → current on every push.

**Warning signs:**
- No `test/db_migration_test.dart` file
- `schema_version` bumped without a matching migration function update
- No fixtures directory

---

### 23. Import without confirmation silently overwrites user's existing data

**Category:** Import/Export / UX / Data integrity
**Severity:** High
**Phase to address:** Import/Export

**What goes wrong:**
User taps "Import" to add a pre-made "places to visit" markers JSON. It contains a `session` key. Their active session "Paris été 2026" is silently replaced by the imported session, losing their real revealed tiles.

**Why it happens:**
- Import behaves like "load" instead of "merge/add".
- Same session UUID in import collides with existing and overwrites without asking.
- No preview / dry-run before committing.

**How to avoid:**
- **Import always merges, never overwrites implicitly.** Collision policies must be explicit:
  - Session UUID collision: ask [Replace] / [Import as new copy] / [Skip].
  - Marker UUID collision: same.
  - Category name collision: auto-rename imported to `<name> (imported)`.
- **Default policy is always "safe"** — new copy for data, skip for config, never replace without explicit user tap.
- **Preview screen before commit**: "This import will add: 1 session, 47 markers, 3 categories. Time to explore!" with a [Proceed] / [Cancel] choice.
- **Undo point**: implicitly back up the DB to `pre_import_<timestamp>.sqlite` before any import commits. Keep last 3.

**Warning signs:**
- Import button directly triggers DB writes with no confirmation
- Code contains `INSERT OR REPLACE` in import paths
- No "preview" intermediate state

---

## Medium-Severity Pitfalls

### 24. Tile cache growing unbounded

**Category:** Storage bloat
**Severity:** Medium
**Phase to address:** Map & Fog

**What goes wrong:**
flutter_map (or flutter_map_cache) caches every viewed tile forever. After 6 months, the tile cache is 2 GB. User has to wipe app data to recover space.

**Why it happens:**
- Cache has no eviction policy or default is "as much as possible."
- No periodic cleanup.

**How to avoid:**
- **Configure the cache with an explicit LRU cap** (e.g., 200 MB for V1.0).
- **Expose "Clear map cache" button** in Options screen with current cache size.
- **Age-based + size-based eviction**: drop tiles older than 30 days OR when cache exceeds cap (evict oldest first).
- **OSM requires minimum 7-day cache** per policy — don't evict more aggressively than that.

**Warning signs:**
- No max-size setting on tile cache
- No "Clear cache" UI
- Cache dir size grows linearly with total tiles viewed ever

---

### 25. Photos stored at full camera resolution without downscaling

**Category:** Storage bloat
**Severity:** Medium
**Phase to address:** Markers

**What goes wrong:**
Modern phone cameras produce 5–12 MB JPEGs. User attaches 5 photos per marker, 200 markers → 10 GB of photos. Export ZIP becomes unmanageable.

**Why it happens:**
- `ImagePicker.pickImage()` returns full-resolution by default.
- No resize step.

**How to avoid:**
- **`ImagePicker.pickImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 85)`** — produces ~300–800 KB photos, visually indistinguishable at marker-preview scale.
- **Store a thumbnail alongside** (`photo_<id>_thumb.jpg` at 256x256 for gallery previews) — 20–30 KB, instant gallery scroll.
- **Strip EXIF** (optional, but recommended for privacy: someone exports a session, EXIF contains GPS of the photo-taking moment, export recipient sees it; we want that explicit, not incidental).
- **Configurable photo quality setting** for power users (Low / Medium / High).

**Warning signs:**
- Photos > 2 MB in the photos dir
- No `maxWidth` / `imageQuality` args on picker calls
- No thumbnail generation

---

### 26. Log files growing unbounded

**Category:** Storage bloat
**Severity:** Medium
**Phase to address:** Foundation

**What goes wrong:**
CLAUDE.md mandates file logs at `<docs>/logs/yyyymmdd_hhmm.ss_logs.txt`. With per-session logs and extensive debug logging (CLAUDE.md asks for every method call in debug), a month of debug use = dozens of multi-MB log files. Export size balloons, storage fills.

**Why it happens:**
- Log handler appends forever, no rotation.
- No log level separation (DEBUG stored same as ERROR).

**How to avoid:**
- **Log rotation**: size-based (max 2 MB per file, truncate oldest) AND age-based (delete files > 14 days old).
- **Per-level file splitting optional but not needed at this scale** — single rotated file is fine.
- **Rotation runs on app start** (cheap) and on log-file hitting threshold.
- **Debug menu**: "Open logs folder" + "Clear all logs" UI. Share-as-file for bug reports.
- **Do NOT include logs in export** (they leak device info and serve no user purpose).

**Warning signs:**
- logs/ dir has files > 20 MB
- No rotation logic in log sink
- Log-file-path computation doesn't include a rotate step

---

### 27. Anti-aliasing makes fog reveal edges look weird

**Category:** Fog rendering / UX
**Severity:** Medium
**Phase to address:** Map & Fog

**What goes wrong:**
The reveal circle has perfectly hard edges OR has an AA mask that bleeds the fog color outward, creating a halo. At z=15 it looks fine, at z=5 the edges pixelate visibly (tile-bitmap approach). At z=18 the gradient is too gentle, fog feels "dirty" rather than "cloudy."

**Why it happens:**
- Developer picks one strategy (bitmap OR polygon) and tunes at a single zoom, then finds it broken at others.
- Antialiasing misconfigured (`Paint..isAntiAlias = true` on a fill that conflicts with a multiply blend mode).

**How to avoid:**
- **Fixed canonical zoom for the revealed-set** (z=16, per Pitfall 6), renderer derives visual presence from it regardless of current map zoom.
- **Per-zoom rendering tuning**: the `MirkRenderer` interface receives zoom level and adapts edge softness (more softening at high zoom where users are close, simpler pixel-aligned fill at low zoom where tiles dominate).
- **Mirk edge = a soft radial gradient** per revealed-tile cluster, composited with the noise/cloud texture. Avoid sharp circle boundaries — organic feel + anti-aliasing artifacts disappear.
- **Multi-zoom visual test fixture**: render at z=5, 10, 15, 18 side-by-side in a test golden file. Review before merge.

**Warning signs:**
- Renderer tested at a single zoom in dev
- No golden tests for fog appearance
- Mirk edge is a hard pixel line in screenshot review

---

### 28. Android 13+ photo permission misconfiguration (image_picker edge case)

**Category:** Permissions
**Severity:** Medium (doesn't crash, but can cause Play-pre-launch warnings and permission denials)
**Phase to address:** Markers

**What goes wrong:**
App declares `READ_EXTERNAL_STORAGE` (pre-13) but not `READ_MEDIA_IMAGES` (Android 13+). Picking photos on Android 13 devices fails silently.
Inverse: app declares `READ_MEDIA_IMAGES` but uses image_picker in "photo picker" mode (which doesn't need the permission on SDK 33+), triggering Play Console "you requested a permission you don't need" warning.

**Why it happens:**
- AndroidManifest.xml inherited from an old template.
- image_picker's Android Photo Picker fallback bypasses the permission, dev doesn't realize.

**How to avoid:**
- **Check image_picker docs for current Android integration**. V1.2.1 uses Android Photo Picker transparently on SDK 33+. If that's sufficient for V1.0, we don't need `READ_MEDIA_IMAGES` at all.
- **If declaring READ_EXTERNAL_STORAGE** for older devices, scope it with `android:maxSdkVersion="32"`.
- **Don't declare broader permissions than needed** — Play Console flags this and can reject.
- **Test on Android 10, 12, 13, 14** emulators in CI (ubuntu-latest can run Android emulators via `reactivecircus/android-emulator-runner`).

**Warning signs:**
- AndroidManifest.xml has both `READ_EXTERNAL_STORAGE` (no maxSdkVersion) AND `READ_MEDIA_IMAGES`
- Image picking fails silently on Android 13
- Play Console pre-launch report: "Unused permissions"

**Precedent:** [flutter/flutter issue #171493 — image_picker Play rejection with READ_MEDIA_IMAGES](https://github.com/flutter/flutter/issues/171493).

---

### 29. Session state desync between DB and Riverpod providers

**Category:** State management
**Severity:** Medium
**Phase to address:** Foundation (state setup), Persistence

**What goes wrong:**
Active session changed in DB (e.g., by the background tracking service that ticks revealed_tiles into the session's associated table). UI providers still show stale count. Marker was added via Add Marker screen, map UI still shows previous list because `markersProvider` didn't refresh.

**Why it happens:**
- Providers hold snapshots, not reactive reads.
- Manual `state = ...` rather than `.invalidate()` + re-fetch.
- Two writers (service isolate + UI isolate), no cross-isolate invalidation.

**How to avoid:**
- **Drift reactive streams everywhere**: `sessionByIdStream(id).watch()` → Riverpod `StreamProvider`. UI auto-refreshes on DB change.
- **Single-writer pattern** for contention-prone tables (revealed_tiles, session_state): the tracking service is the only writer. UI-triggered actions (Stop session) go through a service-level method, never write directly.
- **Invalidate-on-event**: after an import commits, call `ref.invalidate(sessionsProvider)` explicitly (stream updates catch most but manual invalidation documents the boundary).
- **Never cache Provider results across session boundaries** — `ref.watch(activeSessionProvider)` should re-read when the active session changes.

**Warning signs:**
- Providers using `Future` where `Stream` would fit better
- Repeated "why is the UI stale?" bugs
- Debug console shows UI still holding pre-operation data

---

### 30. FOREGROUND_SERVICE_LOCATION notification dismissible — user taps X → service killed

**Category:** Background GPS / Android UX
**Severity:** Medium
**Phase to address:** GPS & Session

**What goes wrong:**
Android 14 made foreground-service notifications dismissible in many configurations. User swipes away the "MirkFall is tracking" notification. On many OEMs, dismissing the notification kills the service. Session silently stops.

**Why it happens:**
- App didn't set `FLAG_ONGOING_EVENT` correctly via flutter_local_notifications config (or Android 14+ overrides it anyway for user-controllable notifications).
- No detection of "session should be running but isn't."

**How to avoid:**
- **Configure notification with `ongoing: true, autoCancel: false`** via flutter_local_notifications. On Android 14+ users can still dismiss; minimize this with a clear tap action ("tap to open MirkFall").
- **Watchdog**: a short periodic timer in the tracking isolate verifies service state every N minutes. If it detects it was killed, it re-registers itself (or writes a "session interrupted" flag the UI picks up on resume).
- **On app foreground**, verify session-expected-state vs service-actual-state. Reconcile by either resuming tracking or surfacing "tracking stopped" to the user (per Pitfall 7 OEM detection).
- **Don't let the notification be the only "am I tracking" indicator**: the app's session screen shows a real-time tracking status badge that reads from the service, not the notification.

**Warning signs:**
- Tests don't cover "user dismisses notification"
- No reconciliation code on app foreground

**Precedent:** [GitHub community discussion — foreground notification dismissible on Android 14+](https://github.com/orgs/community/discussions/160398), [Notifee issue #958](https://github.com/invertase/notifee/issues/958).

---

### 31. Timeouts missing on native calls

**Category:** Robustness
**Severity:** Medium
**Phase to address:** Foundation, reinforced in GPS & Session, Import/Export

**What goes wrong:**
`permission_handler.requestPermission()` or a platform-channel call to a native geocoder pends forever (OEM bug, system-wide issue). UI frozen. User force-quits.

**Why it happens:**
- CLAUDE.md mandates timeouts on all external calls but it's easy to forget on method-channel calls that "feel synchronous."
- Third-party libs don't document timeout behavior.

**How to avoid:**
- **Wrap every platform-channel call with `.timeout(nativeCallTimeout)`** — constant defined in `lib/config/constants.dart`, default 10s.
- **Specifically wrap**:
  - geolocator position requests (one-shot)
  - permission_handler requests
  - file_picker pick calls (can hang if OS picker is buggy)
  - image_picker pick calls
- On timeout, treat as "user cancelled" + log — do NOT silently retry.

**Warning signs:**
- Any `await someLibraryCall()` without `.timeout(...)`
- No `nativeCallTimeout` constant

---

### 32. Update-check logic phoning home (direct GOSL violation)

**Category:** Legal / Privacy
**Severity:** Medium (easy to introduce, easy to forbid)
**Phase to address:** Foundation, reinforced in Polish & Release

**What goes wrong:**
A future contributor thinks "we should check GitHub Releases for new versions" and adds a startup HTTP request. GOSL forbids automatic update checks.

**Why it happens:**
- "Standard" in the industry.
- Seems harmless.

**How to avoid:**
- **README + CONTRIBUTING.md explicitly forbid** auto-update checks.
- **CI "no telemetry" test** (per Pitfall 10) catches startup HTTP traffic.
- **If updates are a genuine need**: manual "Check for updates" button on About screen, explicitly user-initiated, with clear disclosure.

**Warning signs:**
- HTTP request on app startup
- Contributor PR titled "add update check"

---

### 33. Non-compatible license in contributor PR

**Category:** Legal
**Severity:** Medium (rare but catastrophic if merged unnoticed)
**Phase to address:** Foundation (governance), enforced in every phase

**What goes wrong:**
Contributor submits a PR with code lifted from a GPL-licensed project. Merged unwittingly. Project is now in license violation.

**Why it happens:**
- GitHub public project → random contributions.
- No CLA or DCO enforcement.
- Reviewer assumes good faith.

**How to avoid:**
- **CONTRIBUTING.md requires a DCO sign-off** (`git commit -s`) declaring the contribution is under GOSL-compatible terms.
- **PR template** with a checkbox: "I confirm this code is original OR copied from a project under MIT/BSD/Apache-2.0/Unlicense/CC0/ISC/zlib license, and I've credited the source."
- **Reviewer checklist**: for any non-trivial change, verify code origin. Cross-check against GitHub code search for suspicious literal matches.
- **License-header check on all new files** (Pitfall 11).

**Warning signs:**
- PR without DCO sign-off
- PR adds large blocks without author context

---

## Low-Severity Pitfalls

### 34. Single-zoom visual QA

**Category:** Rendering
**Severity:** Low (cosmetic)
**Phase to address:** Map & Fog

**What goes wrong:**
Mirk looks great at z=15 (developer's usual test zoom) but at z=5 the fog texture tiles obviously, at z=18 it pixelates.

**How to avoid:** multi-zoom golden tests (see Pitfall 27).

---

### 35. No About / Legal screen at release

**Category:** Project hygiene / legal
**Severity:** Low (trivial to add if noticed)
**Phase to address:** Polish & Release

**What goes wrong:** CLAUDE.md mandates "MirkFall is distributed under GOSL v1.0" be visible in-app. Forgotten in the race to release.

**How to avoid:** Include in the Options phase acceptance criteria. Ship About screen in the same milestone.

---

### 36. RepaintBoundary cargo-culting

**Category:** Flutter idioms
**Severity:** Low
**Phase to address:** Map & Fog

**What goes wrong:** Developer sprinkles `RepaintBoundary` liberally thinking "more = better". Memory and GPU overhead increase, perf doesn't.

**How to avoid:** Measure with DevTools overlay, place RepaintBoundary only around expensive + independently-repainting subtrees (FogOfWarLayer, MarkerLayer).

**Precedent:** [Saropa — RepaintBoundary misuse](https://saropa.com/articles/why-flutters-repaintboundary-is-your-secret-weapon-against-jank/).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store raw GPS points in a `gps_fixes` table "for later analytics" | 1 line of code | Multi-GB DB, 10× export size, slow queries, future extraction work | NEVER for V1.0; `revealed_tiles` only |
| Skip the schema-version envelope in JSON export "we'll add it in V1.1" | 10 LOC saved | V1.0 exports become unreadable by V1.1 importers without retrofitting | NEVER — the version field is the core promise |
| Use a single long-lived DB write transaction for a session | Easy undo | Corruption risk on kill, UI can't read concurrent | NEVER with WAL at full speed; use short per-event transactions |
| Absolute photo paths in DB "just works for now" | Zero setup | Breaks on reinstall, cross-device import, iOS sandbox rotation | NEVER |
| Test only on stock Android (Pixel emulator) | Fast | Miss 70% of real-world OEM behavior | Acceptable for POC phase; real-device testing mandatory before any release |
| Ship without a pre-launch demo video for store reviewers | Save a day | Double rejection cycle, 2+ week release delay | If store submission isn't planned (GitHub-only distribution), acceptable |
| Skip file rotation on logs "logs are small" | Trivial | Eventually fills device storage | Never on user devices; acceptable in dev |
| Catch-and-log in import code to "be robust" | No crashes | Silent partial import, user trusts corrupted state | NEVER; fail loudly then recover via transaction rollback |
| Single global `GetIt` singleton for services | Short import paths | Violates CLAUDE.md DI; invisible coupling | NEVER — Riverpod providers are the DI container |
| Generic User-Agent on OSM tiles "for now" | Zero config | Sudden tile-server ban with no warning | NEVER |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **OSM tile server** | Default User-Agent, bulk prefetch, no attribution | Identifying UA with contact URL; only viewport-driven fetches; visible ODbL attribution |
| **geolocator (Android)** | No foreground service, no `FOREGROUND_SERVICE_LOCATION` permission on SDK 34+ | Declare permission, run foreground service with `locationForegroundServiceType`, persistent notification |
| **geolocator (iOS)** | `allowsBackgroundLocationUpdates=false`, or combining `startUpdatingLocation` with SLC in low-accuracy mode | `allowsBackgroundLocationUpdates=true`, `activityType: fitness`, pick ONE strategy (continuous OR SLC) based on accuracy need |
| **image_picker (Android 13+)** | Declare `READ_MEDIA_IMAGES` while using PhotoPicker fallback | Rely on PhotoPicker on SDK 33+ (no permission needed), scope legacy `READ_EXTERNAL_STORAGE` to maxSdkVersion 32 |
| **file_picker** | Assume file path is persistent; assume ZIP picking works on all platforms | Treat path as cached copy; verify file exists before opening; for iOS, the returned path is a sandbox temp copy |
| **flutter_local_notifications** | Assume notification is non-dismissible on Android 14+ | Treat as dismissible; add watchdog to detect service death |
| **Drift** | Default journal mode (DELETE), no busy_timeout | WAL mode, `busy_timeout=5000`, `synchronous=NORMAL` |
| **Riverpod 3.x** | Forget `ref.mounted` after async gap in Notifier | Check `ref.mounted` after every `await`; `riverpod_lint` enforces |
| **SideStore sideload** | Assume persistent install | 7-day re-sign cycle; document; auto-save state frequently |
| **GitHub Actions iOS build** | Assume unsigned IPA is installable | Unsigned = CI smoke-test only. Sideload needs personal re-signing step locally |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Iterate all revealed tiles per frame | Raster thread > 16ms, pan lag | Spatial index keyed on tile coord, viewport filter | > ~5k tiles visible |
| 1 Hz GPS polling when stationary | Battery drain, phone warm | distanceFilter > 0, stationary detection, pause on no-movement | Any session > 30 min |
| Full-resolution photo storage | App-data dir > 5 GB | `maxWidth/Height 2048`, `imageQuality 85` | > ~100 markers with photos |
| Unbounded tile cache | Cache dir > 1 GB | LRU cap + age-based eviction | ~3 months normal use |
| Unbounded log files | logs/ > 100 MB | Size + age rotation | ~1 month debug-on use |
| Naive gps_fixes table | DB > 500 MB | Use revealed_tiles only (dedup) | ~6 months daily use |
| Single long write transaction | DB locked errors | Short per-event transactions + WAL | Immediate under contention |
| Over-use of RepaintBoundary | GPU memory spikes | Boundary only around independently-repainting expensive subtrees | Immediate on low-RAM devices |
| Syncing DB queries off reactive streams | Stale UI, extra reads | Drift `watch()` + Riverpod StreamProvider | Immediate |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Export JSON contains raw photo EXIF with GPS of photo-taking moment | Unwanted precise location leakage if user shares export | Strip EXIF on photo import OR document clearly in export flow |
| Import JSON is not schema-validated before parsing | Crafted malicious JSON could crash app or (worst case) write out-of-sandbox paths | Strict schema validation before touching DB; only accept known fields; no `eval`-like deserialization |
| Photo paths in JSON are absolute | Potential path-traversal on import (`../../other_app/...`) | Reject absolute paths in imports; only archive-relative `photos/<uuid>/...` allowed |
| Tile cache shares filesystem with photos | Photo delete could accidentally hit cache | Separate subdirs: `<docs>/photos/` vs `<cache>/tiles/` |
| Logs contain GPS coordinates in plain text | Device compromised → trail visible in logs | In production, log level = WARNING only; debug-level logs (with coordinates) only when user opts in via debug menu |
| Session backups accessible via adb pull / iTunes backup | Device compromise exposes data | This is user-accepted risk for local-first apps; DO document in About/Legal screen |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No rationale before permission prompt | Permanent deny | Pre-flight screen with "why" + "Continue" CTA |
| Background permission requested at startup | Deny → app useless | Request only when user presses Start on first session |
| "Tracking active" indicator only = notification | User doesn't know state when notif dismissed | In-app real-time tracking badge on session screen |
| Silent "Export complete" with no verification | User trusts corrupt backup | Show row counts + round-trip verification before declaring success |
| Import with no preview | User overwrites existing session accidentally | Preview screen with diff + explicit [Proceed] |
| Generic "Tracking stopped" error | User can't troubleshoot | Device-family-specific "fix it for next time" banner (OEM killers) |
| Mirk looks washed out at low zoom | User thinks app is buggy | Per-zoom rendering tuning, multi-zoom QA |
| No way to see how much data is stored | Unknown storage bloat | "Storage" screen showing photos / tiles / DB / logs sizes + clear actions |
| Session stopped unexpectedly on iOS sideload cert expiry | Data-loss panic | Documentation + auto-persist state + resume flow |
| "Clear cache" nuke the tile cache including OSM-required 7-day | Back-to-network on every open | "Clear old tiles (> 7 days)" + "Clear all tiles" with warning |

---

## "Looks Done But Isn't" Checklist

- [ ] **Background location permission flow:** Verify it includes a rationale screen BEFORE the system prompt, not after. Check on Android 11, 12, 13, 14 + iOS 16, 17.
- [ ] **OEM battery killing:** Verify device-family-specific guidance exists for Xiaomi, Huawei, Samsung, OnePlus. Test on at least one non-Pixel device before release.
- [ ] **Persistent notification:** Verify it appears on session Start and is dismissed on session Stop, on Android 10, 12, 14. Tap-action opens the app.
- [ ] **Data export:** Verify the export file can be re-imported into a fresh install with zero loss. Round-trip test per release.
- [ ] **Migration from previous version:** For every release post-V1.0, run the full migration chain against a real V1.0 DB with data. Verify row counts and checksum.
- [ ] **OSM attribution:** Verify "© OpenStreetMap contributors" text is visible on every map screen AND is tappable to https://www.openstreetmap.org/copyright. Check About screen.
- [ ] **User-Agent on tile requests:** Verify HTTP inspector shows `MirkFall/... (+URL)` not `Dart/...`.
- [ ] **License header on new files:** CI check passing. Manual spot-check in release PRs.
- [ ] **No telemetry smoke test:** Run app for 30 seconds with HTTP proxy, verify zero outbound requests in idle state.
- [ ] **GOSL attribution in About:** "MirkFall is distributed under GOSL v1.0" visible with link to full text.
- [ ] **Android 14 targetSdk 34:** `FOREGROUND_SERVICE_LOCATION` declared + requested. `foregroundServiceType="location"` in service declaration.
- [ ] **iOS Info.plist:** `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription` (if camera picker), `NSCameraUsageDescription`, `UIBackgroundModes: location`. All with user-facing copy, not template text.
- [ ] **Sideload 7-day expiry:** Tested behavior: cert expires → app can't relaunch → user re-signs via SideStore → data intact on next open.
- [ ] **Storage cap and rotation:** Tile cache LRU works, log files rotate, photos dir reflects only referenced files.
- [ ] **Photo export round-trip:** Export ZIP, extract, verify every photo file matches its hash in manifest.json.
- [ ] **Provider recreation on hot restart:** Verify active session state survives a hot restart (should rebuild from DB, not in-memory).
- [ ] **Permission revoked mid-session:** User goes to Settings → revokes location while session active. App must detect, stop tracking cleanly, surface UI banner.
- [ ] **Airplane mode during session:** Map goes offline gracefully, GPS still works (radio separate), revealed tiles persist correctly.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Migration corruption (Pitfall 3) | LOW if backup exists | On detect: restore from `backups/pre_migration_*.sqlite`, prompt user, retry migration with diagnostic log |
| Orphaned photos (Pitfall 5) | LOW | Reconciliation job on next launch; expose "Storage → Clean orphans" action |
| OEM killed service (Pitfall 7) | MEDIUM (data between last-tick and kill is lost) | On relaunch: detect stale active session, show "Tracking was interrupted — last update Nm ago" banner, offer resume |
| OSM ban (Pitfall 8) | HIGH | Requires UA fix + abstain from prefetch + wait out ban (days–weeks); plan contingency with alternative tile source |
| GPL in transitive deps (Pitfall 9) | LOW if caught in CI | Drop the package; find alternative (checked in STACK.md) |
| Telemetry crept in (Pitfall 10) | LOW if caught in CI | Revert; audit the release for what version shipped it |
| Sideload cert expiry mid-session (Pitfall 15) | LOW | State auto-persist means "continue session" on resign is seamless |
| Partial import (Pitfall 16) | LOW with transaction | Automatic rollback; user sees clear error, no data harm |
| Import overwrote existing session (Pitfall 23) | MEDIUM if no backup | Restore from `pre_import_*.sqlite` backup |
| Export incomplete (Pitfall 19) | HIGH if user has already trusted it | If caught at export time: abort + warn. If caught on later re-import: user data loss potentially irreversible. Prevention is only strategy. |
| Fog rendering jank (Pitfall 20) | LOW | Lower canonical zoom granularity or introduce spatial index; no data impact |
| Missing license header (Pitfall 11) | LOW | CI fails, fixed in PR |
| Contributor non-compatible license (Pitfall 33) | HIGH if merged | Revert commit + rewrite; painful but recoverable |
| App Store rejection (Pitfall 2) | MEDIUM (2-week delay) | Revise usage descriptions + review notes + resubmit |
| Play Store rejection (Pitfall 1) | MEDIUM | Same pattern + Data Safety form update |

---

## Pitfall-to-Phase Mapping

| Pitfall | Primary Prevention Phase | Secondary / Reinforcement | Verification |
|---------|--------------------------|----------------------------|--------------|
| 1. Play Store rejection (bg location) | Polish & Release | GPS & Session | Play Console Data Safety form review; dry-run review-notes doc in repo |
| 2. App Store rejection (2.5.4) | Polish & Release | GPS & Session | Written review notes + demo video in repo `/docs/store-review/` |
| 3. Catastrophic data loss on update | Persistence | Import/Export | Migration test suite with fixtures; backup-before-migration in `onUpgrade` |
| 4. SQLite corruption | Persistence | — | WAL pragma set; integrity_check on open; crash-simulation test |
| 5. Orphaned photos | Markers | Persistence | Reconciliation job + scheduled run; path-is-relative invariant |
| 6. Naive GPS storage | GPS & Session | Persistence | Schema review; no gps_fixes table; DB size fixture test |
| 7. OEM background kill | GPS & Session | Polish & Release | Non-Pixel device test + "interrupted tracking" reconciliation |
| 8. OSM tile server ban | Map & Fog | — | HTTP inspector test; attribution UI present; no prefetch |
| 9. GPL transitive | Foundation | Every phase | CI license-scan step green |
| 10. Silent telemetry | Foundation | Every phase | CI no-telemetry smoke test green |
| 11. Missing license header | Foundation | Every phase | CI license-header-check green |
| 12. Permission UX bad | GPS & Session | Markers (camera perms) | UX flow review; openAppSettings handler |
| 13. Battery drain | GPS & Session | — | Battery profiling fixture; distanceFilter config |
| 14. iOS background suspended | GPS & Session | Polish & Release | Real-device 30min background test |
| 15. Sideload cert expiry | Polish & Release | Foundation (state persist) | Resume-after-kill flow test |
| 16. Partial import | Import/Export | — | Transactional import + round-trip test |
| 17. Version field not honored | Foundation | Import/Export | Migration chain + cross-version tests at V1.0 |
| 18. Cross-device photo refs | Import/Export | Markers | ZIP archive format + round-trip test |
| 19. Export incomplete | Import/Export | — | Pre-export integrity + post-export round-trip |
| 20. Rendering jank | Map & Fog | — | 50k-tile fixture performance test |
| 21. setState after dispose | Foundation (lints) | Every phase | `flutter analyze` zero warnings mandated |
| 22. Drift migration without fixtures | Persistence | — | `test/db_migration_test.dart` + schema_test adoption |
| 23. Import overwrites without confirm | Import/Export | — | Preview screen + collision dialog in UI tests |
| 24. Tile cache unbounded | Map & Fog | — | LRU cap config + Clear cache UI |
| 25. Full-res photos | Markers | — | maxWidth/imageQuality args; size assertion in tests |
| 26. Logs unbounded | Foundation | — | Rotation config; log dir size test |
| 27. Fog AA weird at edge zoom | Map & Fog | — | Multi-zoom golden tests |
| 28. Android 13+ photo permission | Markers | — | Manifest review; Play Console pre-launch report |
| 29. Riverpod ↔ DB desync | Foundation (state) | Persistence | Drift watch() + StreamProviders universally |
| 30. Notification dismissible | GPS & Session | — | Watchdog + reconcile-on-foreground |
| 31. Missing timeouts | Foundation | Every phase | Constants file `nativeCallTimeout` + lint/grep |
| 32. Update-check phoning home | Foundation | Polish & Release | CI no-telemetry test |
| 33. Contributor non-compat license | Foundation | Every PR | DCO + CONTRIBUTING.md + PR template |
| 34. Single-zoom visual QA | Map & Fog | — | Multi-zoom goldens |
| 35. Missing About/Legal | Polish & Release | — | Release checklist |
| 36. RepaintBoundary cargo-cult | Map & Fog | — | DevTools measurement in review |

---

## Phase Ordering Implication

Reading the mapping, the roadmap benefits from this rough structure:

1. **Foundation** (first, heavy) — sets up CI license scan, license-header check, no-telemetry smoke test, lint config (including `use_build_context_synchronously`), logging with rotation, timeouts constant, DI via Riverpod with doc, DB module stub with WAL pragmas, migration-chain skeleton with V1→V1 identity migration, ZIP archive library choice. This phase spends "setup effort" that pays forward against pitfalls 9, 10, 11, 17, 21, 26, 31, 32, 33.

2. **Persistence** — Drift schema for sessions, markers, categories, revealed_tiles. WAL, busy_timeout, synchronous setup. Backup-on-migration framework. Fixture-based migration tests. Photo path storage as RELATIVE. Addresses 3, 4, 5 (partial), 6, 22.

3. **GPS & Session** (depends on Foundation + Persistence) — tracking service (Android foreground + iOS background modes), permission flow with rationale, OEM-specific guidance, stationary detection, distanceFilter tuning, Info.plist + AndroidManifest, watchdog + reconcile-on-foreground. Addresses 1, 2 (partial), 7, 12, 13, 14, 30.

4. **Map & Fog** (depends on Foundation) — flutter_map with configured User-Agent, OSM attribution, MirkRenderer interface, CustomPainter with spatial index, viewport-driven rendering, multi-zoom goldens, tile cache LRU + cap. Addresses 8, 20, 24, 27, 34, 36.

5. **Markers** (depends on Persistence + Map & Fog) — marker CRUD, categories, image_picker with downscaling, photo reconciliation job, Android 13+ photo permission handling. Addresses 5, 25, 28.

6. **Import/Export** (depends on Persistence + Markers) — versioned envelope + migration chain, ZIP archive, all-or-nothing transaction, preview screen, collision resolution, pre-export integrity + post-export round-trip, backup-before-import. Addresses 16, 17, 18, 19, 23.

7. **Polish & Release** — App Store review notes + demo video, Play Console Data Safety form, About/Legal screen, sideload documentation, CI iOS unsigned build, APK release pipeline. Addresses 1 (secondary), 2, 15, 32, 35.

Each phase's review gate is the checklist above, filtered to that phase's pitfalls.

---

## Sources

**Apple / iOS:**
- [Apple App Review Guidelines 2.5.4 (multitasking apps)](https://developer.apple.com/app-store/review/guidelines/)
- [Handling location updates in the background — Apple Developer docs](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
- [Apple Developer Forums — Background location stops in iOS 16.4 (thread #726945)](https://developer.apple.com/forums/thread/726945)
- [Apple Developer Forums — App rejected for background location (thread #108641)](https://developer.apple.com/forums/thread/108641)
- [Expo forum — iOS rejections for `location` background mode](https://forums.expo.dev/t/ios-app-store-rejections-with-the-location-background-mode/25537)

**Google / Android:**
- [Google Play — Policy announcement April 15, 2026](https://support.google.com/googleplay/android-developer/answer/16926792?hl=en)
- [Google Play — Understanding location in the background permissions](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en)
- [Google Play — Permissions and APIs that Access Sensitive Information](https://support.google.com/googleplay/android-developer/answer/16585319?hl=en)
- [Android Developers — Foreground service types are required (Android 14)](https://developer.android.com/about/versions/14/changes/fgs-types-required)
- [Android Developers — Grant partial access to photos and videos (Android 14)](https://developer.android.com/about/versions/14/changes/partial-photo-video-access)
- [Android Developers — Access location in the background](https://developer.android.com/develop/sensors-and-location/location/background)
- [Android Developers — Optimize for Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)
- [Radar — Guide to Play Store background location approval](https://radar.com/blog/guide-to-play-store-background-location-approval)

**OEM / Battery killing:**
- [dontkillmyapp.com](https://dontkillmyapp.com/)
- [DEV — What Android OEMs do to background apps, 11 layers to survive](https://dev.to/stoyan_minchev/what-android-oems-do-to-background-apps-and-the-11-layers-i-built-to-survive-it-28bb)
- [ProAndroidDev — Beyond Doze: Building Reliable Background Execution on Modern Android (March 2026)](https://proandroiddev.com/beyond-doze-building-reliable-background-execution-on-modern-android-including-oem-realities-5fa0a6e05672)
- [ProAndroidDev — Android Foreground Service Restrictions](https://proandroiddev.com/android-foreground-service-restrictions-d3baa93b2f70)

**OpenStreetMap:**
- [OSM Tile Usage Policy (Operations Working Group)](https://operations.osmfoundation.org/policies/tiles/)
- [OSM Wiki — Blocked tiles](https://wiki.openstreetmap.org/wiki/Blocked_tiles)
- [OSM Community — Access blocked due to tile usage policy](https://community.openstreetmap.org/t/access-blocked-tile-usage-policy/133862)
- [OSM Wiki — Tile usage policy](https://wiki.openstreetmap.org/wiki/Tile_usage_policy)

**Flutter / Dart:**
- [Flutter issue #72066 — CustomPainter performance](https://github.com/flutter/flutter/issues/72066)
- [Flutter issue #73000 — setState after dispose](https://github.com/flutter/flutter/issues/73000)
- [Flutter issue #115054 — CustomPaint jank on Android](https://github.com/flutter/flutter/issues/115054)
- [Flutter issue #171493 — image_picker Play rejection](https://github.com/flutter/flutter/issues/171493)
- [Saropa — RepaintBoundary misuse](https://saropa.com/articles/why-flutters-repaintboundary-is-your-secret-weapon-against-jank/)
- [flutter_file_picker FAQ — scoped storage](https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ)
- [flutter_local_notifications — foreground service behavior](https://github.com/invertase/notifee/issues/958)
- [GitHub community — foreground notification dismissible on Android 14+](https://github.com/orgs/community/discussions/160398)
- [Baseflow permission_handler — Android 13+ photo permission question](https://github.com/Baseflow/flutter-permission-handler/issues/1380)

**Drift / SQLite:**
- [Drift issue #3031 — WAL locking](https://github.com/simolus3/drift/issues/3031)
- [Drift issue #2990 — "database disk image is malformed"](https://github.com/simolus3/drift/issues/2990)
- [SQLite WAL documentation — recovery caveats](https://sqlite.org/wal.html)
- [Drift FAQ](https://drift.simonbinder.eu/faq/)

**Battery / GPS:**
- [Medium — Benchmarked Every Background Location Plugin (March 2026) — geolocator at 10-14%/hr](https://medium.com/@kiranbjm/i-benchmarked-every-background-location-plugin-for-flutter-android-ios-heres-why-most-of-them-5e46ba8fe472)
- [Metova — How to Implement Geolocation Without Draining Battery](https://metova.com/how-to-implement-geolocation-without-draining-your-users-battery/)
- [Vibe Studio — Handling Background Location Tracking Responsibly in Flutter](https://vibe-studio.ai/insights/handling-background-location-tracking-responsibly-in-flutter)

**Data loss — Fog of World precedent:**
- [Fog of World (Ollix) App Store page — user reviews documenting 56-level loss](https://apps.apple.com/us/app/fog-of-world/id505367096)
- [Fog of World — Hacker News thread](https://news.ycombinator.com/item?id=4590663)

**Riverpod 3.x:**
- [flutter_riverpod changelog (Riverpod 3 release notes)](https://pub.dev/packages/flutter_riverpod/changelog)
- [Medium — Flutter Riverpod 3.0 Major Redesign](https://medium.com/@lee645521797/flutter-riverpod-3-0-released-a-major-redesign-of-the-state-management-framework-f7e31f19b179)
- [Riverpod issue #1887 — state stops working after hot reload](https://github.com/rrousselGit/riverpod/issues/1887)

**Sideload / iOS distribution:**
- [SideStore FAQ (7-day cert, 3-app limit)](https://docs.sidestore.io/docs/faq)
- [AltStore FAQ](https://faq.altstore.io/altstore-classic/your-altstore)
- [How iOS Sideloading Actually Works in 2025 (DEV)](https://dev.to/1_king_0b1e1f8bfe6d1/how-ios-sideloading-actually-works-in-2025-dev-certs-altstore-and-the-eu-exception-1m2h)

**License / dependency audit:**
- [Very Good CLI — check licenses](https://cli.vgv.dev/docs/commands/check_licenses)
- [dart_license_checker](https://github.com/redsolver/dart_license_checker)
- [FOSSLight Dependency Scanner](https://fosslight.org/fosslight-guide-en/scanner/3_dependency.html)

**Fog-of-war rendering (reference for design):**
- [Brendan Keesing — Fog Of War blog post](https://brendankeesing.com/blog/fog_of_war/)
- [FOW-research by PeterMCP](https://petermcp.github.io/FOW-research/)

**Project-internal:**
- `C:/claude_checkouts/GOSL-MirkFall/CLAUDE.md` — project rules, license policy, lint config
- `C:/claude_checkouts/GOSL-MirkFall/.planning/PROJECT.md` — scope and constraints
- `C:/Users/oliver/Documents/main_vault_ath/GOSL-MirkFall/specification V1.0.md` — functional spec §9 flags the GPS storage constraint and background tracking review question
- `C:/claude_checkouts/GOSL-MirkFall/.planning/research/STACK.md` — forbidden packages (FMTC GPL, flutter_background_geolocation paid), chosen packages

---

*Pitfalls research for: MirkFall — Flutter fog-of-war map app (iOS + Android, GOSL v1.0)*
*Researched: 2026-04-17*
