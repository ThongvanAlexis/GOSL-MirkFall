// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:mirkfall/infrastructure/map/style_rewriter.dart';
import 'package:test/test.dart';

import '../../fakes/fake_installed_manifest_repository.dart';

void main() {
  // Load the real asset once per run — it doubles as a fixture AND as a
  // regression guard (any drift in style.json fires these tests).
  final String realStyleJson = File('assets/maps/style.json').readAsStringSync();

  group('StyleRewriter — real asset path (via injected loader)', () {
    test('substitutes the placeholder with the world URI when activeCountry is null', () async {
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => realStyleJson);

      final String out = await rewriter.rewriteStyleForCountry(null);
      expect(out, isNot(contains('YOUR_PMTILES_PATH_PLACEHOLDER')));
      expect(out, contains('pmtiles://file:///app_support/maps/world.pmtiles'));
      await port.close();
    });

    test('substitutes with per-country URI when code is installed', () async {
      final CountryCode fra = CountryCode.parse('fra');
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      port.seedWith(
        InstalledManifest(
          schemaVersion: 1,
          catalogVersion: 'v20260419',
          installed: <String, InstalledCountry>{
            'fra': InstalledCountry(
              alpha3: fra,
              installedAtUtc: DateTime.utc(2026, 4, 20),
              fileSize: 1024,
              pmtilesVersion: 'v20260419',
              sha256: 'a' * 64,
              filePath: 'maps/countries/fra.pmtiles',
            ),
          },
        ),
      );
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => realStyleJson);

      final String out = await rewriter.rewriteStyleForCountry(fra);
      expect(out, contains('pmtiles://file:///app_support/maps/countries/fra.pmtiles'));
      expect(out, isNot(contains('YOUR_PMTILES_PATH_PLACEHOLDER')));
      await port.close();
    });

    test('rewriteWithSnapshot matches async rewrite output byte-for-byte', () async {
      final CountryCode fra = CountryCode.parse('fra');
      final InstalledManifest snapshot = InstalledManifest(
        schemaVersion: 1,
        catalogVersion: 'v20260419',
        installed: <String, InstalledCountry>{
          'fra': InstalledCountry(
            alpha3: fra,
            installedAtUtc: DateTime.utc(2026, 4, 20),
            fileSize: 1024,
            pmtilesVersion: 'v20260419',
            sha256: 'a' * 64,
            filePath: 'maps/countries/fra.pmtiles',
          ),
        },
      );
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      port.seedWith(snapshot);
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => realStyleJson);

      final String asyncOut = await rewriter.rewriteStyleForCountry(fra);
      final String syncOut = rewriter.rewriteWithSnapshot(activeCountry: fra, templateJson: realStyleJson, snapshot: snapshot);
      expect(syncOut, asyncOut);
      await port.close();
    });
  });

  group('StyleRewriter — error paths', () {
    test('throws MapAssetMissingException when asset loader fails', () async {
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => throw Exception('asset not bundled'));

      await expectLater(rewriter.rewriteStyleForCountry(null), throwsA(isA<MapAssetMissingException>()));
      await port.close();
    });

    test('throws MapStyleCorruptException when placeholder is missing from template', () async {
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      // Start from the real style.json so the layer-order check passes,
      // then remove the placeholder to trigger the guard that Task 1's
      // action spec requires.
      final String withoutPlaceholder = realStyleJson.replaceAll(
        'pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER',
        'pmtiles://file:///already_resolved.pmtiles',
      );
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => withoutPlaceholder);

      await expectLater(rewriter.rewriteStyleForCountry(null), throwsA(isA<MapStyleCorruptException>()));
      await port.close();
    });

    test('propagates layer-order drift as MapStyleCorruptException', () async {
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      // Swap two layer ids in the decoded+re-encoded style — a reliable
      // drift that triggers assertStyleLayerOrder without depending on
      // exact whitespace from the style.json file on disk.
      final Map<String, Object?> parsed = Map<String, Object?>.from(jsonDecode(realStyleJson) as Map);
      final List<Object?> layers = List<Object?>.from(parsed['layers']! as List);
      final Object? a = layers[0];
      layers[0] = layers[1];
      layers[1] = a;
      parsed['layers'] = layers;
      final String mutated = jsonEncode(parsed);
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => mutated);

      await expectLater(rewriter.rewriteStyleForCountry(null), throwsA(isA<MapStyleCorruptException>()));
      await port.close();
    });

    test('rejects external https:// URL injected into sources.<name>.tiles[] (row #3)', () async {
      // Row #3 regression: StyleRewriter must fail closed on any
      // http[s]:// URL inside a scanned field, mirroring the CI gate
      // tool/check_style_no_external_url.dart. Covers the sideloaded-
      // style case (V1.x style pack) where CI lint cannot run.
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      final Map<String, Object?> parsed = Map<String, Object?>.from(jsonDecode(realStyleJson) as Map);
      final Map<String, Object?> sources = Map<String, Object?>.from(parsed['sources']! as Map);
      final Map<String, Object?> mapSource = Map<String, Object?>.from(sources['mirkfall_map']! as Map);
      mapSource['tiles'] = <String>['https://tile.openstreetmap.org/{z}/{x}/{y}.pbf'];
      sources['mirkfall_map'] = mapSource;
      parsed['sources'] = sources;
      final String poisoned = jsonEncode(parsed);
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => poisoned);

      await expectLater(
        rewriter.rewriteStyleForCountry(null),
        throwsA(isA<MapStyleCorruptException>().having((MapStyleCorruptException e) => e.reason, 'reason', contains('external http'))),
      );
      await port.close();
    });

    test('rejects external http:// URL in glyphs field (row #3)', () async {
      final FakeInstalledManifestRepository port = FakeInstalledManifestRepository();
      final PmtilesSource src = PmtilesSource(installedManifestPort: port, appSupportDir: '/app_support');
      final Map<String, Object?> parsed = Map<String, Object?>.from(jsonDecode(realStyleJson) as Map);
      parsed['glyphs'] = 'http://example.test/fonts/{fontstack}/{range}.pbf';
      final String poisoned = jsonEncode(parsed);
      final StyleRewriter rewriter = StyleRewriterTestSeam.withAssetLoader(src, (_) async => poisoned);

      await expectLater(
        rewriter.rewriteStyleForCountry(null),
        throwsA(isA<MapStyleCorruptException>().having((MapStyleCorruptException e) => e.reason, 'reason', contains('glyphs'))),
      );
      await port.close();
    });
  });
}
