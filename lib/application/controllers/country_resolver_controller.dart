// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderSubscription;
import 'package:mirkfall/infrastructure/map/country_resolver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'country_resolver_controller.g.dart';

/// Snapshot of the country-resolver state.
///
/// - [activeCountry]: the alpha3 whose PMTiles source the MapView is
///   currently showing. `null` when the world bundle is active (viewport
///   below `zoom<3` OR viewport not in any installed polygon).
/// - [viewportCountry]: the alpha3 the viewport centre currently falls
///   in. Equals [activeCountry] when the viewport country is installed;
///   differs when the viewport has panned into a non-installed country
///   (the banner data for "Télécharger ce pays").
/// - [viewportInInstalled]: true iff [viewportCountry] is present in the
///   installed manifest — used by the Plan 07-06 "download this country"
///   banner.
class CountryResolverState {
  const CountryResolverState({this.activeCountry, this.viewportCountry, this.viewportInInstalled = false});

  final CountryCode? activeCountry;
  final CountryCode? viewportCountry;
  final bool viewportInInstalled;

  CountryResolverState copyWith({Object? activeCountry = _sentinel, Object? viewportCountry = _sentinel, bool? viewportInInstalled}) {
    return CountryResolverState(
      activeCountry: identical(activeCountry, _sentinel) ? this.activeCountry : activeCountry as CountryCode?,
      viewportCountry: identical(viewportCountry, _sentinel) ? this.viewportCountry : viewportCountry as CountryCode?,
      viewportInInstalled: viewportInInstalled ?? this.viewportInInstalled,
    );
  }

  /// Sentinel value so `copyWith` can distinguish "not passed" from
  /// "explicitly passed null". Dart's optional-named-arg semantics treat
  /// `null` as "provided null" by default; we need the tri-state.
  static const Object _sentinel = Object();
}

/// Orchestrates viewport → country hot-swap.
///
/// Subscribes to [MapView.viewportUpdates] (debounced 500 ms) and runs
/// each settled viewport through a [CountryResolver]. Behaviour:
///
/// - Result equals current active → no-op.
/// - Result is a DIFFERENT installed country → set activeCountry to the
///   new alpha3 + call `mapView.showMap(newAlpha3)` (the MapLibre adapter
///   reloads the style with the new PMTiles source).
/// - Result is a DIFFERENT country NOT installed → update
///   viewportCountry + viewportInInstalled=false (UI surfaces the banner);
///   activeCountry stays on whatever was last showing.
/// - Result is `null` (water / zoom<3) → set activeCountry=null +
///   `mapView.showMap(null)` switches to the world bundle.
///
/// Re-derivation trigger: [installedManifestProvider] changes (country
/// added / removed) cause a rebuild of the internal [CountryResolver]
/// polygon map via [CountryPolygonLoader]. The controller re-runs the
/// resolve on the last-known viewport + emits the new active state.
@Riverpod(keepAlive: true)
class CountryResolverController extends _$CountryResolverController {
  static final Logger _log = Logger('application.controllers.country_resolver');

  /// Debounce window on viewport updates. 500 ms matches the Plan 07-03
  /// CountryResolver's own `resolveForViewportUpdates` default; keeps
  /// continuous-gesture panning off the point-in-polygon hot path.
  static const Duration _kViewportDebounce = Duration(milliseconds: 500);

  MapView? _mapView;
  StreamSubscription<({double latitude, double longitude, double zoom})>? _viewportSub;
  ProviderSubscription<AsyncValue<InstalledManifest>>? _manifestSub;
  Timer? _debounceTimer;
  ({double latitude, double longitude, double zoom})? _lastViewport;
  CountryResolver _resolver = CountryResolver(installedPolygons: const <CountryCode, List<CountryPolygonRing>>{});
  CountryPolygonLoader _polygonLoader = CountryPolygonLoader();

  @override
  CountryResolverState build() {
    ref.onDispose(_tearDown);
    // Re-attach the viewport subscription whenever the MapViewHolder
    // publishes a new adapter — the widget's onReady callback fires
    // AFTER build(), so the initial attach would otherwise miss the
    // first-ever MapView publication.
    ref.listen<MapView?>(mapViewProvider, (previous, next) {
      _attachMapViewIfReady();
    });
    _attachIfNeeded();
    return const CountryResolverState();
  }

