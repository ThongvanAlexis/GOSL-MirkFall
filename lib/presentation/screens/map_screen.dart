// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
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
typedef MapViewWidgetBuilder =
    Widget Function({required StyleRewriter styleRewriter, required PmtilesSource pmtilesSource, required ValueChanged<MapView> onReady});

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
  Widget build(BuildContext context) {
    final AsyncValue<StyleRewriter> rewriterAsync = ref.watch(styleRewriterProvider);
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
          data: (source) => _buildMapStack(context, rewriter, source),
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

  Widget _buildMapStack(BuildContext context, StyleRewriter rewriter, PmtilesSource source) {
    final Widget mapWidget = widget.mapViewBuilderForTest != null
        ? widget.mapViewBuilderForTest!(styleRewriter: rewriter, pmtilesSource: source, onReady: _onMapReady)
        : MapLibreMapViewWidget(styleRewriter: rewriter, pmtilesSource: source, onReady: _onMapReady);
    return Stack(
      children: <Widget>[
        Positioned.fill(child: mapWidget),
        // Top-left burger menu.
        Positioned(
          top: MediaQuery.of(context).padding.top + 8.0,
          left: 8.0,
          child: _MenuButton(scaffoldKey: _scaffoldKey),
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

/// Country alpha3 hint used by Plan 07-06 callers that need to pass an
/// explicit initial country without loading the viewport resolver. Plan
/// 07-06 scope keeps this in the domain vocabulary (CountryCode); the
/// export exists so Task 3's SessionDetailScreen can reuse it.
typedef MapScreenInitialCountry = CountryCode;
