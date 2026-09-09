// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/infrastructure/map/flutter_map_map_view.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';

import '../widgets/map_attribution_icon.dart';
import '../widgets/map_country_banner.dart';
import '../widgets/map_follow_me_fab.dart';
import '../widgets/mirk_initial_reveal_fade.dart';
import '../widgets/mirk_overlay.dart';
import '../widgets/mirk_tuner_sheet.dart';
import '../widgets/session_burger_menu.dart';

final Logger _log = Logger('presentation.map_screen');

/// Builder signature used for injecting a fake map widget in widget tests
/// without dragging flutter_map into the test runner. Production code
/// always goes through the default [FlutterMapMapViewWidget] constructor.
/// [fogLayers] are the widgets the map mounts on its own canvas above the
/// tiles (empty until plan 09.1-07 moves the fog there).
typedef MapViewWidgetBuilder = Widget Function({required ValueChanged<MapView> onReady, required List<Widget> fogLayers});

/// Full-screen map route (`/map`).
///
/// Layers (bottom-to-top):
/// 1. [FlutterMapMapViewWidget] — sole flutter_map consumer; publishes a
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
  /// [FlutterMapMapViewWidget] constructor. Production callers always
  /// omit this parameter; widget tests pass a builder that returns a fake
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
  void initState() {
    super.initState();
    // BUG-009 follow-up diagnostic (2026-04-25) — record /map mount so
    // we can verify the user actually reached the map after pressing
    // "Carte plein écran" (or after auto-navigation following a
    // permission grant). Pairs with the dispose / deactivate logs.
    _log.info('MapScreen.initState: mounted');
  }

  @override
  void dispose() {
    _log.info('MapScreen lifecycle: dispose');
    super.dispose();
  }

  @override
  void deactivate() {
    _log.info('MapScreen lifecycle: deactivate');
    // Phase 08.1-REVIEW §3 row #13 (Could). `deactivate()` fires on
    // two very different events:
    //
    //  1. REAL teardown — the /map route is being popped, the state
    //     will be disposed, the MapView adapter will be torn down.
    //     The microtask below MUST fire so controllers release their
    //     stale reference to the dying map surface.
    //  2. KEPT-ALIVE re-parent — rotation / AutomaticKeepAliveClientMixin /
    //     TabView migration. `deactivate()` fires, `activate()` fires
    //     right after, the map surface keeps rendering the whole time.
    //     Nullifying `mapViewProvider` during (2) opens a null-gap where
    //     a GPS fix landing in the window causes the MapCameraController
    //     to skip its `moveCameraTo`; briefly loses follow-me
    //     mid-rotation.
    //
    // Discrimination: in a REAL teardown, the scheduled microtask sees
    // `mounted == false` (the state has been disposed by the next
    // microtask tick). In a KEPT-ALIVE re-parent, `mounted` stays
    // true across the deactivate/activate pair. The microtask guards
    // on `mounted` and skips the nullify when we're still alive — the
    // adapter reference then stays valid across the rotation and the
    // controllers never see a null-gap.
    _nullifyMapViewProviderAfterDeactivate();
    super.deactivate();
  }

  /// Publishes `null` into [`mapViewProvider`] once the current
  /// deactivate/dispose phase has closed, so long-lived controllers
  /// ([`MapCameraController`], [`CountryResolverController`] — both
  /// `keepAlive: true`) release their stale reference to the dying
  /// map surface. Without this signal the controllers kept calling
  /// `setUserLocation` / `moveCameraTo` on a disposed adapter (post
  /// row #39 the adapter's `_aliveOrLog` guard silently no-ops on
  /// disposed state, so a missed nullification leaks work but does not
  /// crash — still worth clearing).
  ///
  /// ### Why microtask, not direct call
  ///
  /// Riverpod 3.x forbids provider mutations during the widget-tree
  /// build / deactivate / dispose phase —
  /// `_debugCanModifyProviders` triggers a red-screen assertion
  /// (Android debug build, 2026-04-22). Scheduling the `set(null)`
  /// on [`Future.microtask`] defers it until AFTER the current phase
  /// closes; the notifier captured here is provider-owned and
  /// outlives the widget. Between the microtask and the next frame's
  /// build, no widget can observe a stale adapter.
  ///
  /// `dispose()` was evaluated as an alternative but Riverpod 3.x
  /// rejects `ref.read` there with "Using ref when a widget is about
  /// to or has been unmounted is unsafe". `deactivate` + microtask
  /// is the narrowest legal window.
  ///
  /// ### Why the try/catch (row #39 scope-down)
  ///
  /// In test / hot-reload scenarios the parent `ProviderScope` can
  /// dispose before the scheduled microtask fires; `notifier.set`
  /// on a disposed container throws. That catch is NOT a defence
  /// against a "state that shouldn't exist" (the smell-tag
  /// triggered by §3 row #39) — it's the real behaviour of
  /// Riverpod 3.x in `ProviderScope` teardown ordering. A tighter
  /// design would subscribe through a [`ProviderSubscription`] with
  /// its own `close` contract; that rewrite is deferred to Phase 10
  /// when Riverpod 4.x lands on pub.dev and the lifecycle APIs are
  /// re-shaped. See 08-REVIEW.md §3 row #39.
  void _nullifyMapViewProviderAfterDeactivate() {
    final MapViewHolder notifier = ref.read(mapViewProvider.notifier);
    Future<void>.microtask(() {
      // Phase 08.1-REVIEW §3 row #13 (Could). Skip nullify when the
      // State is still mounted — a kept-alive re-parent (rotation,
      // TabView migration) fires deactivate()+activate() in quick
      // succession without tearing down the map surface. See
      // [deactivate] docstring for the two-scenario breakdown.
      if (mounted) return;
      try {
        notifier.set(null);
      } on Object catch (_) {
        // Container teardown ordering — see method docstring.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The PMTiles resolver is FutureProvider-backed (it awaits the
    // app-support directory + the installed-manifest repository);
    // surface a loading / error shell until it resolves so the map is
    // never constructed against a half-wired context. Every bootstrap
    // path pre-warms the provider in main.dart, so this is a cheap
    // guard rather than a real spinner.
    final AsyncValue<PmtilesSource> sourceAsync = ref.watch(pmtilesSourceProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SessionBurgerMenu(),
      body: sourceAsync.when(
        loading: _buildLoading,
        error: (err, st) => _buildError('Préparation de la carte : $err'),
        data: (PmtilesSource source) => _buildMapStack(context, source),
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

  Widget _buildMapStack(BuildContext context, PmtilesSource source) {
    // Compute the initial camera at BUILD time from the active session's
    // last known fix and hand it to the widget constructor: the map
    // boots with the camera already at the right place, no post-ready
    // move needed for the initial positioning.
    final ActiveSessionState? sessionState = ref.watch(activeSessionControllerProvider).value;
    final Tracking? tracking = sessionState is Tracking ? sessionState : null;
    final CameraLatLngZoom initialCamera = tracking?.lastFix != null
        ? CameraLatLngZoom(latitude: tracking!.lastFix!.latitude, longitude: tracking.lastFix!.longitude, zoom: kInitialSessionMapZoom.toDouble())
        : const CameraLatLngZoom(latitude: 0, longitude: 0, zoom: kMapWorldOverviewZoom);
    // Seed the initial archive with the country containing the active
    // session's lastFix. Done via a stateless point-in-polygon lookup
    // on the CountryResolverController's loaded polygons — survives
    // iOS background-kills (which wipe Riverpod keepAlive state but
    // not the on-disk installed polygons, reloaded on app start by
    // `_rebuildResolver`).
    //
    // Without this seed, a cold map open with an active session would
    // show the world bundle at zoom 15 (pure blur) while the resolver
    // waits for the viewport stream to settle enough to fire
    // `showMap(<country>)`. Seeding `initialCountry` directly makes the
    // map boot on the country's archive with no transient.
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
    // `fogLayers` is left at its EMPTY default in plan 09.1-02: the fog
    // is still the MirkOverlay sibling below. Plan 09.1-07 passes
    // `fogLayers: [MirkInitialRevealFade(child: FogLayerConnector())]`
    // here so the fog is painted on the same canvas as the tiles
    // (BUG-014).
    final Widget mapWidget = widget.mapViewBuilderForTest != null
        ? widget.mapViewBuilderForTest!(onReady: _onMapReady, fogLayers: const <Widget>[])
        : FlutterMapMapViewWidget(pmtilesSource: source, onReady: _onMapReady, initialCamera: initialCamera, initialCountry: initialCountry);
    return Stack(
      children: <Widget>[
        Positioned.fill(child: mapWidget),
        // Phase 09 mirk overlay — TEMPORARILY still a sibling of the map
        // (screen-space CustomPaint, lags the camera: BUG-014). Plan
        // 09.1-07 removes this entry and mounts `FogLayer` inside the
        // FlutterMap children instead. Wrapped in MirkInitialRevealFade
        // so the initial 20 m reveal fades from opacity 0 → 1 over
        // 500 ms at session start. RepaintBoundary isolates the noise
        // tick from the rest of the Stack. IgnorePointer: the overlay is
        // purely visual — pan, pinch and zoom must reach the map
        // underneath (caught during the BUG-003 UAT walk on 2026-04-25).
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: MirkInitialRevealFade(child: MirkOverlay())),
          ),
        ),
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
        // BUG-009 follow-up — top-right live-tuner icon. Always
        // visible: this is solo-dev with iOS sideload as the only
        // distribution channel, and `kDebugMode` is false in the
        // release builds SideStore installs. If the app later goes
        // to non-dev users, gate this on a runtime toggle instead.
        Positioned(top: MediaQuery.of(context).padding.top + 8.0, right: 8.0, child: _MirkTunerButton()),
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
  /// attach their listeners. Called by [FlutterMapMapViewWidget] from
  /// flutter_map's `onMapReady` (a post-frame callback, hence outside
  /// the build phase — Riverpod accepts the mutation directly).
  ///
  /// If an active session is already tracking when we reach /map (via the
  /// SessionList "Ouvrir la carte" entry, a direct deep-link, or a return
  /// from a smoke walk), fires [`MapCameraController.openForSession`]
  /// so the follow-me FAB sees a non-Idle state. Without this auto-open,
  /// the controller stays in [`MapCameraIdle`] and the FAB would mislead
  /// the user with "Démarre une session pour activer le centrage GPS"
  /// even though one IS active.
  void _onMapReady(MapView adapter) {
    // Ignore late callbacks after the widget is torn down; the
    // MapViewHolder handles the transition back to null via the
    // deactivate microtask.
    if (!mounted) return;
    ref.read(mapViewProvider.notifier).set(adapter);
    final ActiveSessionState? sessionState = ref.read(activeSessionControllerProvider).value;
    if (sessionState is Tracking) {
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

/// Top-right tuner-icon button. Always visible in this binary —
/// solo-dev sideload distribution means `kDebugMode` is false in
/// the actual install, so we cannot gate on it. If/when the app
/// ships to non-dev users a runtime toggle should gate the button.
///
/// Opens [showMirkTunerSheet] on tap. The sheet is a non-blocking
/// DraggableScrollableSheet so the user can scrub a slider, watch the
/// fog respond on the visible map strip above the sheet, and adjust
/// without leaving the route.
class _MirkTunerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.8),
      shape: const CircleBorder(),
      elevation: 2.0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showMirkTunerSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(Icons.tune, size: 22.0, color: cs.onSurface),
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
