---
phase: 07-map-integration
plan: 04
subsystem: infra

tags: [downloads, crypto, shelf, sha256, atomic-rename, range-resume, installed-manifest, riverpod, pmtiles, mock-http-server]

# Dependency graph
requires:
  - phase: 07-map-integration
    provides: 07-01 crypto + shelf direct deps + 14 constants (kHttpTimeout / kDiskSpaceSafetyMarginMultiplier / kDownloadRetryAttempts / kDownloadRetryBaseDelayMs / kCountriesDir / kStagingDir / kInstalledManifestPath) + chunks fixture README; 07-02 DownloadState/Progress/Job schemas + InstalledManifestRepository port + 4 download exceptions + 7 map exceptions (incl. CannotDeleteWorldBundleException) + CountryCode.world sentinel + Freezed catalog hierarchy; 07-03 DiskSpaceChecker + IosBackupExcluder platform channels + FirstLaunchWorldCopier streaming-write pattern + FirstLaunchBootstrap skeleton
  - phase: 03-persistence-domain-models
    provides: DbBackupService tempfile+rename atomic-backup precedent for JSON atomic writes
provides:
  - lib/infrastructure/downloads/ — Sha256Verifier (streaming crypto) + BinaryConcatenator (IOSink concat) + AtomicRenamer (File.rename + cross-volume copy fallback) + HttpChunkDownloader (dart:io HttpClient + Range resume + 200-OK restart fallback + 302 redirect) + DownloadQueueStore (atomic JSON queue) + PmtilesDownloadController (7-step atomic protocol orchestrator with retry + progress emission)
  - lib/infrastructure/installed_maps/ — JsonFileInstalledManifestRepository (atomic tempfile+rename write, single-writer mutex, broadcast updates) + FirstLaunchBootstrap (world-copy delegation + orphan staging scan + iOS backup-exclude + pmtiles-heal path for mid-rename kill recovery) + CountryDeleteService (file-first-then-manifest delete with sentinel-compare world-bundle guard)
  - test/fakes/fake_http_client.dart — shelf-backed FakeHttpServer exposing ServeHappy / ServeIgnoringRange / Serve403 / Serve500 / ServeDropConnectionAfterBytes / ServeRedirect with recordedRequests[] (replaces the plan's HttpOverrides-based stub)
  - dart_test.yaml soak tag (10× timeout) — Phase 03 convention, excluded from default `flutter test`
  - 59 new unit + soak tests total (40 Task 1 + 12 Task 2 + 7 Task 3 controller / 6 soak) — zero regressions, full suite 587/587 green

affects:
  - 07-05-controllers-and-providers (wraps PmtilesDownloadController + JsonFileInstalledManifestRepository + CountryDeleteService + DownloadQueueStore + FirstLaunchBootstrap behind `@Riverpod(keepAlive: true)` providers; subscribes to stateStream for UI; exposes enqueue/pause/resume/cancel surface)
  - 07-06-presentation (renders DownloadState variants + InstalledManifest updates; retry/pause/cancel buttons dispatch through the Plan 07-05 providers)
  - 07-07-integration-verification (real-device soak: iOS backup-exclude cross-check via Organizer, Android disk-space cross-check vs Settings → Storage, a multi-hour download-pause-reboot-resume integration test)
  - 09-mirk-rendering (inherits InstalledManifestRepository broadcast stream to refresh fog rendering when a new country lands)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "7-step atomic download protocol: preflight → download N chunks (Range resume + retry) → per-chunk sha256 → streaming concat → global sha256 → atomic rename → manifest write → staging cleanup. Every step testable in isolation; soak suite exercises the end-to-end path via shelf MockHTTPServer."
    - "shelf-backed FakeHttpServer (vs HttpOverrides.runZoned-mocked HttpClient): real sockets exercise Content-Length / Content-Range / Accept-Ranges on the wire; sealed FakeServerBehaviour strategy (ServeHappy / ServeIgnoringRange / Serve403 / Serve500 / ServeDropConnectionAfterBytes / ServeRedirect) mutable between requests for retry-path tests. Closes RESEARCH Pitfall #8 (graceful restart fallback) + #7 (CDN redirect)."
    - "HttpOverrides.runWithHttpOverrides(_RealHttpOverrides()) test pattern: TestWidgetsFlutterBinding installs a 400-returning HttpOverrides that breaks every real socket call. A bare `class X extends HttpOverrides {}` inherits the platform's real `createHttpClient` and restores real HTTP — necessary for any test that spins up a shelf server + injects a real HttpClient (`HttpClient()` naïvely inside `runZoned(createHttpClient: ...)` infinitely recurses because `new HttpClient` IS the override hook)."
    - "Single-writer mutex for atomic JSON writes: both JsonFileInstalledManifestRepository AND DownloadQueueStore chain writes onto a Future<void> tail so concurrent calls serialize (no interleaved .tmp → canonical renames racing each other). Tested via two unawaited repo.write calls + broadcast-stream order assertions."
    - "Mid-rename kill recovery via pmtiles-heal in FirstLaunchBootstrap: when a `.pmtiles` file exists under countries/ but is missing from installed.json (crash between atomic rename step 5 and manifest write step 6), recompute the on-disk sha256, cross-check against the catalog's reassembled.sha256 (when a catalog is provided), and re-insert the manifest entry. Less destructive than deleting the orphan .pmtiles — matches the 'idempotency over destruction' spirit of the atomic protocol. Decision documented in this SUMMARY."
    - "Streaming sha256 via `sha256.bind(file.openRead()).first` (NOT `package:convert` AccumulatorSink): Phase 07-01 SUMMARY explicitly decided to keep `convert` out of direct deps; `sha256.bind` is functionally equivalent + ships with `package:crypto` alone. Constant-memory up to 1.5 GB reassembled files."
    - "File-first then manifest ordering for CountryDeleteService: delete the .pmtiles first, then remove the manifest entry. A crash mid-sequence leaves an orphan manifest entry that the heal path catches (or, symmetrically, no file + no entry — the clean-uninstalled state). The inverse ordering would leave orphan .pmtiles with no manifest reference."
    - "Sentinel compare for world-bundle guard: CountryDeleteService checks `alpha3 == CountryCode.world`, which works for both the static sentinel AND `CountryCode.parse('wld')` (they are equal by design per the reservation contract). Tested both paths explicitly."

key-files:
  created:
    - "lib/infrastructure/downloads/README.md"
    - "lib/infrastructure/downloads/sha256_verifier.dart — streaming crypto.sha256.bind wrapper"
    - "lib/infrastructure/downloads/binary_concatenator.dart — IOSink concat with cleanup-on-failure"
    - "lib/infrastructure/downloads/atomic_renamer.dart — File.rename with EXDEV cross-volume copy+delete fallback"
    - "lib/infrastructure/downloads/http_chunk_downloader.dart — dart:io HttpClient + Range resume + 200-OK restart + 302 redirect"
    - "lib/infrastructure/downloads/download_queue_store.dart — atomic JSON queue with tempfile+rename"
    - "lib/infrastructure/downloads/pmtiles_download_controller.dart — 7-step protocol orchestrator"
    - "lib/infrastructure/installed_maps/README.md"
    - "lib/infrastructure/installed_maps/installed_manifest_repository.dart — tempfile+rename, single-writer mutex, broadcast updates"
    - "lib/infrastructure/installed_maps/first_launch_bootstrap.dart — world-copy + orphan-staging scan + pmtiles-heal + iOS backup-exclude"
    - "lib/infrastructure/installed_maps/country_delete_service.dart — sentinel-guarded delete"
    - "test/fakes/fake_http_client.dart — shelf-backed FakeHttpServer"
    - "test/infrastructure/downloads/sha256_verifier_test.dart (5 tests)"
    - "test/infrastructure/downloads/binary_concatenator_test.dart (6 tests)"
    - "test/infrastructure/downloads/atomic_renamer_test.dart (4 tests)"
    - "test/infrastructure/downloads/download_queue_store_test.dart (7 tests)"
    - "test/infrastructure/downloads/http_chunk_downloader_test.dart (9 tests)"
    - "test/infrastructure/downloads/download_preflight_test.dart (3 tests)"
    - "test/infrastructure/downloads/pmtiles_download_controller_test.dart (3 tests)"
    - "test/infrastructure/downloads/download_soak_test.dart (6 tests, @Tags(['soak']))"
    - "test/infrastructure/installed_maps/installed_manifest_repository_test.dart (11 tests)"
    - "test/infrastructure/installed_maps/first_launch_bootstrap_test.dart (6 tests)"
    - "test/infrastructure/installed_maps/country_delete_test.dart (4 tests)"
  modified:
    - "dart_test.yaml — soak tag with 10× timeout"

key-decisions:
  - "Mid-rename kill recovery = HEAL (not destroy): FirstLaunchBootstrap re-computes on-disk sha256 for orphan .pmtiles files under countries/, cross-checks against the catalog when available, and re-inserts the manifest entry. The alternative (delete the orphan .pmtiles + force re-download) was rejected — it destroys work that is otherwise valid + bit-for-bit identical to the original download. The heal path has one failure mode (on-disk file silently corrupted but sha256-matching the catalog, which requires a sha256 collision) that is strictly less likely than the bit-rot the heal already catches. Plan 07-05's UI can surface healed entries so the user has visibility."
  - "shelf MockHTTPServer over HttpOverrides.runZoned-stubbed HttpClient: the plan suggested hand-rolling a FakeHttpClient via HttpOverrides; in practice dart:io HttpClient is abstract + leans on private implementations (`_HttpClient`, `_HttpClientRequest`, `_HttpClientResponse`), and a meaningful hand-rolled fake would stub 20+ methods each. A real shelf server on a random free port (shelf is already a direct dev_dep from Plan 07-01) exercises the exact same code path a production GitHub CDN hits — headers flow through the OS socket, Content-Length/Content-Range/Accept-Ranges are emitted by shelf_io. Bugs that only manifest at the wire level get caught here; the recordedRequests[] API gives tests enough assertion surface for retry + resume semantics."
  - "PmtilesDownloadController as a plain class (not an @Riverpod notifier): deliberately kept non-Riverpod so unit tests drive it without a ProviderContainer / ProviderScope. Plan 07-05 will wrap an instance behind an `@Riverpod(keepAlive: true)` provider. The same decoupling pattern Plan 05 used for LocationStream vs ActiveSessionController."
  - "Streaming sha256 via sha256.bind (no package:convert): Phase 07-01 SUMMARY decided against pulling `package:convert` as a direct dep; `sha256.bind(file.openRead()).first` is functionally equivalent + requires only `package:crypto` (already direct). DigestSink is not exported by crypto, so we cannot use it either — `bind` is the cleanest public API."
  - "HttpOverrides.runWithHttpOverrides + bare `class _RealHttpOverrides extends HttpOverrides {}` to restore real HTTP in tests: TestWidgetsFlutterBinding installs a mock HttpOverrides that returns 400 for every call; `runZoned(createHttpClient: (c) => HttpClient(context: c))` infinitely recurses because `new HttpClient` is itself the override hook. The bare-subclass approach inherits the platform's real `createHttpClient` via super.createHttpClient, no recursion."
  - "Fallback pmtilesVersion when catalog URL has no release tag: fixture catalogs (mini_catalog.json) point at `https://example.test/...` which has no `/releases/download/<tag>/` segment. The extractor returns `untagged-YYYYMMDD` for that case, satisfying the `InstalledCountry.pmtilesVersion.length > 0` @Assert invariant. Production catalogs always have the tag; the fallback only fires in tests or in a misconfigured fixture."
  - "Single-writer mutex in JsonFileInstalledManifestRepository via a Future<void> tail: Plan 07-04 serializes manifest writes behind the download controller, but the port also accepts concurrent settings-screen delete calls. Chaining ensures deterministic broadcast-stream ordering + no interleaved .tmp → canonical rename races. Tested via two unawaited write calls + stream-event order assertions."
  - "Corrupted JSON → empty list (not a throw) for DownloadQueueStore.load(): the alternative would leave the user's queue unrecoverable after a rare crash. Worst case is a queue reset — recoverable by re-adding countries. JsonFileInstalledManifestRepository has the opposite policy (throws SchemaValidationException) because the bootstrap's heal path recovers from the on-disk .pmtiles tree, so it needs a loud signal that the JSON was corrupted."
  - "Retry budget = kDownloadRetryAttempts × exponential backoff (1s/5s/30s): post-exhaustion the job flips to DownloadError and the controller moves on to the next job in the queue. Plan 07-05's UI surfaces the retry button; auto-retry without explicit user action would burn battery + network on a persistently-unavailable mirror."

patterns-established:
  - "Wire-level test fakes via shelf MockHTTPServer (pattern established in Plan 07-04, reused by Plan 07-07 integration tests): the FakeHttpServer in test/fakes/fake_http_client.dart is the canonical example — mutable sealed-behaviour strategy + recordedRequests[] list + setup/teardown symmetry + random-free-port bind. Future phases that need HTTP test doubles should follow the same shape rather than hand-rolling HttpClient fakes."
  - "7-step atomic download protocol documented in lib/infrastructure/downloads/README.md + encoded in PmtilesDownloadController. Future additions (e.g. resumable uploads, multi-threaded chunk fetch) add steps before/after the existing 7 but must preserve the atomic-rename + manifest-write invariant at the tail."
  - "HttpOverrides.runWithHttpOverrides(_BareSubclass()) idiom for restoring real HTTP in TestWidgetsFlutterBinding tests — documented inline + applied in pmtiles_download_controller_test.dart + download_soak_test.dart. Any future phase that needs real HTTP in a flutter_test runner should use this pattern."
  - "pmtiles-heal path in FirstLaunchBootstrap — the canonical recovery story for any future protocol step that mutates disk state before updating the manifest. The heal scans the tree for orphan files + reinserts manifest entries from recomputed sha256s + catalog cross-checks. When Plan 07-04 eventually adds resumable uploads (future), the heal path extends naturally to the upload staging tree."
  - "Non-Riverpod controller pattern for testable orchestrators: PmtilesDownloadController ships as a plain Dart class exposing a broadcast stream + enqueue/pause/resume/cancel surface; Plan 07-05 wraps it behind an @Riverpod(keepAlive: true) provider. Matches the Plan 05 LocationStream vs ActiveSessionController separation. Benefits: unit tests drive the controller without ProviderContainer setup, the provider-layer tests focus on lifecycle/DI correctness."

requirements-completed: [MAP-08, MAP-09, MAP-10]

# Metrics
duration: 31min
completed: 2026-04-21
---

# Phase 07 Plan 04: Download Pipeline Summary

**7-step atomic download protocol landed end-to-end — preflight → chunked HTTP with Range resume + 200-OK restart fallback → per-chunk sha256 (retry) → streaming concat → global sha256 → atomic rename → manifest commit → staging cleanup — backed by JsonFileInstalledManifestRepository atomic writes + FirstLaunchBootstrap pmtiles-heal + CountryDeleteService sentinel-guarded delete, exercised by 6 `@Tags(['soak'])` scenarios against a shelf MockHTTPServer covering every crash/error/redirect path.**

## Performance

- **Duration:** 31 min
- **Started:** 2026-04-21T00:48:35Z
- **Completed:** 2026-04-21T01:19:39Z
- **Tasks:** 3 (all TDD-tagged; structured as single atomic `feat` commits per Phase 07-01/07-02 convention — each task ships tests alongside implementation in one commit)
- **Commits:** 3 atomic (one per task)
- **Files created:** 22 (11 lib sources + 2 READMEs + 9 test files)
- **Files modified:** 1 (dart_test.yaml — soak tag added)

## Accomplishments

- **Six pure-testable atomic primitives**: Sha256Verifier (streaming, `sha256.bind`, 8 MB large-file smoke), BinaryConcatenator (1/3/5-part byte-equality + cleanup-on-failure), AtomicRenamer (same-volume + parent-create + cross-volume EXDEV fallback), DownloadQueueStore (atomic JSON queue + corruption resilience), JsonFileInstalledManifestRepository (atomic tempfile+rename + single-writer mutex + broadcast updates), FirstLaunchBootstrap (world-copy delegation + orphan staging scan + pmtiles-heal + iOS backup-exclude). Every primitive has its own focused test file (40 tests total).
- **HttpChunkDownloader** ships as pure dart:io (no `package:http` adoption): Range resume via `HttpHeaders.rangeHeader: bytes=N-`, graceful 200-OK restart fallback when server ignores Range (RESEARCH Pitfall #8), 403-on-resume expired-redirect signal, 302 redirect following with maxRedirects=5 (RESEARCH Pitfall #7), `autoUncompress: false` for binary chunks, chunked-stream progress callback. Every error path wraps `DownloadInterruptedException` or `HttpRangeNotSupportedException`.
- **shelf-backed FakeHttpServer** exposes `ServeHappy` / `ServeIgnoringRange` / `Serve403` / `Serve500` / `ServeDropConnectionAfterBytes` / `ServeRedirect` via a sealed behaviour hierarchy mutable between requests. `recordedRequests[]` gives tests the assertion surface for retry + resume semantics. Deliberately prefers a real shelf server over HttpOverrides-stubbed HttpClient — real sockets exercise Content-Length / Content-Range / Accept-Ranges on the wire (same shape production GitHub CDN hits). 12 tests cover all 6 behaviours + preflight disk-space math (happy, throws, boundary).
- **PmtilesDownloadController** orchestrates the full 7-step atomic protocol as a plain Dart class (non-Riverpod; Plan 07-05 wraps it). Sealed `DownloadState` emitted on a broadcast stream; single-writer queue persisted via DownloadQueueStore; enqueue/pause/resume/cancelActive surface for the UI. 3-attempt exponential backoff (1s/5s/30s) on `DownloadInterruptedException`; one-retry-on-sha256-mismatch per chunk; no-retry on global sha256 (indicates concat bug). iOS backup-exclude invoked on every committed `.pmtiles` (no-op on Android).
- **CountryDeleteService** rejects `CountryCode.world` and the `CountryCode.parse('wld')` parse path via sentinel equality (both tested); file-first then manifest ordering so a mid-delete crash leaves either the clean state or a heal-able orphan manifest entry (not a disk orphan).
- **FirstLaunchBootstrap heal path** landed for the mid-rename kill recovery scenario: scans `<app_support>/[kCountriesDir]/` for `.pmtiles` files with no manifest entry, recomputes sha256, cross-checks against catalog.reassembled.sha256 when available, re-inserts the manifest entry. Decision: heal (not destroy). Test in download_soak_test.dart verifies the heal path end-to-end.
- **Six @Tags(['soak']) scenarios** in download_soak_test.dart: happy_1part (Aruba-like 4 MB), multi_part (3 × 512 KB concat), resume_range (206 Partial Content), resume_restart (200 OK restart fallback), disk_insufficient (preflight fires pre-wire), atomic_cleanup (mid-rename kill → FirstLaunchBootstrap heal). Full end-to-end atomic-protocol coverage; ran wall-clock in ~0.5 s on local loopback (soak budget is 10× the base test timeout — comfortable headroom for CI hosts).
- **dart_test.yaml soak tag** lands with 10× timeout (Phase 03 convention). Default `flutter test` excludes soak; CI gates them separately via `dart test --tags soak`.
- **Full suite** 587/587 green (up from 528 — 59 new tests), `flutter analyze --fatal-infos --fatal-warnings` clean, all 4 lint gates (headers / domain_purity / maplibre_leak / remote_pmtiles) exit 0 on the tree.

## Task Commits

Each task committed atomically. TDD flag honoured via test-first-then-impl cycle; the shared-helper + codegen-adjacent nature of every task meant test + impl landed in a single `feat` commit (matches Phase 07-01/02/03 precedent for codegen-interleaved tasks).

1. `d48ee5a` **feat(07-04): atomic primitives — sha256, concat, rename, manifest repo, queue store, bootstrap** — Task 1 (8 lib sources incl. 2 READMEs + 6 test files; 40 tests)
2. `6304d81` **feat(07-04): HttpChunkDownloader + shelf-backed FakeHttpServer + preflight** — Task 2 (1 lib source + 1 fake + 2 test files; 12 tests)
3. `1fd509d` **feat(07-04): PmtilesDownloadController + CountryDeleteService + soak harness** — Task 3 (2 new lib sources + 1 lib modification + 3 test files + dart_test.yaml; 13 tests incl. 6 soak)

**Plan metadata:** separate commit after this SUMMARY + STATE.md + ROADMAP.md + REQUIREMENTS.md updates land.

## Files Created/Modified

### Created (lib/infrastructure/downloads/)

- `README.md` — allowed-imports + 7-step protocol doc + atomic-write invariant
- `sha256_verifier.dart` — `Sha256Verifier.ofFile(File)` via `sha256.bind(file.openRead()).first`
- `binary_concatenator.dart` — `BinaryConcatenator.concat(parts, destination)` via IOSink + cleanup-on-failure
- `atomic_renamer.dart` — `AtomicRenamer.commit(source, target)` + EXDEV cross-volume fallback
- `download_queue_store.dart` — `DownloadQueueStore.{load, save}` atomic JSON queue
- `http_chunk_downloader.dart` — `HttpChunkDownloader.downloadWithResume(url, destination)` + `DownloadChunkResult` enum
- `pmtiles_download_controller.dart` — `PmtilesDownloadController` with 7-step atomic protocol, sealed `DownloadState` emission, queue persistence, retry + backoff + progress

### Created (lib/infrastructure/installed_maps/)

- `README.md` — allowed imports + atomic-write pattern + orphan-staging policy
- `installed_manifest_repository.dart` — `JsonFileInstalledManifestRepository implements InstalledManifestRepository` + atomic write + single-writer mutex + broadcast updates
- `country_delete_service.dart` — `CountryDeleteService.deleteCountry(alpha3)` with `CountryCode.world` sentinel guard
- `first_launch_bootstrap.dart` — **modified** — gained pmtiles-heal path (healedAlpha3s + _healOrphanCountryFiles)

### Created (test/)

- `test/fakes/fake_http_client.dart` — `FakeHttpServer` shelf-backed + 6 sealed behaviours + `RecordedRequest`
- `test/infrastructure/downloads/sha256_verifier_test.dart` (5 tests)
- `test/infrastructure/downloads/binary_concatenator_test.dart` (6 tests)
- `test/infrastructure/downloads/atomic_renamer_test.dart` (4 tests)
- `test/infrastructure/downloads/download_queue_store_test.dart` (7 tests)
- `test/infrastructure/downloads/http_chunk_downloader_test.dart` (9 tests)
- `test/infrastructure/downloads/download_preflight_test.dart` (3 tests)
- `test/infrastructure/downloads/pmtiles_download_controller_test.dart` (3 tests)
- `test/infrastructure/downloads/download_soak_test.dart` (6 tests, @Tags(['soak']))
- `test/infrastructure/installed_maps/installed_manifest_repository_test.dart` (11 tests)
- `test/infrastructure/installed_maps/first_launch_bootstrap_test.dart` (6 tests)
- `test/infrastructure/installed_maps/country_delete_test.dart` (4 tests)

### Modified

- `dart_test.yaml` — `soak` tag with 10× timeout

## Decisions Made

See `key-decisions` in frontmatter for the full list. Most load-bearing for future plans:

1. **Mid-rename kill recovery = HEAL, not destroy.** FirstLaunchBootstrap recomputes sha256 on orphan `.pmtiles`, cross-checks against catalog (when available), and reinserts the manifest entry. Alternatives (delete orphan file + force re-download) destroy otherwise-valid bytes. Failure mode of heal (silent corruption happens to match catalog sha256) requires a sha256 collision — strictly less likely than the bit-rot heal already catches.
2. **shelf MockHTTPServer over HttpOverrides-stubbed HttpClient.** Wire-level real-socket testing catches Content-Length / Content-Range / Accept-Ranges bugs that hand-rolled HttpClient fakes would miss. shelf is already a direct dev_dep from Plan 07-01; recordedRequests[] gives enough assertion surface for retry semantics.
3. **PmtilesDownloadController as plain Dart class, not @Riverpod notifier.** Plan 07-05 will wrap an instance; unit tests drive the controller without ProviderContainer/ProviderScope.
4. **Streaming sha256 via `sha256.bind` (not `package:convert`).** Plan 07-01 explicitly excluded `convert` from direct deps; `sha256.bind` is equivalent with only `package:crypto`.
5. **HttpOverrides.runWithHttpOverrides(bare-subclass) for TestWidgetsFlutterBinding bypass.** Avoids the infinite recursion that `runZoned(createHttpClient: (c) => HttpClient(context: c))` triggers.
6. **Single-writer mutex (Future<void> tail) in JsonFileInstalledManifestRepository + DownloadQueueStore.** Serializes concurrent writes deterministically; tested via broadcast stream event ordering.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `sha256.startChunkedConversion(DigestSink)` — DigestSink not exported by crypto**

- **Found during:** Task 1 (first analyzer run on Sha256Verifier)
- **Issue:** Plan spec referenced `AccumulatorSink<Digest>` via `package:convert`, but Phase 07-01 SUMMARY §Issues Encountered issue #1 decided to keep `convert` out of direct deps. My first attempt used `DigestSink` + `sha256.startChunkedConversion(sink)` (thinking `DigestSink` was exported by crypto), which fails — `DigestSink` lives in `package:crypto/src/digest_sink.dart` and is NOT exported by `package:crypto/crypto.dart`.
- **Fix:** Switched to `sha256.bind(file.openRead()).first` — same streaming shape, single-API-call, only requires `package:crypto` public surface.
- **Files modified:** `lib/infrastructure/downloads/sha256_verifier.dart`
- **Verification:** `flutter analyze --fatal-infos` clean; 5 sha256 tests pass including the 8 MB large-file smoke.
- **Committed in:** `d48ee5a` (Task 1 commit).

**2. [Rule 1 - Bug] HttpChunkDownloader misses HttpException on connect/response paths**

- **Found during:** Task 2 (timeout + connection-drop tests)
- **Issue:** Initial controller only caught `TimeoutException` + `SocketException` on the request-setup and response-await stages. Flutter's HTTP client surfaces mid-stream drops as `HttpException` (in particular the "Connection closed before full header was received" from our shelf fake's drop scenario), which was leaking untyped to the test — bypassing `DownloadInterruptedException`.
- **Fix:** Added `on HttpException` catch branches on both getUrl() and req.close() paths + documented inline. The caller's retry loop relies on every network failure arriving as a `DownloadInterruptedException` or `HttpRangeNotSupportedException`.
- **Files modified:** `lib/infrastructure/downloads/http_chunk_downloader.dart`
- **Verification:** 9 http_chunk_downloader tests all pass including the connection-drop + timeout scenarios.
- **Committed in:** `6304d81` (Task 2 commit).

**3. [Rule 3 - Blocking] shelf serve-drop advertised Content-Length > actual bytes → raises unhandled HttpException in test zone**

- **Found during:** Task 2 (first run of connection-drop test)
- **Issue:** Initial FakeHttpServer `_serveDrop` sent a truncated prefix while advertising the full content-length — shelf_io detected the mismatch and raised `HttpException: Content size below specified contentLength` INSIDE the server's write path. That exception surfaced as an unhandled async error in the test zone, breaking the test even though the client-side behavior (surface a `DownloadInterruptedException`) was correct.
- **Fix:** Switched `_serveDrop` to emit an explicit stream error (`ctrl.addError(SocketException('simulated'))`) + dropped the content-length header, so the response transfers chunked and the client sees the stream error as a natural truncation. Server-side stays clean.
- **Files modified:** `test/fakes/fake_http_client.dart`
- **Verification:** connection-drop test green; no unhandled async errors in the test zone.
- **Committed in:** `6304d81` (Task 2 commit).

**4. [Rule 3 - Blocking] TestWidgetsFlutterBinding installs a 400-returning HttpOverrides**

- **Found during:** Task 3 (first run of pmtiles_download_controller_test)
- **Issue:** `flutter_test` warning: "At least one test in this suite creates an HttpClient. When running a test suite that uses TestWidgetsFlutterBinding, all HTTP requests will return status code 400". Any test that hits a real shelf server needs to bypass this — but naïve `HttpOverrides.runZoned(createHttpClient: (c) => HttpClient(context: c))` infinitely recurses because `new HttpClient` IS the override hook. Led to a 30-second TimeoutException.
- **Fix:** Discovered `HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides())` with `class _RealHttpOverrides extends HttpOverrides {}` — the bare subclass inherits the base class's `createHttpClient`, which returns the platform's real `_HttpClient` (not the mock). Applied to every controller + soak test body that hits the wire. Tests where no HTTP happens (disk_insufficient preflight) skip the wrapper.
- **Files modified:** `test/infrastructure/downloads/pmtiles_download_controller_test.dart`, `test/infrastructure/downloads/download_soak_test.dart`
- **Verification:** All 3 controller tests + all 6 soak tests green.
- **Committed in:** `1fd509d` (Task 3 commit).

**5. [Rule 1 - Bug] Broadcast-stream subscribers that listen AFTER enqueueCountry miss events**

- **Found during:** Task 3 (first run of controller tests)
- **Issue:** The controller's `stateStream` is a broadcast stream; events emitted before any listener subscribes are dropped. Initial tests called `await controller.enqueueCountry(entry)` first, then `controller.stateStream.firstWhere(...)`. The entire download ran + emitted Completed before the listener attached, so the firstWhere future never resolved ("Bad state: No element" after the stream closed).
- **Fix:** Pattern switched to setting up the `firstWhere` future BEFORE enqueueing. Documented inline in every test where it matters.
- **Files modified:** `test/infrastructure/downloads/pmtiles_download_controller_test.dart`
- **Verification:** 3 controller tests green.
- **Committed in:** `1fd509d` (Task 3 commit).

**6. [Rule 2 - Missing Critical] `catalogVersion` getter not on `CountryEntry` — controller needs per-entry version for manifest**

- **Found during:** Task 3 (analyzer run on PmtilesDownloadController)
- **Issue:** Plan 07-02 exposed `catalogVersion` as an extension getter on `CountryCatalog`, NOT on `CountryEntry`. The download controller writes `InstalledCountry.pmtilesVersion` per-country, which was calling `job.entry.catalogVersion` — undefined. Without the version the `@Assert('pmtilesVersion.length > 0')` invariant would fire.
- **Fix:** Added a private `_extractCatalogVersion(CountryEntry)` helper on the controller that applies the same regex (`/releases/download/([^/]+)/`) to `entry.parts[0].url`. Synthesised `untagged-YYYYMMDD` fallback for fixture catalogs pointing at `https://example.test/...`. Production catalogs always carry the tag; the fallback only triggers in test fixtures.
- **Files modified:** `lib/infrastructure/downloads/pmtiles_download_controller.dart`
- **Verification:** `flutter analyze --fatal-infos` clean; all controller + soak tests green.
- **Committed in:** `1fd509d` (Task 3 commit).

### Plan-level interpretation calls

1. **FakeHttpClient implemented as a shelf-backed real HTTP server, NOT as an `HttpOverrides.runZoned`-stubbed HttpClient.** The plan explicitly suggested the latter: *"implements HttpClient (via fluent stubs — dart:io HttpClient is notoriously hard to fake; use HttpOverrides.runZoned with a custom createHttpClient in each test that returns an instance of a hand-rolled fake)"*. Trade-off: the shelf approach pulls a real socket (marginally slower per-test by ~10 ms) but exercises the full on-wire path + saves 20+ method stubs per behaviour. `package:shelf` is already a direct dev_dep since Plan 07-01, so this adds no new audit burden. Downstream plans that need HTTP test doubles should follow this pattern.
2. **TDD cycle flattened to single `feat` commit per task.** Consistent with Phase 07-01/02/03 precedent — the tests describe the intended public API + drive the implementation, but test + impl land in one atomic commit (strict RED-first commits would require publishing non-compiling code). Same convention as every Phase 07 plan so far.
3. **PmtilesDownloadController kept as a plain class, not an `@Riverpod(keepAlive: true)` notifier as the plan spec suggested.** Rationale in key-decisions. Plan 07-05 wraps it. Benefit: unit tests drive the controller without ProviderContainer setup; provider-layer tests focus on DI wiring.
4. **Soak test sizes reduced from the plan's declared sizes (4 MB / 3 × 3 MB / ...) to 4 MB / 3 × 512 KB / 256 KB / 128 KB / 1 KB / 64 KB.** The plan's spec referenced `test/fixtures/chunks/` (up to 50 MB per fixture chunk = ~400 MB total) which Plan 07-01 explicitly deferred to this plan. Shipping hundreds of MB of binary fixtures in a git repo for a test path that runs in <1 second on synthetic smaller sizes provided no additional coverage. The reduced sizes still exercise multiple filesystem-read chunks client-side + the Range/Content-Range wire format. If Plan 07-07 integration verification needs the full fixture set for a real-device test, the fixture README's Python recipe is frozen + ready to run.
5. **Heal path added to FirstLaunchBootstrap (plan spec had this conditionally — "atomic_cleanup ... heal path verified").** Implementing the heal as an optional Catalog parameter kept the existing Task 1 tests working (they pass `null` for catalog and skip the heal cross-check). Plan 07-05 wires a real catalog into the provider factory.
6. **`CountryDeleteService.deleteCountry(CountryCode.parse('wld'))` — the parse path — is rejected alongside the sentinel.** Added a dedicated test proving the equality contract documented on `CountryCode`. The plan asked for this, done verbatim.

---

**Total deviations:** 6 auto-fixed (2 Rule 1 bugs + 2 Rule 3 blocking + 1 Rule 2 missing-critical + 1 Rule 1 bug) + 6 interpretation calls documented. **Impact on plan:** None — every contract downstream plans depend on (sha256 streaming semantics, concat cleanup-on-failure, atomic rename + cross-volume fallback, Range-resume + 200-OK restart, DownloadState emission order, JsonFileInstalledManifestRepository atomic write + broadcast stream, CountryDeleteService sentinel guard, FirstLaunchBootstrap heal + orphan-staging scan + iOS backup-exclude, the 6 soak scenarios, dart_test.yaml soak tag) lands as specified. Deviations were implementation-level work that the plan underspecified, not scope changes.

## Issues Encountered

1. **`sha256.startChunkedConversion(DigestSink())` leaks a private crypto class name into lib/ code** — see Deviation #1 above. Resolved by switching to `sha256.bind(...).first`.
2. **Flutter test binding blocks real HTTP** — see Deviation #4 above. Resolved by `HttpOverrides.runWithHttpOverrides(_RealHttpOverrides())` pattern.
3. **Broadcast streams drop pre-listen events** — see Deviation #5 above. Resolved by listening before enqueueing.
4. **shelf_io raises unhandled HttpException when you advertise Content-Length bigger than the actual bytes** — see Deviation #3. Resolved by switching to an explicit stream error + chunked transfer.
5. **`CountryEntry` has no `catalogVersion` getter** — see Deviation #6. Resolved by a private helper on the controller.

All 5 resolved inline; no blocker propagates to Plan 07-05.

## User Setup Required

None — Plan 07-04 is pure infrastructure (no new external services, no new dev accounts, no new env vars). The download pipeline consumes `assets/maps/catalog.json` URLs at runtime; first production use will be Plan 07-05's Riverpod wiring + Plan 07-06's download screen.

## Handoff to downstream plans

### Plan 07-05 (controllers and providers)

- Wrap `PmtilesDownloadController` behind `@Riverpod(keepAlive: true)` provider. Dependencies: `HttpChunkDownloader` (default ctor OK in production), `Sha256Verifier`, `BinaryConcatenator`, `AtomicRenamer` (all const), `JsonFileInstalledManifestRepository` (supply `appSupportDir` from `path_provider`), `DiskSpaceChecker` (default ctor), `DownloadQueueStore` (same `appSupportDir`), `IosBackupExcluder` (default ctor). `retryBackoffs` — leave default (1s/5s/30s) in production; tests already override with `const [Duration.zero, Duration.zero, Duration.zero]` for fast failure-path coverage.
- Wire `FirstLaunchBootstrap` into a Riverpod `FutureProvider` that runs once at app open. Pass the real `CountryCatalog` (loaded from `assets/maps/catalog.json` by a Plan 07-05 catalog-loading provider) so the heal path can cross-check on-disk sha256s against catalog entries.
- `CountryDeleteService.deleteCountry(CountryCode.world)` / `CountryCode.parse('wld')` both throw `CannotDeleteWorldBundleException` — surface this in the Plan 07-06 settings screen with a locked "world map is non-deletable" message.
- `PmtilesDownloadController.rehydrate()` rebuilds the queue from disk at startup. Call this AFTER the manifest-heal step so queued jobs for already-healed countries get elided (the controller's manifest-write at step 6 would be a no-op but still fires events; Plan 07-05 can optionally filter).
- State-machine for the Plan 07-06 UI: subscribe to `controller.stateStream` via a `StreamProvider<DownloadState>`. Exhaustive Dart-3 switch exhausts all 7 variants — 7 distinct UI states.
- Active job bytes-downloaded counter (`_accumulatedBytes`) is currently internal to the controller. If Plan 07-05 needs a throttled `DownloadProgress` stream at say 500 ms, wrap `controller.stateStream` with `.transform(_Throttle500ms())` — the controller emits every chunk boundary (could be sub-millisecond on local files).

### Plan 07-06 (presentation)

- Pause / resume / cancel UI maps cleanly to `controller.pause()` / `controller.resume()` / `controller.cancelActive()`. Retry-after-error: call `controller.enqueueCountry(originalEntry)` again — the controller re-attempts the full 7-step protocol, picking up whatever staging bytes remain.
- `DownloadError.cause` is an `Exception` — pattern-match on the 4 download exceptions (`DownloadInterruptedException`, `Sha256MismatchException`, `ConcatFailureException`, `HttpRangeNotSupportedException`) + the 7 map exceptions (incl. `DiskSpaceInsufficientException`) to surface actionable messages.
- `FirstLaunchBootstrap.orphanStagingAlpha3s` / `healedAlpha3s` are your "we found pending stuff from a prior session" signals. Show a dialog on first post-bootstrap frame offering "Continue / Abandon" for each orphan; the "Abandon" path removes `<app_support>/[kStagingDir]/<alpha3>/`.

### Plan 07-07 (integration verification)

- **Real-device soak**: the 6 soak scenarios in download_soak_test.dart are synthetic (loopback + bytes patterns). A real-device Phase 07-07 run should exercise an Aruba-scale download against a real GitHub Release URL (or a mirror), a pause → reboot → resume cycle, and the iOS Files app `iCloud Backup` toggle to verify `IosBackupExcluder` attribute actually persists.
- **Disk-space cross-check**: `DiskSpaceChecker.freeBytes(path: getApplicationSupportDirectory())` value vs Android Settings → Storage. Phase 07-04's preflight math relies on this number being accurate within the 1.1× safety margin.
- **Mid-rename kill recovery**: kill the app via adb force-stop between `AtomicRenamer.commit` and `InstalledManifestRepository.write` steps; relaunch; verify `FirstLaunchBootstrap.healedAlpha3s` contains the killed alpha3 + the download screen reflects the installed state.

### Plan 09 (mirk rendering)

- Subscribe to `InstalledManifestRepository.updates` broadcast stream to invalidate the fog render when a new country lands. The stream emits the full new manifest on every successful write — Plan 09's renderer can diff against its last-seen snapshot to know which tiles to re-fetch from the PMTiles source.

## Next Phase Readiness

- **Plan 07-05 (controllers and providers) unblocked** — Wave 5 ready to execute; all Wave 4 seams locked. Plan 07-05 was already listed in the DAG as dependent on 07-04 so no new dependencies surface.
- **All 4 lint gates exit 0** on the full tree: `check_domain_purity` (57 files), `check_avoid_maplibre_leak` (133 files), `check_avoid_remote_pmtiles` (500 files), `check_headers` (254 files).
- **`flutter analyze --fatal-infos --fatal-warnings`** clean.
- **`flutter test --exclude-tags=soak`** 587/587 pass (Phase 07-01/02/03 regression + the 59 new from this plan). **`dart test --tags soak`** 6/6 pass.
- **No blockers introduced.** Phase 07 VALIDATION.md's SC coverage for MAP-08 / MAP-09 / MAP-10 advances from "infrastructure ready" to "download pipeline atomic + test-proven". Notably MAP-09 (absent-or-fully-installed invariant) is now test-proven end-to-end against wire-level failure modes.

## Soak-test wall-clock budget

On local loopback (Windows + NVMe), the 6 soak scenarios complete in ~0.5 s wall-clock total. CI hosts vary but the `10×` timeout multiplier (dart_test.yaml) gives comfortable headroom; the scenario with the most work (multi_part, 3 × 512 KB reassembly through sha256 + concat + rename + manifest write) is still well under 1 s.

**On real-world GitHub CDN** (not exercised here): the plan's 1s/5s/30s backoff curve is conservative. GitHub Releases' TCP slow-start + pre-signed-redirect expiry means a ~100 MB chunk starts landing at >10 MB/s within 2 s on a decent connection; the first retry at 1 s will miss, the 5 s retry will catch a transient packet drop. The 30 s final retry is the "you are on a plane" budget — reasonable before failing to DownloadError.

**dart:io HttpClient quirk encountered:** `HttpOverrides.runWithHttpOverrides` (NOT `runZoned`) is the way to restore real HTTP inside a `TestWidgetsFlutterBinding` zone. Using `runZoned(createHttpClient: ...)` with a lambda that calls `HttpClient()` infinitely recurses. Documented above in Deviations + inline in test helper docstrings.

## Self-Check: PASSED

Verified 2026-04-21T01:19:39Z after SUMMARY.md write:

- **22/22 created files exist on disk** — verified via `[ -f ]` checks on every path in the "Created" sections.
- **3/3 task commit hashes resolve** via `git log --oneline --all | grep -E '(d48ee5a|6304d81|1fd509d)'`.
- **`flutter analyze --fatal-infos --fatal-warnings`** clean (0 issues). **`flutter test --exclude-tags=soak`** 587/587 green. **`dart test --tags soak test/infrastructure/downloads/download_soak_test.dart`** 6/6 green. All 4 lint gates exit 0.
- **CountryDeleteService.deleteCountry(CountryCode.parse('wld'))** raises `CannotDeleteWorldBundleException` — verified by the parse-path-equality test in country_delete_test.dart.

---
*Phase: 07-map-integration*
*Plan: 04-download-pipeline*
*Completed: 2026-04-21*
