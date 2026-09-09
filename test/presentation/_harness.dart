// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/presentation/widgets/fog_layer_connector.dart';
import 'package:mirkfall/presentation/widgets/mirk_initial_reveal_fade.dart';

/// Camera of the harness map — Paris at the in-session zoom.
const LatLng kHarnessMapCentre = LatLng(48.85, 2.35);
const double kHarnessMapZoom = 15.0;

/// Test-only harness that mimics the [`MapScreen`] Stack structure with
/// injection hooks for the sibling widgets (attribution, FAB, banner,
/// chip).
///
/// The structure mirrors [`MapScreen._buildMapStack`]
/// (`lib/presentation/screens/map_screen.dart`) after Phase 09.1: the base
/// layer is a REAL `FlutterMap` (no tile layer) hosting
/// `MirkInitialRevealFade(FogLayerConnector())` as one of its CHILDREN — the
/// same-canvas composition — and 4 sibling positioned widgets supplied via
/// builders. Tests pass counter-wrapped builders to verify the `FogLayer`'s
/// per-frame Ticker does not rebuild the siblings (it drives the painter's
/// `repaint:` Listenable, never `setState`, which is why no `RepaintBoundary`
/// wraps the fog any more).
///
/// Wrap in [`ProviderScope`] (with the necessary overrides for
/// [`activeSessionControllerProvider`], [`activeMirkRendererProvider`],
/// [`discsInViewportProvider`] and [`mapViewportProvider`]) before pumping.
class TestMapScreenHarness extends StatelessWidget {
  const TestMapScreenHarness({super.key, this.attributionBuilder, this.fabBuilder, this.bannerBuilder, this.chipBuilder, this.mapController});

  /// Counter-wrapped attribution widget. Production uses
  /// [`MapAttributionIcon`]; tests pass a spy that increments a counter
  /// on each build to assert the fog Ticker does NOT cascade rebuilds.
  final WidgetBuilder? attributionBuilder;

  /// Counter-wrapped follow-me FAB widget.
  final WidgetBuilder? fabBuilder;

  /// Counter-wrapped country banner widget.
  final WidgetBuilder? bannerBuilder;

  /// Counter-wrapped download progress chip widget.
  final WidgetBuilder? chipBuilder;

  /// Optional controller so a test can read / drive the harness camera.
  final MapController? mapController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: FlutterMap(
                mapController: mapController,
                options: const MapOptions(initialCenter: kHarnessMapCentre, initialZoom: kHarnessMapZoom),
                children: const <Widget>[MirkInitialRevealFade(child: FogLayerConnector())],
              ),
            ),
            if (attributionBuilder != null)
              Align(
                alignment: Alignment.bottomLeft,
                child: Builder(builder: attributionBuilder!),
              ),
            if (fabBuilder != null)
              Align(
                alignment: Alignment.topRight,
                child: Builder(builder: fabBuilder!),
              ),
            if (bannerBuilder != null)
              Align(
                alignment: Alignment.topCenter,
                child: Builder(builder: bannerBuilder!),
              ),
            if (chipBuilder != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Builder(builder: chipBuilder!),
              ),
          ],
        ),
      ),
    );
  }
}
