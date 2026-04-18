-- Copyright (c) 2026 THONGVAN Alexis
-- Licensed under the Good Old Software License v1.0
-- See LICENSE file for details
--
-- Phase 03 fixture: baseline seed for V1 identity test (03-04) and the
-- V1->V2 migration test (03-05). Hand-written INSERTs, explicit column
-- lists, all timestamps in UTC milliseconds + minute offset (CONTEXT.md
-- §Nommage / §Time storage convention).
--
-- Inventory:
--   3  marker_categories
--   10 sessions  (all status='stopped' — SessionStatus enum has only
--                 'active' | 'stopped'; partial unique index tolerates zero
--                 actives, which keeps the fixture collision-free)
--   50 markers   (5 per session, distributed across the 10 fixtures)
--   5  revealed_tiles  (3 on sess_..A + 2 on sess_..B)
--   2  mirk_styles  (one well-known renderer, one unknown-renderer blob)
--
-- The bitmap blobs are dummy (zeroblob(512)) — set_bit_count is 0 so the
-- identity round-trip tests in 03-04 do not need to assert bit-level shape.
-- 03-09 (paint perf) seeds a separate fixture with realistic bit density.
--
-- Schema authority: 03-04 owns lib/infrastructure/db/app_database.dart.
-- If column names diverge there, this file is updated by 03-04 (tracked
-- in 03-04 must_haves), not by a downstream consumer.

-- =============================================================================
-- Categories (3)
-- =============================================================================
INSERT INTO t_marker_categories (id, display_name, icon_name, created_at_utc, created_at_offset_minutes) VALUES
  ('cat_default',                 'Default',  'pin',   1712000000000, 120),
  ('cat_01HRCATHOUSEAAAAAAAAAA',  'Maison',   'house', 1712000001000, 120),
  ('cat_01HRCATTREASUREAAAAAAA',  'Tresor',   'chest', 1712000002000, 120);

-- =============================================================================
-- Sessions (10) — none active, mix of stopped and paused
-- =============================================================================
INSERT INTO t_sessions (id, display_name, status, started_at_utc, started_at_offset_minutes, stopped_at_utc, stopped_at_offset_minutes) VALUES
  ('sess_01HRFIX0000000000000000A', 'Fixture session 01',  'stopped', 1712001000000, 120, 1712010000000, 120),
  ('sess_01HRFIX0000000000000000B', 'Fixture session 02',  'stopped', 1712002000000, 120, 1712011000000, 120),
  ('sess_01HRFIX0000000000000000C', 'Fixture session 03',  'stopped', 1712003000000, 120, 1712012000000, 120),
  ('sess_01HRFIX0000000000000000D', 'Fixture session 04',  'stopped', 1712004000000, 120, 1712013000000, 120),
  ('sess_01HRFIX0000000000000000E', 'Fixture session 05',  'stopped', 1712005000000, 120, 1712014000000, 120),
  ('sess_01HRFIX0000000000000000F', 'Fixture session 06',  'stopped', 1712006000000, 120, 1712015000000, 120),
  ('sess_01HRFIX0000000000000000G', 'Fixture session 07',  'stopped', 1712007000000, 120, 1712016000000, 120),
  ('sess_01HRFIX0000000000000000H', 'Fixture session 08',  'stopped', 1712008000000, 120, 1712017000000, 120),
  ('sess_01HRFIX0000000000000000J', 'Fixture session 09',  'stopped', 1712009000000, 120, 1712018000000, 120),
  ('sess_01HRFIX0000000000000000K', 'Fixture session 10',  'stopped', 1712010500000, 120, 1712019000000, 120);

