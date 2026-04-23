---
phase: 07-map-integration
plan: 07
type: execute
wave: 7
depends_on: ["07-06"]
files_modified:
  - integration_test/airplane_mode_test.dart
  - integration_test/first_launch_world_copy_test.dart
  - integration_test/map_end_to_end_test.dart
  - test/presentation/phase_07_navigation_test.dart
  - docs/phase-07-smoke.md
autonomous: false
requirements:
  - MAP-01
  - MAP-02
  - MAP-03
  - MAP-05
  - MAP-07
  - MAP-08
  - MAP-09
  - MAP-10

must_haves:
  truths:
    - "Airplane-mode HTTP interceptor test (HttpOverrides.runZoned with fail-all client) pumps MapScreen + pan/zoom/country-switch and asserts zero HTTP requests reached the interceptor (MAP-01 unit-test subset of QUAL-05)"
    - "First-launch integration test: on a fresh tempdir appSupportDir with no world.pmtiles, app launch triggers FirstLaunchBootstrap, copies asset, verifies sha256, and MapScreen renders without throwing (MAP-07)"
    - "End-to-end navigation test walks: SessionListScreen → create session → start tracking → tap 'Ouvrir la carte' → MapScreen renders via FakeMapView → tap burger menu → drawer opens → lat/lon row present → return → tap attribution icon → bottom-sheet visible → close"
    - "End-to-end download test (MockHTTPServer) walks: SettingsScreen → Télécharger une carte → tap Aruba tile → confirm → DownloadState transitions Queued → InProgress → Completed → MapsManageScreen lists Aruba"
    - "Physical device smoke checkpoint (Pixel 4a or equivalent Android): install APK, verify map renders at z0-2 offline, pan/zoom smooth, burger menu works, attribution visible, download 1-part country completes + appears in manage screen"
    - "Physical device smoke checkpoint (iOS via CI-produced unsigned IPA sideloaded): verify map renders, burger menu + attribution + download flow work; iOS backup-exclude active (inspect via Xcode Device Files)"
  artifacts:
    - path: "integration_test/airplane_mode_test.dart"
      provides: "MAP-01 network-zero verification (subset of QUAL-05)"
    - path: "integration_test/first_launch_world_copy_test.dart"
      provides: "MAP-07 first-launch world-bundle copy verification"
    - path: "integration_test/map_end_to_end_test.dart"
      provides: "happy-path user journey + MockHTTPServer download"
    - path: "docs/phase-07-smoke.md"
      provides: "device-smoke evidence for Android + iOS with screenshots"
  key_links:
    - from: "integration_test/airplane_mode_test.dart"
      to: "lib/presentation/screens/map_screen.dart"
      via: "pump MapScreen under HttpOverrides fail-all + assert no interception"
      pattern: "HttpOverrides.runZoned"
    - from: "integration_test/map_end_to_end_test.dart"
      to: "lib/application/controllers/download_queue_controller.dart"
      via: "drives enqueue + state observation"
      pattern: "downloadQueueControllerProvider"
---

> **⚠ SCOPE REDUCED — 2026-04-23**
>
> Plan 07-07 was scope-reduced at Phase 08 CONTEXT time. What actually landed under this plan: the physical device smoke walks (Android Pixel 4a + iOS iPhone 17 Pro) and the iOS animateCamera crash fix (commits `81d30c7` + `ab497ab` + `40b49d5`, 2026-04-22). The four integration tests originally scoped here are delivered in **Phase 08 Plan 08-04 (adversarial wave)** as permanent regression guards with inertness guards.
>
> See `.planning/phases/07-map-integration/07-07-SUMMARY.md` for the full rationale + list of deferred tests + cross-reference.
>
> The body below is preserved verbatim for git-trace purposes. Do NOT execute it as-is; follow Phase 08 Plan 08-04 instead.

