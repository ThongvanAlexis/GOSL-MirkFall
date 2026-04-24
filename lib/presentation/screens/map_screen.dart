// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/infrastructure/map/maplibre_map_view.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:mirkfall/infrastructure/map/style_rewriter.dart';

import '../widgets/map_attribution_icon.dart';
import '../widgets/map_country_banner.dart';
import '../widgets/map_follow_me_fab.dart';
import '../widgets/session_burger_menu.dart';

/// Builder signature used for injecting a fake map widget in widget tests
/// without dragging MapLibre into the test runner. Production code always
/// goes through the default [MapLibreMapViewWidget] constructor.
typedef MapViewWidgetBuilder = Widget Function({required StyleRewriter styleRewriter, required ValueChanged<MapView> onReady});

/// Full-screen map route (`/map`).
///
/// Layers (bottom-to-top):
/// 1. [MapLibreMapViewWidget] — sole MapLibre consumer; publishes a
///    [MapView] adapter via `mapViewProvider` on `onReady`.
/// 2. Top-left: burger menu IconButton — opens [SessionBurgerMenu] as a
///    [Scaffold]'s drawer. Responsive width (75% portrait / 40% landscape)
///    handled by the drawer itself.
/// 3. Bottom-right stack: [MapFollowMeFab] + [MapAttributionIcon]
///    stacked vertically — follow-me above attribution so the thumb
///    reach zone hits the high-frequency control first.
/// 4. Bottom-centre (non-intrusive): [MapCountryBanner] — appears when
///    the viewport centre hits a non-installed country.
///
/// AppBar is deliberately absent: the map is edge-to-edge so panning
/// never clips under a chrome bar. The burger menu button doubles as the
/// navigation affordance (back button is reachable via the system-level
/// gesture + the drawer's "Fermer" entry).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.mapViewBuilderForTest});

  /// Optional test seam: when non-null, replaces the default
  /// [MapLibreMapViewWidget] constructor. Production callers always omit
  /// this parameter; widget tests pass a builder that returns a fake
  /// widget (typically `SizedBox.expand()`) and publishes a [FakeMapView]
  /// to `mapViewProvider` synchronously.
  @visibleForTesting
  final MapViewWidgetBuilder? mapViewBuilderForTest;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void deactivate() {
    // Clear the published MapView adapter so long-lived controllers
    // (MapCameraController, CountryResolverController — both
    // keepAlive:true) stop calling methods on the dying native
    // MapLibre surface. Without this hook the controllers kept a
    // stale reference to a disposed adapter; any subsequent fix /
    // session transition invoked setUserLocation on the dead
    // platform view, cascading into iOS native crashes on the
    // 2026-04-21 device smoke.
    //
    // Riverpod 3.x forbids provider mutations DURING widget-tree
    // build / deactivate / dispose — doing so triggers
    // `_debugCanModifyProviders` and Flutter renders a red screen
    // (Android debug build, 2026-04-22). The workaround is to
    // capture the notifier ref here (still valid during deactivate)
    // and schedule the `set(null)` on a microtask so it fires AFTER
    // the current build/deactivate phase closes. The notifier is a
    // long-lived provider-owned object; it survives the widget
    // disposal that immediately follows.
    //
    // `dispose` was also considered but Riverpod 3.x rejects
    // `ref.read` there ("Using ref when a widget is about to or has
    // been unmounted is unsafe"). The microtask pattern here is the
    // only clean middle ground.
    //
    // Timing guarantee: the microtask fires before the next frame's
    // build scope opens, so `mapViewProvider` listeners (the
    // keepAlive controllers) see `null` before any new Widget can
    // `ref.watch` the map screen's children again.
    final MapViewHolder notifier = ref.read(mapViewProvider.notifier);
    Future<void>.microtask(() {
      try {
        notifier.set(null);
      } on Object catch (_) {
        // Provider container already disposed (test teardown, hot
        // reload, or parent ProviderScope unmounted before the
        // microtask fired). Nothing to clean up — consumers that
        // would have cared about mapView=null are also dead.
      }
    });
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<StyleRewriter> rewriterAsync = ref.watch(styleRewriterProvider);
    // Still watch pmtilesSource: it warms the on-disk cache + catalog
    // prerequisites that the style rewriter depends on transitively.
    // We don't USE the value directly here (the rewriter owns PMTiles
    // URI rewriting), but awaiting the future keeps MapLibre from
    // constructing against a half-wired context.
    final AsyncValue<PmtilesSource> sourceAsync = ref.watch(pmtilesSourceProvider);

    // Infrastructure prerequisites (style rewriter + pmtiles source) are
    // FutureProvider-backed; surface a loading / error shell until they
    // resolve so MapLibre is never constructed against a half-wired
    // context. Every Phase 07 bootstrap path pre-warms these providers
    // in main.dart, so this is a cheap guard rather than a real spinner.
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SessionBurgerMenu(),
      body: rewriterAsync.when(
        loading: _buildLoading,
        error: (err, st) => _buildError('Préparation de la carte : $err'),
        data: (rewriter) => sourceAsync.when(
          loading: _buildLoading,
          error: (err, st) => _buildError('Préparation de la carte : $err'),
          data: (_) => _buildMapStack(context, rewriter),
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator.adaptive());

  Widget _buildError(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _buildMapStack(BuildContext context, StyleRewriter rewriter) {
    // Compute the initial camera at BUILD time from the active session's
    // last known fix. Passing this as `initialCameraPosition` to
    // MapLibreMap lets the map LOAD with the camera already at the
    // right place — zero method-channel calls needed post-style-load.
    //
    // Phase 07-07 rationale (2026-04-22): any method-channel call
    // touching the camera (animateCamera, moveCamera) in the window
    // right after onStyleLoaded throws an unhandled C++ exception in
    // MapLibre.framework → SIGABRT (confirmed across 5 .ips files,
    // same convergence point in the native stack regardless of which
    // Dart method was dispatched). See
    // `docs/phase-07-ios-animate-camera-crash.md`. Supplying the
    // camera through the widget constructor avoids that code path
    // entirely for the initial positioning.
    final ActiveSessionState? sessionState = ref.watch(activeSessionControllerProvider).value;
    final Tracking? tracking = sessionState is Tracking ? sessionState : null;
    final CameraLatLngZoom initialCamera = tracking?.lastFix != null
        ? CameraLatLngZoom(latitude: tracking!.lastFix!.latitude, longitude: tracking.lastFix!.longitude, zoom: kInitialSessionMapZoom.toDouble())
        : const CameraLatLngZoom(latitude: 0, longitude: 0, zoom: 2);
    // Seed the initial style with the country containing the active
    // session's lastFix. Done via a stateless point-in-polygon lookup
    // on the CountryResolverController's loaded polygons — survives
    // iOS background-kills (which wipe Riverpod keepAlive state but
    // not the on-disk installed polygons, reloaded on app start by
    // `_rebuildResolver`).
    //
    // Phase 07-07 rationale: without this seed, a cold map open with
    // an active session spends 5-10 s showing the world-bundle at
    // zoom 13 (pure blur) while the resolver waits for the viewport
    // stream to settle enough to fire `showMap(<country>)` via
    // setStyle. Seeding `initialCountry` directly makes the map boot
    // on the country's style with no transient.
    //
    // Falls through to `null` (world) when no session is active, no
    // fix yet, or the polygons haven't finished loading (cold-start
    // race, rare).
    CountryCode? initialCountry;
    if (tracking?.lastFix != null) {
      initialCountry = ref
          .read(countryResolverControllerProvider.notifier)
          .resolveForPoint(latitude: tracking!.lastFix!.latitude, longitude: tracking.lastFix!.longitude, zoom: kInitialSessionMapZoom.toDouble());
    }
    final Widget mapWidget = widget.mapViewBuilderForTest != null
        ? widget.mapViewBuilderForTest!(styleRewriter: rewriter, onReady: _onMapReady)
        : MapLibreMapViewWidget(styleRewriter: rewriter, onReady: _onMapReady, initialCamera: initialCamera, initialCountry: initialCountry);
    return Stack(
      children: <Widget>[
        Positioned.fill(child: mapWidget),
        // Top-left controls: back button (when poppable) + burger menu.
        // Back stays left-most so the iOS pattern "back = top-left" is
        // preserved. Android also gets the button — harmless next to the
        // system back gesture and matches the platform convention where
        // edge-to-edge screens surface an explicit back affordance.
        Positioned(
          top: MediaQuery.of(context).padding.top + 8.0,
          left: 8.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (Navigator.of(context).canPop()) ...<Widget>[const _BackButton(), const SizedBox(width: 8.0)],
              _MenuButton(scaffoldKey: _scaffoldKey),
            ],
          ),
        ),
        // Bottom-right: follow-me FAB + attribution icon.
        Positioned(
          right: 16.0,
          bottom: MediaQuery.of(context).padding.bottom + 80.0,
          child: const Column(mainAxisSize: MainAxisSize.min, children: <Widget>[MapFollowMeFab(), SizedBox(height: 12.0), MapAttributionIcon()]),
        ),
        // Bottom-centre country banner (hidden by default — the widget
        // returns SizedBox.shrink() when the viewport IS installed).
        const Positioned(left: 0.0, right: 0.0, bottom: 0.0, child: SafeArea(child: MapCountryBanner())),
      ],
    );
  }

  /// Publishes the newly-ready [MapView] adapter to the application layer
  /// so controllers (MapCameraController, CountryResolverController) can
  /// attach their listeners. Called by [MapLibreMapViewWidget] once the
  /// first `onStyleLoaded` fires.
  ///
  /// If an active session is already tracking when we reach /map (via the
  /// SessionList "Ouvrir la carte" entry, a direct deep-link, or a return
  /// from a Phase 07-07 smoke walk), fires [`MapCameraController.openForSession`]
  /// so the follow-me FAB sees a non-Idle state. Without this auto-open,
  /// the controller stays in [`MapCameraIdle`] and the FAB would mislead
  /// the user with "Démarre une session pour activer le centrage GPS"
  /// even though one IS active.
  void _onMapReady(MapView adapter) {
    // Ignore late callbacks after the widget is torn down; the
    // MapViewHolder handles the transition back to null via dispose of
    // the underlying adapter.
    if (!mounted) return;
    // Defer publication by one frame — see [_publishMapViewAfterFrame] for
    // the maplibre_gl 0.25.0 crash this avoids. Row #40 (§3) swapped the
    // previous Future.delayed(Duration.zero) for SchedulerBinding's
    // post-frame callback to make the "wait until the current frame
    // commits" intent explicit in the API used.
    SchedulerBinding.instance.addPostFrameCallback((_) => _publishMapViewAfterFrame(adapter));
  }

  /// Publishes the [MapView] adapter to [mapViewProvider] and, when a
  /// session is already Tracking, opens the camera controller — both
  /// scheduled for the next frame so MapLibre has finished its render-thread
  /// commit before any method-channel calls land on the native side.
  ///
  /// Workaround for flutter-maplibre-gl 0.25.0 issue #717 (fixed by
  /// PR #719 on release-0.26.0, not yet published to pub.dev): the iOS
  /// plugin invokes onStyleLoadedCallback synchronously while MLNMapView's
  /// internal state is not yet committed. Any subsequent method-channel
  /// call in that same runloop turn (setUserLocation, animateCamera,
  /// addCircle, etc.) throws a C++ exception inside MapLibre Native that
  /// propagates unhandled through __cxa_throw → std::terminate →
  /// _objc_terminate → abort → SIGABRT, killing the app (see native
  /// crash report Runner-2026-04-22-092721.ips — frames 9-13 in
  /// MapLibre.framework, frame 14 in the plugin's onMethodCall dispatch).
  ///
  /// The post-frame callback mirrors PR #719's `DispatchQueue.main.async`
  /// fix on the native side, buying MapLibre time to finalise its
  /// render-thread state. Remove this indirection when `maplibre_gl`
  /// >= 0.26.0 lands on pub.dev.
  void _publishMapViewAfterFrame(MapView adapter) {
    if (!mounted) return;
    ref.read(mapViewProvider.notifier).set(adapter);
    final ActiveSessionState? sessionState = ref.read(activeSessionControllerProvider).value;
    if (sessionState is Tracking) {
      // Phase 07-07 probe B (2026-04-22) — re-enable openForSession
      // after confirming the crash disappears with `user_location`
      // style layer removed. If the crash stays gone with this call
      // active, the style layer was the sole trigger; if it returns,
      // this call needs a stronger defer or a redesign.
      //
      // Fire-and-forget: openForSession is async but the widget doesn't
      // need to block on it — the controller publishes state changes
      // through Riverpod which propagate back via the FAB's ref.watch.
      unawaited(ref.read(mapCameraControllerProvider.notifier).openForSession(sessionState.sessionId));
    }
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.scaffoldKey});

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.8),
      shape: const CircleBorder(),
      elevation: 2.0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => scaffoldKey.currentState?.openDrawer(),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(Icons.menu, size: 22.0, color: cs.onSurface),
        ),
      ),
    );
  }
}

/// Chevron back button shown on the map screen when the Navigator has
/// something to pop.
///
/// iOS needs this because the MapScreen deliberately ships edge-to-edge
/// without an AppBar, and unlike Android there is no system-level
/// edge-swipe back gesture (GoRouter's default page transitions do NOT
/// enable the iOS swipe-from-left because that would conflict with the
/// drawer open gesture from the burger menu).
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.8),
      shape: const CircleBorder(),
      elevation: 2.0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(Icons.arrow_back, size: 22.0, color: cs.onSurface),
        ),
      ),
    );
  }
}

/// Country alpha3 hint used by Plan 07-06 callers that need to pass an
/// explicit initial country without loading the viewport resolver. Plan
/// 07-06 scope keeps this in the domain vocabulary (CountryCode); the
/// export exists so Task 3's SessionDetailScreen can reuse it.
typedef MapScreenInitialCountry = CountryCode;
