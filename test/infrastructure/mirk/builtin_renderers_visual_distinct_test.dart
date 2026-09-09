// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 4 visual-distinctness test for the 4
// builtin `MirkRenderer` implementations (MIRK-06).
//
// Each pair of builtin renderers must produce DISTINCT paint output
// at the same frame — a structural guard against accidentally building
// 2 variants that collapse to identical pixels. There are C(4, 2) = 6
// unique pairs to compare.
//
// Phase 09.1 plan 09.1-06 — the same guard under the EXTENDED context the
// `FogLayer` hands out (one disc, ~1e6 pixelOrigin, zoomScale 4), on iOS
// and on Android: the shared clip and the camera-derived fields must not
// collapse two variants onto the same pixels either.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '../../_helpers/mirk_paint_context_builder.dart';
import '_render_helpers.dart';

/// Disc radius that yields a ~18 px hole on the 1° × 1° test viewport.
const double _visibleHoleRadiusMeters = 8000.0;

/// Raw camera pixelOrigin at a high zoom (~1e6 / 2e6 magnitudes, FOG-18).
const ({double x, double y}) _highZoomRawPixelOrigin = (x: 1e6, y: 2e6);

/// Camera zoomScale two zoom levels above the reference (z15).
const double _extendedZoomScale = 4.0;

/// Fresh instances of the 4 builtins (each test owns and disposes its own).
List<(String, MirkRenderer)> _builtinRenderers() => <(String, MirkRenderer)>[
  ('atmospheric', AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig)),
  ('solid', SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig)),
  ('candlelight', CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig)),
  ('heavenly', HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig)),
];

/// Renders every builtin under [context] and asserts the C(4, 2) = 6 pairs differ.
Future<void> _expectPairwiseDistinct(MirkPaintContext context) async {
  final buffers = <(String, Uint8List)>[];
  for (final (String name, MirkRenderer renderer) in _builtinRenderers()) {
    final bytes = await renderToBytes(renderer, context: context);
    buffers.add((name, bytes));
    await renderer.dispose();
  }
  for (var a = 0; a < buffers.length; a++) {
    for (var b = a + 1; b < buffers.length; b++) {
      final (nameA, bytesA) = buffers[a];
      final (nameB, bytesB) = buffers[b];
      expect(
        bytesA,
        isNot(equals(bytesB)),
        reason:
            'Variants "$nameA" and "$nameB" produced byte-identical '
            'output (MIRK-06 distinctness violation — two variants '
            'collapsed to the same pixels)',
      );
    }
  }
}

void main() {
  group('09-04 — no two builtins produce identical output (MIRK-06 distinctness)', () {
    test('4 variants × identical context → 4 distinct pixel buffers (6 pairs)', () async {
      // Use a non-zero sessionElapsed so animated variants are NOT in
      // their "frame zero" coincidental state.
      await _expectPairwiseDistinct(fakeContext(elapsedMs: 1500));
    });
  });

  group('09.1-06 — distinctness holds under the extended FogLayer context', () {
    final MirkViewportBbox bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

    MirkPaintContext extendedContext({required bool isAndroid}) {
      final PlatformShaderCorrections corrected = applyPlatformShaderCorrections(pixelOrigin: _highZoomRawPixelOrigin, isAndroid: isAndroid);
      return buildTestMirkPaintContext(
        sessionElapsed: const Duration(milliseconds: 1500),
        viewportBbox: bbox,
        discs: <RevealDisc>[singleCentreDisc(bbox: bbox, radiusMeters: _visibleHoleRadiusMeters)],
        pixelOrigin: corrected.pixelOrigin,
        zoomScale: _extendedZoomScale,
        sdfRect: corrected.sdfRect,
      );
    }

    test('iOS (identity sdfRect): 6 pairs distinct', () async {
      await _expectPairwiseDistinct(extendedContext(isAndroid: false));
    });

    test('Android (V-flip sdfRect, negative pixelOrigin.y): 6 pairs distinct', () async {
      await _expectPairwiseDistinct(extendedContext(isAndroid: true));
    });
  });
}
