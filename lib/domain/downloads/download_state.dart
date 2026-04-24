// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters (analyzer can't see it through the factory indirection).

import 'package:freezed_annotation/freezed_annotation.dart';

import '../map/country_code.dart';
import 'download_job.dart';

part 'download_state.freezed.dart';

/// Sealed hierarchy describing the state of the per-country download
/// pipeline at any point in time.
///
/// Eight variants covering the full lifecycle, partitioned into three
/// groups :
///
/// **Quiescent** (no active job, no in-flight work) :
/// - [DownloadIdle] — no active queue, no pending jobs
/// - [DownloadQueued] — jobs persisted, loop not yet started
///
/// **Running** (one job is active; carries `active` + `snapshot`) :
/// - [DownloadInProgress] — actively transferring (default)
///                         or concatenating (post-transfer phase)
/// - [DownloadRetrying]  — between retry attempts (backoff in flight)
/// - [DownloadPaused]    — paused by user / connectivity / retry-exhaust
///
/// **Terminal** (one job has concluded; UI surfaces result + moves on) :
/// - [DownloadError]     — errored ; non-terminal from the caller's
///                         perspective (retry button returns to Queued)
/// - [DownloadCompleted] — terminal success
/// - [DownloadCancelled] — terminal cancellation (user action)
///
/// Valid transition graph :
///
/// ```
///                  ┌─────────────┐
///                  │    Idle     │◀─────────────────────┐
///                  └──────┬──────┘                      │
///                   enqueue() / rehydrate              drain
///                         ▼                             │
///                  ┌─────────────┐                      │
///         ┌───────▶│   Queued    │◀─┐                   │
///         │        └──────┬──────┘  │                   │
///         │        loop picks job   │                   │
///         │               ▼         │                   │
///      retry      ┌──────────────┐  │ retry /           │
///      success    │  InProgress  │  │ continue next     │
///         │       └──┬──┬──┬─────┘  │                   │
///         │     pause│  │  │error   │                   │
///         │          │  │  │        │                   │
///         │          ▼  │  ▼        │                   │
///         │    ┌──────────┐  ┌─────────────┐            │
///         │    │  Paused  │  │    Error    │────────────┤
///         │    └────┬─────┘  └─────────────┘            │
///         │  resume │                                   │
///         │         ▼                                   │
///         │   ┌──────────────┐                          │
///         └───│  Retrying    │                          │
///             └──────┬───────┘                          │
///                    │ reassembled sha ok               │
///                    ▼                                  │
///             ┌──────────────┐     cancelActive ┌──────────────┐
///             │  Completed   │     ───────────▶ │  Cancelled   │
///             └──────────────┘                  └──────────────┘
/// ```
///
/// Row #29 (Could, [smell:over-state-machine]) : the 8 variants DO form
/// a valid graph when grouped as above. The earlier concern was the
/// per-variant dispatcher duplication — resolved in row #20 via the
/// [DownloadStateActive] extension's `activeJob` + `activeSnapshot`
/// polymorphic getters, so UI code no longer pattern-matches over
/// InProgress / Retrying / Paused individually for field access. The
/// remaining transition graph above is the minimum required by the UI
/// contract (pause semantics + retry visibility + terminal
/// surfacing) — no variant can be collapsed without losing user-
/// visible signal.
///
/// Callers pattern-match exhaustively (Dart-3 sealed semantics) —
/// downstream plans MUST NOT add `is DownloadX` chains, which would
/// silently skip new variants.
sealed class DownloadState {
  const DownloadState();
}

/// No active queue. Start of life for the controller; the transition
/// path `Idle -> Queued -> InProgress -> (Paused <-> InProgress) ->
/// (Completed | Error | Cancelled) -> (Idle | Queued)` is driven by
/// Plan 07-04's controller.
final class DownloadIdle extends DownloadState {
  const DownloadIdle();
}

/// One or more jobs waiting; none has started transferring yet. [queue]
/// is snapshot-immutable per Freezed convention (copies go through
/// `copyWith`).
final class DownloadQueued extends DownloadState {
  const DownloadQueued({required this.queue});

