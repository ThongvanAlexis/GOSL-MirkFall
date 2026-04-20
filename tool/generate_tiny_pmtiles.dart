// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

/// Build-time script that writes a 1 KB stub PMTiles file at
/// `test/fixtures/pmtiles/tiny.pmtiles`. The stub starts with the PMTiles
/// v3 magic (`"PMTiles"` 7-byte ASCII + version byte `3`) and pads the
/// remaining 1016 bytes with zero. Phase 07 plan 07-04 download soak
/// tests use this for the "concat assembled file looks sane" smoke
/// check — the binary_concatenator + sha256 verifier need a deterministic
/// tiny file to reassemble, not a full MapLibre-parseable PMTiles.
///
/// Real MapLibre will NOT be able to load this stub (it rejects a PMTiles
/// with no directory); we do not need it to, the downstream test suite
/// only exercises byte-level checks on the assembled artefact.
///
/// Idempotent: re-running the script overwrites the stub verbatim. The
/// resulting file is committed alongside this script so CI does not
/// need to re-run the generator.
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : wrote the stub successfully
///   - exit 1 : IO failure (permissions, disk full)
const String _outputPath = 'test/fixtures/pmtiles/tiny.pmtiles';

/// Total fixture size in bytes. 1 KB is more than enough for a magic
/// header + padding and matches the Phase 07-01 plan description.
const int _totalBytes = 1024;

/// PMTiles v3 magic bytes followed by a version octet. Documented at
/// github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md §Magic Number.
final Uint8List _magic = Uint8List.fromList(<int>[
  0x50, 0x4D, 0x54, 0x69, 0x6C, 0x65, 0x73, // "PMTiles"
  0x03, // version 3
]);

Future<int> runCheck({String? outputPath}) async {
  final String resolvedOutput = outputPath ?? _outputPath;
  final Uint8List buf = Uint8List(_totalBytes);
  buf.setRange(0, _magic.length, _magic);
  // Remaining bytes are zero by default (Uint8List constructor
  // zero-initialises).
  try {
    final File f = File(resolvedOutput);
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(buf);
  } on IOException catch (e) {
    stderr.writeln('generate_tiny_pmtiles: failed to write $resolvedOutput: $e');
    return 1;
  }
  stdout.writeln('generate_tiny_pmtiles: OK — wrote $_totalBytes bytes to $resolvedOutput (magic="PMTiles" + version 3 + zero padding)');
  return 0;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
