// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Builds the deterministic 50k-row fixture at
/// `test/fixtures/mirk/fifty_k_tiles_seed.sql` for the Phase 09 perf probe.
///
/// Source of truth — `tool/check_mirk_fixture_fresh.dart` runs this builder
/// to a tmp file and byte-compares against the committed SQL. Two
/// invocations from a pristine state MUST produce byte-identical output
/// (deterministic seed, fixed timestamps, fixed grid).
///
/// CLI:
/// ```
/// dart run tool/fixtures/build_50k_tiles.dart            # write to default path
/// dart run tool/fixtures/build_50k_tiles.dart --output=foo.sql
/// ```
///
/// Layout:
/// 1. Header comment block (deterministic — fixed prose).
/// 2. One `INSERT INTO t_sessions` row (the FK target).
/// 3. 50,000 `INSERT INTO t_revealed_tiles` rows on a 500×100 parent
///    tile grid at parent zoom 14, each carrying a 512-byte hex literal
///    bitmap with ≈ 25 % of bits set.
///
/// Constants below are wire-locked: changing them rewrites the entire
/// fixture and the freshness gate will surface the drift on next CI run.
/// ---------------------------------------------------------------------------
/// Determinism seed — Crockford-encoded "MIRK" (0x4D49524B). Embedding
/// the seed in the fixture's session id (sess_01FIFTYKTEST...) makes it
/// trivially traceable from a `git log -p` of `fifty_k_tiles_seed.sql`.
const int kFiftyKSeed = 0x4D49524B;

/// Total revealed-tile rows.
const int kFiftyKRowCount = 50000;

/// Grid dimensions — 500 × 100 = 50_000.
const int kFiftyKGridXCount = 500;
const int kFiftyKGridYCount = 100;

/// Origin of the parent-tile grid (zoom 14). 8400 / 5500 sits over central
/// Europe at z=14 — irrelevant to the perf measurement but a sane default
/// for any debug visualisation that loads the fixture into a real DB.
const int kFiftyKOriginParentX = 8400;
const int kFiftyKOriginParentY = 5500;
const int kFiftyKParentZoom = 14;

/// Bitmap density — fraction of the 4096-bit bitmap set per row.
///
/// Lower than the 09-RESEARCH suggestion (25 %) for git-friendliness:
/// the iteration cost in [`buildUnrevealedCellsPath`] is per-cell
/// (4096 cells iterated unconditionally regardless of bit value), so
/// the perf measurement is insensitive to density. 1 % keeps most
/// bitmap bytes at 0x00, which gzip crunches from ~60 MB raw down to
/// roughly 4 MB — well below the 20 MB plan ceiling and small enough
/// that `git status` on the fixture is instant.
const double kFiftyKBitDensity = 0.01;

/// Fixed UTC offset on every t_sessions/t_revealed_tiles row — keeps the
/// SQL stable across runs regardless of host timezone.
const String kFiftyKUtcInstantIso = '2026-01-01T00:00:00.000Z';

/// Default output path (relative to repo root). Gzipped — at full hex
/// resolution (4096 bits ≈ 1024 hex chars per row × 50_000 rows ≈ 60 MB
/// raw) the uncompressed SQL exceeds the 20 MB plan ceiling, so the
/// committed artefact is gzip-compressed at default level. Test loaders
/// stream-decompress on read.
const String kFiftyKDefaultOutput = 'test/fixtures/mirk/fifty_k_tiles_seed.sql.gz';

/// Fixed session id for the fixture rows. The 26-char ULID body is
/// hand-crafted (NOT minted by IdGenerator) so the builder stays
/// deterministic across `dart:math.Random`-seeded ULID minting.
const String kFiftyKSessionId = 'sess_01FIFTYKTEST0000000000000';

/// Bitmap byte length per Phase 03 invariant — 64×64 / 8 = 512.
const int kFiftyKBitmapBytes = 512;

/// Total bits per bitmap (4096).
const int kFiftyKBitmapBits = kFiftyKBitmapBytes * 8;