  final List<DownloadJob> queue;
}

/// Post-transfer phase the active job is currently in. Drives UI copy
/// so the user is never left staring at a frozen progress bar —
/// `transferring` is the default (network bytes flowing), while
/// `concatenating` covers the on-device single-pass step that streams
/// every chunk into the reassembled file while computing its sha256
/// inline. The concat's returned hash is the single correctness gate
/// for the whole download; no separate per-chunk or final-verify
/// phase is needed.
///
/// - `transferring`: bytes in flight from the CDN. Default.
/// - `concatenating`: streaming chunks into the reassembled file +
///   computing the final sha256 in the same pass.
enum DownloadPhase { transferring, concatenating }

/// The active job is transferring (or in a post-transfer verification
/// phase — see [phase]). [remaining] lists the jobs still queued
/// behind it (possibly empty — single-job downloads are a
/// [DownloadInProgress] with empty [remaining]).
///
/// [snapshot] is the current progress reading. Named `snapshot` (not
/// `progress`) to match [DownloadRetrying.snapshot] and
/// [DownloadPaused.snapshot] — all three variants carry a
/// `DownloadProgress` under the same field name so polymorphic
/// dispatch can use a single pattern arm instead of three per-variant
/// arms that only differ by field access.
final class DownloadInProgress extends DownloadState {
  const DownloadInProgress({required this.active, required this.snapshot, required this.remaining, this.phase = DownloadPhase.transferring});

  final DownloadJob active;
  final DownloadProgress snapshot;
  final List<DownloadJob> remaining;
  final DownloadPhase phase;
}

/// The active job hit a transient failure (stream stall, HTTP error,
/// etc.) and is between retry attempts — the backoff delay is in
/// flight. Transitions back to [DownloadInProgress] when the next
/// attempt starts transferring, or to [DownloadError] if the retry
/// budget is exhausted.
///
/// Distinct from [DownloadPaused] — pauses are discrete lifecycle
/// events driven by user action / connectivity loss / retry-exhaustion,
/// whereas retrying is the short-lived in-between state of the pipeline
/// regaining footing. Phase 07-07 introduced this so the UI can render
/// "Reprise en cours (tentative N/M)" instead of showing a silently-
/// frozen progress bar for up to 30 s + backoff while a stall timeout
/// unwinds.
///
/// [attemptIndex] is 0-indexed and refers to the attempt that JUST
/// failed; the next attempt will be `attemptIndex + 1`. [totalAttempts]
/// mirrors `kDownloadRetryAttempts`.
final class DownloadRetrying extends DownloadState {
  const DownloadRetrying({required this.active, required this.snapshot, required this.attemptIndex, required this.totalAttempts, required this.cause});

  final DownloadJob active;
  final DownloadProgress snapshot;
  final int attemptIndex;
  final int totalAttempts;
  final Exception cause;
}

/// The active job is paused; [snapshot] captures the progress at the
/// pause moment so the UI can render a resume-from-X indicator without
/// refetching anything.
final class DownloadPaused extends DownloadState {
  const DownloadPaused({required this.active, required this.snapshot, required this.reason});

  final DownloadJob active;
  final DownloadProgress snapshot;
  final PauseReason reason;
}

/// The active job errored. [cause] carries the originating exception
/// (typically one of the download-layer exceptions from
/// `download_errors.dart`). Non-terminal from the caller's perspective:
/// the UI may show a retry button that transitions back through
/// [DownloadQueued].
final class DownloadError extends DownloadState {
  const DownloadError({required this.active, required this.cause});

  final DownloadJob active;
  final Exception cause;
}

/// Terminal state — job finished successfully. Carries [totalElapsed]
/// for telemetry-free on-screen display (local time measurement, not
/// sent anywhere per CLAUDE.md §télémétrie interdite).
final class DownloadCompleted extends DownloadState {
  const DownloadCompleted({required this.alpha3, required this.totalElapsed});

  final CountryCode alpha3;
  final Duration totalElapsed;
}

