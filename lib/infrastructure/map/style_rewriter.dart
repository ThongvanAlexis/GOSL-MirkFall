// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/services.dart' show rootBundle;
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';

import 'pmtiles_source.dart';
import 'style_layer_order.dart';

/// Literal placeholder baked into `assets/maps/style.json` that the
/// runtime rewriter substitutes for the resolved `pmtiles://file:///…`
/// URI. See Plan 07-01 §Style (style.json `sources.mirkfall_map.url`).
const String kStylePmtilesPlaceholder = 'pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER';

/// Loads the bundled style.json and substitutes the runtime PMTiles URI.
///
/// Two responsibilities:
/// 1. Fetch `assets/maps/style.json` via `rootBundle`.
/// 2. Replace the literal [kStylePmtilesPlaceholder] with the URI produced
///    by [PmtilesSource] for the active country (or the world bundle when
///    the active country is `null` / not installed).
///
/// The rewritten JSON is returned as a raw string — MapLibre's
/// `setStyle` accepts the raw style document, and keeping the
/// serialisation avoids a round-trip through `jsonDecode`/`jsonEncode`
/// that would re-order keys and inflate the style payload unnecessarily.
///
/// Error handling:
/// - Missing asset → [MapAssetMissingException].
/// - Asset without the placeholder literal (someone edited style.json
///   and forgot the marker) → [MapStyleCorruptException] with an
///   actionable reason.
/// - Layer-order or per-layer-shape drift → [MapStyleCorruptException]
///   via [assertStyleLayerOrder] + [assertStyleLayerValidity].
class StyleRewriter {
  StyleRewriter(this._pmtilesSource, {StyleAssetLoader? assetLoader}) : _assetLoader = assetLoader ?? _defaultAssetLoader;

  final PmtilesSource _pmtilesSource;
  final StyleAssetLoader _assetLoader;

  /// Loads `assets/maps/style.json`, substitutes the PMTiles placeholder,
  /// validates the style shape, and returns the finished JSON string.
  Future<String> rewriteStyleForCountry(CountryCode? activeCountry) async {
    final String template = await _loadTemplate();
    assertStyleLayerOrder(template);
    assertStyleLayerValidity(template);

    if (!template.contains(kStylePmtilesPlaceholder)) {
      throw const MapStyleCorruptException(reason: 'style.json does not contain placeholder "$kStylePmtilesPlaceholder" — asset may have been hand-edited');
    }

    final String resolvedUri = await _pmtilesSource.forCountry(activeCountry);
    // `replaceAll`, not `replaceFirst` — the Phase 07-01 style.json carries
    // the placeholder in two spots: the `metadata.mirkfall:runtime_url_placeholder`
    // documentation string AND the `sources.mirkfall_map.url` tile URL.
    // Both must be substituted for the runtime to find a valid source URL
    // and for the metadata block to reflect reality.
    return template.replaceAll(kStylePmtilesPlaceholder, resolvedUri);
  }

  /// Synchronous rewrite variant — consumes a caller-provided
  /// [snapshot] + pre-loaded [templateJson] and returns the substituted
  /// style. Used by paths that need to avoid `await` (camera-preserving
  /// showMap, widget `initState`).
  String rewriteWithSnapshot({required CountryCode? activeCountry, required String templateJson, required InstalledManifest snapshot}) {
    assertStyleLayerOrder(templateJson);
    assertStyleLayerValidity(templateJson);
    if (!templateJson.contains(kStylePmtilesPlaceholder)) {
      throw const MapStyleCorruptException(reason: 'style.json does not contain placeholder "$kStylePmtilesPlaceholder" — asset may have been hand-edited');
    }
    final String resolvedUri = _pmtilesSource.forCountryOrWorld(activeCountry, snapshot);
    return templateJson.replaceAll(kStylePmtilesPlaceholder, resolvedUri);
  }

  Future<String> _loadTemplate() async {
    try {
      return await _assetLoader(kStyleJsonAssetPath);
    } on Object catch (e) {
      throw MapAssetMissingException(assetPath: kStyleJsonAssetPath, reason: 'rootBundle.loadString failed: $e');
    }
  }
}

/// Signature for the asset loader injection. Tests pass a fake loader
/// that returns a synthetic style JSON without requiring the
/// ServicesBinding / rootBundle to be live.
typedef StyleAssetLoader = Future<String> Function(String path);

Future<String> _defaultAssetLoader(String path) => rootBundle.loadString(path);

/// Test-facing hook — lets unit tests drive [StyleRewriter] through a
/// controlled asset loader. Kept separate from the class constructor so
/// production call sites do not see the injection seam in IDE auto-complete.
extension StyleRewriterTestSeam on StyleRewriter {
  static StyleRewriter withAssetLoader(PmtilesSource source, Future<String> Function(String path) loader) {
    return StyleRewriter(source, assetLoader: loader);
  }
}
