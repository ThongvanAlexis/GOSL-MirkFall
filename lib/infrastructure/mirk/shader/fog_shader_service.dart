// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' as ui;

/// Loader / cache for the volumetric fog `ui.FragmentProgram`.
///
/// Phase 09 BUG-009 (TIER 2). The actual `.frag` body grows over the
/// commit sequence (placeholder → 3D-FBM → curl → parallax → faux
/// shading → boundary → hue). This service handles the parts that
/// stay constant: asset loading with try/catch, single-program cache,
/// `FragmentShader` reuse across frames.
///
/// ## Why a service rather than a top-level future
///
/// 1. Test seam — production callers depend on the service shape, tests
///    can construct a [FogShaderService.test] that returns a stub or a
///    `null` program (simulating a load failure to exercise the Paint
///    fallback path in the renderers).
/// 2. Per-asset caching — each `.frag` has one [FragmentProgram];
///    `program.fragmentShader()` returns a cheap bag of uniforms that
///    callers reuse across frames.
/// 3. Lifecycle — Phase 13 will load multiple shaders (user-imported
///    `ShaderConfig` payloads). The service shape extends naturally.
///
/// ## Foot-guns guarded
///
/// * Invalid asset path crashes the app under Impeller (issue #108037).
///   [load] wraps `FragmentProgram.fromAsset` in try/catch and stores
///   the error so callers can fall back to a Paint-only path.
/// * `FragmentProgram.fromAsset` is async — never call from within a
///   `build()` synchronously. Call once on renderer construction; cache
///   the resulting Future.
class FogShaderService {
  /// Constructs a service that loads [assetPath] on first [load] call
  /// and memoises the result.
  FogShaderService({this.assetPath = 'assets/shaders/atmospheric_fog.frag'});

  /// Path to the `.frag` asset. Default points at the BUG-009 fog
  /// shader; tests can override with a stub asset.
  final String assetPath;

  /// Cached future result of [load]. First caller triggers the load;
  /// subsequent callers reuse the same future.
  ///
  /// Resolved value: a [ui.FragmentProgram] on success or `null` on
  /// load failure (caller falls back to the Paint-only path).
  Future<ui.FragmentProgram?>? _programFuture;

  /// Whether [load] has been called at least once. Tests can assert
  /// the lazy-load contract.
  bool get hasLoadStarted => _programFuture != null;

  /// Loads the fragment program at [assetPath] and caches the future.
  /// Calls after the first reuse the cached value.
  ///
  /// Returns `null` if the asset cannot be loaded (invalid path,
  /// shader compile error, missing pubspec entry). The renderer calls
  /// this once at construction and falls back to a Paint-only path if
  /// it returns `null` — production never crashes on a missing shader.
  Future<ui.FragmentProgram?> load() {
    final cached = _programFuture;
    if (cached != null) return cached;
    // Chain a side-effect capture so [obtainShaderSync] has a
    // synchronous handle on the program once the load resolves. The
    // captured value is null on load failure (matches the contract).
    final future = _loadInternal().then((program) {
      _resolvedProgram = program;
      return program;
    });
    _programFuture = future;
    return future;
  }

  /// Inner load helper. Catches the entire error space (`Object`)
  /// because `FragmentProgram.fromAsset` can throw `Exception`,
  /// `AssertionError` (invalid asset path on debug builds), or
  /// platform-specific compilation errors. We don't care about the
  /// type — we only need a bool "did this succeed".
  Future<ui.FragmentProgram?> _loadInternal() async {
    try {
      return await ui.FragmentProgram.fromAsset(assetPath);
    } catch (_) {
      // Swallow — caller falls back to Paint-only path. The exact
      // failure mode is irrelevant to the renderer; a Paint-fallback
      // is already a graceful degradation.
      return null;
    }
  }

  /// Returns a fresh [ui.FragmentShader] from the loaded program, or
  /// `null` if the load failed. Each call returns a new shader
  /// instance — callers should NOT cache the result across frames
  /// because [ui.FragmentShader] uniforms are stateful and would
  /// require re-setting every frame anyway.
  ///
  /// More efficient pattern for renderers: cache the Future from
  /// [load], extract one [ui.FragmentShader] when the program
  /// resolves, then reuse that single shader and call setFloat /
  /// setImageSampler on it before each `canvas.drawRect`.
  Future<ui.FragmentShader?> obtainShader() async {
    final program = await load();
    return program?.fragmentShader();
  }

  /// Synchronous accessor — returns a fresh `ui.FragmentShader` if the
  /// program has already loaded successfully, or `null` otherwise (load
  /// not yet started, still in flight, or failed).
  ///
  /// This is the hot-path call inside `MirkRenderer.paint`: paint runs
  /// every frame and cannot block on a Future. The first frames after
  /// construction may return null while the program is loading; the
  /// renderer falls back to its CPU path, then picks up the shader on
  /// a subsequent frame once `_shaderProgramSync` is non-null.
  ///
  /// Internally watches the cached Future from [load] and snapshots the
  /// resolved value to a synchronous field via `.then`. Tests can
  /// `await load()` first to guarantee a non-null return.
  ui.FragmentShader? obtainShaderSync() {
    final program = _resolvedProgram;
    return program?.fragmentShader();
  }

  /// Resolved program value — written by the [.then] callback chained
  /// onto [load]. Null until the future resolves successfully; stays
  /// null forever on load failure.
  ui.FragmentProgram? _resolvedProgram;
}
