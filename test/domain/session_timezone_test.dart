// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:test/test.dart';

void main() {
  test('Session JSON round-trip preserves UTC and offset', () {
    final original = Session(
      id: const SessionId('sess_01HRTZTESTAAAAAAAAAAAAAAAA'),
      displayName: 'Paris trip',
      status: SessionStatus.stopped,
      startedAtUtc: DateTime.utc(2026, 4, 1, 6), // 06:00 UTC = 08:00 +02:00
      startedAtOffsetMinutes: 120,
      stoppedAtUtc: DateTime.utc(2026, 4, 1, 12, 30),
      stoppedAtOffsetMinutes: 120,
    );

    final json = original.toJson();
    final restored = Session.fromJson(json);

    expect(restored, original);
    expect(restored.startedAtUtc, DateTime.utc(2026, 4, 1, 6));
    expect(restored.startedAtOffsetMinutes, 120);
    expect(restored.stoppedAtUtc, DateTime.utc(2026, 4, 1, 12, 30));
    expect(restored.stoppedAtOffsetMinutes, 120);
  });

  test('local wall-clock reconstructs correctly from UTC + offset (CEST +120)', () {
    final session = Session(
      id: const SessionId('sess_01HRTZTESTAAAAAAAAAAAAAAAB'),
      displayName: 'Berlin',
      status: SessionStatus.active,
      startedAtUtc: DateTime.utc(2026, 7, 1, 10), // 12:00 CEST
      startedAtOffsetMinutes: 120,
    );
    // Local wall-clock representation = UTC + offset.
    final localWallClock = session.startedAtUtc.add(Duration(minutes: session.startedAtOffsetMinutes));
    expect(localWallClock.hour, 12);
  });

  test('negative offset (UTC-5 New York winter) round-trips', () {
    final session = Session(
      id: const SessionId('sess_01HRTZTESTAAAAAAAAAAAAAAAC'),
      displayName: 'NYC',
      status: SessionStatus.stopped,
      startedAtUtc: DateTime.utc(2026, 1, 15, 17),
      startedAtOffsetMinutes: -300,
    );
    final restored = Session.fromJson(session.toJson());
    expect(restored.startedAtOffsetMinutes, -300);
    expect(restored.startedAtUtc, DateTime.utc(2026, 1, 15, 17));
  });
}
