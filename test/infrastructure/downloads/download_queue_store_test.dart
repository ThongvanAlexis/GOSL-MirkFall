// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/downloads/download_queue_store.dart';
import 'package:path/path.dart' as p;

DownloadJob makeJob(String alpha3Raw, {bool paused = false}) {
  // Synthetic but schema-valid entry: all @Asserts satisfied (sha256
  // 64 hex chars, size > 0, url non-empty). The queue store does not
  // introspect payload semantics — it just round-trips JSON.
  const String sha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return DownloadJob(
    alpha3: CountryCode.parse(alpha3Raw),
    entry: CountryEntry(
      alpha3: CountryCode.parse(alpha3Raw),
      name: alpha3Raw.toUpperCase(),
      parts: <ChunkPart>[ChunkPart(sha256: sha, size: 1024, url: 'https://example.test/$alpha3Raw.part01')],
      reassembled: ReassembledMeta(sha256: sha, size: 1024),
    ),
    enqueuedAtUtc: DateTime.utc(2026, 4, 21, 12),
    userPausedFlag: paused,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_queue_store_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DownloadQueueStore — roundtrip', () {
    test('empty queue roundtrips cleanly', () async {
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      await store.save(<DownloadJob>[]);
      final List<DownloadJob> loaded = await store.load();
      expect(loaded, isEmpty);
    });

    test('3-job queue preserves order + fields', () async {
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      final List<DownloadJob> seed = <DownloadJob>[makeJob('fra'), makeJob('deu', paused: true), makeJob('esp')];
      await store.save(seed);

      final List<DownloadJob> loaded = await store.load();
      expect(loaded.map((DownloadJob j) => j.alpha3.value).toList(), <String>['fra', 'deu', 'esp']);
      expect(loaded[1].userPausedFlag, isTrue);
      expect(loaded[0].enqueuedAtUtc, DateTime.utc(2026, 4, 21, 12));
    });
  });

  group('DownloadQueueStore — atomic write', () {
    test('save uses tempfile + rename pattern (no leftover .tmp visible)', () async {
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      await store.save(<DownloadJob>[makeJob('fra')]);

      // Canonical file exists; .tmp has been renamed away.
      final File canonical = File(store.filename);
      final File tmp = File('${store.filename}.tmp');
      expect(canonical.existsSync(), isTrue);
      expect(tmp.existsSync(), isFalse);
    });

    test('creates the `maps/` parent directory if missing', () async {
      final Directory maps = Directory(p.join(tempDir.path, 'maps'));
      expect(maps.existsSync(), isFalse);

      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      await store.save(<DownloadJob>[makeJob('fra')]);

      expect(maps.existsSync(), isTrue);
      expect(File(store.filename).existsSync(), isTrue);
    });
  });

  group('DownloadQueueStore — corruption resilience', () {
    test('missing file returns empty list', () async {
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      expect(await store.load(), isEmpty);
    });

    test('corrupted JSON returns empty list (not a throw)', () async {
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      final File f = File(store.filename);
      await f.parent.create(recursive: true);
      await f.writeAsString('{this is not json[');

      expect(await store.load(), isEmpty);
    });

    test('top-level JSON object (not a list) returns empty list', () async {
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      final File f = File(store.filename);
      await f.parent.create(recursive: true);
      await f.writeAsString('{"unexpected": "shape"}');

      expect(await store.load(), isEmpty);
    });

    test('empty file returns empty list', () async {
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      final File f = File(store.filename);
      await f.parent.create(recursive: true);
      await f.writeAsString('');

      expect(await store.load(), isEmpty);
    });

    test('row #34: partial corruption — valid entries preserved, invalid dropped + logged', () async {
      // Build a queue JSON where 1 entry is a valid job, 1 is a
      // non-object (string), and 1 is a malformed object that fails
      // DownloadJob.fromJson. Previous behaviour silently filtered the
      // invalid entries via whereType<Map> — row #34 asked for diagnostic
      // logs so the operator can spot degradation after a rare crash.
      final List<Object?> mixed = <Object?>[
        makeJob('fra').toJson(), // valid
        'not-an-object', // wrong shape
        <String, Object?>{'alpha3': 'deu'}, // object but missing required fields
        makeJob('esp').toJson(), // valid
      ];
      final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
      final File f = File(store.filename);
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(mixed));

      final List<LogRecord> records = <LogRecord>[];
      final Logger testLogger = Logger.detached('row34_partial_corruption');
      final StreamSubscription<LogRecord> sub = testLogger.onRecord.listen(records.add);
      addTearDown(sub.cancel);

      final DownloadQueueStore storeWithLogger = DownloadQueueStore(appSupportDir: tempDir.path, logger: testLogger);
      final List<DownloadJob> loaded = await storeWithLogger.load();

      expect(loaded.map((DownloadJob j) => j.alpha3.value).toList(), <String>['fra', 'esp'], reason: 'valid entries must survive partial corruption');
      final List<String> warningMessages = records.where((LogRecord r) => r.level == Level.WARNING).map((LogRecord r) => r.message).toList();
      expect(warningMessages.length, equals(2), reason: 'should have logged one warning per dropped entry');
      expect(warningMessages[0], contains('#1'), reason: 'first warning identifies index of non-object entry');
      expect(warningMessages[1], contains('#2'), reason: 'second warning identifies index of malformed object');
      // Keep store alive to satisfy unused-var analyzer warnings.
      expect(store.filename, storeWithLogger.filename);
    });
  });
}
