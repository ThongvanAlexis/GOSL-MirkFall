// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — port of the POC `DevMarkerLogger`
// (`mirk-poc-debug` @ 90c9321, `lib/infrastructure/mirk/dev_marker_logger.dart`).
// Changes vs the POC: instance (`const DevMarkerLogger()`, constructor-injected
// per CLAUDE.md §Dependency Injection) instead of a static namespace,
// `emit(tag:)` → `mark(label)`, verbose-only gating (CLAUDE.md §Logging).
// The JSONL payload is unchanged (`event` / `tag` / `epochMs`).

import 'dart:convert';

import 'package:logging/logging.dart';

/// Developer-observation marker — POC diagnostic, active only in verbose
/// logging (`--dart-define=DEBUG=true` or the debug-menu toggle) — CLAUDE.md §Logging.
///
/// One JSONL line per [mark] call, on `Logger('infrastructure.mirk.dev_marker')`,
/// so post-walk grep can correlate the moment the developer SAW a symptom
/// against the per-second `frame_delta` / `fog_transform` rollups. The line
/// carries a wall-clock `epochMs` (sub-second, finer than the rollup windows it
/// is matched against) and the free-form [mark] label under the POC `tag` key.
///
/// No camera state is captured here: the rollup streams already carry
/// pixelOrigin / canvasTransform / centre continuously; the marker only needs
/// a timestamp pointing at the right window.
class DevMarkerLogger {
  /// Creates a stateless marker logger.
  const DevMarkerLogger();

  static final Logger _log = Logger('infrastructure.mirk.dev_marker');

  /// Whether the diagnostic is enabled (verbose logging active).
  bool get _isVerbose => _log.isLoggable(Level.FINE);

  /// Emits `{"event":"dev_marker","tag":"<label>","epochMs":<int>}` at INFO,
  /// or nothing when verbose logging is off. [label] should be a short
  /// snake_case symptom identifier (e.g. `steppy_translation`).
  void mark(String label) {
    if (!_isVerbose) return;
    final int epochMs = DateTime.now().millisecondsSinceEpoch;
    _log.info(json.encode(<String, Object>{'event': 'dev_marker', 'tag': label, 'epochMs': epochMs}));
  }
}
