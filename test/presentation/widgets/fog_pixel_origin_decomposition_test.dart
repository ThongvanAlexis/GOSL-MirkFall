// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_pixel_origin_decomposition_test.dart — invariant FOG-18

import 'dart:io' show File;
import 'dart:math' show Point;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';

import '../../_helpers/atmospheric_fog_layer_harness.dart';

/// FOG-18 — direct `pixelOrigin` forwarding (the FOG-17a Dart-side wrap is gone).
///
/// Walk #4's debug-spiral positive control proved the FBM noise is NOT
/// periodic on `kMirkFogNoiseTilePx` in practice: the wrap event itself was
/// the visible snap, not the fp32 precision penalty it was meant to avoid.
/// fp32 keeps exact integers up to 16.7 M raw px, above the ~4.26 M observed.
///
/// MirkFall drops the POC's `truncateToDouble()` decomposition too: the painter
/// hands `camera.pixelOrigin` to `applyPlatformShaderCorrections` once and the
/// context carries the result verbatim to the seam.
void main() {
  /// Strips `//` line comments so prose may mention the historical formulation.
  String activeCode(String source) => source
      .split('\n')
      .map((line) {
        final commentIdx = line.indexOf('//');
        return commentIdx >= 0 ? line.substring(0, commentIdx) : line;
      })
      .join('\n');

  group('FOG-18 — direct pixelOrigin forwarding (FOG-17a wrap eliminated)', () {
    test('STATIC source: fog_layer.dart has no Dart-side modulo / wrap period / decomposition on pixelOrigin', () {
      final source = File('lib/presentation/widgets/fog_layer.dart').readAsStringSync();
      final code = activeCode(source);
      expect(code, isNot(contains('%')), reason: 'no modulo anywhere in the painter (the wrap event IS the snap)');
      expect(source, isNot(contains('IntegerWrapPeriod')), reason: 'the FOG-17a period constant must not come back');
      expect(source, isNot(contains('truncateToDouble')), reason: 'no integer / fractional decomposition either (identity in fp32)');
      expect(
        RegExp(r'applyPlatformShaderCorrections\(\s*pixelOrigin:\s*\(x:\s*camera\.pixelOrigin\.x,\s*y:\s*camera\.pixelOrigin\.y\)').allMatches(code),
        hasLength(1),
        reason: 'raw camera.pixelOrigin in, exactly once (the corrections are deliberately not idempotent)',
      );
    });

    test('NUMERICAL: the iOS forward path is the identity at Walk #4 magnitude (4_256_182.0, 2_896_819.0)', () {
      final forwarded = applyPlatformShaderCorrections(pixelOrigin: (x: 4256182.0, y: 2896819.0), isAndroid: false).pixelOrigin;
      expect(forwarded, equals((x: 4256182.0, y: 2896819.0)));
    });

    test('NUMERICAL: extrapolated zoom-19 magnitude (17_040_000.0, 4_260_000.0) forwards unchanged', () {
      final forwarded = applyPlatformShaderCorrections(pixelOrigin: (x: 17040000.0, y: 4260000.0), isAndroid: false).pixelOrigin;
      expect(forwarded, equals((x: 17040000.0, y: 4260000.0)));
    });

    test('NUMERICAL: small-magnitude boundary (1536.5, 384.25) and negative inputs forward unchanged (no wrap, sign kept)', () {
      expect(applyPlatformShaderCorrections(pixelOrigin: (x: 1536.5, y: 384.25), isAndroid: false).pixelOrigin, equals((x: 1536.5, y: 384.25)));
      expect(applyPlatformShaderCorrections(pixelOrigin: (x: -100.0, y: -1536.5), isAndroid: false).pixelOrigin, equals((x: -100.0, y: -1536.5)));
      // Android only flips the sign of y (FOG-23) — still no wrap.
      expect(applyPlatformShaderCorrections(pixelOrigin: (x: 1536.5, y: 384.25), isAndroid: true).pixelOrigin, equals((x: 1536.5, y: -384.25)));
    });

    testWidgets('BEHAVIOURAL: the seam receives camera.pixelOrigin verbatim at zoom 15 (~2.1 M raw px, no modulo bound)', (tester) async {
      final mapController = MapController();
      addTearDown(mapController.dispose);
      final harness = await pumpAtmosphericFogLayer(tester, mapController: mapController, initialZoom: 15);

      final forwarded = harness.recorder.renders.last.pixelOrigin;
      final Point<double> cameraPixelOrigin = mapController.camera.pixelOrigin;
      expect(
        forwarded,
        equals((x: cameraPixelOrigin.x, y: cameraPixelOrigin.y)),
        reason: 'FOG-18: forwarded == camera.pixelOrigin exactly — a wrap would leave a ~2.1 M gap',
      );
      expect(forwarded.x, greaterThan(1e6), reason: 'raw world-pixel magnitude at z15 + Melun');
      expect(forwarded.y, greaterThan(1e6));
      await harness.renderer.dispose();
    });
  });
}
