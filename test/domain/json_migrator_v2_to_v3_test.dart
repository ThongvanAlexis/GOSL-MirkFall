// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:mirkfall/domain/envelope/envelope.dart';
import 'package:mirkfall/domain/envelope/json_migration.dart';
import 'package:mirkfall/domain/envelope/json_migrator.dart';
import 'package:mirkfall/domain/envelope/v1_to_v2_rename_radius.dart';
import 'package:mirkfall/domain/envelope/v2_to_v3_fixes.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('V2ToV3Fixes identity migration', () {
    test('apply returns a copy with identical content', () {
      final input = <String, Object?>{'displayName': 'Paris trip', 'reveal_radius_m': 50};
      final output = V2ToV3Fixes().apply(input);
      expect(output, input);
      expect(identical(output, input), isFalse, reason: 'migration must not return the input map — contract forbids aliasing');
    });

    test('does not mutate the input map (immutability contract)', () {
      final input = <String, Object?>{'key': 'value'};
      V2ToV3Fixes().apply(input);
      expect(input, {'key': 'value'});
    });

    test('JsonMigrator chains v1 → v2 → v3 without modifying payload after v2', () {
      final migrator = JsonMigrator(<JsonMigration>[V1ToV2RenameRadius(), V2ToV3Fixes()]);
      final v1Payload = <String, Object?>{'mirk_radius_m': 42, 'displayName': 'test'};
      final migrated = migrator.migrate(fromVersion: 1, toVersion: 3, payload: v1Payload);
      // v1→v2 rename fired; v2→v3 identity preserved the result.
      expect(migrated, {'reveal_radius_m': 42, 'displayName': 'test'});
    });

    test('fixture: v2_to_v3_envelope.json round-trips with unchanged payload', () {
      final fixtureFilename = p.join(
        Directory.current.path,
        'test',
        'fixtures',
        'json',
        'v2_to_v3_envelope.json',
      );
      final raw = jsonDecode(File(fixtureFilename).readAsStringSync()) as Map<String, Object?>;

      final envelope = Envelope.parse(raw);
      expect(envelope.schemaVersion, 2);

      final migrator = JsonMigrator(<JsonMigration>[V2ToV3Fixes()]);
      final migrated = migrator.migrate(
        fromVersion: envelope.schemaVersion,
        toVersion: 3,
        payload: envelope.payload,
      );

      expect(migrated, envelope.payload);
    });
  });
}
