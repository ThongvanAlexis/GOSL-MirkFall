// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/providers/builtin_mirk_styles_provider.dart';
import 'package:mirkfall/application/providers/mirk_renderer_factory_provider.dart';
import 'package:mirkfall/application/providers/mirk_style_store_provider.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/mirk_renderer_factory.dart';

import '../../fakes/fake_mirk_style_store.dart';

/// Plan 09-05 Task 2 — the lazy-seeding `builtinMirkStylesProvider`.
///
/// Mirrors the Phase 05 `_buildContainer` pattern from
/// `test/application/controllers/active_session_controller_test.dart`
/// — explicit ProviderContainer with concrete overrides for the store
/// dependency (no placeholder comments, no Mocktail).
///
/// Coverage:
/// * First read on a fresh DB seeds 4 rows in canonical order.
/// * Second read after invalidation is idempotent (no duplicate
///   inserts).
/// * Self-healing — if a builtin row is deleted out-of-band, a fresh
///   read re-seeds it.
/// * `mirkRendererFactoryProvider` is a stable singleton.
ProviderContainer _buildContainer({required FakeMirkStyleStore styleStore}) {
  return ProviderContainer(overrides: [mirkStyleStoreProvider.overrideWith((ref) async => styleStore)]);
}

void main() {
  group('09-05 — mirkRendererFactoryProvider', () {
    test('exposes a const MirkRendererFactory singleton', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final factory = container.read(mirkRendererFactoryProvider);
      expect(factory, isA<MirkRendererFactory>());
      // Subsequent reads return the same instance (keepAlive: true,
      // const constructor).
      expect(container.read(mirkRendererFactoryProvider), same(factory));
    });
  });

  group('09-05 — builtinMirkStylesProvider', () {
    late FakeMirkStyleStore styleStore;

    setUp(() {
      styleStore = FakeMirkStyleStore();
    });

    test('first read seeds 4 builtins in canonical order', () async {
      expect(styleStore.rows, isEmpty, reason: 'precondition: store starts empty');

      final container = _buildContainer(styleStore: styleStore);
      addTearDown(container.dispose);

      final styles = await container.read(builtinMirkStylesProvider.future);

      expect(styles, hasLength(4));
      expect(styleStore.rows, hasLength(4), reason: 'all 4 builtins must be inserted into the store');
      expect(styles.map((s) => s.id.value).toList(), <String>[
        'style_builtin_atmospheric',
        'style_builtin_solid',
        'style_builtin_candlelight',
        'style_builtin_heavenly_clouds',
      ], reason: 'canonical builtin order from kBuiltinMirkStyles');

      // Each entity carries the descriptor's default config variant.
      expect(styles[0].config, isA<AtmosphericConfig>());
      expect(styles[1].config, isA<SolidConfig>());
      expect(styles[2].config, isA<CandlelightConfig>());
      expect(styles[3].config, isA<HeavenlyCloudsConfig>());
    });

    test('second read is idempotent — no duplicate inserts', () async {
      final container = _buildContainer(styleStore: styleStore);
      addTearDown(container.dispose);

      await container.read(builtinMirkStylesProvider.future);
      expect(styleStore.rows, hasLength(4));

      // Force re-evaluation. The provider must read the existing 4 rows
      // and short-circuit the seed, NOT re-insert.
      container.invalidate(builtinMirkStylesProvider);
      final secondRead = await container.read(builtinMirkStylesProvider.future);

      expect(styleStore.rows, hasLength(4), reason: 'idempotent — no duplicate inserts on re-read');
      expect(secondRead, hasLength(4));
    });

    test('missing builtin is self-heal-re-seeded on the next read', () async {
      final container = _buildContainer(styleStore: styleStore);
      addTearDown(container.dispose);

      await container.read(builtinMirkStylesProvider.future);
      expect(styleStore.rows, hasLength(4));

      // Simulate an out-of-band delete (manual SQL, test scenario).
      styleStore.rows.removeWhere((r) => r.id.value == 'style_builtin_solid');
      expect(styleStore.rows, hasLength(3));

      container.invalidate(builtinMirkStylesProvider);
      await container.read(builtinMirkStylesProvider.future);

      expect(styleStore.rows, hasLength(4), reason: 'self-healing — missing builtin re-seeded');
      expect(styleStore.rows.any((r) => r.id.value == 'style_builtin_solid'), isTrue);
    });

    test('seeded entities carry stable creation metadata', () async {
      final container = _buildContainer(styleStore: styleStore);
      addTearDown(container.dispose);

      final styles = await container.read(builtinMirkStylesProvider.future);
      // All 4 builtins share the Phase 09 landing seed timestamp + UTC
      // offset 0 — schema-sentinel pattern (parallels cat_default's
      // 2026-04-18 fixed timestamp).
      for (final style in styles) {
        expect(style.createdAtOffsetMinutes, 0, reason: 'builtins use UTC offset 0 (schema-sentinel)');
        expect(style.createdAtUtc.year, 2026);
        expect(style.createdAtUtc.month, 4);
        expect(style.createdAtUtc.day, 25);
      }
    });
  });
}
