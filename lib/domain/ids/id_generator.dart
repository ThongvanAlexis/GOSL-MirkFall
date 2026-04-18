// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Abstract seam for ID generation.
///
/// Implementations live under `lib/infrastructure/ids/` so the domain layer
/// stays toolchain-independent. Tests inject `SeededIdGenerator` to make ID
/// sequences deterministic; production code wires `RandomIdGenerator` via
/// Riverpod (see Phase 03 store wiring).
abstract class IdGenerator {
  /// Returns a unique identifier prefixed with [prefix] (e.g. `'sess_'`).
  ///
  /// Total length = `prefix.length + 26` (26-char ULID body).
  String newId(String prefix);
}
