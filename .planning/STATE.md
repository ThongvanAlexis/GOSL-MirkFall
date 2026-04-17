---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 1
status: executing
stopped_at: Completed 02-01-PLAN.md (scaffold + user-first capture)
last_updated: "2026-04-17T18:15:16Z"
last_activity: 2026-04-17
progress:
  total_phases: 16
  completed_phases: 1
  total_plans: 8
  completed_plans: 5
  percent: 56
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-17)

**Core value:** Ne jamais perdre sa progression — import/export JSON versionné durable entre instances.
**Current focus:** Phase 02 — Review Gate Foundation (02-01 done, 02-02 audit sub-agents unblocked)

## Current Position

Phase: 02 of 16 (Review Gate — Foundation)
Current Plan: 1
Total Plans in Phase: 4
Plan: 1 of 4 in current phase (02-01 scaffold + user-first §1 capture shipped)
Status: In Progress
Last Activity: 2026-04-17

Progress: [█████▌░░░░] 56%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 h

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| — | — | — | — |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-foundation P01 | 9 min | 1 tasks | 14 files |
| Phase 01-foundation P02 | 13 min | 2 tasks | 15 files |
| Phase 01-foundation P03 | 9 min | 2 tasks | 9 files |
| Phase 01-foundation P04 | 1h 36m | 2 tasks | 2 files |
| Phase 02-review-gate-foundation P01 | 2 min | 2 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions carried from research (2026-04-17) :

