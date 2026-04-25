// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

/// CI gate: ensures `test/fixtures/mirk/fifty_k_tiles_seed.sql` matches
/// what `tool/fixtures/build_50k_tiles.dart` produces.
///
/// Wave 0 scaffold: exits 0 (inert until Wave 7 wires the real diff). The
/// gate is wired into `.github/workflows/ci.yml` upfront so plan 09-08
/// only has to fill the body, not chase a CI-edit at fixture-bump time.
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : clean (Wave 0 always; Wave 7+ on fixture match).
///   - exit 1 : fixture stale (Wave 7+ only).
///   - exit 2 : misconfiguration (Wave 7+ only).
Future<void> main(List<String> args) async {
  stdout.writeln('check_mirk_fixture_fresh: Wave 0 scaffold — inert');
  exitCode = 0;
}
