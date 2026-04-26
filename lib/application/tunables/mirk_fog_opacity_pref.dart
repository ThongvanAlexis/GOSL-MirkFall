// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence helpers for the user-facing fog density slider.
///
/// The slider lives in the session burger menu (`SessionBurgerMenu`) and
/// drives all three opacity octaves of [MirkRuntimeTunables] at once, so
/// the user can pick a single "fog density" value without juggling the
/// per-octave sliders exposed in the dev tuner sheet.
///
/// Persistence is a single double under [kMirkFogOpacityPrefsKey]. Read
/// at app boot in `main.dart` (so the user's choice survives across
/// launches) and written on every slider change. SharedPreferences async
/// writes are cheap (~1 ms on hot path), so we write eagerly rather than
/// debouncing — keeps the code path trivially testable.
class MirkFogOpacityPref {
  const MirkFogOpacityPref._();

  /// Reads the persisted fog opacity from [SharedPreferences], or returns
  /// `null` if no value has been written yet (first launch). Caller is
  /// expected to fall back to the baked default ([kMirkFogOpacityFar])
  /// when the result is `null`.
  ///
  /// Clamped to `[kMirkFogOpacityMin .. kMirkFogOpacityMax]` so a stored
  /// out-of-range value (range tightened in code, manual-edit, etc.)
  /// can never propagate into the renderer.
  static Future<double?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(kMirkFogOpacityPrefsKey);
    if (raw == null) return null;
    return raw.clamp(kMirkFogOpacityMin, kMirkFogOpacityMax);
  }

  /// Writes [value] to [SharedPreferences] under [kMirkFogOpacityPrefsKey].
  /// Clamps the input so a callsite that forgot to clamp cannot persist
  /// an out-of-range value.
  static Future<void> write(double value) async {
    final clamped = value.clamp(kMirkFogOpacityMin, kMirkFogOpacityMax);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kMirkFogOpacityPrefsKey, clamped);
  }

  /// Applies [value] to all three opacity octaves of [MirkRuntimeTunables]
  /// AND persists it. Single source of truth for the slider's onChanged
  /// path so the slider widget stays trivial.
  static Future<void> applyAndPersist(double value) async {
    final clamped = value.clamp(kMirkFogOpacityMin, kMirkFogOpacityMax);
    final tunables = MirkRuntimeTunables.instance;
    tunables.opacityFar = clamped;
    tunables.opacityMid = clamped;
    tunables.opacityNear = clamped;
    await write(clamped);
  }

  /// Reads the persisted value and applies it to [MirkRuntimeTunables] —
  /// the synchronous boot-time path. Called from `main.dart` BEFORE
  /// `runApp` so the renderers paint the user's choice on the first
  /// frame. No-op if no value has been written yet (first launch — the
  /// constants.dart defaults already populate the tunables).
  static Future<void> applyOnBoot() async {
    final stored = await read();
    if (stored == null) return;
    final tunables = MirkRuntimeTunables.instance;
    tunables.opacityFar = stored;
    tunables.opacityMid = stored;
    tunables.opacityNear = stored;
  }
}
