// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/envelope/envelope.dart';
import 'package:mirkfall/domain/errors/import_errors.dart';
import 'package:test/test.dart';

void main() {
  group('Envelope.fromJson', () {
    test('round-trip is byte-equal for a well-formed envelope', () {
      final json = <String, Object?>{
        'schemaVersion': 1,
        'type': 'session',
        'payload': <String, Object?>{'foo': 'bar', 'n': 42},
      };
      final envelope = Envelope.fromJson(json);
      expect(envelope.schemaVersion, 1);
      expect(envelope.type, 'session');
      expect(envelope.payload, <String, Object?>{'foo': 'bar', 'n': 42});
      // toJson -> fromJson round-trip.
      final restored = Envelope.fromJson(envelope.toJson());
      expect(restored, envelope);
    });

    test('missing schemaVersion throws ImportValidationException', () {
      expect(
        () => Envelope.fromJson(<String, Object?>{
          'type': 'session',
          'payload': <String, Object?>{},
        }),
        throwsA(
          isA<ImportValidationException>().having(
            (e) => e.reason,
            'reason',
            contains('schemaVersion'),
          ),
        ),
      );
    });

    test(
      'schemaVersion of wrong type (string) throws ImportValidationException',
      () {
        expect(
          () => Envelope.fromJson(<String, Object?>{
            'schemaVersion': 'one',
            'type': 'session',
            'payload': <String, Object?>{},
          }),
          throwsA(
            isA<ImportValidationException>().having(
              (e) => e.reason,
              'reason',
              contains('schemaVersion'),
            ),
          ),
        );
      },
    );

    test('empty type throws ImportValidationException', () {
      expect(
        () => Envelope.fromJson(<String, Object?>{
          'schemaVersion': 1,
          'type': '',
          'payload': <String, Object?>{},
        }),
        throwsA(isA<ImportValidationException>()),
      );
    });

    test('missing type throws ImportValidationException', () {
      expect(
        () => Envelope.fromJson(<String, Object?>{
          'schemaVersion': 1,
          'payload': <String, Object?>{},
        }),
        throwsA(isA<ImportValidationException>()),
      );
    });

    test('missing payload throws ImportValidationException', () {
      expect(
        () => Envelope.fromJson(<String, Object?>{
          'schemaVersion': 1,
          'type': 'session',
        }),
        throwsA(
          isA<ImportValidationException>().having(
            (e) => e.reason,
            'reason',
            contains('payload'),
          ),
        ),
      );
    });

    test('copyWith works on envelope (Freezed equality + copyWith)', () {
      final original = Envelope.fromJson(<String, Object?>{
        'schemaVersion': 1,
        'type': 'session',
        'payload': <String, Object?>{'x': 1},
      });
      final bumped = original.copyWith(schemaVersion: 2);
      expect(bumped.schemaVersion, 2);
      expect(bumped.type, original.type);
      expect(bumped.payload, original.payload);
      expect(bumped, isNot(equals(original)));
    });
  });
}
