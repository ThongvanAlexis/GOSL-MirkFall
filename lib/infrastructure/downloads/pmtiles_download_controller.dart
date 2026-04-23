// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/downloads/download_errors.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/infrastructure/downloads/atomic_renamer.dart';
import 'package:mirkfall/infrastructure/downloads/binary_concatenator.dart';
import 'package:mirkfall/infrastructure/downloads/download_queue_store.dart';
import 'package:mirkfall/infrastructure/downloads/http_chunk_downloader.dart';
import 'package:mirkfall/infrastructure/downloads/sha256_verifier.dart';
import 'package:mirkfall/infrastructure/platform/disk_space_checker.dart';
import 'package:mirkfall/infrastructure/platform/ios_backup_excluder.dart';
import 'package:path/path.dart' as p;

/// Orchestrates the 7-step atomic download protocol for per-country
/// PMTiles bundles.
///
/// ## Protocol (from the plan's behaviour spec)
///
/// 0. **Preflight**: `DiskSpaceChecker.freeBytes(path)` must return at
///    least `reassembled.size * kDiskSpaceSafetyMarginMultiplier` —
///    else emit [DownloadError] with [DiskSpaceInsufficientException].
/// 1. **Download N chunks**: each `ChunkPart` is fetched via
///    [HttpChunkDownloader.downloadWithResume] into
///    `staging/<alpha3>/part##`. Retry up to [kDownloadRetryAttempts]
///    with 1s/5s/30s backoff on [DownloadInterruptedException].
/// 2. **Per-chunk sha256**: after each chunk lands, verify against
///    `ChunkPart.sha256`. One retry on mismatch; second mismatch is
///    terminal ([Sha256MismatchException]).
/// 3. **Concat**: [BinaryConcatenator] streams all parts into
///    `staging/<alpha3>/<alpha3>.pmtiles`.
/// 4. **Global sha256**: hash the reassembled file; mismatch against
///    `ReassembledMeta.sha256` is terminal (indicates concat bug; do
///    NOT retry).
/// 5. **Atomic rename**: [AtomicRenamer.commit] moves the staging
///    reassembled file to `<app_support>/[kCountriesDir]/<alpha3>.pmtiles`.
/// 6. **Manifest write**: [InstalledManifestRepository.write] updates
///    `installed.json` atomically.
/// 7. **Cleanup**: remove `staging/<alpha3>/` recursively.
///
/// Between steps 5 and 6 the controller calls
/// [IosBackupExcluder.excludePath] on the newly-committed `.pmtiles`
/// (iOS-only; no-op elsewhere). Closes RESEARCH Open Question #3.
///
/// ## State machine
///
/// Emits events on [stateStream]; subscribers (Plan 07-05 Riverpod
/// provider + widget) drive the UI. [state] returns the latest
/// snapshot. Transitions:
///
///   Idle → Queued → InProgress → (Paused ↔ InProgress)
///                                → (Completed | Error | Cancelled)
///                                → next-in-queue or Idle
///
/// ## Cleanup on exception
///
/// Staging remains intact on any exception UNLESS [cancelActive] is
/// called. This allows resume: the next call to [enqueueCountry] (or
/// an explicit [resume]) continues from the last fully-written chunk.
///
/// ## Non-Riverpod for testability
///
/// Deliberately a plain class rather than a `@Riverpod` notifier so
/// unit tests can drive it without a `ProviderContainer`. Plan 07-05
/// wraps an instance behind a `@Riverpod(keepAlive: true)` provider.
class PmtilesDownloadController {
  PmtilesDownloadController({
    required String appSupportDir,
    required HttpChunkDownloader httpDownloader,
    required Sha256Verifier sha256Verifier,
    required BinaryConcatenator concatenator,
    required AtomicRenamer renamer,
    required InstalledManifestRepository manifestRepository,
    required DiskSpaceChecker diskSpaceChecker,
    required DownloadQueueStore queueStore,
    IosBackupExcluder? iosBackupExcluder,
    List<Duration>? retryBackoffs,
    Logger? logger,
  }) : _appSupportDir = appSupportDir,
       _httpDownloader = httpDownloader,
       _sha256Verifier = sha256Verifier,
       _concatenator = concatenator,
       _renamer = renamer,
       _manifestRepository = manifestRepository,
       _diskSpaceChecker = diskSpaceChecker,
       _queueStore = queueStore,
       _iosBackupExcluder = iosBackupExcluder ?? IosBackupExcluder(),
       _retryBackoffs = retryBackoffs ?? _defaultBackoffs(),
       _log = logger ?? Logger('infrastructure.downloads.pmtiles_controller');

