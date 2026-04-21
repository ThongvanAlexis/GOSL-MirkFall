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
        final File partFile = File(p.join(stagingDir.path, 'part${i.toString().padLeft(2, '0')}'));
        await _downloadChunkWithRetries(part: part, destination: partFile, job: job, partIndex: i);
        await _verifyChunkWithOneRetry(part: part, partFile: partFile, job: job, partIndex: i);
        partFiles.add(partFile);
      }

      // 3. Concat.
      await _concatenator.concat(parts: partFiles, destination: reassembledStaging);

      // 4. Global sha256.
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

  Future<void> _downloadChunkWithRetries({required ChunkPart part, required File destination, required DownloadJob job, required int partIndex}) async {
    DownloadInterruptedException? lastError;
    for (int attempt = 0; attempt < kDownloadRetryAttempts; attempt++) {
      if (_cancelRequested) return;
      try {
        _emit(
          DownloadInProgress(
            active: job,
            progress: DownloadProgress(
              bytesDownloaded: _accumulatedBytes,
              totalBytes: job.entry.reassembled.size,
              currentPartIndex: partIndex,
              totalParts: job.entry.parts.length,
            ),
            remaining: _queue.length > 1 ? List<DownloadJob>.unmodifiable(_queue.skip(1)) : <DownloadJob>[],
          ),
        );
        await _httpDownloader.downloadWithResume(
          url: Uri.parse(part.url),
          destination: destination,
          onProgress: (int delta, int? _) {
            _accumulatedBytes += delta;
          },
        );
        return;
      } on DownloadInterruptedException catch (e) {
        lastError = e;
        _log.info('chunk ${job.alpha3.value}.part$partIndex attempt ${attempt + 1} failed: $e');
        if (attempt + 1 < kDownloadRetryAttempts) {
          await _backoff(attempt);
        }
      }
    }
    // Exhausted retries.
    throw lastError ?? const DownloadInterruptedException(reason: 'retry budget exhausted with no recorded cause');
  }

  Future<void> _verifyChunkWithOneRetry({required ChunkPart part, required File partFile, required DownloadJob job, required int partIndex}) async {
    final String first = await _sha256Verifier.ofFile(partFile);
    if (first == part.sha256) return;
    _log.warning('chunk ${job.alpha3.value}.part$partIndex sha256 mismatch — retrying once');
    // Delete and re-download once.
    await partFile.delete();
    await _downloadChunkWithRetries(part: part, destination: partFile, job: job, partIndex: partIndex);
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
