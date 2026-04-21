# Phase 07 — Map Integration device-smoke evidence log

Real-device verification for Phase 07 map integration. This file is
the single source of truth for the two human-device smoke checkpoints
required by Plan 07-07 Task 2:

- **Android smoke**: sideload-built APK on a Pixel 4a (or equivalent
  real Android device) — validates MapLibre native render + offline
  pan/zoom + airplane-mode reality + country download round-trip.
- **iOS smoke** (via CI-produced unsigned IPA + sideload through
  SideStore or equivalent): validates the same UX plus the iOS-specific
  backup-exclude attribute on per-country PMTiles files.

Each entry documents one real-device walk: device + build + step-by-step
pass/fail notes + screenshots. Screenshots live under
`docs/phase-07-smoke-screenshots/`.

## Protocol

Launch flow under test:

1. Install APK / sideload IPA onto the target device.
2. First launch — app should show a brief "Préparation de la carte…" ~1 s
   then SessionListScreen.
3. Create a session (FAB "+", accept rationale), start tracking (allow
   GPS).
4. Tap the AppBar map icon → MapScreen renders the bundled world PMTiles
   — verify: map visible, pan/zoom smooth, attribution icon bottom-right,
   follow-me FAB bottom-right above attribution, burger menu top-left.
5. Open burger menu — 3 unwired action tiles (snackbar on tap) + 3
   live-data rows (Position 6 decimals, Distance placeholder, Durée
   HH:MM:SS) populate.
6. **Enable airplane mode on the device (OS-level).** Relaunch app from
   cold. Verify the map STILL RENDERS from the bundled world.pmtiles,
   session UX still works (MAP-01 code-path already verified by
   `test/phase_07_integration/airplane_mode_test.dart`; this step
   validates the code-path holds under real native MapLibre rendering).
7. Disable airplane mode. Navigate Settings → Télécharger une carte.
   Tap "Aruba" (~4 MB single-part download). Confirm. Observe progress
   indicator + AppBar chip.
8. Navigate Settings → Gérer les cartes installées. Verify Aruba
   appears with correct size + version + delete button.
9. Tap delete → confirmation → Aruba disappears from the list + the
   world row remains non-deletable.
10. Archive screenshots + pass/fail notes in the appropriate section
    below.

## Acceptance rubric

- **PASS**: every step above completes without crash, the UI renders
  as described, and screenshots match the expected surfaces.
- **BLOCKER**: map does not render, download fails, or any step
  produces a crash / incorrect state. Feeds back into a fix-forward
  loop (Phase 05 / 06 review-gate precedent).
- **PASS-with-caveat** (iOS only, per Phase 05 precedent): if the
  Xcode container-inspection step cannot be performed (e.g. the
  signing cert expired before this walk, the device was reset, etc.),
  degrade to PASS-with-caveat. Phase 08 Review Gate re-litigates.

---

## Entry 1 — Android (Pixel 4a or equivalent)

- **Device:** _(fill in: e.g. Pixel 4a)_
- **OS version:** _(fill in: e.g. Android 14)_
- **MirkFall build:** _(fill in: commit hash from the CI run)_
- **APK source:** _(fill in: GitHub Actions artifact URL)_
- **Date of walk (UTC):** _(fill in)_
- **Walk duration:** _(fill in: total elapsed time)_

### Step-by-step results

| # | Step                                                | Result  | Notes                          |
| - | --------------------------------------------------- | ------- | ------------------------------ |
| 1 | Install + first launch                              | _PASS_  |                                |
| 2 | "Préparation de la carte…" then SessionListScreen   | _PASS_  |                                |
| 3 | Create + start session                              | _PASS_  |                                |
| 4 | MapScreen: map renders + AppBar affordances visible | _PASS_  |                                |
| 5 | Burger menu: 3 tiles + 3 live-data rows             | _PASS_  |                                |
| 6 | Airplane mode cold-start: map still renders         | _PASS_  |                                |
| 7 | Aruba download completes                            | _PASS_  |                                |
| 8 | Aruba in Manage screen with correct size + version  | _PASS_  |                                |
| 9 | Delete Aruba → disappears + world row stays         | _PASS_  |                                |

### Screenshots

- (a) MapScreen with world bundle + attribution + follow-me + burger menu open → `docs/phase-07-smoke-screenshots/android-01-map-screen.png`
- (b) Airplane-mode launch still renders map → `docs/phase-07-smoke-screenshots/android-02-airplane-mode.png`
- (c) Aruba download in progress → `docs/phase-07-smoke-screenshots/android-03-download-progress.png`
- (d) Aruba in Manage screen → `docs/phase-07-smoke-screenshots/android-04-manage-installed.png`
- (e) Post-delete Manage screen → `docs/phase-07-smoke-screenshots/android-05-post-delete.png`

### Verdict

**PENDING** — fill in `PASS` / `BLOCKER <description>` after the walk.

---

## Entry 2 — iOS (via CI-produced unsigned IPA + sideload)

- **Device:** _(fill in: e.g. iPhone 12 mini)_
- **iOS version:** _(fill in)_
- **Sideload method:** _(fill in: SideStore / AltStore / other)_
- **IPA source:** _(fill in: GitHub Actions artifact URL)_
- **Date of walk (UTC):** _(fill in)_
- **Walk duration:** _(fill in)_

### Step-by-step results

| # | Step                                                                           | Result | Notes                 |
| - | ------------------------------------------------------------------------------ | ------ | --------------------- |
| 1 | Sideload + first launch                                                        | _PASS_ |                       |
| 2 | "Préparation de la carte…" then SessionListScreen                              | _PASS_ |                       |
| 3 | Create + start session                                                         | _PASS_ |                       |
| 4 | MapScreen: map renders + AppBar affordances visible                            | _PASS_ |                       |
| 5 | Burger menu: 3 tiles + 3 live-data rows                                        | _PASS_ |                       |
| 6 | Airplane mode cold-start: map still renders                                    | _PASS_ |                       |
| 7 | Aruba download completes                                                       | _PASS_ |                       |
| 8 | Aruba in Manage screen with correct size + version                             | _PASS_ |                       |
| 9 | Delete Aruba → disappears + world row stays                                    | _PASS_ |                       |
| 10 | Xcode container inspection: `Library/Application Support/mirkfall/maps/` tree exists AND `world.pmtiles` + installed country `.pmtiles` are marked `NSURLIsExcludedFromBackupKey=1` (inspect via `xattr -l` on the extracted container) | _PASS_ |                       |

### Screenshots

- (a) MapScreen + attribution + burger menu → `docs/phase-07-smoke-screenshots/ios-01-map-screen.png`
- (b) Aruba download completion → `docs/phase-07-smoke-screenshots/ios-02-download-complete.png`
- (c) Xcode container inspection proving maps/ tree + backup-exclude → `docs/phase-07-smoke-screenshots/ios-03-xcode-container.png`

### Verdict

**PENDING** — fill in `PASS` / `PASS-with-caveat <description>` / `BLOCKER <description>` after the walk.

---

## Overall Phase 07 close verdict

- **Android smoke:** PENDING
- **iOS smoke:** PENDING
- **Ready for Phase 08 Review Gate:** PENDING

User signal required: type `approved` in response to the Plan 07-07
checkpoint message once both entries are filled in and both verdicts
are PASS (or iOS PASS-with-caveat and user accepts).
