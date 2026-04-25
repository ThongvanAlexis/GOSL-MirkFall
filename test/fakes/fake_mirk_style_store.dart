// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style.dart';
import 'package:mirkfall/domain/mirk/mirk_style_store.dart';

/// In-memory fake implementing [MirkStyleStore] for provider/controller
/// suites that need a mirk-style backend without spinning up Drift.
///
/// Plan 09-05 Task 2 — used by `builtinMirkStylesProvider_test`. Plan
/// 09-05 Task 3 + plan 09-06 reuse it for `activeMirkRendererProvider`
/// and the upcoming `MirkStyleSessionController`.
///
/// The internal [rows] list is exposed so tests can:
/// * pre-seed rows before driving the SUT (`fakeStore.rows.add(...)`),
/// * inspect post-state after driving the SUT
///   (`expect(fakeStore.rows.length, ...)`),
/// * simulate a missing builtin
///   (`fakeStore.rows.removeWhere(...)`).
///
/// Mirrors the in-memory fake idiom used by Phase 03/05 store fakes
/// (`_FakeSessionStore`, `_FakeFixStore`) — explicit operation list +
/// public mutable backing state.
class FakeMirkStyleStore implements MirkStyleStore {
  /// Mutable backing rows. Tests both seed and inspect this list.
  final List<MirkStyle> rows = <MirkStyle>[];

  @override
  Future<List<MirkStyle>> listAll() async => List<MirkStyle>.of(rows);

  @override
  Future<MirkStyle?> findById(MirkStyleId id) async {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  @override
  Future<MirkStyle> requireById(MirkStyleId id) async {
    final found = await findById(id);
    if (found == null) {
      throw StateError('FakeMirkStyleStore: no row with id ${id.value}');
    }
    return found;
  }

  @override
  Future<void> insert(MirkStyle style) async {
    rows.add(style);
  }

  @override
  Future<void> update(MirkStyle style) async {
    final idx = rows.indexWhere((r) => r.id == style.id);
    if (idx == -1) {
      throw StateError('FakeMirkStyleStore.update: id ${style.id.value} not found');
    }
    rows[idx] = style;
  }

  @override
  Future<void> delete(MirkStyleId id) async {
    rows.removeWhere((r) => r.id == id);
  }
}