/// Drift uses Unix-epoch milliseconds for the date columns
/// (UnixMsToDateTimeConverter, see `lib/infrastructure/db/type_converters.dart`).
/// 2026-01-01T00:00:00.000Z = 1767225600000 ms.
const int kFiftyKUtcInstantMs = 1767225600000;

Future<void> main(List<String> args) async {
  final String output = _parseOutputArg(args) ?? kFiftyKDefaultOutput;
  final File outFile = File(output);
  outFile.parent.createSync(recursive: true);

  // Build the SQL into an in-memory buffer first, then gzip-encode +
  // write. Two-pass keeps the determinism contract simple — gzip's
  // header carries no timestamp by default with `GZipCodec(level:
  // gzip.defaultLevel)` (verified: ZLib library writes a fixed
  // mtime=0 unless the embedder overrides) so two runs produce
  // byte-identical output.
  final BytesBuilder bb = BytesBuilder(copy: false);
  final IOSink mem = IOSink(_BytesBuilderConsumer(bb));
  try {
    _writeHeader(mem);
    _writeSessionInsert(mem);
    _writeRevealedTileInserts(mem);
  } finally {
    await mem.flush();
    await mem.close();
  }
  final Uint8List rawSql = bb.takeBytes();

  if (output.endsWith('.gz')) {
    // Use a fixed gzip configuration so `dart run …` twice produces
    // byte-identical output. The default GZipCodec sets mtime=0 which
    // is what we need for deterministic builds.
    //
    // Cross-platform fix: Dart's GZipCodec writes the gzip OS byte
    // (header offset 9, RFC 1952 §2.3.1) based on the host platform —
    // 0x0A on Windows, 0x03 on Linux, etc. That breaks the byte-identical
    // contract that `check_mirk_fixture_fresh` enforces between dev
    // machines and CI runners. We force OS=0xFF ("unknown") which is the
    // canonical "platform-agnostic" value per the RFC.
    final Uint8List gz = Uint8List.fromList(gzip.encode(rawSql));
    gz[9] = 0xFF;
    outFile.writeAsBytesSync(gz, flush: true);
  } else {
    outFile.writeAsBytesSync(rawSql, flush: true);
  }
  stdout.writeln('build_50k_tiles: wrote ${outFile.path} (${outFile.lengthSync()} bytes)');
}

/// `StreamConsumer<List<int>>` over a [BytesBuilder] so we can use
/// [IOSink] for the row-by-row writes (its `writeln` API is more
/// readable than direct byte concat) without materialising a temp file.
class _BytesBuilderConsumer implements StreamConsumer<List<int>> {
  _BytesBuilderConsumer(this._bb);

  final BytesBuilder _bb;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bb.add(chunk);
    }
  }

  @override
  Future<void> close() async {}
}

/// Parses `--output=<path>` from argv. Returns null if absent.
String? _parseOutputArg(List<String> args) {
  for (final a in args) {
    if (a.startsWith('--output=')) return a.substring('--output='.length);
  }
  return null;
}

void _writeHeader(IOSink sink) {
  // Header is intentionally verbose: anyone landing on this file in a
  // git diff should immediately know it is generated, not hand-edited.
  sink.writeln('-- Copyright (c) 2026 THONGVAN Alexis');
  sink.writeln('-- Licensed under the Good Old Software License v1.0');
  sink.writeln('-- See LICENSE file for details');
  sink.writeln('--');
  sink.writeln('-- DETERMINISTIC FIXTURE — DO NOT EDIT BY HAND.');
  sink.writeln('-- Generated by tool/fixtures/build_50k_tiles.dart');
  sink.writeln('-- (seed=0x${kFiftyKSeed.toRadixString(16).toUpperCase()},');
  sink.writeln('--  rows=$kFiftyKRowCount, grid=${kFiftyKGridXCount}x$kFiftyKGridYCount,');
  sink.writeln('--  origin=($kFiftyKOriginParentX,$kFiftyKOriginParentY), zoom=$kFiftyKParentZoom).');
  sink.writeln('-- Re-generate via:  dart run tool/fixtures/build_50k_tiles.dart');
  sink.writeln('-- Freshness gate:   dart run tool/check_mirk_fixture_fresh.dart');
  sink.writeln('--');
  sink.writeln('-- Phase 09 plan 09-08 — 50k-tile perf probe (SC#4).');
  sink.writeln();
}