  /// 1 s / 5 s / 30 s curve described in 07-CONTEXT.md §Pipeline.
  static List<Duration> _defaultBackoffs() => const <Duration>[
    Duration(milliseconds: kDownloadRetryBaseDelayMs),
    Duration(milliseconds: kDownloadRetryBaseDelayMs * 5),
    Duration(milliseconds: kDownloadRetryBaseDelayMs * 30),
  ];

  final String _appSupportDir;
  final HttpChunkDownloader _httpDownloader;
  final Sha256Verifier _sha256Verifier;
  final BinaryConcatenator _concatenator;
  final AtomicRenamer _renamer;
  final InstalledManifestRepository _manifestRepository;
  final DiskSpaceChecker _diskSpaceChecker;
  final DownloadQueueStore _queueStore;
  final IosBackupExcluder _iosBackupExcluder;
  final List<Duration> _retryBackoffs;
  final Logger _log;

  final StreamController<DownloadState> _stateCtrl = StreamController<DownloadState>.broadcast();
  DownloadState _state = const DownloadIdle();
  final List<DownloadJob> _queue = <DownloadJob>[];

  bool _pauseRequested = false;
  bool _cancelRequested = false;
  Completer<void>? _processingDone;

  /// Latest state snapshot.
  DownloadState get state => _state;

  /// Broadcast stream of state transitions.
  Stream<DownloadState> get stateStream => _stateCtrl.stream;

  /// Current queued jobs (excluding the active one), in FIFO order.
  /// Exposed for test assertions + Plan 07-05 UI consumers.
  List<DownloadJob> get queuedJobs => List<DownloadJob>.unmodifiable(_queue);

  void _emit(DownloadState next) {
    _state = next;
    _stateCtrl.add(next);
  }

  /// Enqueues [entry] for download. The first enqueue kicks off the
  /// processing loop; subsequent calls append to the queue.
  Future<void> enqueueCountry(CountryEntry entry) async {
    final DownloadJob job = DownloadJob(alpha3: entry.alpha3, entry: entry, enqueuedAtUtc: DateTime.now().toUtc());
    _queue.add(job);
    await _persistQueue();
    _emit(DownloadQueued(queue: List<DownloadJob>.unmodifiable(_queue)));
    _startProcessingIfIdle();
  }

  /// Rehydrates the queue from the persistent store + resumes processing.
  /// Called at app startup by Plan 07-05's bootstrap sequence.
  Future<void> rehydrate() async {
    final List<DownloadJob> saved = await _queueStore.load();
    if (saved.isEmpty) return;
    _queue.addAll(saved);
    _emit(DownloadQueued(queue: List<DownloadJob>.unmodifiable(_queue)));
    _startProcessingIfIdle();
  }

  /// Request a pause of the current in-flight job. Takes effect at the
  /// next chunk boundary; the in-flight chunk completes first.
  Future<void> pause() async {
    _pauseRequested = true;
  }

  /// Resume a previously paused job. No-op when not paused.
  Future<void> resume() async {
    _pauseRequested = false;
    if (_state is DownloadPaused) {
      _startProcessingIfIdle();
    }
  }

  /// Cancel the active download and discard its staging directory.
  Future<void> cancelActive() async {
    _cancelRequested = true;
    // Wait for the current processing loop to wind down before
    // emitting a Cancelled state; the loop itself handles cleanup.
    await _processingDone?.future;
  }

  /// Shuts down the controller, closes streams + the http client.
  Future<void> dispose() async {
    _cancelRequested = true;
    await _processingDone?.future;
    await _stateCtrl.close();
    _httpDownloader.close();
  }

