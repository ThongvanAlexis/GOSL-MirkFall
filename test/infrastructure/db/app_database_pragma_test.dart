// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:test/test.dart';

/// Boots an in-memory [AppDatabase] with `PRAGMA journal_mode = WAL`
/// applied via `NativeDatabase.memory`'s `setup:` hook (RESEARCH pitfall
/// #2: WAL must be set BEFORE Drift's first query).
AppDatabase _newInMemoryDb() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA journal_mode = WAL');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _newInMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  /// Reads a single PRAGMA value. SQLite returns PRAGMA results as a one-row
  /// result set whose single column name matches the pragma name.
  Future<String> pragmaValue(String name) async {
    final row = await db.customSelect('PRAGMA $name').getSingle();
    final raw = row.data.values.first;
    return raw.toString();
  }

  test('PRAGMA journal_mode: in-memory DBs always report "memory"; '
      'WAL wiring is exercised in the production factory, not the test', () async {
    // Force the connection open so beforeOpen fires.
    await db.customStatement('SELECT 1');
    // SQLite in-memory databases ignore `PRAGMA journal_mode = WAL` and keep
    // the fixed `memory` mode (sqlite.org/wal.html §2.1 — WAL requires an
    // on-disk shared-memory region). The `setup:` hook that sets WAL is
    // still invoked — we assert the expected outcome for the in-memory
    // backend so the test is self-consistent. The production DB factory
    // (03-05) points NativeDatabase at a real file and WAL kicks in there;
    // an integration test for file-backed WAL lands in 03-05.
    expect(await pragmaValue('journal_mode'), 'memory');
  });

  test('PRAGMA synchronous returns 1 (NORMAL)', () async {
    await db.customStatement('SELECT 1');
    expect(await pragmaValue('synchronous'), '1');
  });

  test('PRAGMA busy_timeout returns kDbBusyTimeoutMs (5000)', () async {
    await db.customStatement('SELECT 1');
    expect(await pragmaValue('busy_timeout'), kDbBusyTimeoutMs.toString());
  });

  test('PRAGMA foreign_keys returns 1 (CASCADE enforced)', () async {
    await db.customStatement('SELECT 1');
    expect(await pragmaValue('foreign_keys'), '1');
  });
}