-- =============================================================================
-- Markers (50) — 5 per session, category rotation across the first six
-- =============================================================================
INSERT INTO t_markers (id, session_id, category_id, lat, lon, title, notes, created_at_utc, created_at_offset_minutes) VALUES
  -- Session 01 (5 markers)
  ('mrk_01HRFIX0000000000000M001', 'sess_01HRFIX0000000000000000A', 'cat_default',                48.8566,  2.3522, 'Marker 01', NULL,            1712001100000, 120),
  ('mrk_01HRFIX0000000000000M002', 'sess_01HRFIX0000000000000000A', 'cat_01HRCATHOUSEAAAAAAAAAA', 48.8584,  2.2945, 'Marker 02', 'Notes 02',      1712001200000, 120),
  ('mrk_01HRFIX0000000000000M003', 'sess_01HRFIX0000000000000000A', 'cat_01HRCATTREASUREAAAAAAA', 48.8606,  2.3376, 'Marker 03', NULL,            1712001300000, 120),
  ('mrk_01HRFIX0000000000000M004', 'sess_01HRFIX0000000000000000A', 'cat_default',                48.8530,  2.3499, 'Marker 04', 'Notes 04',      1712001400000, 120),
  ('mrk_01HRFIX0000000000000M005', 'sess_01HRFIX0000000000000000A', 'cat_default',                48.8462,  2.3464, 'Marker 05', NULL,            1712001500000, 120),
  -- Session 02 (5 markers)
  ('mrk_01HRFIX0000000000000M006', 'sess_01HRFIX0000000000000000B', 'cat_01HRCATHOUSEAAAAAAAAAA', 45.7640,  4.8357, 'Marker 06', NULL,            1712002100000, 120),
  ('mrk_01HRFIX0000000000000M007', 'sess_01HRFIX0000000000000000B', 'cat_default',                45.7578,  4.8320, 'Marker 07', 'Notes 07',      1712002200000, 120),
  ('mrk_01HRFIX0000000000000M008', 'sess_01HRFIX0000000000000000B', 'cat_01HRCATTREASUREAAAAAAA', 45.7485,  4.8467, 'Marker 08', NULL,            1712002300000, 120),
  ('mrk_01HRFIX0000000000000M009', 'sess_01HRFIX0000000000000000B', 'cat_default',                45.7702,  4.8597, 'Marker 09', NULL,            1712002400000, 120),
  ('mrk_01HRFIX0000000000000M010', 'sess_01HRFIX0000000000000000B', 'cat_default',                45.7437,  4.8202, 'Marker 10', 'Notes 10',      1712002500000, 120),
  -- Session 03 (5 markers)
  ('mrk_01HRFIX0000000000000M011', 'sess_01HRFIX0000000000000000C', 'cat_default',                43.2965,  5.3698, 'Marker 11', NULL,            1712003100000, 120),
  ('mrk_01HRFIX0000000000000M012', 'sess_01HRFIX0000000000000000C', 'cat_default',                43.3058,  5.3739, 'Marker 12', NULL,            1712003200000, 120),
  ('mrk_01HRFIX0000000000000M013', 'sess_01HRFIX0000000000000000C', 'cat_default',                43.2630,  5.4100, 'Marker 13', NULL,            1712003300000, 120),
  ('mrk_01HRFIX0000000000000M014', 'sess_01HRFIX0000000000000000C', 'cat_default',                43.2790,  5.3950, 'Marker 14', NULL,            1712003400000, 120),
  ('mrk_01HRFIX0000000000000M015', 'sess_01HRFIX0000000000000000C', 'cat_default',                43.2920,  5.3850, 'Marker 15', NULL,            1712003500000, 120),
  -- Session 04 (5 markers)
  ('mrk_01HRFIX0000000000000M016', 'sess_01HRFIX0000000000000000D', 'cat_default',                47.2184, -1.5536, 'Marker 16', NULL,            1712004100000, 120),
  ('mrk_01HRFIX0000000000000M017', 'sess_01HRFIX0000000000000000D', 'cat_default',                47.2120, -1.5500, 'Marker 17', NULL,            1712004200000, 120),
  ('mrk_01HRFIX0000000000000M018', 'sess_01HRFIX0000000000000000D', 'cat_default',                47.2250, -1.5610, 'Marker 18', NULL,            1712004300000, 120),
  ('mrk_01HRFIX0000000000000M019', 'sess_01HRFIX0000000000000000D', 'cat_default',                47.2080, -1.5450, 'Marker 19', NULL,            1712004400000, 120),
  ('mrk_01HRFIX0000000000000M020', 'sess_01HRFIX0000000000000000D', 'cat_default',                47.2300, -1.5680, 'Marker 20', NULL,            1712004500000, 120),
  -- Session 05 (5 markers)
  ('mrk_01HRFIX0000000000000M021', 'sess_01HRFIX0000000000000000E', 'cat_default',                50.6292,  3.0573, 'Marker 21', NULL,            1712005100000, 120),
  ('mrk_01HRFIX0000000000000M022', 'sess_01HRFIX0000000000000000E', 'cat_default',                50.6300,  3.0610, 'Marker 22', NULL,            1712005200000, 120),
  ('mrk_01HRFIX0000000000000M023', 'sess_01HRFIX0000000000000000E', 'cat_default',                50.6230,  3.0500, 'Marker 23', NULL,            1712005300000, 120),
  ('mrk_01HRFIX0000000000000M024', 'sess_01HRFIX0000000000000000E', 'cat_default',                50.6360,  3.0700, 'Marker 24', NULL,            1712005400000, 120),
  ('mrk_01HRFIX0000000000000M025', 'sess_01HRFIX0000000000000000E', 'cat_default',                50.6190,  3.0420, 'Marker 25', NULL,            1712005500000, 120),
  -- Session 06 (5 markers)
  ('mrk_01HRFIX0000000000000M026', 'sess_01HRFIX0000000000000000F', 'cat_default',                48.5734,  7.7521, 'Marker 26', NULL,            1712006100000, 120),
  ('mrk_01HRFIX0000000000000M027', 'sess_01HRFIX0000000000000000F', 'cat_default',                48.5700,  7.7480, 'Marker 27', NULL,            1712006200000, 120),
  ('mrk_01HRFIX0000000000000M028', 'sess_01HRFIX0000000000000000F', 'cat_default',                48.5800,  7.7600, 'Marker 28', NULL,            1712006300000, 120),
  ('mrk_01HRFIX0000000000000M029', 'sess_01HRFIX0000000000000000F', 'cat_default',                48.5650,  7.7440, 'Marker 29', NULL,            1712006400000, 120),
  ('mrk_01HRFIX0000000000000M030', 'sess_01HRFIX0000000000000000F', 'cat_default',                48.5870,  7.7680, 'Marker 30', NULL,            1712006500000, 120),
  -- Session 07 (5 markers)
  ('mrk_01HRFIX0000000000000M031', 'sess_01HRFIX0000000000000000G', 'cat_default',                44.8378, -0.5792, 'Marker 31', NULL,            1712007100000, 120),
  ('mrk_01HRFIX0000000000000M032', 'sess_01HRFIX0000000000000000G', 'cat_default',                44.8410, -0.5810, 'Marker 32', NULL,            1712007200000, 120),
  ('mrk_01HRFIX0000000000000M033', 'sess_01HRFIX0000000000000000G', 'cat_default',                44.8330, -0.5740, 'Marker 33', NULL,            1712007300000, 120),
  ('mrk_01HRFIX0000000000000M034', 'sess_01HRFIX0000000000000000G', 'cat_default',                44.8450, -0.5860, 'Marker 34', NULL,            1712007400000, 120),
  ('mrk_01HRFIX0000000000000M035', 'sess_01HRFIX0000000000000000G', 'cat_default',                44.8290, -0.5680, 'Marker 35', NULL,            1712007500000, 120),
  -- Session 08 (5 markers)
  ('mrk_01HRFIX0000000000000M036', 'sess_01HRFIX0000000000000000H', 'cat_default',                43.6047,  1.4442, 'Marker 36', NULL,            1712008100000, 120),
  ('mrk_01HRFIX0000000000000M037', 'sess_01HRFIX0000000000000000H', 'cat_default',                43.6100,  1.4480, 'Marker 37', NULL,            1712008200000, 120),
  ('mrk_01HRFIX0000000000000M038', 'sess_01HRFIX0000000000000000H', 'cat_default',                43.6020,  1.4400, 'Marker 38', NULL,            1712008300000, 120),
  ('mrk_01HRFIX0000000000000M039', 'sess_01HRFIX0000000000000000H', 'cat_default',                43.6150,  1.4520, 'Marker 39', NULL,            1712008400000, 120),
  ('mrk_01HRFIX0000000000000M040', 'sess_01HRFIX0000000000000000H', 'cat_default',                43.5970,  1.4360, 'Marker 40', NULL,            1712008500000, 120),
  -- Session 09 (5 markers)
  ('mrk_01HRFIX0000000000000M041', 'sess_01HRFIX0000000000000000J', 'cat_default',                49.4944,  0.1079, 'Marker 41', NULL,            1712009100000, 120),
  ('mrk_01HRFIX0000000000000M042', 'sess_01HRFIX0000000000000000J', 'cat_default',                49.4980,  0.1110, 'Marker 42', NULL,            1712009200000, 120),
  ('mrk_01HRFIX0000000000000M043', 'sess_01HRFIX0000000000000000J', 'cat_default',                49.4900,  0.1040, 'Marker 43', NULL,            1712009300000, 120),
  ('mrk_01HRFIX0000000000000M044', 'sess_01HRFIX0000000000000000J', 'cat_default',                49.5020,  0.1140, 'Marker 44', NULL,            1712009400000, 120),
  ('mrk_01HRFIX0000000000000M045', 'sess_01HRFIX0000000000000000J', 'cat_default',                49.4870,  0.1010, 'Marker 45', NULL,            1712009500000, 120),
  -- Session 10 (5 markers)
  ('mrk_01HRFIX0000000000000M046', 'sess_01HRFIX0000000000000000K', 'cat_default',                47.3220,  5.0415, 'Marker 46', NULL,            1712010600000, 120),
  ('mrk_01HRFIX0000000000000M047', 'sess_01HRFIX0000000000000000K', 'cat_default',                47.3260,  5.0450, 'Marker 47', NULL,            1712010700000, 120),
  ('mrk_01HRFIX0000000000000M048', 'sess_01HRFIX0000000000000000K', 'cat_default',                47.3180,  5.0380, 'Marker 48', NULL,            1712010800000, 120),
  ('mrk_01HRFIX0000000000000M049', 'sess_01HRFIX0000000000000000K', 'cat_default',                47.3300,  5.0490, 'Marker 49', NULL,            1712010900000, 120),
  ('mrk_01HRFIX0000000000000M050', 'sess_01HRFIX0000000000000000K', 'cat_default',                47.3140,  5.0340, 'Marker 50', NULL,            1712011000000, 120);

