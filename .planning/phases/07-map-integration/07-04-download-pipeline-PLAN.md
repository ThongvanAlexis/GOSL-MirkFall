---
phase: 07-map-integration
plan: 04
type: execute
wave: 3
depends_on: ["07-02"]
files_modified:
  - lib/infrastructure/downloads/http_chunk_downloader.dart
  - lib/infrastructure/downloads/sha256_verifier.dart
  - lib/infrastructure/downloads/binary_concatenator.dart
  - lib/infrastructure/downloads/atomic_renamer.dart
  - lib/infrastructure/downloads/pmtiles_download_controller.dart
  - lib/infrastructure/downloads/download_queue_store.dart
  - lib/infrastructure/downloads/README.md
  - lib/infrastructure/installed_maps/installed_manifest_repository.dart
  - lib/infrastructure/installed_maps/first_launch_bootstrap.dart
  - lib/infrastructure/installed_maps/README.md
  - test/infrastructure/downloads/http_chunk_downloader_test.dart
  - test/infrastructure/downloads/sha256_verifier_test.dart
  - test/infrastructure/downloads/binary_concatenator_test.dart
  - test/infrastructure/downloads/atomic_renamer_test.dart
  - test/infrastructure/downloads/pmtiles_download_controller_test.dart
  - test/infrastructure/downloads/download_soak_test.dart
  - test/infrastructure/downloads/download_queue_store_test.dart
  - test/infrastructure/downloads/download_preflight_test.dart
  - test/infrastructure/installed_maps/installed_manifest_repository_test.dart
  - test/infrastructure/installed_maps/country_delete_test.dart
  - test/fakes/fake_http_client.dart
  - test/fixtures/chunks/
  - dart_test.yaml
autonomous: true
requirements:
  - MAP-08
  - MAP-09
  - MAP-10

must_haves:
  truths:
    - "`Sha256Verifier.ofFile(File)` streams sha256 hash via crypto AccumulatorSink with constant memory — handles files > 1 GB without heap explosion"
    - "`BinaryConcatenator.concat(parts, destination)` streams each part's bytes into destination sink without loading reassembled file into memory"
    - "`HttpChunkDownloader.downloadWithResume(url, destination)` uses dart:io HttpClient with Range: bytes=N- header; honours 206 Partial Content (resume) and 200 OK (server ignored Range → restart from byte 0)"
    - "`AtomicRenamer.commit(staging, final)` uses File.rename() for atomic same-volume move"
    - "`PmtilesDownloadController` (Riverpod keepAlive) orchestrates the 7-step atomic protocol: disk preflight → download N chunks → sha256 per chunk → concat → global sha256 → atomic rename → manifest update → cleanup"
    - "Queue persisted in `<app_support>/maps/download_queue.json` via DownloadQueueStore atomic write — survives app restart"
    - "`InstalledManifestRepository` impl uses tempfile + rename atomic write (Phase 03 DbBackupService pattern); crash mid-write leaves the old manifest or the new one, never a truncated file"
    - "`FirstLaunchBootstrap.run()` ensures world bundle exists (delegates to Plan 07-03 FirstLaunchWorldCopier) AND sweeps orphan staging dirs from previous interrupted sessions"
    - "Soak test (`@Tags(['soak'])`) covers: happy 1-part (Aruba-like 4 MB), multi-part concat (FRA-like 3 parts), mid-chunk kill + resume via Range, server-ignored-Range restart, sha256 mismatch retry, disk-insufficient preflight, mid-rename kill cleanup"
    - "`FakeHttpClient` supports: happy serve, 206 Partial Content on Range, 200 OK (ignoring Range), 302 redirect (GitHub CDN), 403 expired-redirect token, 500 transient, connection drop mid-response"
  artifacts:
    - path: "lib/infrastructure/downloads/pmtiles_download_controller.dart"
      provides: "Riverpod controller orchestrating full atomic download"
      contains: "@Riverpod(keepAlive: true)"
    - path: "lib/infrastructure/downloads/http_chunk_downloader.dart"
      provides: "dart:io HttpClient + Range resume + redirect handling"
      contains: "HttpHeaders.rangeHeader"
    - path: "lib/infrastructure/downloads/sha256_verifier.dart"
      provides: "streaming sha256 via AccumulatorSink"
      contains: "AccumulatorSink"
    - path: "lib/infrastructure/downloads/binary_concatenator.dart"
      provides: "streamed IOSink concat without heap blowout"
      contains: "openRead"
    - path: "lib/infrastructure/installed_maps/installed_manifest_repository.dart"
      provides: "tempfile + rename atomic JSON write"
      contains: "tmp.rename"
    - path: "test/infrastructure/downloads/download_soak_test.dart"
      provides: "6+ atomic-protocol scenarios gated behind @Tags(['soak'])"
      contains: "Tags(['soak'])"
  key_links:
    - from: "lib/infrastructure/downloads/pmtiles_download_controller.dart"
      to: "lib/infrastructure/installed_maps/installed_manifest_repository.dart"
      via: "step 6 updates installed.json via atomic write"
      pattern: "installedManifestRepository.write"
    - from: "lib/infrastructure/downloads/pmtiles_download_controller.dart"
      to: "lib/infrastructure/platform/disk_space_checker.dart"
      via: "step 0 preflight query"
      pattern: "diskSpaceChecker.freeBytes"
    - from: "lib/infrastructure/installed_maps/first_launch_bootstrap.dart"
      to: "lib/infrastructure/map/first_launch_world_copier.dart"
      via: "delegates world-copy to Plan 07-03 copier"
      pattern: "FirstLaunchWorldCopier"