  Future<void> _persistQueue() async {
    await _queueStore.save(List<DownloadJob>.unmodifiable(_queue));
  }

  void _startProcessingIfIdle() {
    if (_processingDone != null && !_processingDone!.isCompleted) {
      return; // already running
    }
    _processingDone = Completer<void>();
    scheduleMicrotask(_processQueue);
  }

  Future<void> _processQueue() async {
    try {
      while (_queue.isNotEmpty) {
        if (_cancelRequested) break;
        final DownloadJob job = _queue.first;
        await _processJob(job);
        if (_cancelRequested) break;
      }
      if (_queue.isEmpty && _state is! DownloadPaused && _state is! DownloadError) {
        _emit(const DownloadIdle());
      }
    } finally {
      _cancelRequested = false;
      _pauseRequested = false;
      if (_processingDone != null && !_processingDone!.isCompleted) {
        _processingDone!.complete();
      }
    }
  }

  Future<void> _processJob(DownloadJob job) async {
    final Stopwatch wallclock = Stopwatch()..start();
    final Directory stagingDir = Directory(p.join(_appSupportDir, kStagingDir, job.alpha3.value));
    final File reassembledStaging = File(p.join(stagingDir.path, '${job.alpha3.value}.pmtiles'));
    final File finalFile = File(p.join(_appSupportDir, kCountriesDir, '${job.alpha3.value}.pmtiles'));

    try {
      // 0. Preflight.
      await _preflight(job.entry);

      // 1+2. Download + per-chunk verify.
      final List<File> partFiles = <File>[];
      for (int i = 0; i < job.entry.parts.length; i++) {
        if (_cancelRequested) {
          await _cleanupStaging(stagingDir);
          _emit(DownloadCancelled(alpha3: job.alpha3));
          _queue.removeAt(0);
          await _persistQueue();
          return;
        }
        if (_pauseRequested) {
          _emit(
            DownloadPaused(
              active: job,
              snapshot: DownloadProgress(
                bytesDownloaded: _accumulatedBytes,
                totalBytes: job.entry.reassembled.size,
                currentPartIndex: i,
                totalParts: job.entry.parts.length,
              ),
              reason: PauseReason.manual,
            ),
          );
          return;
        }

        final ChunkPart part = job.entry.parts[i];
        final String partBasename = 'part${i.toString().padLeft(2, '0')}';
        final File partFile = File(p.join(stagingDir.path, partBasename));
        final File verifiedMarker = File(p.join(stagingDir.path, '$partBasename.verified'));
        final bool preVerified = await _downloadChunkWithRetries(part: part, destination: partFile, verifiedMarker: verifiedMarker, job: job, partIndex: i);
        if (preVerified) {
          // Resume optimisation (Phase 07-07 device-smoke, 2026-04-22):
          // this chunk was already fully on disk at job start AND a
          // `.verified` sidecar marker attests that a prior session
          // completed its per-chunk sha256 check. Re-hashing here
          // would waste tens of seconds per 100 MB chunk with no
          // safety benefit — the reassembled global sha256 later
          // catches any disk-level corruption that could have crept
          // in since the marker was written.
          //
          // The marker is critical: without it, a chunk whose verify
          // was killed mid-compute on the previous run (e.g. user
          // swiped the app away during sha256 of chunk 2/4) would
          // look indistinguishable from a chunk whose verify had
          // completed, and we would wrongly skip re-verifying it.
          _log.info('chunk ${job.alpha3.value}.part$i verify: SKIPPED (pre-verified marker present)');
        } else {
          _emitInProgress(job: job, partIndex: i, phase: DownloadPhase.verifyingChunk);
          _log.info('chunk ${job.alpha3.value}.part$i verify: sha256 starting (size=${part.size})');
          await _verifyChunkWithOneRetry(part: part, partFile: partFile, job: job, partIndex: i);
          await verifiedMarker.writeAsBytes(const <int>[], flush: true);
          _log.info('chunk ${job.alpha3.value}.part$i verify: OK');
        }
        partFiles.add(partFile);
      }

      // 3. Concat.
      _emitInProgress(job: job, partIndex: job.entry.parts.length - 1, phase: DownloadPhase.concatenating);
      _log.info('concat ${job.alpha3.value}: starting (${job.entry.parts.length} parts → reassembled ${job.entry.reassembled.size} bytes)');
      await _concatenator.concat(parts: partFiles, destination: reassembledStaging);
      _log.info('concat ${job.alpha3.value}: OK');

      // 4. Global sha256.
      _emitInProgress(job: job, partIndex: job.entry.parts.length - 1, phase: DownloadPhase.verifyingFinal);
      _log.info('final verify ${job.alpha3.value}: sha256 starting (size=${job.entry.reassembled.size})');
      final String reassembledHash = await _sha256Verifier.ofFile(reassembledStaging);
      if (reassembledHash != job.entry.reassembled.sha256) {
        throw Sha256MismatchException(expected: job.entry.reassembled.sha256, actual: reassembledHash, at: 'reassembled');
      }

      // 5. Atomic rename.
      await _renamer.commit(source: reassembledStaging, target: finalFile);

      // iOS-only: mark the newly-committed file as excluded from iCloud backup.
      await _iosBackupExcluder.excludePath(finalFile.path);

      // 6. Manifest write.
      final InstalledManifest current = await _manifestRepository.read();
      final String pmtilesVersion = _extractCatalogVersion(job.entry);
      final InstalledCountry installed = InstalledCountry(
        alpha3: job.alpha3,
        installedAtUtc: DateTime.now().toUtc(),
        fileSize: await finalFile.length(),
        pmtilesVersion: pmtilesVersion,
        sha256: reassembledHash,
        filePath: p.join(kCountriesDir, '${job.alpha3.value}.pmtiles'),
      );
      final InstalledManifest next = current.copyWithInsert(installed).copyWith(catalogVersion: pmtilesVersion);
      await _manifestRepository.write(next);

      // 7. Cleanup staging.
      await _cleanupStaging(stagingDir);

      wallclock.stop();
      _emit(DownloadCompleted(alpha3: job.alpha3, totalElapsed: wallclock.elapsed));
      _queue.removeAt(0);
      await _persistQueue();
    } on Exception catch (e) {
      _log.warning('processJob ${job.alpha3.value} failed: $e');
      _emit(DownloadError(active: job, cause: e));
      // Keep staging intact for a future resume. Remove the job from
      // the head of the queue to avoid blocking subsequent entries
      // behind a persistently-failing country.
      if (_queue.isNotEmpty && _queue.first.alpha3 == job.alpha3) {
        _queue.removeAt(0);
        await _persistQueue();
      }
    }
  }

