-- Copyright (c) 2026 THONGVAN Alexis
-- Licensed under the Good Old Software License v1.0
-- See LICENSE file for details
--
-- Phase 04 Plan 04-02 runtime walk — CMD-compatible PRAGMA + schema dump.
-- Invoked against the mirkfall.db produced by `dart run tool/walk_db.dart`
-- to disambiguate runtime invariants (WAL mode, foreign_keys, busy_timeout,
-- schema version) on the real Windows filesystem.
--
-- Usage (CMD, PowerShell, or bash — all equivalent):
--   sqlite3 "<PATH>\mirkfall.db" < tool\inspect_db.sql
--
-- Output captured verbatim into .planning/phases/04-review-gate-persistence/
-- 04-REVIEW.md §1b. Written as a .sql script (not a heredoc) because
-- Windows CMD does not support POSIX heredoc syntax.

.headers on
.mode column

PRAGMA user_version;
PRAGMA journal_mode;
PRAGMA foreign_keys;
PRAGMA synchronous;
PRAGMA busy_timeout;
PRAGMA page_size;

.schema
.indexes t_sessions
