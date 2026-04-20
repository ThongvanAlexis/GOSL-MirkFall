// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One-shot maintenance script that reads the user-provided country polygons
/// under `C:\claude_checkouts\countries\data\<alpha3>.geo.json` and emits
/// simplified versions under `assets/maps/polygons/<alpha3>.geo.json` for
/// the Phase 07 country resolver (viewport-center → alpha3 decisions).
///
/// ## Why bounding-box simplification (Phase 07-01 initial drop)
///
/// The raw data totals ~16 MB across 249 countries; Phase 07-01's budget
/// is ≤ 5 MB total. A full-fidelity simplification via mapshaper or
/// Douglas-Peucker at a real tolerance would require either an external
/// CLI dependency (mapshaper, Node.js) or a non-trivial pure-Dart
/// implementation, both of which inflate scope.
///
/// Instead, this initial drop emits **axis-aligned bounding boxes** per
/// country: each polygon is reduced to a 5-vertex closed ring
/// `[[minLon,minLat],[maxLon,minLat],[maxLon,maxLat],[minLon,maxLat],[minLon,minLat]]`.
/// This gives the country resolver a deterministic fallback footprint
/// large enough that the "is this viewport center inside alpha3?" question
/// always has a definitive yes/no answer at boundaries.
///
/// Accepted drawbacks, documented in 07-01-SUMMARY.md:
///  - Overlap: adjacent countries with similar latitudes share bbox edges.
///    The resolver (Phase 07 plan 07-03) tie-breaks by installed-order
///    or deterministic sort — acceptable per 07-CONTEXT "glitch frontière
///    acceptable".
///  - Enclaves (e.g. Lesotho inside ZAF) fully inside a neighbour's bbox.
///    Resolved by catalog ordering + per-installed-country match priority.
///
/// A follow-up plan can replace this with real mapshaper output. The
/// output path stays stable (`assets/maps/polygons/<alpha3>.geo.json`,
/// GeoJSON FeatureCollection shape) so consumers do not churn.
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : clean run, all source polygons processed
///   - exit 1 : at least one source file was unparseable (emitted stderr,
///              skipped — remaining files still processed)
///   - exit 2 : source directory missing, output directory cannot be
///              created, or output write failure
///
/// Invocation: `dart run tool/simplify_polygons.dart` from the repo root,
/// once, whenever the upstream `C:\claude_checkouts\countries\data`
/// folder is refreshed. The output is committed alongside the run.
const String _defaultSourceDir = r'C:\claude_checkouts\countries\data';
const String _defaultOutputDir = 'assets/maps/polygons';

const String _goslHeader =
    '// Copyright (c) 2026 THONGVAN Alexis\n'
    '// Licensed under the Good Old Software License v1.0\n'
    '// See LICENSE file for details\n';

/// One bounding box across all coordinate pairs in a GeoJSON geometry.
/// Encapsulated so we do not grow a 4-element list + flags out of line.
class _Bbox {
  double minLon = double.infinity;
  double minLat = double.infinity;
  double maxLon = double.negativeInfinity;
  double maxLat = double.negativeInfinity;

  bool get isValid => minLon.isFinite && minLat.isFinite && maxLon.isFinite && maxLat.isFinite;

  void feed(num lon, num lat) {
    if (lon < minLon) minLon = lon.toDouble();
    if (lon > maxLon) maxLon = lon.toDouble();
    if (lat < minLat) minLat = lat.toDouble();
    if (lat > maxLat) maxLat = lat.toDouble();
  }
}