  /// Injects a non-default [CountryPolygonLoader] — test seam so unit
  /// tests can feed deterministic polygons without loading real GeoJSON
  /// from `rootBundle`.
  // ignore: use_setters_to_change_properties — this is a deliberate
  // injection method, not a property setter; setter conversion would
  // imply the value is a stored attribute rather than a test-only seam.
  void setPolygonLoaderForTest(CountryPolygonLoader loader) {
    _polygonLoader = loader;
  }

  /// Force-runs the resolver on the last seen viewport. Useful after
  /// the installed manifest changes (resolver rebuild) + after a new
  /// country is installed (the user's current viewport may now hit an
  /// installed polygon).
  Future<void> rerunForLastViewport() async {
    final v = _lastViewport;
    if (v == null) return;
    await _resolveAndApply(v);
  }

  /// Stateless point-in-polygon lookup against the currently-loaded
  /// installed polygons. Returns the alpha3 whose polygon contains
  /// `(latitude, longitude)` at `zoom`, or `null` for world fallback.
  ///
  /// Unlike the stream-driven `activeCountry` / `viewportCountry`
  /// fields (which only populate after a viewport event flows through
  /// the adapter stream), this method reads the resolver's in-memory
  /// polygon table directly — callable at any time from Dart, including
  /// during widget `build` before any map instance exists.
  ///
  /// Phase 07-07 device-smoke (2026-04-22) uses this from
  /// `MapScreen._buildMapStack` to seed `MapLibreMapViewWidget`'s
  /// `initialCountry` from the active session's `lastFix`. With that
  /// seed the map boots directly on the country's style (no
  /// world → country transient), surviving even an iOS-triggered
  /// background-kill that wipes Riverpod keepAlive state: the installed
  /// polygons have just been reloaded by `_rebuildResolver` on app
  /// start, so the lookup is reliable.
  ///
  /// Returns `null` if the polygons have not yet been loaded
  /// (cold-start race); callers should treat that as "unknown, use
  /// world" rather than an error.
  CountryCode? resolveForPoint({required double latitude, required double longitude, required double zoom}) {
    return _resolver.resolve(latitude: latitude, longitude: longitude, zoom: zoom);
  }

  /// Test-facing hook to synchronously rebuild the resolver from the
  /// currently-known manifest. Bypasses `ref.listen`'s async dispatch
  /// so unit tests can deterministically seed polygons + manifest +
  /// then resolve, without relying on microtask scheduling.
  @visibleForTesting
  Future<void> rebuildNowForTest() async {
    final AsyncValue<InstalledManifest> snap = ref.read(installedManifestProvider);
    final InstalledManifest manifest = snap.value ?? InstalledManifest.empty();
    await _rebuildResolver(manifest);
  }

  void _attachIfNeeded() {
    _attachMapViewIfReady();
    _attachManifestListenerIfNeeded();
  }

  void _attachMapViewIfReady() {
    final MapView? current = ref.read(mapViewProvider);
    if (current == null) {
      // Adapter was cleared (MapScreen popped). Drop stale reference
      // + cancel subscription so subsequent viewport events don't
      // invoke showMap on a disposed native surface.
      _viewportSub?.cancel();
      _viewportSub = null;
      _mapView = null;
      return;
    }
    if (identical(current, _mapView)) return;
    _viewportSub?.cancel();
    _mapView = current;
    _viewportSub = current.viewportUpdates.listen(
      _onViewportUpdate,
      onError: (Object e, StackTrace st) {
        _log.warning('viewport stream error', e, st);
      },
    );
  }

  StreamSubscription<InstalledManifest>? _manifestStreamSub;

  void _attachManifestListenerIfNeeded() {
    // Primary path: watch installedManifestProvider. Triggers a rebuild
    // whenever the StreamProvider emits a new manifest.
    _manifestSub ??= ref.listen<AsyncValue<InstalledManifest>>(installedManifestProvider, (previous, next) {
      final value = next.value;
      if (value != null) {
        unawaited(_rebuildResolver(value));
      }
    }, fireImmediately: true);
    // Secondary path: listen directly to the repo's broadcast stream —
    // ensures resolver rebuilds even if the StreamProvider layer has not
    // been subscribed (test scenarios that bypass the provider +
    // production races where the controller is driven before the
    // UI tree mounts a ConsumerWidget that watches the manifest).
    if (_manifestStreamSub == null) {
      unawaited(() async {
        try {
          final repo = await ref.read(installedManifestRepositoryProvider.future);
          _manifestStreamSub = repo.updates.listen((m) {
            unawaited(_rebuildResolver(m));
          });
        } on Object catch (e, st) {
          _log.warning('failed to attach manifest stream listener', e, st);
        }
      }());
    }
  }

