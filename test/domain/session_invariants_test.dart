// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:test/test.dart';

void main() {
  Session buildSession({String displayName = 'Paris 2026', int startedAtOffsetMinutes = 120}) => Session(
    id: const SessionId('sess_01HRSESSIONFIXTUREAAAAAAAA'),
    displayName: displayName,
    status: SessionStatus.stopped,
    startedAtUtc: DateTime.utc(2026, 4, 1, 8),
    startedAtOffsetMinutes: startedAtOffsetMinutes,
  );

  group('Session @Assert invariants', () {
    test('empty displayName throws AssertionError', () {
      expect(() => buildSession(displayName: ''), throwsA(isA<AssertionError>()));
    });

    test('whitespace-only displayName throws AssertionError', () {
      expect(() => buildSession(displayName: '   '), throwsA(isA<AssertionError>()));
    });

    test('startedAtOffsetMinutes below kMinUtcOffsetMinutes throws AssertionError', () {
      expect(() => buildSession(startedAtOffsetMinutes: kMinUtcOffsetMinutes - 1), throwsA(isA<AssertionError>()));
    });

    test('startedAtOffsetMinutes above kMaxUtcOffsetMinutes throws AssertionError', () {
      expect(() => buildSession(startedAtOffsetMinutes: kMaxUtcOffsetMinutes + 1), throwsA(isA<AssertionError>()));
    });

    test('boundary offsets kMinUtcOffsetMinutes and kMaxUtcOffsetMinutes construct successfully', () {
      expect(buildSession(startedAtOffsetMinutes: kMinUtcOffsetMinutes).startedAtOffsetMinutes, kMinUtcOffsetMinutes);
      expect(buildSession(startedAtOffsetMinutes: kMaxUtcOffsetMinutes).startedAtOffsetMinutes, kMaxUtcOffsetMinutes);
    });

    test('session.dart @Assert literal bounds match kMin/MaxUtcOffsetMinutes (sync guard)', () {
      // Session's @Assert string literal uses -720/840 because Freezed @Assert
      // expressions can't reference top-level const int identifiers (annotation
      // body compile-time evaluation constraint). This test is the sync guard:
      // if kMin/MaxUtcOffsetMinutes ever change, this test fails until the
      // Session.@Assert literal is also updated.
      expect(kMinUtcOffsetMinutes, -720, reason: 'kMinUtcOffsetMinutes drifted — update session.dart @Assert');
      expect(kMaxUtcOffsetMinutes, 840, reason: 'kMaxUtcOffsetMinutes drifted — update session.dart @Assert');
    });

    test('happy path constructs without throwing', () {
      final s = buildSession();
      expect(s.displayName, 'Paris 2026');
      expect(s.status, SessionStatus.stopped);
      expect(s.startedAtOffsetMinutes, 120);
    });
  });
}
