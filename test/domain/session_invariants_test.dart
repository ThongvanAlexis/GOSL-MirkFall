// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:test/test.dart';

void main() {
  Session buildSession({
    String displayName = 'Paris 2026',
    int startedAtOffsetMinutes = 120,
  }) => Session(
    id: const SessionId('sess_01HRSESSIONFIXTUREAAAAAAAA'),
    displayName: displayName,
    status: SessionStatus.stopped,
    startedAtUtc: DateTime.utc(2026, 4, 1, 8),
    startedAtOffsetMinutes: startedAtOffsetMinutes,
  );

  group('Session @Assert invariants', () {
    test('empty displayName throws AssertionError', () {
      expect(
        () => buildSession(displayName: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('whitespace-only displayName throws AssertionError', () {
      expect(
        () => buildSession(displayName: '   '),
        throwsA(isA<AssertionError>()),
      );
    });

    test('startedAtOffsetMinutes below -720 throws AssertionError', () {
      expect(
        () => buildSession(startedAtOffsetMinutes: -721),
        throwsA(isA<AssertionError>()),
      );
    });

    test('startedAtOffsetMinutes above 840 throws AssertionError', () {
      expect(
        () => buildSession(startedAtOffsetMinutes: 841),
        throwsA(isA<AssertionError>()),
      );
    });

    test('boundary offsets -720 and 840 construct successfully', () {
      expect(buildSession(startedAtOffsetMinutes: -720).startedAtOffsetMinutes, -720);
      expect(buildSession(startedAtOffsetMinutes: 840).startedAtOffsetMinutes, 840);
    });

    test('happy path constructs without throwing', () {
      final s = buildSession();
      expect(s.displayName, 'Paris 2026');
      expect(s.status, SessionStatus.stopped);
      expect(s.startedAtOffsetMinutes, 120);
    });
  });
}