- Phase 03: Revealed area = zoom-14 parent tiles + 64×64 sub-tile bitmaps (D3)
- Phase 03: Single Drift DB pour toute donnée structurée (D4)
- Phase 03: Envelope JSON `{schemaVersion, type, payload}` pour import/export (D9)
- Phase 05: Pas de `flutter_background_geolocation` — clé de licence payante incompatible GOSL ; geolocator + foreground service Android + iOS background mode à la place
- Phase 05: Exclusivité session enforced par partial unique index Drift, pas par discipline caller (D13)
- Phase 07: `TileSource` seam — V1.0 online OSM, V1.1 MBTiles offline en pur ajout (D7)
- Phase 09: `MirkRenderer` seam — expose uniquement `paint(Canvas, Size, MirkPaintContext)`, aucun détail d'implémentation (D6)
- Project-wide: Riverpod comme unique state management + DI (D5)
- [Phase 01-foundation]: Held analyzer stack at <9.0 for Phase 01 — No compatible custom_lint + riverpod_lint + analyzer trio exists yet; upgrading to analyzer ^9 would force dropping lint tools. Phase 03 will re-evaluate when ecosystem converges.
- [Phase 01-foundation]: Defer custom_lint + riverpod_lint to Phase 03 — Phase 01 has no @riverpod providers; lint tools add no value until codegen starts.
- [Phase 01-foundation]: Empty ios/Podfile.lock placeholder on Windows dev host — CocoaPods not available on Windows; macOS CI regenerates on first pod install.
- [Phase 01-foundation]: FileLogger as static class, not Riverpod provider — owns process-global IOSink + Logger.root subscription — Wrapping process-global singletons in a provider would be cargo-cult DI per CLAUDE.md §Wrappers (no wrappers without added logic)
- [Phase 01-foundation]: Single DEBUG-define test with runtime branching on bool.fromEnvironment('DEBUG') — One test file asserts Level.ALL when --dart-define=DEBUG=true and Level.INFO otherwise — CI never silently skips the DEBUG-define path
- [Phase 01-foundation]: cross_file imported via share_plus re-export (not as direct dep) — share_plus_platform_interface re-exports package:cross_file/cross_file.dart — XFile available through share_plus import, no extra audit entry
- [Phase 01-foundation]: pumpAndSettle() replaced with bounded settleRefresh(tester) in DebugMenuScreen tests — Active FileLogger sink + Logger.root listener feed microtask queue continuously; pump+runAsync helper with bounded iteration avoids timeout
- [Phase 01-foundation]: Accept dbus/geoclue/gsettings MPL-2.0 as Linux-only transitives via narrow _manualOverrides with synthetic SPDX MPL-2.0-Linux-only — Linux plugin surfaces never execute on Android/iOS (MirkFall's ship targets); MPL-2.0 is file-level weak-copyleft so it does not contaminate combined work. Synthetic SPDX keeps exception visible in code review.
- [Phase 01-foundation]: Promote yaml + test from transitive to direct dev dependencies — Our scripts/tests import them directly; depend_on_referenced_packages lint + CLAUDE.md pin policy require explicit declaration.
- [Phase 01-foundation]: CI gate exit code contract: 0=clean, 1=policy violation, 2=misconfiguration — Distinct signals let CI differentiate between a caught violation and a broken run; keeps gate outputs actionable.
- [Phase 01-foundation]: Option A for cross-platform Podfile.lock bootstrap — CI detects placeholder (no COCOAPODS: footer), removes it before pod install, does NOT auto-commit the regenerated lockfile back — Windows dev host cannot generate Podfile.lock (no CocoaPods). Option B (CI auto-commit back) was rejected — creates noisy commit history + requires CI write access to main. Option C (seed once on Mac, commit) was rejected — drifts on every transitive pod upgrade, and author primarily works on Windows. Option A keeps CI read-only, makes the pins the single source of truth, and regenerates from scratch every run.
- [Phase 01-foundation]: Core library desugaring enabled in android/app/build.gradle.kts with pinned desugar_jdk_libs:2.1.4 — flutter_local_notifications 21.0.0 requires java.time APIs at minSdk 24; AGP 8.x needs isCoreLibraryDesugaringEnabled = true + the coreLibraryDesugaring dep. Version 2.1.4 matches the AGP 8.x bundled version as of 2026-04.
- [Phase 01-foundation]: Forensic-analysis diagnostic step added to android + ios CI jobs with continue-on-error — Runs after flutter pub get, before the build step — dumps runner OS, toolchain, SDK, deps, disk, env. continue-on-error guarantees the diagnostic itself can never break a build. Reusable pattern for Phase 15 release CI and beyond.
- [Phase 02-review-gate-foundation]: Review-gate protocol operationalized as Plan 02-01 with blocking checkpoint — Encoding CLAUDE.md §Code Review Phases as a structural gate (scaffold + solicit+capture + commit-before-agents) makes it enforceable under time pressure. Future review gates (04, 06, 08, 10, 12, 14, 16) will reuse this 2-task pattern.
- [Phase 02-review-gate-foundation]: 5-section review artifact contract locked — §1 User-observed / §2 Claude audit / §3 Triage / §4 Adversarial / §5 CI-green. gsd-verifier greps `^## [1-5]\\.` to confirm 5 headings. Reusable across all even-numbered phases.
- [Phase 02-review-gate-foundation]: GOSL Dart copyright header NOT prepended to .md review artifacts — tool/check_headers.dart scans .dart only; markdown exempt. Consistent with Phase 01 header scanner scope.

### Pending Todos

None yet.

### Blockers/Concerns

**Phase 05 (POC GPS background):** Risque #1 projet. Si la validation background sur OEM Android ou iOS échoue, toute la V1.0 est remise en question. Doit être validé avant d'investir dans Map/Fog/Markers.

**Phase 05 (store policy):** Les strings de justification "Always" location doivent être rédigées humainement pour résister à une revue App Store / Play Store. Texte finalisé en Phase 15.

**Phase 09 (fog perf):** Sub-tile grid size (32/64/128) et batch-flush interval à profiler sur fixture 50k-tiles avant de finaliser les constantes.

**Phase 11 (EXIF strip):** `image_picker` ne strippe pas EXIF nativement ; approche lightweight à évaluer en début de Phase 11.

**Phase 13 (ZIP archive format):** Format ZIP final (.mirkfall extension, layout manifest/photos/) à confirmer au démarrage de la phase ; audit licence du package `archive` à documenter dans DEPENDENCIES.md (O11).

## Session Continuity

Last session: 2026-04-17T18:15:16Z
Stopped at: Completed 02-01-PLAN.md (scaffold + user-first §1 capture)
Resume file: .planning/phases/02-review-gate-foundation/02-02-PLAN.md
