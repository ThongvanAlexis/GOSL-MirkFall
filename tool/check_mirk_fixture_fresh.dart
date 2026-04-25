// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// CI gate: ensures `test/fixtures/mirk/fifty_k_tiles_seed.sql.gz` matches
/// what `tool/fixtures/build_50k_tiles.dart` produces.
///
/// Runs the builder to a tmp file then byte-compares the result against
/// the committed fixture. Determinism on the builder side (fixed RNG seed,
/// fixed UTC instant, fixed grid, gzip mtime=0) guarantees byte equality
/// when the fixture is fresh.
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : clean (committed fixture matches builder output).
///   - exit 1 : fixture stale (drift surfaced; rerun builder + commit).
///   - exit 2 : misconfiguration (builder process failed, builder absent,
///              committed fixture missing, etc.).
const String _kCommittedFixturePath = 'test/fixtures/mirk/fifty_k_tiles_seed.sql.gz';
const String _kBuilderPath = 'tool/fixtures/build_50k_tiles.dart';

Future<void> main(List<String> args) async {
  final File committed = File(_kCommittedFixturePath);
  if (!committed.existsSync()) {
    stderr.writeln('check_mirk_fixture_fresh: committed fixture missing at $_kCommittedFixturePath');
    stderr.writeln('  Run `dart run $_kBuilderPath` to generate it, then commit the result.');
    exitCode = 2;
    return;
  }
  if (!File(_kBuilderPath).existsSync()) {
    stderr.writeln('check_mirk_fixture_fresh: builder script missing at $_kBuilderPath');
    exitCode = 2;
    return;
  }

  // Spawn the builder against a tmp output file.
  final Directory tmpDir = await Directory.systemTemp.createTemp('mirkfall_fixture_fresh_');
  final String tmpOutput = p.join(tmpDir.path, 'fresh.sql.gz');

  try {
    final ProcessResult result = await Process.run(Platform.executable, <String>['run', _kBuilderPath, '--output=$tmpOutput']);
    if (result.exitCode != 0) {
      stderr.writeln('check_mirk_fixture_fresh: builder failed (exit ${result.exitCode})');
      stderr.writeln('  stdout: ${result.stdout}');
      stderr.writeln('  stderr: ${result.stderr}');
      exitCode = 2;
      return;
    }
    final File fresh = File(tmpOutput);
    if (!fresh.existsSync()) {
      stderr.writeln('check_mirk_fixture_fresh: builder reported success but $tmpOutput not present');
      exitCode = 2;
      return;
    }

    final List<int> committedBytes = committed.readAsBytesSync();
    final List<int> freshBytes = fresh.readAsBytesSync();

    if (_bytesEqual(committedBytes, freshBytes)) {
      stdout.writeln(
        'check_mirk_fixture_fresh: committed fixture matches builder output '
        '(${committedBytes.length} bytes).',
      );
      exitCode = 0;
      return;
    }

    // Drift — produce an actionable summary.
    stderr.writeln('check_mirk_fixture_fresh: FIXTURE STALE');
    stderr.writeln('  committed: $_kCommittedFixturePath (${committedBytes.length} bytes)');
    stderr.writeln('  fresh    : $tmpOutput (${freshBytes.length} bytes)');
    final int firstDiff = _firstDifferingIndex(committedBytes, freshBytes);
    if (firstDiff >= 0) {
      stderr.writeln(
        '  first byte difference at offset $firstDiff: '
        'committed=0x${_hex(committedBytes, firstDiff)} '
        'fresh=0x${_hex(freshBytes, firstDiff)}',
      );
    } else {
      stderr.writeln('  size mismatch (no overlapping byte differs).');
    }
    stderr.writeln('  Re-run `dart run $_kBuilderPath` and commit the result.');
    exitCode = 1;
  } finally {
    try {
      await tmpDir.delete(recursive: true);
    } on Object {
      // Best-effort cleanup; never let a tmp-dir delete failure mask the
      // real exit code.
    }
  }
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Returns the first index where `a[i] != b[i]`, or `-1` if every
/// index in the overlap matches (i.e. only length differs).
int _firstDifferingIndex(List<int> a, List<int> b) {
  final int n = a.length < b.length ? a.length : b.length;
  for (int i = 0; i < n; i++) {
    if (a[i] != b[i]) return i;
  }
  return -1;
}

String _hex(List<int> bytes, int i) {
  if (i < 0 || i >= bytes.length) return '??';
  return bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase();
}
