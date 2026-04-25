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

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '_render_helpers.dart';

void main() {
  group('09-04 — no two builtins produce identical output (MIRK-06 distinctness)', () {
    test('4 variants × identical context → 4 distinct pixel buffers (6 pairs)', () async {
      // Use a non-zero sessionElapsed so animated variants are NOT in
      // their "frame zero" coincidental state.
      final ctx = fakeContext(elapsedMs: 1500);

      final renderers = <(String, MirkRenderer)>[
        ('atmospheric', AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig)),
        ('solid', SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig)),
        ('candlelight', CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig)),
        ('heavenly', HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig)),
      ];

      final buffers = <(String, List<int>)>[];
      for (final (name, renderer) in renderers) {
        final bytes = await renderToBytes(renderer, context: ctx);
        buffers.add((name, bytes));
        await renderer.dispose();
      }

      // 4 buffers → C(4, 2) = 6 unique pairs.
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
    });
  });
}
