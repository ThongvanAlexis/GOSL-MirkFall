---
phase: 07-map-integration
plan: 05
type: execute
wave: 4
depends_on: ["07-03", "07-04"]
files_modified:
  - lib/application/controllers/map_camera_controller.dart
  - lib/application/controllers/country_resolver_controller.dart
  - lib/application/controllers/download_queue_controller.dart
  - lib/application/controllers/installed_maps_controller.dart
  - lib/application/providers/map_providers.dart
  - test/application/controllers/map_camera_controller_test.dart
  - test/application/controllers/country_resolver_controller_test.dart
  - test/application/controllers/download_queue_controller_test.dart
  - test/application/controllers/installed_maps_controller_test.dart
  - test/application/providers/map_providers_test.dart
autonomous: true
requirements:
  - MAP-01
  - MAP-05
  - MAP-06
  - MAP-08
  - MAP-09
  - MAP-10

must_haves:
  truths:
    - "`MapCameraController` orchestrates follow-me + initial session-open zoom (Z=13) + manual-pan-disables-follow + GPS fix stream from Phase 05's `ActiveSessionController`"
    - "`CountryResolverController` debounces viewport updates (500 ms), calls `CountryResolver.resolve(…)`, triggers `MapView.showMap(alpha3)` on transition, and exposes a stream of non-installed alpha3s (powers the banner 'Télécharger ce pays')"
    - "`DownloadQueueController` wraps `PmtilesDownloadController` with UI-friendly surface (enqueue, pause, resume, cancel, progress stream); hides the infrastructure layer from screens"
    - "`InstalledMapsController` watches `InstalledManifestRepository.updates` + compares installed countries' `pmtiles_version` against current catalog tag; derives an `UpdatesAvailable` per-alpha3 map"
    - "All 4 controllers are Riverpod `@Riverpod(keepAlive: true)` — downloads + manifest watchers survive screen navigation"
    - "`map_providers.dart` hosts: `mapViewProvider`, `countryCatalogProvider`, `installedManifestProvider`, `styleJsonProvider`, `pmtilesSourceProvider`, `firstLaunchBootstrapProvider`, `diskSpaceCheckerProvider`, `iosBackupExcluderProvider`"
    - "MapCameraController disables follow-me on manual pan (detected via `MapView.viewportUpdates` stream ≠ controller-initiated moves)"
    - "InstalledMapsController surfaces `'update available'` badge data only for countries where `installedCountry.pmtilesVersion != catalog.catalogVersion`"
    - "FirstLaunchBootstrap runs once at app startup via a provider initialiser (wired from main.dart or via auto-init pattern); the iOS backup-exclude side-effect happens here"
  artifacts:
    - path: "lib/application/controllers/map_camera_controller.dart"
      provides: "Z=13 session-open zoom + follow-me + manual-pan detection"
      contains: "@Riverpod(keepAlive: true)"
    - path: "lib/application/controllers/country_resolver_controller.dart"
      provides: "viewport → alpha3 hot-swap orchestrator"
      contains: "class CountryResolverController"
    - path: "lib/application/controllers/download_queue_controller.dart"
      provides: "UI-layer wrapper over PmtilesDownloadController"
    - path: "lib/application/controllers/installed_maps_controller.dart"
      provides: "manifest watcher + update-available derivation"
    - path: "lib/application/providers/map_providers.dart"
      provides: "Riverpod DI graph for Phase 07 map stack"
      contains: "mapViewProvider"
  key_links:
    - from: "lib/application/controllers/map_camera_controller.dart"
      to: "lib/application/controllers/active_session_controller.dart"
      via: "subscribes to Phase 05 active session fix stream"
      pattern: "activeSessionControllerProvider"
    - from: "lib/application/controllers/country_resolver_controller.dart"
      to: "lib/infrastructure/map/country_resolver.dart"
      via: "controller holds a CountryResolver instance fed by polygon assets"
      pattern: "CountryResolver"
    - from: "lib/application/controllers/download_queue_controller.dart"
      to: "lib/infrastructure/downloads/pmtiles_download_controller.dart"
      via: "controller re-exports infrastructure's DownloadState stream + UI-friendly action methods"
      pattern: "pmtilesDownloadControllerProvider"
    - from: "lib/application/providers/map_providers.dart"
      to: "lib/infrastructure/installed_maps/first_launch_bootstrap.dart"
      via: "firstLaunchBootstrapProvider triggers FirstLaunchBootstrap.run() on initialisation"
      pattern: "FirstLaunchBootstrap"
