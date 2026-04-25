// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Builds the deterministic 50k-row fixture at
/// `test/fixtures/mirk/fifty_k_tiles_seed.sql` for the Phase 09 perf probe.
///
/// Wave 0 scaffold — body lands in plan 09-08. See 09-RESEARCH §Fixture 50k
/// Strategy + Format for the seed + layout spec.
///
/// Throws [UnimplementedError] until Wave 7 wires the real builder so any
/// accidental Wave 0 invocation fails loudly rather than producing an
/// empty / partial fixture file that downstream perf tests would silently
/// skip.
void main(List<String> args) {
  throw UnimplementedError('Wave 7 — plan 09-08');
}
