// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details
//
// WORKAROUND: guard temporaire jusqu'à Phase 09 où computeRevealMask sera
// implémenté et ce test supprimé. CLAUDE.md §Workarounds — ce test scanne
// les sources pour détecter toute accroche au symbole non implémenté, pour
// empêcher un appel silencieux qui propagerait UnimplementedError en
// production.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('computeRevealMask has no callers outside its definition site (Phase 09 guard)', () {
    const definitionSite = 'lib/domain/revealed/reveal_calculator.dart';
    const selfSite = 'test/domain/compute_reveal_mask_no_callers_test.dart';
    // Existing Phase 03 test asserts the `throws UnimplementedError`
    // contract — allowed to reference the symbol until Phase 09 lands.
    const allowedTestSite = 'test/domain/reveal_calculator_test.dart';

    final callers = <String>[];
    for (final root in <String>['lib', 'test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalizedPath = entity.path.replaceAll(r'\', '/');
        if (normalizedPath.endsWith(definitionSite)) continue;
        if (normalizedPath.endsWith(selfSite)) continue;
        if (normalizedPath.endsWith(allowedTestSite)) continue;
        if (entity.readAsStringSync().contains('computeRevealMask')) {
          callers.add(normalizedPath);
        }
      }
    }
    expect(callers, isEmpty, reason: 'computeRevealMask is unimplemented until Phase 09. Callers found: $callers');
  });
}
