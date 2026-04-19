// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: unused_import
// TODO(05-01 Task 2): Fix + FixId land in Plan 05-01 Task 2; these imports turn
// green at that point. Keeping the import eagerly so the file surfaces the
// expected TDD-red shape ("Fix isn't defined") instead of a generic missing-
// file error.

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:test/test.dart';

/// Domain-level `@Assert` invariants on [Fix].
///
/// Mirrors the DB CHECK constraints on `t_fixes` (lat in [-90, 90], lon in
/// [-180, 180], accuracy >= 0, UTC offset in [-720, +840]). The asserts
/// guarantee that an invalid [Fix] cannot reach the store — a CHECK-
/// violation SqliteException is therefore always an infrastructure bug,
/// never a domain contract break.
void main() {
  const FixId validFixId = FixId('fix_01HR0001INVARIANTTESTAAAA');
  const SessionId validSessionId = SessionId('sess_01HR0001INVARIANTAAAAAAAA');
  final DateTime recordedAtUtc = DateTime.utc(2026, 4, 19);

  group('Fix.@Assert', () {
    test('latitude > 90 throws AssertionError', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: 0,
          latitude: 91.0,
          longitude: 0.0,
          accuracyMeters: 5.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('latitude < -90 throws AssertionError', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: 0,
          latitude: -90.01,
          longitude: 0.0,
          accuracyMeters: 5.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('longitude > 180 throws AssertionError', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: 0,
          latitude: 0.0,
          longitude: 181.0,
          accuracyMeters: 5.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('longitude < -180 throws AssertionError', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: 0,
          latitude: 0.0,
          longitude: -180.01,
          accuracyMeters: 5.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('accuracyMeters < 0 throws AssertionError', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: 0,
          latitude: 0.0,
          longitude: 0.0,
          accuracyMeters: -0.01,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('recordedAtOffsetMinutes below -720 throws', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: -721,
          latitude: 0.0,
          longitude: 0.0,
          accuracyMeters: 5.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('recordedAtOffsetMinutes above +840 throws', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: 841,
          latitude: 0.0,
          longitude: 0.0,
          accuracyMeters: 5.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('valid boundary values (lat=90, lon=180, accuracy=0, offset=+840) '
        'do not throw', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: 840,
          latitude: 90.0,
          longitude: 180.0,
          accuracyMeters: 0.0,
        ),
        returnsNormally,
      );
    });

    test('valid negative boundary values (lat=-90, lon=-180, offset=-720) '
        'do not throw', () {
      expect(
        () => Fix(
          id: validFixId,
          sessionId: validSessionId,
          recordedAtUtc: recordedAtUtc,
          recordedAtOffsetMinutes: -720,
          latitude: -90.0,
          longitude: -180.0,
          accuracyMeters: 5.0,
        ),
        returnsNormally,
      );
    });
  });
}
