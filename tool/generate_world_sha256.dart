// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Build-time script that stream-reads `assets/maps/world.pmtiles`, computes
/// its sha256, and emits `lib/config/world_bundle_sha256.dart` containing a
/// single `const String kWorldBundleSha256 = '<hex>';` export.
///
/// Rationale: the first-launch world copier (Phase 07 plan 07-03) compares
/// the sha256 of the file currently living at
/// `<app_support>/maps/world.pmtiles` against this build-time constant. If
/// the file is missing OR its hash does not match (asset updated between
/// releases), the copier re-seeds from the asset. Keeping the expected hash
/// as a Dart `const` means the verification has zero runtime cost — no asset
/// re-read, no disk scan at boot. Closes 07-RESEARCH Open Question #5.
///
/// Invocation: `dart run tool/generate_world_sha256.dart` from the repo
/// root, once, whenever `assets/maps/world.pmtiles` is updated. The emitted
/// `lib/config/world_bundle_sha256.dart` is committed alongside the asset
/// bump.
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : asset read, hash computed, file written successfully
///   - exit 1 : write failed (permissions, disk full, etc.)
///   - exit 2 : misconfiguration — asset missing at the expected path
///
/// The script reads the 856 KB asset into memory with `readAsBytes()` and
/// computes sha256 in one pass via `sha256.convert(bytes)`. A streaming
/// approach would be preferred for 1.5 GB downloads (the Phase 07 chunk
/// pipeline will do that via `AccumulatorSink<Digest>` from
/// `package:convert`), but the world bundle is small enough that the
/// extra dependency buys nothing here.
const String _worldAssetPath = 'assets/maps/world.pmtiles';
const String _outputPath = 'lib/config/world_bundle_sha256.dart';

const String _goslHeader =
    '// Copyright (c) 2026 THONGVAN Alexis\n'
    '// Licensed under the Good Old Software License v1.0\n'
    '// See LICENSE file for details\n';

/// Reads [assetPath] and writes a Dart file at [outputPath] declaring a
/// `const String kWorldBundleSha256` equal to the streaming sha256 digest
/// of the asset bytes.
///
/// Public so unit tests (should a future plan add them) can drive the
/// script against a synthetic fixture. The script has no side effects
/// beyond the single `File.writeAsStringSync` call below, and is safe to
/// re-run — the output file is overwritten in full.
Future<int> runCheck({String? assetPath, String? outputPath}) async {
  final String resolvedAsset = assetPath ?? _worldAssetPath;
  final String resolvedOutput = outputPath ?? _outputPath;

  final File assetFile = File(resolvedAsset);
  if (!assetFile.existsSync()) {
    stderr.writeln('generate_world_sha256: asset missing at ${p.relative(resolvedAsset)}');
    stderr.writeln('Run `/gsd:execute-plan 07-01` or copy the world bundle manually before invoking this script.');
    return 2;
  }

  final Uint8List bytes = assetFile.readAsBytesSync();
  final Digest digest = sha256.convert(bytes);
  // `package:crypto` Digest.toString() yields the hex representation
  // (lowercase), same shape as the `<chunk>.sha256` strings declared in
  // catalog.json. No need to pull `package:convert` for `hex.encode`.
  final String hexDigest = digest.toString();

  final StringBuffer sb = StringBuffer();
  sb.writeln(_goslHeader.trimRight());
  sb.writeln();
  sb.writeln('/// sha256 (hex) of the bundled `assets/maps/world.pmtiles` world-map PMTiles.');
  sb.writeln('///');
  sb.writeln('/// Emitted build-time by `tool/generate_world_sha256.dart`. The first-launch');
  sb.writeln('/// world copier (Phase 07 plan 07-03) compares this constant against the hash');
  sb.writeln('/// of the file currently at `<app_support>/maps/world.pmtiles`; a mismatch or');
  sb.writeln('/// missing file triggers a re-seed from the asset. Zero runtime cost — no');
  sb.writeln('/// asset re-read at app boot.');
  sb.writeln('///');
  sb.writeln('/// **Do NOT hand-edit.** Regenerate via `dart run tool/generate_world_sha256.dart`');
  sb.writeln('/// after every `assets/maps/world.pmtiles` update.');
  sb.writeln("const String kWorldBundleSha256 = '$hexDigest';");

  try {
    File(resolvedOutput).writeAsStringSync(sb.toString());
  } on IOException catch (e) {
    stderr.writeln('generate_world_sha256: failed to write $resolvedOutput: $e');
    return 1;
  }

  stdout.writeln('generate_world_sha256: OK — wrote sha256=$hexDigest to ${p.relative(resolvedOutput)}');
  return 0;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