  /// Tracks bytes written across all parts of the current job. Updated
  /// by the per-chunk progress callback; used in [DownloadPaused]
  /// snapshots + [DownloadInProgress] emissions.
  int _accumulatedBytes = 0;

  Future<void> _preflight(CountryEntry entry) async {
    final int free = await _diskSpaceChecker.freeBytes(path: _appSupportDir);
    final int needed = (entry.reassembled.size * kDiskSpaceSafetyMarginMultiplier).ceil();
    if (free < needed) {
      throw DiskSpaceInsufficientException(neededBytes: needed, freeBytes: free);
    }
  }

  /// Downloads [part] into [destination] with up to
  /// [kDownloadRetryAttempts] retries on transient HTTP failures.
  ///
  /// Returns `true` ONLY when the chunk was already fully on disk at
  /// entry AND a sibling [verifiedMarker] attests that a prior session
  /// completed the per-chunk sha256 check — the caller can then skip
  /// the verify step entirely (resume optimisation). Returns `false`
  /// in every other case (fresh download, partial resume, size match
  /// without a marker, etc.) and the caller MUST run sha256.
  ///
  /// The marker is written AFTER a successful verify in `_processJob`,
  /// so its presence is a durable attestation of a completed check —
  /// not a guess based on file size alone. This matters when a prior
  /// session was killed mid-sha256: the chunk would be fully sized on
  /// disk but never actually verified, and a size-only heuristic would
  /// wrongly classify it as verified.
  Future<bool> _downloadChunkWithRetries({
    required ChunkPart part,
    required File destination,
    required File verifiedMarker,
    required DownloadJob job,
    required int partIndex,
  }) async {
    // Pre-check: skip the network round-trip when the local chunk is
    // already fully sized. The per-chunk sha256 is skipped ONLY if the
    // sibling .verified marker is also present (see the function-level
    // docstring for rationale).
    //
    // Phase 07 device-smoke (2026-04-22) — without this guard, a
    // kill-during-download that leaves a part fully written on disk
    // produces `resumeByte == server content length` on the next run,
    // which the CDN answers with `416 Range Not Satisfiable`. That
    // lands in `http_chunk_downloader`'s catch-all for 4xx-on-resume
    // and throws `HttpRangeNotSupportedException`, which
    // `DownloadInterruptedException catch` below does NOT match — so
    // the download aborts and the UI sees `DownloadError` without the
    // user ever learning the download was actually already complete.
    if (await destination.exists()) {
      final int localSize = await destination.length();
      if (localSize == part.size) {
        final bool hasVerifiedMarker = await verifiedMarker.exists();
        if (hasVerifiedMarker) {
          _log.info(
            'chunk ${job.alpha3.value}.part$partIndex staging already verified (size=$localSize, marker present) — skipping network + skipping per-chunk sha256',
          );
          _accumulatedBytes += localSize;
          _emitInProgress(job: job, partIndex: partIndex, phase: DownloadPhase.verifyingResumedData);
          return true;
        }
        // Fully sized but no marker — a prior session wrote the chunk
        // but was killed before its verify completed. Skip the network
        // round-trip, but fall through to let the caller run sha256.
        _log.info('chunk ${job.alpha3.value}.part$partIndex staging sized but unverified (no marker) — skipping network, will verify sha256');
        _accumulatedBytes += localSize;
        _emitInProgress(job: job, partIndex: partIndex);
        return false;
      }
      if (localSize > part.size) {
        _log.warning('chunk ${job.alpha3.value}.part$partIndex staging size $localSize > expected ${part.size} — deleting to restart from byte 0');
        await destination.delete();
      }
    }
    // A chunk about to be (re)downloaded is no longer trustworthy from
    // any prior verification — drop the marker so a subsequent kill
    // cannot see a stale marker pointing at just-overwritten bytes.
    if (await verifiedMarker.exists()) {
      await verifiedMarker.delete();
    }
    DownloadInterruptedException? lastError;
    for (int attempt = 0; attempt < kDownloadRetryAttempts; attempt++) {
      if (_cancelRequested) return false;
      try {
        _emitInProgress(job: job, partIndex: partIndex);
        DateTime lastEmit = DateTime.now();
        await _httpDownloader.downloadWithResume(
          url: Uri.parse(part.url),
          destination: destination,
          onProgress: (int delta, int? _) {
            _accumulatedBytes += delta;
            // Re-emit during the chunk body so the UI's percent + speed
            // readouts keep ticking between chunk boundaries. Without
            // this throttle the callback would fire for every TCP
            // segment (tens of times per second) and flood the Riverpod
            // state stream. With the 250 ms window we get ~4 updates/s
            // — enough to render a smooth speed label, cheap enough to
            // stay invisible on the CPU graph.
            final DateTime now = DateTime.now();
            if (now.difference(lastEmit).inMilliseconds < kDownloadProgressEmitThrottleMs) return;
            lastEmit = now;
            _emitInProgress(job: job, partIndex: partIndex);
          },
        );
        return false;
      } on DownloadInterruptedException catch (e) {
        lastError = e;
        // Phase 07-07 (2026-04-22): upgraded to WARNING (was INFO) and
        // emit a distinct DownloadRetrying state so the UI can show
        // "Reprise en cours" instead of a silently-frozen progress
        // bar during the backoff window.
        _log.warning('chunk ${job.alpha3.value}.part$partIndex attempt ${attempt + 1} failed: $e');
        if (attempt + 1 < kDownloadRetryAttempts) {
          _emit(
            DownloadRetrying(
              active: job,
              snapshot: DownloadProgress(
                bytesDownloaded: _accumulatedBytes.clamp(0, job.entry.reassembled.size),
                totalBytes: job.entry.reassembled.size,
                currentPartIndex: partIndex,
                totalParts: job.entry.parts.length,
              ),
              attemptIndex: attempt,
              totalAttempts: kDownloadRetryAttempts,
              cause: e,
            ),
          );
          await _backoff(attempt);
        }
      }
    }
    // Exhausted retries.
    throw lastError ?? const DownloadInterruptedException(reason: 'retry budget exhausted with no recorded cause');
  }

