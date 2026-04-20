// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// CI gate enforcing the MAP-05 seam : no `pmtiles://http:` or
/// `pmtiles://https:` URI may appear in any `.dart` source file or
/// `.json` asset under `lib/`, `test/`, or `assets/`. The only accepted
/// tile URI scheme is `pmtiles://file:///…` (local-only).
///
/// Why this matters: MirkFall's V1.0 promise is "zero network for map
/// tiles, ever" — the world bundle + per-country PMTiles both live on
/// disk. A stray `pmtiles://https://…` URI would let MapLibre silently
/// stream tiles over HTTPS, breaking airplane-mode UX and the Phase 08
/// review-gate QUAL-05 smoke test. This scanner is cheap, deterministic,
/// and catches the leak at lint time rather than at user-reported
/// bug time.
///
/// Note: the catalog.json `parts[].url` entries hold plain
/// `https://github.com/ThongvanAlexis/countries-pmtiles/releases/…` URLs.
/// Those do NOT match this pattern — the pattern specifically looks for
/// `pmtiles://http` (the `pmtiles` scheme wrapping an http target),
/// not bare HTTP URLs. The GitHub download URLs in the catalog are
/// out-of-scope.
///
/// The .json scan is whole-file (string search, not AST) because a
/// MapLibre style.json embeds the source URL as a nested string value
/// (`{"sources":{"…":{"url":"…"}}}`) that would be tedious to pick out
/// via path-aware parsing. The pattern is narrow enough that a
/// substring match is safe (no legitimate JSON value starts with
/// `pmtiles://https`).
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : clean — no `pmtiles://http[s]` anywhere in the scanned
///     roots. This includes the placeholder `pmtiles://file:///…`
///     URI in `assets/maps/style.json`.
///   - exit 1 : violation — at least one offending string, emitted with
///     file path + line number + offending line on stderr.
///   - exit 2 : misconfiguration — every scan root is missing.
///
/// Case-insensitive because a malicious or inattentive contributor could
/// upper-case the scheme (`PMTILES://HTTPS:`) and dodge a
/// case-sensitive regex. RegExp `caseSensitive: false` closes that hole.
final RegExp _remotePattern = RegExp(r'pmtiles://https?:', caseSensitive: false);

const List<String> _defaultRoots = <String>['lib', 'test', 'assets'];

const List<String> _excludedDartSuffixes = <String>['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart'];

/// Runs the scan against [roots] (default `['lib', 'test', 'assets']`).
///
/// Public so unit tests can drive the scanner against synthetic fixture
/// trees built with `Directory.systemTemp.createTemp`. The default paths
/// are resolved against `Directory.current`, so production CI runs from
/// the repo root pick up `./lib/`, `./test/`, `./assets/`.
Future<int> runCheck({List<String>? roots}) async {
  final List<String> resolvedRoots = roots ?? _defaultRoots;
  final List<String> violations = <String>[];
  var filesScanned = 0;
  var rootsSeen = 0;

  for (final String rootPath in resolvedRoots) {
    final Directory root = Directory(rootPath);
    if (!root.existsSync()) continue;
    rootsSeen++;

    await for (final FileSystemEntity entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final String normalized = entity.path.replaceAll('\\', '/');
      final bool isDart = normalized.endsWith('.dart');
      final bool isJson = normalized.endsWith('.json');
      if (!isDart && !isJson) continue;
      if (isDart && _excludedDartSuffixes.any(normalized.endsWith)) continue;

      filesScanned++;
      // Read line-by-line so we can report a line number on violation.
      // `readAsLines()` handles both LF + CRLF endings transparently.
      final List<String> lines = await entity.readAsLines();
      for (var i = 0; i < lines.length; i++) {
        if (_remotePattern.hasMatch(lines[i])) {
          violations.add('${p.relative(entity.path)}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
  }

  if (rootsSeen == 0) {
    stderr.writeln('check_avoid_remote_pmtiles: no scan root exists (tried: ${resolvedRoots.join(', ')})');
    return 2;
  }

  if (violations.isEmpty) {
    stdout.writeln('check_avoid_remote_pmtiles: OK ($filesScanned file(s), zero pmtiles://http[s] URIs)');
    return 0;
  }

  stderr.writeln('check_avoid_remote_pmtiles: ${violations.length} remote pmtiles URI(s) found:');
  for (final String v in violations) {
    stderr.writeln('  $v');
  }
  stderr.writeln();
  stderr.writeln('Rule (MAP-05): MirkFall ships 100 % offline. The only accepted tile URI scheme is `pmtiles://file:///…`.');
  stderr.writeln('Replace the offending URI with a local-file path or route through lib/infrastructure/map/pmtiles_source.dart.');
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