void _writeSessionInsert(IOSink sink) {
  // Match the V4 t_sessions schema (Drift snake_case columns):
  //   id, display_name, status, started_at_utc, started_at_offset_minutes,
  //   stopped_at_utc, stopped_at_offset_minutes, notes, mirk_style_id
  sink.writeln(
    "INSERT INTO t_sessions (id, display_name, status, started_at_utc, started_at_offset_minutes, stopped_at_utc, stopped_at_offset_minutes, notes, mirk_style_id) "
    "VALUES ('$kFiftyKSessionId', 'Fifty-K Perf Fixture', 'stopped', $kFiftyKUtcInstantMs, 0, $kFiftyKUtcInstantMs, 0, NULL, NULL);",
  );
  sink.writeln();
}

void _writeRevealedTileInserts(IOSink sink) {
  final math.Random rng = math.Random(kFiftyKSeed);
  // Reusable buffer to avoid allocating 50k Uint8List instances.
  final Uint8List bitmap = Uint8List(kFiftyKBitmapBytes);

  // Match the V1 t_revealed_tiles schema:
  //   id, sessionId, parentX, parentY, parentZoom, bitmap, setBitCount, updatedAtUtc
  for (int idx = 0; idx < kFiftyKRowCount; idx++) {
    // Iteration order: outer = y, inner = x — yields a row-major sweep
    // through the grid that, combined with the deterministic RNG order,
    // produces a stable byte stream.
    final int gridY = idx ~/ kFiftyKGridXCount;
    final int gridX = idx % kFiftyKGridXCount;
    final int parentX = kFiftyKOriginParentX + gridX;
    final int parentY = kFiftyKOriginParentY + gridY;

    // Reset bitmap, then set ≈ 25 % of bits using the RNG. Per-bit Bernoulli
    // trial keeps the math simple and the output deterministic given the
    // seed.
    for (int b = 0; b < kFiftyKBitmapBytes; b++) {
      bitmap[b] = 0;
    }
    int popcount = 0;
    for (int bit = 0; bit < kFiftyKBitmapBits; bit++) {
      if (rng.nextDouble() < kFiftyKBitDensity) {
        bitmap[bit >> 3] |= 1 << (bit & 7);
        popcount++;
      }
    }

    final String hex = _hexUpper(bitmap);
    final String rowId = _formatRowId(idx);

    sink.writeln(
      "INSERT INTO t_revealed_tiles (id, session_id, parent_x, parent_y, parent_zoom, bitmap, set_bit_count, updated_at_utc) "
      "VALUES ('$rowId', '$kFiftyKSessionId', $parentX, $parentY, $kFiftyKParentZoom, X'$hex', $popcount, $kFiftyKUtcInstantMs);",
    );
  }
}

/// Crockford-base32-styled row id of the form `rvt_01FIFTYK<5-digit idx>00000000000`
/// (26-char ULID body following the `rvt_` prefix).
///
/// Pure formatting — does not call IdGenerator (which would draw from
/// `dart:math.Random` differently per build) so the SQL stays byte-stable.
String _formatRowId(int idx) {
  final String paddedIdx = idx.toString().padLeft(5, '0');
  // Body must be exactly 26 chars: 'FIFTYK' (6) + paddedIdx (5) + 'AAAAAAAAAAAAAAA' (15) = 26.
  return 'rvt_01FIFTYK${paddedIdx}AAAAAAAAAAAAAAA';
}

/// Uppercase hex encoding for a 512-byte bitmap. Drift's `BlobColumn`
/// reads `X'…'` literals as raw bytes — uppercase chosen for visual
/// regularity in `git diff`.
String _hexUpper(Uint8List bytes) {
  const String alphabet = '0123456789ABCDEF';
  final StringBuffer buf = StringBuffer();
  for (final b in bytes) {
    buf.write(alphabet[(b >> 4) & 0x0F]);
    buf.write(alphabet[b & 0x0F]);
  }
  return buf.toString();
}