<objective>
Close Phase 07 with integration tests + human-device smoke checkpoints that prove the three critical invariants no unit test can fully cover: (1) zero network for tiles under airplane conditions, (2) first-launch world-bundle copy actually works on a cold system, (3) the full user journey (create session → open map → download a country → see it in manage) works end-to-end. The human smokes sign off MAP-01 (airplane mode) + MAP-07 (first-launch) on real hardware before Phase 08 Review Gate opens.

Purpose: Without this plan, Phase 07 is green on CI but unvalidated on actual devices. Phase 08 Review Gate will re-litigate if we skip here.
Output: 3 integration tests + 1 navigation test + 1 human-verify checkpoint producing device-smoke evidence archived in `docs/phase-07-smoke.md`.
</objective>


<sc_task_crosswalk>
Mapping ROADMAP.md Phase 07 Success Criteria (SC#1..SC#9) to the task IDs + test files that verify each criterion. Use this table during `/gsd:verify-work` to confirm every SC has at least one automated binding and one device-smoke step.

| SC | ROADMAP statement (abridged) | Plan-task verifiers | Automated tests | Device smoke (Task 2) |
|----|------------------------------|---------------------|-----------------|-----------------------|
| SC#1 | First-launch world copy + offline pan/zoom + zero net req for tiles | 07-01-01 (assets bundled), 07-03-01 (FirstLaunchWorldCopier + PmtilesSource local-only), 07-05-01 (firstLaunchBootstrapProvider), 07-07-01 (airplane_mode_test + first_launch_world_copy_test) | `integration_test/airplane_mode_test.dart`, `integration_test/first_launch_world_copy_test.dart`, `test/infrastructure/map/first_launch_world_copier_test.dart`, `dart run tool/check_avoid_remote_pmtiles.dart` | Task 2 Android step 2-6 + iOS step 1-3 (airplane-mode cold start renders) |
| SC#2 | Attribution on map AND on À propos with official copyright links | 07-06-01 (MapAttributionIcon bottom-sheet), 07-06-04 (AboutPlaceholderScreen attribution block) | `test/presentation/widgets/map_attribution_icon_test.dart`, `test/presentation/screens/about_placeholder_screen_test.dart` | Task 2 Android step 4 + iOS step 3 (visual check of attribution icon + À propos screen) |
| SC#3 | MapView interface is the only seam; `avoid_maplibre_leak` lint enforces | 07-01-02 (lint script + paired test), 07-02-01 (MapView abstract), 07-03-02 (MapLibreMapView adapter = sole consumer), 07-06 (all screens use FakeMapView override) | `dart run tool/check_avoid_maplibre_leak.dart`, `dart test tool/test/check_avoid_maplibre_leak_test.dart`, `test/presentation/screens/map_screen_test.dart` (FakeMapView proof) | n/a (structural invariant) |
| SC#4 | PmtilesSource local-only + `avoid_remote_pmtiles` lint + country resolver swap | 07-01-02 (second lint + paired test), 07-03-01 (PmtilesSource + CountryResolver + point_in_polygon), 07-05-02 (CountryResolverController hot-swap) | `dart run tool/check_avoid_remote_pmtiles.dart`, `dart test tool/test/check_avoid_remote_pmtiles_test.dart`, `test/infrastructure/map/pmtiles_source_test.dart`, `test/infrastructure/map/country_resolver_test.dart`, `test/application/controllers/country_resolver_controller_test.dart` | Task 2 Android step 6 (airplane-mode world fallback) |
| SC#5 | Mirk overlay stub present at frozen z-order; paints nothing | 07-01-01 (style.json with frozen 8 layers, mirk_fog = `background` transparent), 07-03-01 (NoopMirkRenderer + styleLayerOrder + assertStyleLayerValidity), 07-06-01 (layer-order regression test) | `test/presentation/map_style_layer_order_test.dart`, `test/infrastructure/map/style_layer_order_test.dart`, `test/infrastructure/mirk/noop_mirk_renderer_test.dart` | Task 2 Android step 4 (map renders without any black aplat) |
| SC#6 | Download screen lists catalog.json + per-country alpha3/name/size + version | 07-01-01 (catalog.json bundled asset), 07-02-01 (CountryCatalog Freezed + catalogVersion getter), 07-06-02 (MapsDownloadScreen + MapDownloadProgressChip) | `test/domain/map/country_catalog_test.dart`, `test/presentation/screens/maps_download_screen_test.dart`, `test/presentation/widgets/map_download_progress_chip_test.dart` | Task 2 Android step 7 + iOS step 3 (Aruba download completes) |
| SC#7 | Download pipeline: chunks → sha256 → concat → atomic commit → manifest | 07-04-01 (Sha256Verifier + BinaryConcatenator + AtomicRenamer + InstalledManifestRepository), 07-04-02 (HttpChunkDownloader + Range), 07-04-03 (PmtilesDownloadController + soak test) | `test/infrastructure/downloads/*_test.dart` (5 unit tests), `dart test --tags soak test/infrastructure/downloads/download_soak_test.dart` (7 scenarios), `integration_test/map_end_to_end_test.dart` | Task 2 Android step 7 + iOS step 3 |
| SC#8 | Manage screen: installed list + disk size + version + delete frees space; world read-only | 07-04-03 (CountryDeleteService rejects CountryCode.world via CannotDeleteWorldBundleException), 07-05-03 (InstalledMapsController), 07-06-02 (MapsManageScreen) | `test/infrastructure/installed_maps/country_delete_test.dart`, `test/application/controllers/installed_maps_controller_test.dart`, `test/presentation/screens/maps_manage_screen_test.dart` | Task 2 Android step 8-9 + iOS step 3 (delete flow + world row disabled) |
| SC#9 | DEPENDENCIES.md audit entries for maplibre_gl + crypto + bundled assets | 07-01-01 (pubspec swap + DEPENDENCIES.md rows + check_dependencies_md.dart green) | `dart run tool/check_dependencies_md.dart`, `dart run tool/check_licenses.dart` | n/a (documentation invariant) |

If any SC has an empty `Plan-task verifiers` column, the verification is incomplete and the phase cannot close. Current table: every SC bound to at least one task + one automated test.
</sc_task_crosswalk>

<execution_context>
@C:/Users/oliver/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/oliver/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-map-integration/07-CONTEXT.md
@.planning/phases/07-map-integration/07-RESEARCH.md
@.planning/phases/07-map-integration/07-06-SUMMARY.md
@CLAUDE.md
@integration_test/

<interfaces>
<!-- Integration test idioms from Phase 05. -->

Flutter integration_test convention:
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('name', (tester) async { … });
}
```

HttpOverrides for airplane-mode simulation:
```dart
await HttpOverrides.runZoned(() async {
  // pump widgets here; any HttpClient.getUrl throws SocketException
  await tester.pumpWidget(…);
}, createHttpClient: (_) => _FailAllHttpClient());
```

Phase 05 docs/qual-01-02-poc.md precedent for manual device smoke evidence capture.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: airplane_mode_test.dart + first_launch_world_copy_test.dart + map_end_to_end_test.dart + phase_07_navigation_test.dart</name>
  <files>
    integration_test/airplane_mode_test.dart,
    integration_test/first_launch_world_copy_test.dart,
    integration_test/map_end_to_end_test.dart,
    test/presentation/phase_07_navigation_test.dart
  </files>
  <behavior>
    - **`airplane_mode_test.dart`** (MAP-01 subset of QUAL-05):
      - Wraps the entire test body in `HttpOverrides.runZoned(createHttpClient: (_) => _FailAllHttpClient())`
      - `_FailAllHttpClient` throws `SocketException('airplane mode — network blocked')` on every `getUrl` / `get` / any HTTP method
      - pumpWidget full ProviderScope with FakeMapView override
      - Simulate pan: call FakeMapView.pushViewport 10 times with varying lat/lon/zoom
      - Simulate country switch: invoke countryResolverControllerProvider's `showMap(alpha3)` path — FakeMapView.showMapInvocations grows
      - Assert: `_FailAllHttpClient.invocationCount == 0` — NO HTTP request was attempted anywhere in the pipeline
      - Note: this tests the unit subset; the full QUAL-05 device-level smoke is Phase 15. Document this in the test docstring.
    - **`first_launch_world_copy_test.dart`** (MAP-07):
      - Override path_provider to a fresh `Directory.systemTemp` under the test
      - Ensure `<tempdir>/maps/world.pmtiles` doesn't exist pre-test
      - Pump `runApp` via `main.dart`-equivalent bootstrap (or invoke `firstLaunchBootstrapProvider` directly)
      - Assert: `<tempdir>/maps/world.pmtiles` exists post-pump, file size matches asset (856 KB), sha256 matches `kWorldBundleSha256`
      - Mutation test: corrupt the file post-pump, re-invoke bootstrap, assert auto-heal (re-copy) kicks in
    - **`map_end_to_end_test.dart`**:
      - Sets up a shelf MockHTTPServer serving a 4 MB Aruba fixture over 1 part with correct sha256
      - Overrides `httpChunkDownloaderProvider` to point to the server
      - Overrides `mapViewProvider` with FakeMapView
      - Pumps root app; navigates SessionListScreen → +FAB → create session → start tracking (fake fix stream) → AppBar map button → MapScreen
      - From MapScreen: tap burger menu → drawer opens → lat/lon row visible
      - Back → Settings → Télécharger une carte → tap Aruba tile → confirm dialog → wait for DownloadState transitions
      - After completion: navigate to Manage → Aruba row visible with correct size + version
      - Assertion coverage: ~10 expect calls across the flow
    - **`phase_07_navigation_test.dart`** (unit):
      - Pure navigation assertions without full bootstrap: `/map` is reachable from SessionListScreen; `/maps/download`, `/maps/manage`, `/styles/import`, `/styles/export` all resolve; back stack is correct after `context.push`
      - Use a GoRouter testing harness that records navigation events
  </behavior>
  <action>
    1. **airplane_mode_test.dart**: ~120 LoC. Requires careful `HttpOverrides.runZoned` nesting + FakeMapView overrides.

    2. **first_launch_world_copy_test.dart**: ~80 LoC. Tempdir strategy + path_provider override via TestDefaultBinaryMessengerBinding.

    3. **map_end_to_end_test.dart**: ~200 LoC including MockHTTPServer setup (shelf bind to 127.0.0.1 random port).

    4. **phase_07_navigation_test.dart**: ~60 LoC. Navigation event observer pattern.

    5. **Run the full suite locally**: `flutter test integration_test/` (on host; runs via `flutter test` platform `integration_test` — note that `integration_test` tests usually require a device, but integration_test with mocked platform channels can run under `flutter test` if they don't need platform-view primitives; for now, tag them so CI excludes and document that local host-run is best-effort).
       - **Caveat**: if maplibre_gl widgets don't construct under `flutter test` host mode (platform view issue), use FakeMapView exclusively — verified by Plan 07-02 FakeMapView covering the full `MapView` surface. The real MapLibre adapter coverage comes from the device smoke in Task 2.

    6. **Analyze + headers + lint gates** green.

    7. Commit.
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos integration_test/ test/presentation/phase_07_navigation_test.dart &&
      flutter test integration_test/airplane_mode_test.dart integration_test/first_launch_world_copy_test.dart integration_test/map_end_to_end_test.dart test/presentation/phase_07_navigation_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_avoid_remote_pmtiles.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    4 integration + navigation tests green on CI. Airplane-mode HTTP interceptor proves zero network for tiles. First-launch copy + auto-heal proven. End-to-end user journey green under FakeMapView + MockHTTPServer.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Physical device smoke — Android (Pixel 4a) + iOS (via CI IPA + sideload)</name>
  <files>
    docs/phase-07-smoke.md
  </files>
  <what-built>
    Full Phase 07 map integration shipped through Plans 07-01 → 07-06:
    - Offline map rendering via maplibre_gl 0.25.0 + local PMTiles (world bundle + per-country)
    - MapScreen full-screen route + SessionDetailScreen integration
    - Burger menu with 3 unwired actions + 3 live-data rows
    - Country download pipeline with atomic 7-step protocol (disk preflight → chunks → sha256 → concat → rename → manifest → cleanup)
    - Manage maps screen + attribution bottom-sheet + country banner + follow-me FAB

    Unit/widget/integration tests in Plans 07-01..07-07 cover every code path via fakes + MockHTTPServer. This checkpoint validates the 3 invariants a device alone can prove:
    1. Airplane-mode reality (no unexpected network round-trip sneaks in beyond the unit-test subset)
    2. MapLibre native SDK render actually draws the world bundle on real hardware at z0-2
    3. Download of a small real country (Aruba ~4 MB from GitHub Release) completes atomically over real HTTP
  </what-built>
  <action>
    This task is a blocking human-verify checkpoint. Claude does NOT execute a device smoke itself — it produces the CI-built APK + IPA, points the user at the build artefacts, and awaits user's in-hand verification.

    1. Trigger a fresh CI run on the final Plan 07-06 commit. Verify all 3 jobs (gates, android, ios) green. Record the run URL.
    2. Download the Android APK from the `android` job artefacts.
    3. Download the unsigned iOS IPA from the `ios` job artefacts.
    4. Emit a checkpoint message to the user containing:
       - Run URL + green badge
       - Artefact download links (GitHub Actions artefacts expire after 90 days by default — warn the user if approaching)
       - Full `how-to-verify` script (see below under &lt;how-to-verify&gt;)
       - Template `docs/phase-07-smoke.md` pre-created with headers for Android section + iOS section + blank screenshot placeholders
    5. Wait for user signal (`approved` or `blocker &lt;description&gt;`).
    6. On approval: commit `docs/phase-07-smoke.md` with the user's filled-in evidence + screenshots placed into the repo at `docs/phase-07-smoke-screenshots/`.
    7. On blocker: exit this plan; a fix-forward loop opens (similar to Phase 05/06 review-gate pattern).
  </action>
  <how-to-verify>
    **Android smoke (Pixel 4a or equivalent):**
    1. `flutter build apk --debug` → sideload onto device (or use the CI artefact APK)
    2. First launch: app should show "Préparation de la carte…" ~1 s then SessionListScreen
    3. Create a session, start tracking (allow GPS)
    4. Tap AppBar map icon → MapScreen renders the world bundle. Verify: map visible, pan/zoom smooth, attribution icon bas-droit, follow-me FAB bas-droit, burger menu top-left
    5. Open burger menu → 3 unwired actions (snackbar appears on tap) + 3 live-data rows (position, distance, chrono) populate
    6. Enable **airplane mode** on device (Settings → Network → Airplane mode ON). Relaunch app from cold. Verify: map STILL RENDERS from the bundled world.pmtiles + session UX still works
    7. Disable airplane mode. Navigate Settings → Télécharger une carte. Tap "Aruba" (should be ~4 MB). Confirm. Observe progress indicator complete.
    8. Navigate Settings → Gérer les cartes installées. Verify Aruba appears with correct size + version + delete button
    9. Tap delete → confirmation → Aruba disappears from list
    10. Archive screenshots in `docs/phase-07-smoke.md` Android section: (a) MapScreen with world bundle + attribution + follow-me + burger menu open, (b) Airplane-mode launch still renders map, (c) Aruba download in progress, (d) Aruba in manage screen, (e) Post-delete manage screen

    **iOS smoke (via CI-produced unsigned IPA + sideload through SideStore or equivalent):**
    1. CI should have produced `ios/build/...unsigned.ipa` on merge to main (or cherry-pick build before phase close)
    2. Sideload via SideStore. First launch: expect similar ~1 s bootstrap screen
    3. Same 10 steps as Android, plus:
    4. Via Xcode → Devices & Simulators → select device → select MirkFall → "Download Container..." → inspect the downloaded container's `Library/Application Support/mirkfall/maps/` — verify `world.pmtiles` present, verify NSURLIsExcludedFromBackupKey set (check via `xattr -l` on the extracted folder)
    5. Screenshots archived in `docs/phase-07-smoke.md` iOS section: (a) MapScreen + attribution + burger menu, (b) Aruba download completion, (c) Xcode container inspection proving maps/ tree + backup-exclude

    **Acceptance rubric:**
    - Android: every step passes = PASS
    - Android: map doesn't render or download fails = BLOCKER (bounce to fix)
    - iOS: every step passes = PASS
    - iOS: if Xcode container step can't be completed (e.g. no device), downgrade to "PASS-with-caveat" per Phase 05 precedent; Phase 08 Review Gate re-litigates

    **Artefact:**
    - `docs/phase-07-smoke.md` with Android section (6 screenshots + pass/fail notes) + iOS section (3 screenshots + pass/fail notes) + total walk time + device model + OS version. Use `docs/qual-01-02-poc.md` from Phase 05 as the template.
  </how-to-verify>
  <verify>
    <automated>test -f docs/phase-07-smoke.md</automated>
  </verify>
  <done>
    User has tested the APK + IPA on their device(s), provided smoke evidence (screenshots + pass/fail), and signalled `approved` (or `PASS-with-caveat` per Phase 05 iOS precedent). `docs/phase-07-smoke.md` committed with verdict.
  </done>
  <resume-signal>Type "approved" if both smokes PASS (or iOS is PASS-with-caveat and user accepts). Type "blocker &lt;description&gt;" if anything failed — plan is paused pending fix.</resume-signal>
</task>

</tasks>

<verification>
Full-suite Phase 07 pre-close gate:
```
dart run build_runner build --delete-conflicting-outputs &&
flutter analyze --fatal-infos --fatal-warnings &&
flutter test --exclude-tags=soak &&
dart test --tags soak test/infrastructure/downloads/download_soak_test.dart &&
flutter test integration_test/ &&
dart run tool/check_headers.dart &&
dart run tool/check_licenses.dart &&
dart run tool/check_dependencies_md.dart &&
dart run tool/check_platform_manifests.dart &&
dart run tool/check_domain_purity.dart &&
dart run tool/check_avoid_maplibre_leak.dart &&
dart run tool/check_avoid_remote_pmtiles.dart
```

All 7 gate scripts + full test suite + soak + integration MUST exit 0 before the phase closes. CI run on the final commit must be fully green across gates / android / ios.
</verification>

<success_criteria>
- 4 new test files (3 integration + 1 navigation) green on CI
- `docs/phase-07-smoke.md` archived with Android + iOS smokes + screenshots
- Both device smokes PASS (or iOS PASS-with-caveat with user sign-off)
- Full CI green on final Phase 07 commit
- Every Phase 07 requirement (MAP-01 through MAP-10) has at least one automated test AND at least one must_haves.truth bound to a plan
- Phase 08 Review Gate unblocked
</success_criteria>

<output>
After completion, create `.planning/phases/07-map-integration/07-07-SUMMARY.md` documenting:
- Integration test wall-clock runtime (CI budget for Phase 08)
- Device smoke results (both platforms): pass/fail per step, screenshots paths, any caveats
- Final CI run URL with all 3 jobs green
- Summary of any deferrals to Phase 08 Review Gate (e.g. "iOS auto-resume scenarios still deferred per Phase 05 precedent")
- Phase 07 close checklist:
  - [ ] 10 MAP-* requirements mapped to at least one plan
  - [ ] 7 CI gate scripts exit 0 on main
  - [ ] Both device smokes documented
  - [ ] DEPENDENCIES.md contains maplibre_gl + crypto + shelf + Protomaps bundled assets
  - [ ] `docs/phase-07-smoke.md` committed
  - [ ] ROADMAP.md Phase 07 marked `Complete` with completion date
  - [ ] STATE.md updated with Phase 07 closure
- Commit hashes for this plan's atomic commits
</output>