  Future<void> _rebuildResolver(InstalledManifest manifest) async {
    try {
      // Resolve across ALL catalogued alpha3 codes (installed + not),
      // not only installed ones. Installed-status is applied downstream
      // in `_resolveAndApply` to drive the "showMap vs banner" branch —
      // if we only loaded installed polygons here, a viewport panning
      // into a non-installed country would resolve to `null` and the
      // Plan 07-05 banner ("Télécharger ce pays") could never surface.
      final AsyncValue<CountryCatalog> catalogSnap = ref.read(countryCatalogProvider);
      final CountryCatalog? catalog = catalogSnap.value;
      final Set<CountryCode> codesToLoad = <CountryCode>{};
      if (catalog != null) {
        for (final CountryEntry c in catalog.countries) {
          codesToLoad.add(c.alpha3);
        }
      }
      // Always include installed codes too (they might come from a
      // manifest that predates the current catalog).
      for (final String key in manifest.installed.keys) {
        codesToLoad.add(CountryCode.parse(key));
      }
      final Map<CountryCode, List<CountryPolygonRing>> polygons = await _polygonLoader.loadPolygonsForInstalled(codesToLoad);
      _resolver = CountryResolver(installedPolygons: polygons);
      _log.fine('rebuilt CountryResolver with ${polygons.length} polygon set(s) (requested ${codesToLoad.length})');
    } on Object catch (e, st) {
      _log.warning('failed to rebuild CountryResolver', e, st);
    }
    await rerunForLastViewport();
  }

  void _onViewportUpdate(({double latitude, double longitude, double zoom}) v) {
    _lastViewport = v;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_kViewportDebounce, () {
      unawaited(_resolveAndApply(v));
    });
  }

  Future<void> _resolveAndApply(({double latitude, double longitude, double zoom}) v) async {
    _attachMapViewIfReady();
    final MapView? mapView = _mapView;
    final CountryCode? resolved = _resolver.resolve(latitude: v.latitude, longitude: v.longitude, zoom: v.zoom);
    final InstalledManifest manifest = await _readManifest();
    final bool installed = resolved != null && manifest.installed.containsKey(resolved.value);

    final current = state;
    if (resolved == null) {
      // Viewport below Z=3 OR no installed country contains it.
      if (current.activeCountry != null) {
        if (mapView != null) {
          await mapView.showMap(null);
        }
      }
      state = current.copyWith(activeCountry: null, viewportCountry: null, viewportInInstalled: false);
      return;
    }

    if (installed) {
      if (current.activeCountry == resolved) {
        // Same country — just keep viewport tracking in sync.
        state = current.copyWith(viewportCountry: resolved, viewportInInstalled: true);
        return;
      }
      if (mapView != null) {
        await mapView.showMap(resolved);
      }
      state = current.copyWith(activeCountry: resolved, viewportCountry: resolved, viewportInInstalled: true);
      return;
    }

    // Viewport in a country that is NOT installed — banner data path.
    state = current.copyWith(viewportCountry: resolved, viewportInInstalled: false);
  }

  /// Reads the installed manifest with three-way fallback:
  /// 1. installedManifestProvider's cached value (common case after the
  ///    stream has emitted at least once);
  /// 2. direct read via the manifest repository port (sync from disk);
  /// 3. empty manifest as a last resort.
  ///
  /// The three-way path handles the test scenario where the Riverpod
  /// StreamProvider has not been subscribed to (its value stays null
  /// even though the repo has written content) — unit tests bypass the
  /// stream layer to keep setup minimal.
  Future<InstalledManifest> _readManifest() async {
    final AsyncValue<InstalledManifest> snap = ref.read(installedManifestProvider);
    final InstalledManifest? cached = snap.value;
    if (cached != null) return cached;
    try {
      final repo = await ref.read(installedManifestRepositoryProvider.future);
      return await repo.read();
    } on Object catch (e, st) {
      _log.warning('failed to read manifest from repo — falling back to empty', e, st);
      return InstalledManifest.empty();
    }
  }

  void _tearDown() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _viewportSub?.cancel();
    _viewportSub = null;
    _manifestSub?.close();
    _manifestSub = null;
    _manifestStreamSub?.cancel();
    _manifestStreamSub = null;
    _mapView = null;
  }
}