---

<objective>
Wire the domain + infrastructure from Plans 07-02/03/04 into Riverpod controllers and providers the presentation layer (Plan 07-06) will consume. Enforces the architectural invariant that screens NEVER import `lib/infrastructure/` directly — they consume controllers + providers only. Closes the follow-me + manual-pan + session-open-Z=13 UX stitch.

Purpose: The presentation layer deserves a clean API surface. Without controllers, `MapScreen` would pull in 15+ infrastructure imports. Consolidating orchestration here prevents the "screen swamp" anti-pattern.
Output: 4 controllers + 1 providers file, all test-green, ready for Plan 07-06 to consume via `ref.watch`.
</objective>

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
@.planning/phases/07-map-integration/07-02-SUMMARY.md
@.planning/phases/07-map-integration/07-03-SUMMARY.md
@.planning/phases/07-map-integration/07-04-SUMMARY.md
@CLAUDE.md
@lib/application/controllers/active_session_controller.dart
@lib/application/controllers/

<interfaces>
<!-- Phase 05 pattern: active_session_controller is a Riverpod @Riverpod(keepAlive: true) class. -->

From Phase 05:
```dart
@Riverpod(keepAlive: true)
class ActiveSessionController extends _$ActiveSessionController {
  @override
  ActiveSessionState build() => const Idle();
  Future<void> start(SessionId id) async { … }
  Future<void> stop() async { … }
  // state emits Tracking with active session + latest fix
  // Stream<Fix> latestFixes — exposed on Tracking state
}
```

Phase 05 consumer pattern:
```dart
final Stream<Fix> fixes = ref.watch(activeSessionControllerProvider
  .select((state) => state is Tracking ? state.latestFix : null));
```