---

<objective>
Build the complete country-download pipeline: the 7-step atomic protocol (disk preflight → chunked HTTP download with Range resume → per-chunk sha256 → streaming concat → global sha256 → atomic rename → manifest update → staging cleanup). Every step is testable in isolation + covered by an end-to-end soak test via MockHTTPServer (shelf). The installed-manifest repository lands here too (atomic tempfile + rename) along with the first-launch bootstrap sweeper.

Purpose: MAP-09 is the single highest-risk invariant of Phase 07 — "a country is either absent or fully installed, never partial". Getting the crash-safety + sha256 + atomic rename ordering correct now prevents weeks of cross-platform filesystem debugging later. Closes RESEARCH Pitfalls #1 (mid-write), #7 (GitHub CDN redirect), #8 (Range support fallback), #11 (foreground-service constraints documented, not enforced).
Output: A compiling download infrastructure subtree that a Riverpod controller exposes to the UI, with exhaustive soak-test coverage of every crash + error path.
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
@CLAUDE.md
@lib/config/constants.dart
@lib/infrastructure/db/db_backup_service.dart
@dart_test.yaml

<interfaces>
<!-- Key types from Plans 07-01 / 07-02 -->

From `lib/domain/downloads/`:
```dart
class DownloadJob {
  CountryCode alpha3;
  CountryEntry entry;
  DateTime enqueuedAtUtc;
  bool userPausedFlag;
}
sealed class DownloadState { … }
class DownloadProgress { int bytesDownloaded; int totalBytes; int currentPartIndex; int totalParts; double get fractionDone; }

class DownloadInterruptedException implements Exception { … }
class Sha256MismatchException implements Exception { String expected; String actual; … }
class ConcatFailureException implements Exception { … }
class HttpRangeNotSupportedException implements Exception { int responseCode; }
```

From `lib/domain/installed_maps/`:
```dart
abstract class InstalledManifestRepository {
  Future<InstalledManifest> read();
  Future<void> write(InstalledManifest manifest);
  Stream<InstalledManifest> get updates;
}
class InstalledManifest { Map<String, InstalledCountry> installed; int schemaVersion; String catalogVersion; }
class InstalledCountry { CountryCode alpha3; DateTime installedAtUtc; int fileSize; String pmtilesVersion; String sha256; String filePath; }
```

Phase 03 DbBackupService.takeBackup atomic write pattern:
```dart
final File tmp = File('$targetPath.tmp');
await tmp.writeAsBytes(bytes, flush: true);  // flush=true calls fsync
await tmp.rename(targetPath);  // atomic on POSIX + ext4/APFS/NTFS
```

Phase 05 Riverpod keepAlive provider pattern:
```dart
@Riverpod(keepAlive: true)
class ActiveSessionController extends _$ActiveSessionController { … }
```

