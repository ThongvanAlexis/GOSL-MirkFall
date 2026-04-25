// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style.dart';
import 'package:mirkfall/infrastructure/mirk/builtin_mirk_styles.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'mirk_style_store_provider.dart';

part 'builtin_mirk_styles_provider.g.dart';

/// Surfaces the 4 built-in `MirkStyle` rows, lazy-seeding them into
/// `t_mirk_styles` on first read.
///
/// Behaviour:
/// 1. Reads the store via `ref.watch(mirkStyleStoreProvider)`.
/// 2. Loads the existing rows via `store.listAll()`.
/// 3. For each `kBuiltinMirkStyles` descriptor not yet present (id
///    match), constructs a `MirkStyle` entity with the deterministic id
///    + the descriptor's default config + a fixed creation timestamp,
///    inserts it, and adds it to the result list.
/// 4. Returns the final list of 4 builtins (all pre-existing or just
///    inserted).
///
/// Self-healing: if a builtin row was deleted out-of-band (manual SQL,
/// test setup, future user action), the next provider read re-inserts
/// it. Idempotent under repeated reads — invalidating + re-reading
/// never duplicates rows.
///
/// `keepAlive: true` because:
/// * The seed is a one-time effect; re-running it on widget-tree churn
///   wastes I/O.
/// * Downstream consumers (`activeMirkRendererProvider`, the burger
///   menu picker) read this provider repeatedly and expect a stable
///   list reference.
///
/// ## Why lazy here vs main.dart bootstrap?
///
/// Lazy seeding inside the provider keeps Phase 09 self-contained — no
/// `main.dart` edits, no FirstLaunchSeeder coupling. The trade-off is
/// that a consumer must read the provider to trigger the seed; plan
/// 09-07 (the picker sheet) is the natural first reader. Until then the
/// seed is dormant, which is fine because no Phase 09 path ALSO
/// dereferences the row directly via `store.findById`.
///
/// ## Seed timestamp
///
/// `createdAtUtc` uses the Phase 09 landing date (`2026-04-25`) at UTC
/// midnight, with offset 0. Stable across reproductions (no wall-clock
/// dependency), self-identifying in logs / SQL inspector — matches the
/// `cat_default` schema-sentinel pattern from `AppDatabase.onCreate`
/// (Phase 04 finding #2).
@Riverpod(keepAlive: true)
Future<List<MirkStyle>> builtinMirkStyles(Ref ref) async {
  final store = await ref.watch(mirkStyleStoreProvider.future);
  final existing = await store.listAll();
  final existingById = <String, MirkStyle>{for (final row in existing) row.id.value: row};

  final result = <MirkStyle>[];
  for (final descriptor in kBuiltinMirkStyles) {
    final pre = existingById[descriptor.id];
    if (pre != null) {
      result.add(pre);
      continue;
    }
    final fresh = MirkStyle(
      id: MirkStyleId(descriptor.id),
      displayName: descriptor.displayName,
      config: descriptor.defaultConfig(),
      createdAtUtc: _kBuiltinSeedTimestamp,
      createdAtOffsetMinutes: 0,
    );
    await store.insert(fresh);
    result.add(fresh);
  }
  return result;
}

/// Phase 09 landing date — used as the deterministic creation timestamp
/// for built-in mirk styles. Mirrors `AppDatabase.onCreate`'s seeding
/// of `cat_default` with `DateTime.utc(2026, 4, 18)` for the Phase 03
/// persistence landing date.
final DateTime _kBuiltinSeedTimestamp = DateTime.utc(2026, 4, 25);