-- =============================================================================
-- Revealed tiles (5) — 3 on sess_..A, 2 on sess_..B. zoom=14 per D3.
-- Bitmap blobs are dummy (zeroblob(512)) — Phase 03 identity tests assert
-- byte-equal round-trip; bit-level shape is exercised by 03-09 paint tests.
-- =============================================================================
INSERT INTO t_revealed_tiles (id, session_id, parent_x, parent_y, parent_zoom, bitmap, set_bit_count, updated_at_utc) VALUES
  ('rvt_01HRFIX0000000000000T001', 'sess_01HRFIX0000000000000000A',  8294, 5630, 14, zeroblob(512), 0, 1712001200000),
  ('rvt_01HRFIX0000000000000T002', 'sess_01HRFIX0000000000000000A',  8295, 5630, 14, zeroblob(512), 0, 1712001210000),
  ('rvt_01HRFIX0000000000000T003', 'sess_01HRFIX0000000000000000A',  8294, 5631, 14, zeroblob(512), 0, 1712001220000),
  ('rvt_01HRFIX0000000000000T004', 'sess_01HRFIX0000000000000000B',  8240, 5840, 14, zeroblob(512), 0, 1712002200000),
  ('rvt_01HRFIX0000000000000T005', 'sess_01HRFIX0000000000000000B',  8241, 5840, 14, zeroblob(512), 0, 1712002210000);

-- =============================================================================
-- Mirk styles (2) — one atmospheric default, one unknown-rendererType blob.
-- Config payload is JSON text (TEXT column); 03-03 parses it through
-- MirkStyleConfig.fromJson and falls back to UnknownConfig(raw) on
-- unrecognised rendererType. This row is the test input.
-- =============================================================================
INSERT INTO t_mirk_styles (id, display_name, renderer_type, config, created_at_utc, created_at_offset_minutes) VALUES
  ('mst_01HRFIXATMOSPHERICAAAAAAA', 'Atmospheric default', 'atmospheric',
   '{"rendererType":"atmospheric","baseColorArgb":-16777216,"noiseScale":0.5}',
   1712000005000, 120),
  ('mst_01HRFIXUNKNOWNAAAAAAAAAAAA', 'Unknown fixture',    'non-existent-future-renderer-v99',
   '{"rendererType":"non-existent-future-renderer-v99","foo":"bar"}',
   1712000006000, 120);
