// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:mirkfall/domain/envelope/envelope.dart';
import 'package:mirkfall/domain/envelope/json_migrator.dart';
import 'package:mirkfall/domain/envelope/v1_to_v2_rename_radius.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  /// Fixture-driven end-to-end proof: load session_v1.json through
  /// Envelope.fromJson, migrate payload v1 -> v2 via JsonMigrator, and
  /// expect the migrated payload byte-equal to session_v2.json's payload.
  /// Closes SC#5 (JsonMigrator integration half, relocated from 03-02).
  test('session_v1.json migrates to session_v2.json payload byte-equal', () {
    final fixtureDir = p.join(
      Directory.current.path,
      'test',
      'fixtures',
      'json',
    );
    final v1Filename = p.join(fixtureDir, 'session_v1.json');
    final v2Filename = p.join(fixtureDir, 'session_v2.json');

    final v1Raw =
        jsonDecode(File(v1Filename).readAsStringSync()) as Map<String, Object?>;
    final v2Raw =
        jsonDecode(File(v2Filename).readAsStringSync()) as Map<String, Object?>;

    final v1Envelope = Envelope.parse(v1Raw);
    expect(v1Envelope.schemaVersion, 1);
    expect(v1Envelope.type, 'session');

    final migrator = JsonMigrator(<V1ToV2RenameRadius>[V1ToV2RenameRadius()]);
    final migratedPayload = migrator.migrate(
      fromVersion: v1Envelope.schemaVersion,
      toVersion: 2,
      payload: v1Envelope.payload,
    );

    final v2Envelope = Envelope.parse(v2Raw);
    expect(migratedPayload, v2Envelope.payload);
  });
}
