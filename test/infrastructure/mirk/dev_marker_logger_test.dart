// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/infrastructure/mirk/dev_marker_logger_test.dart
// (+ verbose-gating case specific to MirkFall, CLAUDE.md §Logging).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/infrastructure/mirk/dev_marker_logger.dart';

/// DevMarkerLogger JSONL contract: every `infrastructure.mirk.dev_marker` line
/// is a JSON object with exactly `event`, `tag`, `epochMs` — the post-walk grep
/// correlator depends on it — and nothing is emitted outside verbose logging.
void main() {
  const String loggerName = 'infrastructure.mirk.dev_marker';
  late Level previousLevel;

  setUp(() {
    previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
  });
  tearDown(() => Logger.root.level = previousLevel);

  group('DevMarkerLogger.mark', () {
    test('emits a single INFO record on the infrastructure.mirk.dev_marker logger', () async {
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        const DevMarkerLogger().mark('steppy_translation');
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(1));
        expect(captured.single.level, equals(Level.INFO));
        expect(captured.single.loggerName, equals(loggerName));
      } finally {
        await sub.cancel();
      }
    });

    test('payload is a JSON object with event=dev_marker, the supplied label under `tag`, and an epochMs near now', () async {
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        final beforeMs = DateTime.now().millisecondsSinceEpoch;
        const DevMarkerLogger().mark('steppy_translation');
        await Future<void>.delayed(Duration.zero);
        final afterMs = DateTime.now().millisecondsSinceEpoch;
        expect(captured, hasLength(1));
        final decoded = json.decode(captured.single.message) as Map<String, Object?>;
        expect(decoded.keys, unorderedEquals(<String>['event', 'tag', 'epochMs']));
        expect(decoded['event'], equals('dev_marker'));
        expect(decoded['tag'], equals('steppy_translation'));
        final epochMs = decoded['epochMs'];
        expect(epochMs, isA<int>());
        expect(epochMs, greaterThanOrEqualTo(beforeMs));
        expect(epochMs, lessThanOrEqualTo(afterMs));
      } finally {
        await sub.cancel();
      }
    });

    test('two marks in a row produce two distinct records (no buffering)', () async {
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        const DevMarkerLogger()
          ..mark('steppy_translation')
          ..mark('rotation_fog_gap');
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(2));
        final firstTag = (json.decode(captured[0].message) as Map<String, Object?>)['tag'];
        final secondTag = (json.decode(captured[1].message) as Map<String, Object?>)['tag'];
        expect(firstTag, equals('steppy_translation'));
        expect(secondTag, equals('rotation_fog_gap'));
      } finally {
        await sub.cancel();
      }
    });

    test('non-verbose (root INFO): mark() emits nothing (CLAUDE.md §Logging)', () async {
      Logger.root.level = Level.INFO;
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        const DevMarkerLogger().mark('steppy_translation');
        await Future<void>.delayed(Duration.zero);
        expect(captured, isEmpty);
      } finally {
        await sub.cancel();
      }
    });
  });
}
