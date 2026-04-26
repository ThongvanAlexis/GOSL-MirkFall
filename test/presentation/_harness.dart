// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:mirkfall/presentation/widgets/mirk_initial_reveal_fade.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

/// Test-only harness that mimics the [`MapScreen`] Stack structure with
/// injection hooks for the sibling widgets (attribution, FAB, banner,
/// chip).
///
/// Tests pass counter-wrapped builders to verify the mirk Ticker does not
/// trigger rebuilds of siblings (SC#4 RepaintBoundary isolation
/// regression — plan 09-08 Task 2). The structure mirrors
/// [`MapScreen._buildMapStack`] (`lib/presentation/screens/map_screen.dart`):
/// a `Stack` with a base layer (proxy for the MapLibre platform view), a
/// `RepaintBoundary` wrapping `MirkInitialRevealFade(MirkOverlay)`, and 4
/// sibling positioned widgets supplied via builders.
///
/// Wrap in [`ProviderScope`] (with the necessary overrides for
/// [`activeSessionControllerProvider`], [`activeMirkRendererProvider`],
/// [`discsInViewportProvider`], [`mapViewportProvider`], and
/// [`mapViewportZoomProvider`]) before pumping.
class TestMapScreenHarness extends StatelessWidget {
  const TestMapScreenHarness({super.key, this.attributionBuilder, this.fabBuilder, this.bannerBuilder, this.chipBuilder});

  /// Counter-wrapped attribution widget. Production uses
  /// [`MapAttributionIcon`]; tests pass a spy that increments a counter
  /// on each build to assert the mirk Ticker does NOT cascade rebuilds.
  final WidgetBuilder? attributionBuilder;

  /// Counter-wrapped follow-me FAB widget.
  final WidgetBuilder? fabBuilder;

  /// Counter-wrapped country banner widget.
  final WidgetBuilder? bannerBuilder;

  /// Counter-wrapped download progress chip widget.
  final WidgetBuilder? chipBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            // Base map proxy — production hosts a `MapLibreMapViewWidget`
            // here. A plain `ColoredBox` is sufficient for the harness
            // because the boundary isolation test only cares that the
            // ticker repaint does NOT bleed into siblings; the base
            // layer's own widget identity is irrelevant.
            const Positioned.fill(child: ColoredBox(color: Color(0xFF202020))),
            const Positioned.fill(
              child: RepaintBoundary(child: MirkInitialRevealFade(child: MirkOverlay())),
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
