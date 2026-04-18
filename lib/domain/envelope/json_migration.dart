// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Single step of the versioned JSON migration chain.
///
/// Each [JsonMigration] migrates `payload` from its [fromVersion] to
/// `fromVersion + 1`. [`JsonMigrator`] composes a list of these into a
/// chain and walks them sequentially when asked to migrate a payload
/// across multiple versions.
abstract class JsonMigration {
  /// Version this step accepts as input. Output version is
  /// `fromVersion + 1` by contract.
  int get fromVersion;

  /// Returns a NEW map representing [payload] migrated to `fromVersion + 1`.
  ///
  /// MUST NOT mutate [payload] in place — callers rely on the input
  /// surviving across the call (the chain executor reuses it on
  /// downgrade-detection paths).
  Map<String, Object?> apply(Map<String, Object?> payload);
}
