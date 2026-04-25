// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 4 smoke test for the 4 builtin
// `MirkRenderer` implementations (MIRK-06).
//
// Cheap canary that catches missing constructor arguments / null
// derefs / dispose-of-unowned-resource bugs across the variant set in
// one place. Each renderer must:
// - Instantiate with its default config
// - Run paint() on a non-empty context without throwing
// - Run update() without throwing
// - Run dispose() without throwing

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '_render_helpers.dart';

void main() {
  group('09-04 — 4 builtin renderers smoke (MIRK-06)', () {
    test('all 4 instantiate + paint + update + dispose without throw', () async {
      final renderers = <MirkRenderer>[
        AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig),
        SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig),
        CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig),
        HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig),
      ];

      for (final renderer in renderers) {
        final ctx = fakeContext(elapsedMs: 1000);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        // paint must not throw
        expect(() => renderer.paint(canvas, kTestCanvasSize, ctx), returnsNormally, reason: '${renderer.runtimeType}.paint() threw');
        // update must not throw
        expect(() => renderer.update(const Duration(milliseconds: 16)), returnsNormally, reason: '${renderer.runtimeType}.update() threw');
        // Release the picture so the recorder doesn't leak.
        recorder.endRecording().dispose();
        // dispose must not throw + must complete
        await renderer.dispose();
      }
    });
  });
}
