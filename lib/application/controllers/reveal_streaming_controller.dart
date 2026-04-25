// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Buffers GPS fixes during a session and merges them into the
/// `RevealedTileStore` on a flush trigger.
///
/// Phase 09 Wave 0 scaffold. Wave 5 (plan 09-06) supplies the body
/// (debounce/coalesce algorithm, time- + count-bound flush, initial 20 m
/// reveal on session start). Method surface mirrors §Reveal Streaming
/// Controller in 09-RESEARCH.
class RevealStreamingController {
  // TODO(09-06): constructor accepts RevealedTileStore + flush settings.
  RevealStreamingController();

  /// Consumes a GPS fix and schedules the reveal mask merge.
  Future<void> onFix(/* Fix fix */) async => throw UnimplementedError('Wave 5 — plan 09-06');

  /// Flushes any buffered reveals (time-bound or count-bound trigger).
  Future<void> flush() async => throw UnimplementedError('Wave 5 — plan 09-06');

  /// Writes the initial 20 m reveal around [fix] at session start.
  Future<void> revealInitial(/* Fix fix */) async => throw UnimplementedError('Wave 5 — plan 09-06');

  /// Releases buffered state. Idempotent.
  Future<void> dispose() async => throw UnimplementedError('Wave 5 — plan 09-06');
}
