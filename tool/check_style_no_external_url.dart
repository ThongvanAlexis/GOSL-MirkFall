// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// CI gate enforcing the MAP-05 + MAP-09 "offline-only style" contract :
/// no `http://` / `https://` URL may appear in `assets/maps/style.json`'s
/// source URLs, tile arrays, glyphs path, or sprite path.
///
/// Why this matters: `maplibre_gl` happily streams tiles from a hosted
/// tile server if the style's `sources.<name>.url` or `tiles[]` points
/// at an HTTPS endpoint. Even a well-intentioned V1.x style-variant
/// commit (e.g. a designer pasting a Mapbox Studio tile URL into
/// `style.json`) would silently turn airplane-mode UX red. This scanner
/// blocks that at lint time, BEFORE it reaches the user.
///
/// Companion to `tool/check_avoid_remote_pmtiles.dart`:
///   - `check_avoid_remote_pmtiles` scans every `.dart` / `.json` file
///     under `lib/` / `test/` / `assets/` for `pmtiles://http[s]:` URIs
///     (the MapLibre PMTiles plugin scheme wrapping HTTP).
///   - `check_style_no_external_url` scans `assets/maps/style.json`
///     specifically for bare `http[s]://…` URLs in the known URL-
///     bearing fields. A poisoned style embeds the HTTP URL in a tile
///     array (not a pmtiles wrapper), so check_avoid_remote_pmtiles
///     would not catch it.
///
/// Allowed URL patterns:
///   - `pmtiles://file:///…`         — local PMTiles wrapped for MapLibre
///   - `file:///…`                   — plain local file URI
///   - `asset:///assets/…`           — Flutter asset-bundle URI (glyphs / sprites)
///   - relative paths `assets/…`     — asset-bundle relative (same origin)
///   - template placeholders like    — MapLibre's style tokens, not URLs
///     `{fontstack}`, `{z}/{x}/{y}`
///
/// Rejected patterns: any `http://` / `https://` URL in the scanned
/// fields.
///
/// CLI contract (Phase 01 convention, same as check_avoid_remote_pmtiles):
///   - exit 0 : clean — no external URL in any scanned field.
///   - exit 1 : violation — at least one offending URL, emitted with
///     file path + JSON path + offending URL on stderr.
///   - exit 2 : misconfiguration — target file missing OR invalid JSON.
///
/// Scanned fields (walk of the style.json AST):
///   - `glyphs`                      — top-level string
///   - `sprite`                      — top-level string
///   - `sources.<name>.url`          — per-source URL
///   - `sources.<name>.tiles[]`      — per-source tile URL array
///
/// The walker ignores other fields (layers, paint, layout, …) — those
/// do not hold URLs in MapLibre style spec.
///
/// Paired unit test: `tool/test/check_style_no_external_url_test.dart`
/// (7 scenarios covering exit codes 0/1/2 + production asset passthrough).
///
/// Wired into `.github/workflows/ci.yml` `gates` job at Plan 08-04
/// Task 6, adjacent to the existing `check_avoid_remote_pmtiles` step.
final RegExp _externalPattern = RegExp(r'^https?://', caseSensitive: false);

const String _defaultStylePath = 'assets/maps/style.json';

/// Runs the scan against [stylePath] (default `assets/maps/style.json`).
///
/// Public so unit tests can invoke the scanner against synthetic fixtures
/// built with `Directory.systemTemp.createTemp`.
Future<int> runCheck({String stylePath = _defaultStylePath}) async {
  final File styleFile = File(stylePath);

  if (!styleFile.existsSync()) {
    stderr.writeln('check_style_no_external_url: missing $stylePath');
    return 2;
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(styleFile.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('check_style_no_external_url: invalid JSON in $stylePath — ${e.message}');
    return 2;
  }

  if (decoded is! Map<String, Object?>) {
    stderr.writeln('check_style_no_external_url: $stylePath top-level is not a JSON object (got ${decoded.runtimeType})');
    return 2;
  }

  final List<String> violations = <String>[];
  final String relPath = p.relative(styleFile.path);

  // `glyphs` — top-level string.
  final Object? glyphs = decoded['glyphs'];
  if (glyphs is String && _externalPattern.hasMatch(glyphs)) {
    violations.add('$relPath: glyphs = $glyphs');
  }

  // `sprite` — top-level string.
  final Object? sprite = decoded['sprite'];
  if (sprite is String && _externalPattern.hasMatch(sprite)) {
    violations.add('$relPath: sprite = $sprite');
  }

  // `sources.<name>.url` + `sources.<name>.tiles[]`.
  final Object? sources = decoded['sources'];
  if (sources is Map) {
    sources.forEach((Object? sourceName, Object? sourceValue) {
      if (sourceValue is! Map) return;

      final Object? url = sourceValue['url'];
      if (url is String && _externalPattern.hasMatch(url)) {
        violations.add('$relPath: sources.$sourceName.url = $url');
      }

      final Object? tiles = sourceValue['tiles'];
      if (tiles is List) {
        for (int i = 0; i < tiles.length; i++) {
          final Object? t = tiles[i];
          if (t is String && _externalPattern.hasMatch(t)) {
            violations.add('$relPath: sources.$sourceName.tiles[$i] = $t');
          }
        }
      }
    });
  }

  if (violations.isEmpty) {
    stdout.writeln('check_style_no_external_url: OK ($relPath has zero http[s]:// URLs in scanned fields)');
    return 0;
  }

  stderr.writeln('check_style_no_external_url: ${violations.length} external URL(s) detected in $relPath:');
  for (final String v in violations) {
    stderr.writeln('  $v');
  }
  stderr.writeln();
  stderr.writeln('Rule (MAP-05 / MAP-09): MirkFall renders offline-only. Any http[s]:// URL in');
  stderr.writeln('the style would let MapLibre stream tiles from a hosted endpoint, breaking');
  stderr.writeln('airplane-mode UX + the Phase 08 review-gate QUAL-05 contract. Use');
  stderr.writeln('`pmtiles://file:///…`, `file:///…`, `asset:///…`, or relative asset paths.');
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