/// Terminal state — job was cancelled by user action (delete from
/// queue, or explicit cancel on the in-flight job). Staging files are
/// cleaned up by the pipeline.
final class DownloadCancelled extends DownloadState {
  const DownloadCancelled({required this.alpha3});

  final CountryCode alpha3;
}

/// Why the active download was paused. Drives UI copy + auto-resume
/// policy (see Plan 07-04).
///
/// - `manual`: user tapped pause. Resume requires user action.
/// - `networkLost`: connectivity loss. Resume auto-triggers when the
///   network comes back (`connectivity_plus`-style monitoring is
///   infrastructure-layer).
/// - `retryExhausted`: the pipeline's retry budget was exceeded. Same
///   surface as `manual` for the user; distinct field lets telemetry-free
///   on-device logs distinguish failure modes.
enum PauseReason { manual, networkLost, retryExhausted }

/// Progress snapshot for an in-flight [DownloadJob].
///
/// Carries the total bytes + downloaded bytes + part-index counters so
/// the UI can render both a byte-level progress bar and a
/// "part N of M" label. [fractionDone] is a derived getter — NOT stored
/// — to keep the type purely functional and to avoid consistency drift
/// if `bytesDownloaded` / `totalBytes` were ever updated out of sync.
@freezed
abstract class DownloadProgress with _$DownloadProgress {
  @Assert('bytesDownloaded >= 0', 'DownloadProgress.bytesDownloaded must be >= 0')
  @Assert('totalBytes > 0', 'DownloadProgress.totalBytes must be > 0')
  @Assert('bytesDownloaded <= totalBytes', 'DownloadProgress.bytesDownloaded must be <= totalBytes')
  @Assert('currentPartIndex >= 0', 'DownloadProgress.currentPartIndex must be >= 0')
  @Assert('totalParts > 0', 'DownloadProgress.totalParts must be > 0')
  @Assert('currentPartIndex < totalParts', 'DownloadProgress.currentPartIndex must be < totalParts')
  factory DownloadProgress({required int bytesDownloaded, required int totalBytes, required int currentPartIndex, required int totalParts}) = _DownloadProgress;
}

/// Convenience getters on [DownloadProgress] — kept in an extension so
/// the Freezed constructor signature stays minimal.
extension DownloadProgressFraction on DownloadProgress {
  /// Fraction of total bytes transferred, in `[0.0, 1.0]`. Division is
  /// safe because `@Assert('totalBytes > 0')` rejects zero at
  /// construction time.
  double get fractionDone => bytesDownloaded / totalBytes;
}

/// Polymorphic getters on [DownloadState] for the three variants that
/// carry an active [DownloadJob] + a progress [snapshot]
/// ([DownloadInProgress], [DownloadRetrying], [DownloadPaused]).
///
/// Consumers that only need "the current active job" / "the current
/// snapshot" should use these getters instead of dispatching on each
/// variant in a `switch`. The dispatch lives here once; UI code stays
/// flat.
///
/// Terminal-variant states ([DownloadIdle], [DownloadQueued],
/// [DownloadError], [DownloadCompleted], [DownloadCancelled]) return
/// `null` — they have no "currently running" job with a live snapshot.
/// Callers that need to distinguish the three active variants
/// (in-progress vs retrying vs paused) still pattern-match; these
/// getters cover the common "is there an active job at all" case.
extension DownloadStateActive on DownloadState {
  /// The active [DownloadJob] when the state is one of the three
  /// running variants, `null` otherwise.
  DownloadJob? get activeJob => switch (this) {
    DownloadInProgress(:final active) => active,
    DownloadRetrying(:final active) => active,
    DownloadPaused(:final active) => active,
    _ => null,
  };

  /// The current [DownloadProgress] snapshot when the state is one of
  /// the three running variants, `null` otherwise.
  DownloadProgress? get activeSnapshot => switch (this) {
    DownloadInProgress(:final snapshot) => snapshot,
    DownloadRetrying(:final snapshot) => snapshot,
    DownloadPaused(:final snapshot) => snapshot,
    _ => null,
  };
}
