// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// NOTE: Envelope.fromJson tests are owned by 03-03 (Envelope is Freezed
// per SC#4). This file exercises only the pure-Dart migration framework
// against synthetic payload maps.

import 'package:mirkfall/domain/envelope/identity_migration_v1.dart';
import 'package:mirkfall/domain/envelope/json_migrator.dart';
import 'package:mirkfall/domain/envelope/v1_to_v2_rename_radius.dart';
import 'package:mirkfall/domain/errors/migration_errors.dart';
import 'package:test/test.dart';

void main() {
  group('JsonMigrator.migrate', () {
    test('same version returns input unchanged (byte-equal map)', () {
      final mig = JsonMigrator([V1ToV2RenameRadius()]);
      final input = {'foo': 'bar', 'n': 42};
      final out = mig.migrate(fromVersion: 1, toVersion: 1, payload: input);
      expect(out, input);
    });

    test('v1 to v2 rename applies and preserves other keys', () {
      final mig = JsonMigrator([V1ToV2RenameRadius()]);
      final out = mig.migrate(
        fromVersion: 1,
        toVersion: 2,
        payload: {'mirk_radius_m': 50, 'displayName': 'Paris', 'other': 3.14},
      );
      expect(out, {'reveal_radius_m': 50, 'displayName': 'Paris', 'other': 3.14});
    });

    test('v1 to v2 rename with missing source key is a no-op for that key', () {
      // Other keys still pass through; the rename is conditional on the
      // source key being present.
      final mig = JsonMigrator([V1ToV2RenameRadius()]);
      final out = mig.migrate(
        fromVersion: 1,
        toVersion: 2,
        payload: {'displayName': 'Paris'},
      );
      expect(out, {'displayName': 'Paris'});
      expect(out.containsKey('reveal_radius_m'), isFalse);
    });

    test('no matching migrator throws MigrationFailureException', () {
      final mig = JsonMigrator(<V1ToV2RenameRadius>[]);
      expect(
        () => mig.migrate(fromVersion: 1, toVersion: 2, payload: <String, Object?>{}),
        throwsA(isA<MigrationFailureException>()),
      );
    });

    test('v1 to v3 with only v1 to v2 registered throws MigrationFailureException', () {
      final mig = JsonMigrator([V1ToV2RenameRadius()]);
      expect(
        () => mig.migrate(fromVersion: 1, toVersion: 3, payload: <String, Object?>{}),
        throwsA(isA<MigrationFailureException>()),
      );
    });

    test('downgrade rejected with MigrationFailureException', () {
      final mig = JsonMigrator([V1ToV2RenameRadius()]);
      expect(
        () => mig.migrate(fromVersion: 2, toVersion: 1, payload: <String, Object?>{}),
        throwsA(isA<MigrationFailureException>()),
      );
    });

    test('V1ToV2RenameRadius does not mutate input map', () {
      final input = <String, Object?>{'mirk_radius_m': 50};
      V1ToV2RenameRadius().apply(input);
      expect(
        input,
        {'mirk_radius_m': 50},
        reason: 'input was mutated — immutability contract violated',
      );
    });

    test('IdentityMigrationV1 sentinel never matches a real version transition', () {
      final mig = JsonMigrator([IdentityMigrationV1()]);
      expect(
        () => mig.migrate(fromVersion: 1, toVersion: 2, payload: <String, Object?>{}),
        throwsA(isA<MigrationFailureException>()),
      );
    });

    test('IdentityMigrationV1 alongside V1ToV2RenameRadius does not double-match', () {
      // The sentinel's fromVersion = -1 is deliberately out of range; adding
      // it to the migration list must not trigger the "multiple migrators"
      // failure path on the v1 to v2 transition.
      final mig = JsonMigrator([IdentityMigrationV1(), V1ToV2RenameRadius()]);
      final out = mig.migrate(
        fromVersion: 1,
        toVersion: 2,
        payload: {'mirk_radius_m': 7},
      );
      expect(out, {'reveal_radius_m': 7});
    });

    test('multiple migrators registered for the same step throws', () {
      final mig = JsonMigrator([V1ToV2RenameRadius(), V1ToV2RenameRadius()]);
      expect(
        () => mig.migrate(
          fromVersion: 1,
          toVersion: 2,
          payload: <String, Object?>{'mirk_radius_m': 1},
        ),
        throwsA(isA<MigrationFailureException>()),
      );
    });
  });
}