Phase 05 widget test convention:
```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      activeSessionControllerProvider.overrideWith(() => FakeActiveSessionController()),
    ],
    child: MaterialApp(home: …),
  ),
);
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: map_providers.dart DI graph + FirstLaunchBootstrap wiring</name>
  <files>
    lib/application/providers/map_providers.dart,
    test/application/providers/map_providers_test.dart
  </files>
  <behavior>
    - Every Riverpod provider `@Riverpod(keepAlive: true)` unless noted.
    - **Providers**:
      - `countryCatalogProvider`: FutureProvider that calls `CountryCatalog.fromJson(jsonDecode(await rootBundle.loadString(kMapCatalogAssetPath)))`. Returns parsed CountryCatalog. Read once at startup + cached.
      - `installedManifestRepositoryProvider`: returns `FilesystemInstalledManifestRepository(appSupportDir: await getApplicationSupportDirectory().then((d) => d.path))`. keepAlive.
      - `installedManifestProvider`: StreamProvider that subscribes to `installedManifestRepositoryProvider.updates` + seeds with `read()`.
      - `pmtilesSourceProvider`: returns `PmtilesSource(installedManifestPort: ..., appSupportDir: ...)`.
      - `styleRewriterProvider`: returns `StyleRewriter(ref.watch(pmtilesSourceProvider))`.
      - `diskSpaceCheckerProvider`: returns `DiskSpaceChecker()` (platform-channel singleton).
      - `iosBackupExcluderProvider`: returns `IosBackupExcluder()`.
      - `firstLaunchWorldCopierProvider`: returns `FirstLaunchWorldCopier(appSupportDir: ..., expectedSha256: kWorldBundleSha256)`.
      - `firstLaunchBootstrapProvider`: FutureProvider that constructs `FirstLaunchBootstrap(worldCopier: ..., appSupportDir: ...)` + calls `.run()` once; emits `void` on completion. Consumed by main.dart (or top-level app shell) via `ref.watch(firstLaunchBootstrapProvider)` — app shows a simple "Préparation de la carte…" screen while the future pends (~1 s).
      - `mapViewProvider`: StateProvider<MapView?> — starts as null; the `MapLibreMapViewWidget` in Plan 07-06 `onReady` callback sets this. Readers like MapCameraController and CountryResolverController watch it + no-op while null.
      - `httpChunkDownloaderProvider`: returns `HttpChunkDownloader()`.
      - `sha256VerifierProvider`: returns `Sha256Verifier()`.
      - `binaryConcatenatorProvider`: returns `BinaryConcatenator()`.
      - `atomicRenamerProvider`: returns `AtomicRenamer()`.
      - `downloadQueueStoreProvider`: returns `DownloadQueueStore(appSupportDir: ...)`.
      - (Plan 07-04's `pmtilesDownloadControllerProvider` already codegen'd — re-reference it here without redefining.)
    - Tests: for each provider construct a ProviderContainer, read it once, assert expected type. The FirstLaunchBootstrap provider gets a scenario where the world bundle is missing in the fake appSupportDir → Bootstrap throws → provider AsyncError state.
  </behavior>
  <action>
    1. Create `lib/application/providers/map_providers.dart` with `@Riverpod` annotations; run `build_runner`.

    2. Every provider has a docstring. `firstLaunchBootstrapProvider` carries a TODO note pointing to Plan 07-06's main.dart wiring task.

    3. Tests: provider container smoke + happy-path FirstLaunchBootstrap + failure-path FirstLaunchBootstrap.

    4. `flutter analyze` + `dart run tool/check_avoid_maplibre_leak.dart` green — this file imports infrastructure but not maplibre_gl.

    5. Commit.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/application/providers/ test/application/providers/ &&
      flutter test test/application/providers/map_providers_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart
    </automated>
  </verify>
  <done>
    map_providers.dart wires the full DI graph; codegen'd; tests green; no maplibre_gl leak.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: MapCameraController + CountryResolverController (the two "orchestration" controllers)</name>
  <files>
    lib/application/controllers/map_camera_controller.dart,
    lib/application/controllers/country_resolver_controller.dart,
    test/application/controllers/map_camera_controller_test.dart,
    test/application/controllers/country_resolver_controller_test.dart
  </files>
  <behavior>
    - **`MapCameraController`**:
      - State: sealed `MapCameraState { Idle | FollowingUser | FreePan | Centering }`
      - `Future<void> openForSession(SessionId sessionId)`:
        - Read last fix from `activeSessionControllerProvider` (select latestFix)
        - Await `ref.read(mapViewProvider).moveCameraTo(latitude: fix.latitude, longitude: fix.longitude, zoom: kInitialSessionMapZoom)`
        - Enable follow-me: `await mapView.setFollowMeEnabled(true)`, state → FollowingUser
        - If no fix yet → state → Centering with "En attente GPS..." + subscribe to fix stream + when fix arrives, re-attempt
      - `Future<void> toggleFollowMe()`: state flip FollowingUser ↔ FreePan + `mapView.setFollowMeEnabled(bool)`
      - Internal listener: subscribes to `mapView.viewportUpdates` + `activeSessionController fix stream`. When a viewport update arrives that wasn't triggered by the controller's own `moveCameraTo` call (detected via a pending-flag + debounce window), transitions FollowingUser → FreePan (disables follow-me).
      - When in FollowingUser + new fix arrives → calls `moveCameraTo(fix.lat, fix.lon, <current zoom>)` keeping zoom untouched.
    - **`CountryResolverController`**:
      - State: `CountryResolverState { CountryCode? activeCountry, CountryCode? viewportCountry, bool inInstalled }`
      - Internal: holds a `CountryResolver` populated at build() from `ref.read(installedManifestProvider)` + polygon assets (loaded via `CountryPolygonLoader` in Plan 07-03).
      - Subscribes to `mapView.viewportUpdates` (debounced 500 ms): on each tick, call `resolver.resolve(…)`:
        - If result == `activeCountry` → no-op
        - If result != `activeCountry` AND result is installed → set activeCountry + call `mapView.showMap(result)` (triggers source swap per Plan 07-03 adapter)
        - If result != `activeCountry` AND result NOT installed → emit `viewportCountry = result, inInstalled = false` (screen uses this to show the "Télécharger ce pays" banner)
        - If result == null (water / zoom<3) → set activeCountry = null → `mapView.showMap(null)` → world bundle
      - Rebuild trigger: if `installedManifestProvider` changes (country added/removed), re-derive the resolver's installedPolygons set.
    - **Tests**:
      - MapCameraController:
        - openForSession with fix available → moveCameraTo called with Z=13
        - openForSession without fix → state = Centering; inject a fix → moveCameraTo called
        - Manual viewport update (mimics user pan) → state transitions FollowingUser → FreePan
        - toggleFollowMe → state flips
      - CountryResolverController:
        - Viewport in FRA (installed) → activeCountry set to FRA + mapView.showMap(FRA) called
        - Viewport in DEU (not installed) → inInstalled=false, banner data emitted
        - Zoom < 3 → activeCountry null → showMap(null)
        - Mock resolver fed polygon fixtures
  </behavior>
  <action>
    1. **`map_camera_controller.dart`**: Riverpod codegen class. Subscribe to 2 upstreams (viewportUpdates + active fix stream) via `ref.listen`.

    2. **`country_resolver_controller.dart`**: Riverpod codegen class. Debounce via hand-rolled StreamTransformer.

    3. **Tests** via FakeMapView (Plan 07-02) + fake active session controller + fake resolver/polygon loader.

    4. Build runner + analyze + headers.

    5. Commit.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/application/controllers/map_camera_controller.dart lib/application/controllers/country_resolver_controller.dart test/application/controllers/map_camera_controller_test.dart test/application/controllers/country_resolver_controller_test.dart &&
      flutter test test/application/controllers/map_camera_controller_test.dart test/application/controllers/country_resolver_controller_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart
    </automated>
  </verify>
  <done>
    Two controllers orchestrate camera + source swap. FollowingUser ↔ FreePan transitions tested. Z=13 session-open honoured. Banner-for-non-installed data surfaced.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: DownloadQueueController + InstalledMapsController + main.dart FirstLaunchBootstrap wiring</name>
  <files>
    lib/application/controllers/download_queue_controller.dart,
    lib/application/controllers/installed_maps_controller.dart,
    test/application/controllers/download_queue_controller_test.dart,
    test/application/controllers/installed_maps_controller_test.dart,
    lib/main.dart
  </files>
  <behavior>
    - **`DownloadQueueController`** — thin UI-friendly wrapper over `pmtilesDownloadControllerProvider`:
      - Exposes: `Stream<DownloadState> get states`, `Future<void> enqueue(CountryEntry entry)`, `pause()`, `resume()`, `cancelActive()`
      - Adds: `double? get aggregateProgressFraction` — computes active job's fraction or null if idle. Used by the AppBar progress-chip widget (Plan 07-06).
    - **`InstalledMapsController`**:
      - Watches `installedManifestProvider` + `countryCatalogProvider`
      - Derives: `Map<CountryCode, InstalledCountry> installed`, `Set<CountryCode> updatesAvailable` (where `installedCountry.pmtilesVersion != catalog.catalogVersion`), `int totalDiskUsageBytes`
      - Methods: `Future<void> deleteCountry(CountryCode alpha3)` — delegates to CountryDeleteService (Plan 07-04), then refreshes manifest.
    - **`main.dart` wiring** (minor extension of Phase 01 bootstrap):
      - After `FileLogger.bootstrap()` and before `runApp(ProviderScope(child: ...))`, we need NO structural change if `firstLaunchBootstrapProvider` auto-initialises. But we DO add a one-line `ref.read(firstLaunchBootstrapProvider.future)` awaited before runApp to ensure:
        - World bundle is copied (MAP-07)
        - Orphan staging is logged (Plan 07-04 spec)
        - iOS backup-exclude invoked (Plan 07-03 + Open Q #3)
      - Use a narrow `ProviderContainer` + `dispose` + pass the overrides through to runApp's `ProviderScope(parent: container)` — this is a known Riverpod pattern for pre-app-init work. OR keep main.dart unchanged and let `firstLaunchBootstrapProvider` auto-init on first UI frame, accepting a ~1 s black flash.
      - **Decision**: take the pre-init path — parity with Phase 05 which pre-initialises `buildAppDatabase` synchronously in main.dart. Keeps first-frame UX clean.
      - Main.dart changes ≤ 15 LoC.
    - **Tests**:
      - DownloadQueueController: enqueue → delegate to infra + state propagation. Aggregate fraction math covering 2-job queue (aggregate = active job's fraction, NOT sum).
      - InstalledMapsController: 3 installed countries, 1 with stale pmtiles_version → updatesAvailable set = 1, totalDiskUsageBytes sum correct. Delete flow calls CountryDeleteService + refreshes.
      - main.dart: indirectly tested via existing `test/smoke_test.dart` — extend it to assert `firstLaunchBootstrapProvider` completes before the first frame. If this is too flaky, rely on Plan 07-06's integration_test for end-to-end verification.
  </behavior>
  <action>
    1. **`download_queue_controller.dart`**: ~80 LoC delegating to pmtilesDownloadControllerProvider + computing aggregateProgressFraction.

    2. **`installed_maps_controller.dart`**: ~100 LoC. Uses ref.watch for reactive updates.

    3. **`main.dart`** extension: ~15 LoC. Construct a temporary `ProviderContainer`, read `firstLaunchBootstrapProvider.future`, await it, then pass the same container to `ProviderScope(parent: container)` on runApp.

    4. **Tests** per behavior.

    5. **Build runner + analyze + lints + headers**.

    6. **Verify existing smoke_test.dart still green** (main.dart change must not break Phase 01 smoke).

    7. Commit.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/application/controllers/ lib/main.dart test/application/controllers/ test/smoke_test.dart &&
      flutter test test/application/controllers/ test/smoke_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    4 controllers complete. main.dart pre-initialises FirstLaunchBootstrap before runApp. Existing Phase 01 smoke test still green. Aggregate download progress + updates-available derivation both tested.
  </done>
</task>

</tasks>

<verification>
```
dart run build_runner build --delete-conflicting-outputs &&
flutter analyze --fatal-infos --fatal-warnings &&
flutter test test/application/ test/smoke_test.dart &&
dart run tool/check_avoid_maplibre_leak.dart &&
dart run tool/check_avoid_remote_pmtiles.dart &&
dart run tool/check_domain_purity.dart &&
dart run tool/check_headers.dart
```
</verification>

<success_criteria>
- 4 controllers + 1 providers file compiled and tested
- `main.dart` awaits `firstLaunchBootstrapProvider` pre-runApp — world bundle installed + orphans logged + iOS backup-exclude invoked
- Z=13 session-open zoom + follow-me + manual-pan-disables-follow fully orchestrated
- Country resolver hot-swap on viewport change + banner data for non-installed countries
- Aggregate download progress computable by UI
- Updates-available derivation correct (installed.pmtiles_version ≠ catalog.catalogVersion)
</success_criteria>

<output>
After completion, create `.planning/phases/07-map-integration/07-05-SUMMARY.md`:
- Pre-init main.dart strategy decision (ProviderContainer pre-read vs FutureProvider auto-init)
- Manual-pan detection heuristic details (pending-flag + debounce window sizing)
- List of new provider names surfaced for Plan 07-06 consumption
- Any Phase 05 active_session_controller contract drift encountered
- Commit hashes
</output>