  /// Emits a [DownloadInProgress] snapshot reflecting the current
  /// accumulated-bytes counter + the requested [partIndex] +
  /// [phase]. Factored out so the chunk-start emit, the throttled
  /// in-body emits, and the post-transfer phase transitions all
  /// share one construction path.
  void _emitInProgress({required DownloadJob job, required int partIndex, DownloadPhase phase = DownloadPhase.transferring}) {
    _emit(
      DownloadInProgress(
        active: job,
        progress: DownloadProgress(
          bytesDownloaded: _accumulatedBytes.clamp(0, job.entry.reassembled.size),
          totalBytes: job.entry.reassembled.size,
          currentPartIndex: partIndex,
          totalParts: job.entry.parts.length,
        ),
        remaining: _queue.length > 1 ? List<DownloadJob>.unmodifiable(_queue.skip(1)) : <DownloadJob>[],
        phase: phase,
      ),
    );
  }

  Future<void> _verifyChunkWithOneRetry({required ChunkPart part, required File partFile, required DownloadJob job, required int partIndex}) async {
    final String first = await _sha256Verifier.ofFile(partFile);
    if (first == part.sha256) return;
    _log.warning('chunk ${job.alpha3.value}.part$partIndex sha256 mismatch — retrying once');
    // Delete and re-download once. The verified-marker for this chunk
    // is computed from the same basename convention as `_processJob`
    // so a stale marker (if any) is dropped by the re-download path.
    await partFile.delete();
    final File verifiedMarker = File('${partFile.path}.verified');
    await _downloadChunkWithRetries(part: part, destination: partFile, verifiedMarker: verifiedMarker, job: job, partIndex: partIndex);
    final String second = await _sha256Verifier.ofFile(partFile);
    if (second != part.sha256) {
      throw Sha256MismatchException(expected: part.sha256, actual: second, at: 'parts[$partIndex]');
    }
  }

