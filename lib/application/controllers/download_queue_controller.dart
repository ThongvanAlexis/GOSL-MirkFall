// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/infrastructure/downloads/pmtiles_download_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_queue_controller.g.dart';

/// UI-layer wrapper around [PmtilesDownloadController].
///
/// The infrastructure controller is deliberately non-Riverpod
/// (07-04-SUMMARY decision: plain Dart class so unit tests drive it
/// without a `ProviderContainer`). This wrapper exposes a presentation-
/// friendly surface — `enqueue` / `pause` / `resume` / `cancelActive`
/// plus an `aggregateProgressFraction` getter for the AppBar chip in
/// Plan 07-06 — and hides the infrastructure module from screens (the
/// architectural invariant from Phase 07 §CONTEXT).
///
/// Lifecycle:
/// - `keepAlive: true` — downloads must survive screen navigation.
/// - On first use, `rehydrate()` on the underlying controller is
///   triggered so any queue persisted from a prior session resumes.
///
/// State stream: exposes the infra controller's broadcast stream
/// verbatim; consumers pattern-match over the 7 `DownloadState`
/// variants for UI rendering. `current` returns the latest snapshot.
@Riverpod(keepAlive: true)
class DownloadQueueController extends _$DownloadQueueController {
  PmtilesDownloadController? _inner;
  StreamSubscription<DownloadState>? _innerSub;
  bool _rehydrated = false;

  @override
  DownloadState build() {
    ref.onDispose(() async {
      await _innerSub?.cancel();
      _innerSub = null;
    });
    _attachInnerIfReady();
    return const DownloadIdle();
  }

  /// Enqueues [entry] for download. Rehydrates the underlying queue on
  /// first call so any leftover jobs from a prior session resume first.
  Future<void> enqueue(CountryEntry entry) async {
    final PmtilesDownloadController inner = await _ensureInner();
    if (!_rehydrated) {
      _rehydrated = true;
      await inner.rehydrate();
    }
    await inner.enqueueCountry(entry);
  }

  /// Requests a pause on the in-flight job. Takes effect at the next
  /// chunk boundary — the in-flight chunk completes first.
  Future<void> pause() async {
    final inner = await _ensureInner();
    await inner.pause();
  }

  /// Resumes a previously paused job. No-op when not paused.
  Future<void> resume() async {
    final inner = await _ensureInner();
    await inner.resume();
  }

  /// Cancels the active download and discards its staging directory.
  Future<void> cancelActive() async {
    final inner = await _ensureInner();
    await inner.cancelActive();
  }

  /// Aggregate progress fraction for the AppBar progress chip.
  ///
  /// Returns `null` when the queue is idle or there is no in-flight job;
  /// otherwise returns the ACTIVE job's `fractionDone` (NOT a sum across
  /// all queued jobs). The UI presents "1 / 3 downloading at 47%" via
  /// the state variant + this getter combined — summing fractions
  /// would conflate the progress metric across files of different sizes.
  double? get aggregateProgressFraction {
    final s = state;
    if (s is DownloadInProgress) {
      return s.progress.fractionDone;
    }
    if (s is DownloadPaused) {
      return s.snapshot.fractionDone;
    }
    return null;
  }

  /// Currently-queued jobs (excluding the active one) in FIFO order —
  /// mirrors the infra controller's `queuedJobs`.
  List<DownloadJob> get queuedJobs {
    final inner = _inner;
    if (inner == null) return const <DownloadJob>[];
    return inner.queuedJobs;
  }

  Future<PmtilesDownloadController> _ensureInner() async {
    if (_inner != null) return _inner!;
    final inner = await ref.read(pmtilesDownloadControllerProvider.future);
    _attachInner(inner);
    return inner;
  }

  void _attachInnerIfReady() {
    // Best-effort eager attach — the provider is a FutureProvider so
    // reading it synchronously returns AsyncLoading initially. The
    // real subscription lands on first public-entry call via
    // _ensureInner().
    final AsyncValue<PmtilesDownloadController> snap = ref.read(pmtilesDownloadControllerProvider);
    final PmtilesDownloadController? value = snap.value;
    if (value != null) _attachInner(value);
  }

  void _attachInner(PmtilesDownloadController inner) {
    if (identical(inner, _inner)) return;
    _innerSub?.cancel();
    _inner = inner;
    state = inner.state;
    _innerSub = inner.stateStream.listen((DownloadState next) {
      state = next;
    });
  }
}
