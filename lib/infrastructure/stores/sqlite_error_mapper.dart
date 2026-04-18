// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// SQLite extended result code for `SQLITE_CONSTRAINT_UNIQUE`.
///
/// Source: https://www.sqlite.org/rescode.html — code 2067 = 19
/// (base `SQLITE_CONSTRAINT`) + the unique-constraint variant.
///
/// Each Drift store catches `SqliteException` and matches on
/// `extendedResultCode == kSqliteConstraintUnique` to rewrap the driver
/// error into the appropriate domain exception (e.g.
/// `ConcurrentActivationException` for SESS-06). Other codes are
/// rethrown unchanged — RESEARCH §pitfall #4 (never wide-catch).
const int kSqliteConstraintUnique = 2067;

/// SQLite extended result code for `SQLITE_CONSTRAINT_FOREIGNKEY` (787).
///
/// Not mapped by Phase 03 stores (no user-facing feature hits a raw FK
/// violation today — cascade policy is handled explicitly at the
/// transaction level). Exposed here so that future callers can pattern
/// match against a named constant rather than a magic literal.
const int kSqliteConstraintForeignKey = 787;