  Future<void> _backoff(int attemptIndex) async {
    if (attemptIndex < _retryBackoffs.length) {
      await Future<void>.delayed(_retryBackoffs[attemptIndex]);
    } else {
      await Future<void>.delayed(_retryBackoffs.last);
    }
  }

  Future<void> _cleanupStaging(Directory stagingDir) async {
    if (stagingDir.existsSync()) {
      await stagingDir.delete(recursive: true);
    }
  }

  /// Extracts the GitHub-Release tag from [entry]'s first part URL.
  /// Mirrors the lazy `CountryCatalog.catalogVersion` getter but on a
  /// single entry — used so the manifest carries a per-country version
  /// without re-wiring the controller through the parent catalog.
  ///
  /// Returns a synthetic `untagged-YYYYMMDD` fallback when the URL
  /// shape does not match (fixture catalogs point at
  /// `https://example.test/...` and have no release tag). The fallback
  /// satisfies the `InstalledCountry.pmtilesVersion.length > 0`
  /// invariant.
  String _extractCatalogVersion(CountryEntry entry) {
    if (entry.parts.isEmpty) return _fallbackVersion();
    final RegExpMatch? match = RegExp(r'/releases/download/([^/]+)/').firstMatch(entry.parts.first.url);
    return match?.group(1) ?? _fallbackVersion();
  }

  String _fallbackVersion() {
    final DateTime now = DateTime.now().toUtc();
    final String yyyymmdd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'untagged-$yyyymmdd';
  }
}
