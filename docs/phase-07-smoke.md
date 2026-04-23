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

- **Device:** Pixel 4a
- **OS version:** Android 13 (4.14.302)
- **MirkFall build:** fbcbde6a2569baad84b3104eceed51b437e38ed4
- **APK source:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24834805699/artifacts/6601556400
- **Date of walk (UTC):** 20260423 14h40
- **Walk duration:** 2 minutes

### Step-by-step results

| #   | Step                                                | Result | Notes |
| --- | --------------------------------------------------- | ------ | ----- |
| 1   | Install + first launch                              | _PASS_ |       |
| 2   | "Préparation de la carte…" then SessionListScreen   | _PASS_ |       |
| 3   | Create + start session                              | _PASS_ |       |
| 4   | MapScreen: map renders + AppBar affordances visible | _PASS_ |       |
| 5   | Burger menu: 3 tiles + 3 live-data rows             | _PASS_ |       |
| 6   | Airplane mode cold-start: map still renders         | _PASS_ |       |
| 7   | Aruba download completes                            | _PASS_ |       |
| 8   | Aruba in Manage screen with correct size + version  | _PASS_ |       |
| 9   | Delete Aruba → disappears + world row stays         | _PASS_ |       |

### Screenshots

- (a) MapScreen with world bundle + attribution + follow-me + burger menu open → `docs/phase-07-smoke-screenshots/android-01-map-screen.png`
- (b) Airplane-mode launch still renders map → `docs/phase-07-smoke-screenshots/android-02-airplane-mode.png`
- (c) Aruba download in progress → `docs/phase-07-smoke-screenshots/android-03-download-progress.png`
- (d) Aruba in Manage screen → `docs/phase-07-smoke-screenshots/android-04-manage-installed.png`
- (e) Post-delete Manage screen → `docs/phase-07-smoke-screenshots/android-05-post-delete.png`

### Verdict

**PASS**

## Entry 2 — iOS (via CI-produced unsigned IPA + sideload)

- **Device:** Iphone 17 pro
- **iOS version:** 26.3.1 (a)
- **MirkFall build:** fbcbde6a2569baad84b3104eceed51b437e38ed4
- **Sideload method:** Iloader (side store)
- **IPA source:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24834805699/artifacts/6601494748
- **Date of walk (UTC):** 20260423 15h00
- **Walk duration:** _2 minutes_

### Step-by-step results

| #   | Step                                                                                                                                                                                                                                    | Result | Notes |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ----- |
| 1   | Sideload + first launch                                                                                                                                                                                                                 | _PASS_ |       |
| 2   | "Préparation de la carte…" then SessionListScreen                                                                                                                                                                                       | _PASS_ |       |
| 3   | Create + start session                                                                                                                                                                                                                  | _PASS_ |       |
| 4   | MapScreen: map renders + AppBar affordances visible                                                                                                                                                                                     | _PASS_ |       |
| 5   | Burger menu: 3 tiles + 3 live-data rows                                                                                                                                                                                                 | _PASS_ |       |
| 6   | Airplane mode cold-start: map still renders                                                                                                                                                                                             | _PASS_ |       |
| 7   | Aruba download completes                                                                                                                                                                                                                | _PASS_ |       |
| 8   | Aruba in Manage screen with correct size + version                                                                                                                                                                                      | _PASS_ |       |
| 9   | Delete Aruba → disappears + world row stays                                                                                                                                                                                             | _PASS_ |       |
| 10  | Xcode container inspection: `Library/Application Support/mirkfall/maps/` tree exists AND `world.pmtiles` + installed country `.pmtiles` are marked `NSURLIsExcludedFromBackupKey=1` (inspect via `xattr -l` on the extracted container) | _N/A_  | No macOS available for this project — IPAs are CI-built on GitHub Actions and sideloaded via SideStore. The code-path is covered by `test/infrastructure/platform/ios_backup_excluder_test.dart` (platform-channel contract) and `test/phase_07_integration/map_end_to_end_test.dart` (commit-step wiring). Falling back to `PASS-with-caveat` per the rubric clause below. |

### Screenshots

- (a) MapScreen + attribution + burger menu → `docs/phase-07-smoke-screenshots/ios-01-map-screen.png`
- (b) Aruba download completion → `docs/phase-07-smoke-screenshots/ios-02-download-complete.png`
- (c) Xcode container inspection — _skipped, see step 10 note above_

### Verdict

**PASS-with-caveat** — every interactive step passed on the iPhone 17 Pro under iOS 26.3.1. The sole caveat is step 10 (Xcode container inspection of the `NSURLIsExcludedFromBackupKey` attribute) which this project cannot perform end-to-end: builds happen on GitHub Actions' `macos-latest` runners, the IPA is downloaded + sideloaded via SideStore, and there is no local macOS toolchain to mount the device's container and run `xattr -l`. The backup-exclude code-path is covered at the boundary by dedicated tests — operator will re-litigate at Phase 08 Review Gate if evidence of the on-device attribute is required.

---

## Overall Phase 07 close verdict

- **Android smoke:** approved
- **iOS smoke:** approved (PASS-with-caveat — step 10 not performable from the project's CI-only macOS setup; see Entry 2 Verdict for details)
- **Ready for Phase 08 Review Gate:** approved