Phase 03 dart_test.yaml @Tags pattern:
```yaml
tags:
  migration:
    timeout: 2x
  soak:
    timeout: 5x
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Sha256Verifier + BinaryConcatenator + AtomicRenamer + InstalledManifestRepository + DownloadQueueStore (pure, testable pieces)</name>
  <files>
    lib/infrastructure/downloads/sha256_verifier.dart,
    lib/infrastructure/downloads/binary_concatenator.dart,
    lib/infrastructure/downloads/atomic_renamer.dart,
    lib/infrastructure/downloads/download_queue_store.dart,
    lib/infrastructure/downloads/README.md,
    lib/infrastructure/installed_maps/installed_manifest_repository.dart,
    lib/infrastructure/installed_maps/first_launch_bootstrap.dart,
    lib/infrastructure/installed_maps/README.md,
    test/infrastructure/downloads/sha256_verifier_test.dart,
    test/infrastructure/downloads/binary_concatenator_test.dart,
    test/infrastructure/downloads/atomic_renamer_test.dart,
    test/infrastructure/downloads/download_queue_store_test.dart,
    test/infrastructure/installed_maps/installed_manifest_repository_test.dart
  </files>
  <behavior>
    - **`Sha256Verifier.ofFile(File f)`** returns `Future<String>` (hex digest).
      - Uses `package:crypto` `AccumulatorSink<Digest>` + `sha256.startChunkedConversion(sink)` + `file.openRead().listen(input.add)`
      - Correctness verified against known test vectors (empty file = `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)
      - Large-file memory safety: test uses a 200 MB synthetic file + verifies peak RSS does not grow proportionally (by measuring memory before + after — rough smoke, not strict budget)
    - **`BinaryConcatenator.concat(parts, destination)`**:
      - Opens `destination.openWrite()` as an IOSink
      - For each part, `await for (final chunk in part.openRead()) sink.add(chunk);`
      - `sink.flush()` + `sink.close()` in finally block
      - Verifies via unit test: 3 parts of (100, 200, 300) bytes concat to a 600-byte file whose sha256 matches the concatenated-bytes-in-memory reference
    - **`AtomicRenamer.commit(source: staging, target: final)`**:
      - Creates parent of target if missing
      - `await source.rename(target.path)`
      - If source and target are on different volumes, rename throws — we detect + fall back to copy+delete with a warning log (the normal case is same-volume for app-support internal moves, so this branch is rare)
    - **`InstalledManifestRepository`** concrete impl `FilesystemInstalledManifestRepository implements InstalledManifestRepository`:
      - Ctor: `FilesystemInstalledManifestRepository({required String appSupportDir})`
      - Path: `p.join(appSupportDir, kInstalledManifestPath)` → `<app_support>/maps/installed.json`
      - `Future<InstalledManifest> read()`:
        - If file doesn't exist → return `InstalledManifest.empty()`
        - Else parse JSON via `InstalledManifest.fromJson`; throw `SchemaValidationException` on parse error
      - `Future<void> write(InstalledManifest m)`:
        - Write to `installed.json.tmp` with `writeAsString(jsonEncode(m.toJson()), flush: true)`
        - `tmp.rename(installed.json)`
        - Emit on broadcast controller
      - `Stream<InstalledManifest> get updates` — broadcast controller
    - **`DownloadQueueStore`** JSON-backed persistent queue:
      - Path: `<app_support>/maps/download_queue.json`
      - `Future<List<DownloadJob>> load()` — empty list if file missing
      - `Future<void> save(List<DownloadJob> queue)` — atomic tempfile + rename
      - Purpose: survives app restart; Plan 07-05's `DownloadQueueController` consumes it
    - **`FirstLaunchBootstrap`**:
      - Ctor: `FirstLaunchBootstrap({required FirstLaunchWorldCopier worldCopier, required String appSupportDir})`
      - `Future<void> run()`:
        1. Delegate to `worldCopier.ensureInstalled()` (Plan 07-03)
        2. Sweep `<app_support>/maps/staging/` — list children; for each alpha3 subdir, if there's no corresponding entry in `installed.json`, LOG at INFO "Orphan staging found: alpha3" but do NOT delete automatically (user may want to resume — `Plan 07-05`'s `DownloadQueueController` will prompt them). If the user has already been prompted + chose "abandon", the 07-05 controller deletes.
        3. (Phase 07-05 addendum) — on iOS, invoke `IosBackupExcluder.excludePath(appSupportDir + '/maps')` once at first launch to exclude the entire maps tree from iCloud backup. Closes Open Question #3.
    - **Tests** exhaustive for each piece:
      - Sha256: known test vectors (empty, small known content, 1 MB random with recorded hash, 200 MB synthetic with reference hash)
      - Concatenator: 1/2/3/5-part concats with byte-level equality
      - AtomicRenamer: same-volume success, non-existent source throws, parent-dir-missing is created
      - InstalledManifestRepository: write + read round-trip, missing file returns empty, corrupted file throws SchemaValidationException, atomic (simulated crash via `.tmp` left behind — next read ignores it and uses the canonical file), concurrent writes serialized (broadcast stream order preserved)
      - DownloadQueueStore: roundtrip, corrupt → empty list, atomic write
  </behavior>
  <action>
    1. **GOSL headers + READMEs** for both new infra dirs.

    2. **Sha256Verifier**: per RESEARCH Example 2 verbatim + large-file test via `Directory.systemTemp` scratch file.

    3. **BinaryConcatenator**: per RESEARCH Example 4 + 3-part test.

    4. **AtomicRenamer**: 20-line class + fail-path test (delete the source mid-rename is hard to simulate in Dart — rely on the file-not-found error path instead).

    5. **InstalledManifestRepository**: atomic write + tests for parse errors + tempfile-leftover-handling (if `.tmp` exists when app starts, the `read` of the canonical file must succeed unchanged — the stale `.tmp` is harmless and cleaned up on next write).

    6. **DownloadQueueStore**: similar pattern + tests.

    7. **FirstLaunchBootstrap**: minimal orchestration class + unit test with in-memory fakes (FakeFirstLaunchWorldCopier + tempdir appSupport).

    8. Run `flutter analyze` + `flutter test test/infrastructure/downloads/ test/infrastructure/installed_maps/` — all green.

    9. Commit.
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos lib/infrastructure/downloads/ lib/infrastructure/installed_maps/ test/infrastructure/downloads/ test/infrastructure/installed_maps/ &&
      flutter test test/infrastructure/downloads/sha256_verifier_test.dart test/infrastructure/downloads/binary_concatenator_test.dart test/infrastructure/downloads/atomic_renamer_test.dart test/infrastructure/downloads/download_queue_store_test.dart test/infrastructure/installed_maps/installed_manifest_repository_test.dart &&
      dart run tool/check_headers.dart &&
      dart run tool/check_domain_purity.dart
    </automated>
  </verify>
  <done>
    Sha256Verifier + BinaryConcatenator + AtomicRenamer + InstalledManifestRepository + DownloadQueueStore + FirstLaunchBootstrap all compile + test-green. Atomic-write pattern matches Phase 03 DbBackupService precedent.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: HttpChunkDownloader + FakeHttpClient + Range + redirect handling unit tests</name>
  <files>
    lib/infrastructure/downloads/http_chunk_downloader.dart,
    test/fakes/fake_http_client.dart,
    test/infrastructure/downloads/http_chunk_downloader_test.dart,
    test/infrastructure/downloads/download_preflight_test.dart
  </files>
  <behavior>
    - **`HttpChunkDownloader`**:
      - Ctor: `HttpChunkDownloader({HttpClient? client, Duration timeout = const Duration(milliseconds: kHttpTimeout), Logger? logger})`. Default constructs a fresh HttpClient; `autoUncompress = false` (chunks are binary, not gzip). `followRedirects = true` (default — per RESEARCH Pitfall #7, needed for GitHub CDN).
      - `Future<DownloadChunkResult> downloadWithResume({required Uri url, required File destination, void Function(int bytesDelta, int? totalBytes)? onProgress})`:
        - `resumeByte = await destination.exists() ? await destination.length() : 0`
        - `req.headers.add(HttpHeaders.rangeHeader, 'bytes=$resumeByte-')` if resumeByte > 0
        - `req.close()` → `res`
        - If `res.statusCode == 206` → Partial Content, append mode
        - If `res.statusCode == 200` + resumeByte > 0 → server ignored Range → truncate destination + write mode (log WARN)
        - If `res.statusCode >= 400` → throw `DownloadInterruptedException` with statusCode
        - If `res.statusCode == 403` after resume → throw `DownloadInterruptedException` marked "expired_redirect" (per RESEARCH Pitfall #7; caller in Task 3 retries by re-requesting the canonical URL)
        - Stream via `sink.add(chunk)`; call `onProgress(chunk.length, res.contentLength)`
        - Finally: `sink.flush()` + `sink.close()`
      - Returns `DownloadChunkResult` enum: `resumedWith206`, `restartedFrom200`, `downloadedFresh`.
    - **`FakeHttpClient`** (test/fakes):
      - Implements `HttpClient` (via fluent stubs — dart:io HttpClient is notoriously hard to fake; use `HttpOverrides.runZoned` with a custom `createHttpClient` in each test that returns an instance of a hand-rolled fake)
      - Supports modes: `serveHappy(bytes)`, `serveRange(bytes, expectedRange)`, `serveIgnoringRange(bytes)`, `serveRedirect(targetUri)`, `serve403`, `serve500`, `serveDropConnectionAfterBytes(N)`
      - Test helpers: `List<RecordedRequest> recordedRequests` for assertions
    - **Tests**:
      - `http_chunk_downloader_test.dart`:
        - Happy full download (no resume) → statusCode 200 → file size matches
        - Resume from mid-byte → Range header sent → 206 response → file has full content
        - Server ignores Range → 200 OK → file truncated + rewritten → final sha256 matches
        - 403 after resume → DownloadInterruptedException
        - Connection drops mid-chunk → throws; destination.length() records partial bytes (used for next retry's resumeByte)
        - 302 redirect followed transparently
        - Timeout → TimeoutException wrapped as DownloadInterruptedException
      - `download_preflight_test.dart`: exercises `DiskSpaceChecker` fake → throws `DiskSpaceInsufficientException` when free < needed * 1.1.
  </behavior>
  <action>
    1. **`http_chunk_downloader.dart`** per behavior spec. Pure `dart:io` — do NOT adopt `package:http`.

    2. **`fake_http_client.dart`** using `HttpOverrides.runZoned` — the idiom where tests override the global HttpClient factory. Document heavily because future debug sessions will stumble over this.

    3. **Tests**: 7+ scenarios in http_chunk_downloader_test.dart + 2 in download_preflight_test.dart.

    4. **Lint + analyze**: clean. Headers check pass.

    5. Commit.
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos lib/infrastructure/downloads/http_chunk_downloader.dart test/fakes/fake_http_client.dart test/infrastructure/downloads/http_chunk_downloader_test.dart test/infrastructure/downloads/download_preflight_test.dart &&
      flutter test test/infrastructure/downloads/http_chunk_downloader_test.dart test/infrastructure/downloads/download_preflight_test.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    HttpChunkDownloader honours Range with graceful restart-from-200 fallback. FakeHttpClient supports 7+ test scenarios via HttpOverrides.runZoned. Preflight disk-space check wired via DiskSpaceChecker. All tests green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: PmtilesDownloadController + MockHTTPServer soak test + CountryDeleteService + dart_test.yaml soak tag</name>
  <files>
    lib/infrastructure/downloads/pmtiles_download_controller.dart,
    lib/infrastructure/installed_maps/country_delete_service.dart,
    test/infrastructure/downloads/pmtiles_download_controller_test.dart,
    test/infrastructure/downloads/download_soak_test.dart,
    test/infrastructure/installed_maps/country_delete_test.dart,
    dart_test.yaml
  </files>
  <behavior>
    - **`PmtilesDownloadController`** — Riverpod `@Riverpod(keepAlive: true)` AsyncNotifier<DownloadState>:
      - Dependencies: `HttpChunkDownloader`, `Sha256Verifier`, `BinaryConcatenator`, `AtomicRenamer`, `InstalledManifestRepository`, `DiskSpaceChecker`, `DownloadQueueStore`, `Logger('application.downloads')`
      - State: sealed DownloadState from domain
      - Methods:
        - `Future<void> enqueueCountry(CountryEntry entry)` — adds to queue, persists via store, triggers processing
        - `Future<void> pause()` — transitions DownloadInProgress → DownloadPaused, flags manually
        - `Future<void> resume()` — transitions DownloadPaused → DownloadInProgress if reason ≠ retryExhausted
        - `Future<void> cancelActive()` — deletes staging, transitions → DownloadCancelled → next job in queue
      - Processing loop `_processNext()`:
        1. Pre-flight: `diskSpaceChecker.freeBytes(path: appSupportDir) < entry.reassembled.size * kDiskSpaceSafetyMarginMultiplier` → emit DownloadError(DiskSpaceInsufficientException)
        2. For each `ChunkPart part in entry.parts`:
           - Download via `HttpChunkDownloader.downloadWithResume(url: Uri.parse(part.url), destination: staging/alpha3/part##)` with backoff (1s / 5s / 30s, max 3 attempts — per CONTEXT.md)
           - Compute sha256; if mismatch, delete + retry chunk 1 time, if still mismatch → DownloadError(Sha256MismatchException)
           - Emit DownloadProgress throttled at 200–500 ms via hand-rolled StreamTransformer
        3. Concat all parts to `staging/alpha3/<alpha3>.pmtiles` via BinaryConcatenator
        4. Global sha256 vs `reassembled.sha256`; mismatch → DownloadError(Sha256MismatchException), do NOT retry (fail hard)
        5. AtomicRenamer.commit(staging file, `countries/<alpha3>.pmtiles`)
        6. InstalledManifestRepository.write(new manifest with installed country entry)
        7. Delete staging/alpha3/ recursively
        8. Transition → DownloadCompleted, emit, process next in queue
      - Cleanup invariants on any exception: keep staging intact for resume UNLESS `cancelActive()` called.
      - iOS backup-exclude invoked once on the very first commit to `<app_support>/maps/` via `IosBackupExcluder.excludePath` (deferred call — subsequent countries land under the already-excluded dir).
    - **`CountryDeleteService`**:
      - `Future<void> deleteCountry(CountryCode alpha3)`:
        - Reject if `alpha3 == CountryCode.parse('wld')` / world bundle sentinel — throw `CannotDeleteWorldBundleException` (new typed exception, add to Plan 07-02 errors file OR here)
        - Read current manifest; if alpha3 missing → no-op
        - Delete `<app_support>/maps/countries/<alpha3>.pmtiles`
        - Remove entry from manifest; write atomically
    - **Soak test** `download_soak_test.dart` with `@Tags(['soak'])`:
      - Uses `shelf` MockHTTPServer: registers a handler that serves configurable byte ranges, can inject kill-after-N-bytes, sha256-mismatch payload, 403/500, 302 redirect, etc.
      - Scenarios:
        - `happy_1part` — Aruba fixture (1 part, 4 MB synthetic) → full atomic install, manifest updated, staging cleaned
        - `multi_part` — 3-part concat (synthetic 3 × 3 MB) → full install
        - `resume_range` — kill after 2 of 3 chunks → relaunch controller → resumes from chunk 2 → completes
        - `resume_restart` — server returns 200 instead of 206 on resume → truncate + rewrite → still completes correctly
        - `sha_retry` — seed one chunk with corrupted bytes for first GET only → controller retries once → second GET clean → completes
        - `disk_insufficient` — DiskSpaceChecker stub returns 10 MB free vs 1 GB required → DownloadError(DiskSpaceInsufficientException) immediately
        - `atomic_cleanup` — kill between step 5 (rename) and step 6 (manifest write) → next startup: FirstLaunchBootstrap logs orphan, manifest doesn't have the country, pmtiles file IS present in `countries/` but missing from manifest. Document: the next start-up bootstrap either (a) re-checks pmtiles sha256 against catalog and inserts the manifest entry (healing) OR (b) deletes the orphaned pmtiles file. **Decision: option (a) — heal by re-computing sha256 and inserting entry. Less destructive + matches idempotency spirit.** Test verifies healing path.
      - Every scenario: setUp creates a tempdir + fake dependencies + MockHTTPServer on a random free port; tearDown closes server + deletes tempdir.
    - **`dart_test.yaml`** extend:
      ```yaml
      tags:
        migration:
          timeout: 2x
        soak:
          timeout: 10x   # download soak tests can run several seconds per case
      ```
      - Default `dart test` / `flutter test` excludes soak (Phase 03 convention).
  </behavior>
  <action>
    1. **`pmtiles_download_controller.dart`** — Riverpod codegen (`@Riverpod(keepAlive: true)` class). Run `build_runner` after writing. Heavy class — ~300 LoC including docstrings.

    2. **`country_delete_service.dart`** — ~50 LoC. Throws typed exception if asked to delete world.

    3. **`pmtiles_download_controller_test.dart`** — unit tests with fake HTTP client + fake disk space + fake manifest repo. Scenarios: enqueue single → completed, enqueue with fail mid-chunk → paused-with-error → manual resume → completed.

    4. **`download_soak_test.dart`** — full-stack soak via `shelf` MockHTTPServer. Each scenario ~50 LoC. Total ~600 LoC. Tagged `@Tags(['soak'])`.

    5. **`country_delete_test.dart`** — 3 tests: happy delete, delete-world rejection, delete-nonexistent no-op.

    6. **`dart_test.yaml`** — add soak tag with 10x timeout.

    7. **Run soak locally once**: `dart test --tags soak test/infrastructure/downloads/download_soak_test.dart`. Expect ~30-60 seconds wallclock.

    8. **Lint + analyze + headers + leak scan** — all green.

    9. Commit.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/infrastructure/downloads/ lib/infrastructure/installed_maps/ test/infrastructure/downloads/ test/infrastructure/installed_maps/ &&
      flutter test test/infrastructure/downloads/pmtiles_download_controller_test.dart test/infrastructure/installed_maps/country_delete_test.dart &&
      dart test --tags soak test/infrastructure/downloads/download_soak_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_avoid_remote_pmtiles.dart
    </automated>
  </verify>
  <done>
    PmtilesDownloadController orchestrates all 7 atomic-protocol steps. MockHTTPServer soak test covers happy + multi-part + resume (206) + restart (200) + sha retry + disk insufficient + mid-rename kill recovery. CountryDeleteService safely rejects deleting the world bundle. dart_test.yaml soak tag keeps the default `flutter test` suite fast.
  </done>
</task>

</tasks>

<verification>
```
dart run build_runner build --delete-conflicting-outputs &&
flutter analyze --fatal-infos --fatal-warnings &&
flutter test --exclude-tags=soak test/infrastructure/downloads/ test/infrastructure/installed_maps/ test/fakes/ &&
dart test --tags soak test/infrastructure/downloads/download_soak_test.dart &&
dart run tool/check_domain_purity.dart &&
dart run tool/check_avoid_maplibre_leak.dart &&
dart run tool/check_avoid_remote_pmtiles.dart &&
dart run tool/check_headers.dart
```

Soak tests are excluded from the default `flutter test` suite (default fast) but gated before the plan merges.
</verification>

<success_criteria>
- 6 production files in `lib/infrastructure/downloads/` + 3 in `lib/infrastructure/installed_maps/` compile, test green
- Atomic-write pattern (tempfile + rename) used for both installed.json AND download_queue.json
- HttpChunkDownloader honours Range with graceful 200-OK restart fallback
- PmtilesDownloadController implements all 7 protocol steps with retry/backoff
- CountryDeleteService rejects deleting the world bundle
- Soak test covers 7 scenarios including mid-rename kill cleanup (heal path)
- MirkFall never leaves a partial country — the "absent OR fully installed" invariant is test-proven
</success_criteria>

<output>
After completion, create `.planning/phases/07-map-integration/07-04-SUMMARY.md`:
- Mid-rename kill recovery decision (heal VS delete orphan pmtiles) + rationale
- Actual wall-clock of the soak suite in CI environment (budget for Phase 08 Review Gate expectations)
- Any dart:io HttpClient quirk encountered (particularly around `HttpOverrides.runZoned` in multi-test scenarios)
- Whether the backoff sequence (1s/5s/30s) proved sufficient on the MockHTTPServer (fast local network) vs expected real-world GitHub CDN
- Commit hashes
</output>