/// Runs the simplification. Public so a future unit test can drive it
/// against synthetic fixture dirs without touching the real
/// `C:\claude_checkouts\countries\data` tree.
Future<int> runCheck({String? sourceDir, String? outputDir}) async {
  final String resolvedSource = sourceDir ?? _defaultSourceDir;
  final String resolvedOutput = outputDir ?? _defaultOutputDir;

  final Directory src = Directory(resolvedSource);
  if (!src.existsSync()) {
    stderr.writeln('simplify_polygons: source directory not found at $resolvedSource');
    return 2;
  }
  final Directory out = Directory(resolvedOutput);
  try {
    out.createSync(recursive: true);
  } on IOException catch (e) {
    stderr.writeln('simplify_polygons: cannot create output dir $resolvedOutput: $e');
    return 2;
  }

  int processed = 0;
  int failed = 0;
  int totalBytes = 0;
  final List<FileSystemEntity> entries = src.listSync();
  // Sort deterministically so the diff is stable across runs on different
  // filesystems (Windows vs POSIX listSync ordering is not guaranteed).
  entries.sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));

  for (final FileSystemEntity entity in entries) {
    if (entity is! File) continue;
    final String basename = p.basename(entity.path);
    if (!basename.endsWith('.geo.json')) continue;
    // Strip the compound '.geo.json' suffix; basenameWithoutExtension only
    // strips one level.
    final String alpha3 = basename.substring(0, basename.length - '.geo.json'.length);
    try {
      final Object? parsed = jsonDecode(entity.readAsStringSync());
      final _Bbox bbox = _bboxFromGeoJson(parsed);
      if (!bbox.isValid) {
        stderr.writeln('simplify_polygons: $basename has no coordinates — skipped');
        failed++;
        continue;
      }
      final String outJson = _writeBboxFeatureCollection(alpha3, bbox);
      final File outFile = File(p.join(resolvedOutput, '$alpha3.geo.json'));
      outFile.writeAsStringSync(outJson);
      totalBytes += outJson.length;
      processed++;
    } on FormatException catch (e) {
      stderr.writeln('simplify_polygons: failed to parse $basename: ${e.message}');
      failed++;
    } on IOException catch (e) {
      stderr.writeln('simplify_polygons: IO error on $basename: $e');
      failed++;
    }
  }

  // Emit an INDEX.md sidecar so downstream readers know this directory is
  // machine-generated + the source of truth for regeneration.
  final String headerBlock = _goslHeader.replaceAll('// ', '<!-- ').replaceAll('\n', ' -->\n');
  final String kbTotal = (totalBytes / 1024).toStringAsFixed(1);
  final File indexFile = File(p.join(resolvedOutput, 'INDEX.md'));
  indexFile.writeAsStringSync(
    '$headerBlock'
    '\n# `assets/maps/polygons/` — country bounding polygons\n\n'
    'Machine-generated by `tool/simplify_polygons.dart`.\n'
    'Do NOT hand-edit. Re-run the script against the upstream\n'
    '`C:\\\\claude_checkouts\\\\countries\\\\data` tree to refresh.\n\n'
    'Each `<alpha3>.geo.json` is a single-polygon GeoJSON FeatureCollection\n'
    'carrying the axis-aligned bounding box of the source country.\n\n'
    '**$processed** files processed, **$failed** failed, '
    '**$kbTotal KB** total.\n',
  );

  stdout.writeln('simplify_polygons: OK — $processed processed, $failed failed, ${(totalBytes / 1024).toStringAsFixed(1)} KB written to $resolvedOutput');
  return failed > 0 ? 1 : 0;
}

/// Walks a GeoJSON geometry tree and feeds every `[lon, lat]` pair into a
/// single bbox. Accepts the `FeatureCollection` / `Feature` wrappers and
/// the `Polygon` / `MultiPolygon` geometry types — the shape actually used
/// by the user-provided tree. Everything else is fed positionally.
_Bbox _bboxFromGeoJson(Object? node) {
  final _Bbox bbox = _Bbox();
  _feedBbox(bbox, node);
  return bbox;
}

void _feedBbox(_Bbox bbox, Object? node) {
  if (node is Map) {
    final Object? features = node['features'];
    if (features is List) {
      for (final Object? f in features) {
        _feedBbox(bbox, f);
      }
      return;
    }
    final Object? geom = node['geometry'];
    if (geom != null) {
      _feedBbox(bbox, geom);
      return;
    }
    final Object? coords = node['coordinates'];
    if (coords != null) {
      _feedCoords(bbox, coords);
      return;
    }
    return;
  }
  // Raw coordinate array.
  if (node is List) {
    _feedCoords(bbox, node);
  }
}

void _feedCoords(_Bbox bbox, Object? coords) {
  if (coords is! List) return;
  // A coordinate pair is [num, num, (num)]. Detect by the two leading nums.
  if (coords.length >= 2 && coords[0] is num && coords[1] is num) {
    bbox.feed(coords[0] as num, coords[1] as num);
    return;
  }
  for (final Object? inner in coords) {
    _feedCoords(bbox, inner);
  }
}

/// Emits a minimal GeoJSON FeatureCollection for [alpha3] carrying the
/// [bbox] as a single closed Polygon ring. The output is a compact
/// pretty-printed JSON for readable diffs.
String _writeBboxFeatureCollection(String alpha3, _Bbox bbox) {
  final Map<String, Object?> payload = <String, Object?>{
    'type': 'FeatureCollection',
    'features': <Map<String, Object?>>[
      <String, Object?>{
        'type': 'Feature',
        'properties': <String, Object?>{'alpha3': alpha3, 'generator': 'tool/simplify_polygons.dart (bbox simplification)'},
        'geometry': <String, Object?>{
          'type': 'Polygon',
          'coordinates': <List<List<double>>>[
            <List<double>>[
              <double>[bbox.minLon, bbox.minLat],
              <double>[bbox.maxLon, bbox.minLat],
              <double>[bbox.maxLon, bbox.maxLat],
              <double>[bbox.minLon, bbox.maxLat],
              <double>[bbox.minLon, bbox.minLat],
            ],
          ],
        },
      },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
