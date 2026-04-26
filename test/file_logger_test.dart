// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/infrastructure/logging/file_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake [PathProviderPlatform] that points all getters at a temp directory
/// owned by the test. Uses [MockPlatformInterfaceMixin] to bypass
/// [PlatformInterface.verify] which normally rejects subclasses.
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this._root);
  final Directory _root;

  @override
  Future<String?> getApplicationDocumentsPath() async => _root.path;

  @override
  Future<String?> getApplicationSupportPath() async => _root.path;

  @override
  Future<String?> getTemporaryPath() async => _root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_filelogger_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    // Ensure the active sink is closed before the OS tries to delete its
    // backing file; otherwise Windows keeps the file handle open.
    await FileLogger.clearAll(rearm: false);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('bootstrap creates <app_docs>/logs and opens a JSONL file', () async {
    await FileLogger.bootstrap();

    expect(FileLogger.activeFilename, isNotNull);
    final logsDir = Directory(p.join(tempDir.path, 'logs'));
    expect(logsDir.existsSync(), isTrue);

    // Active file lives under the logs dir with the expected naming.
    expect(FileLogger.activeFilename, startsWith(logsDir.path), reason: 'Active file must live inside <app_docs>/logs');
    expect(
      p.basename(FileLogger.activeFilename!),
      matches(RegExp(r'^\d{8}_\d{4}\.\d{2}_logs\.txt$')),
      reason: 'Active filename must match yyyymmdd_hhmm.ss_logs.txt',
    );
  });

  test('log record is written as JSONL with expected fields', () async {
    await FileLogger.bootstrap();

    Logger('test').info('hello world');

    // Records are now flushed synchronously per record (RandomAccessFile
    // + flushSync replaced the previous async IOSink path), but Logger
    // still emits records via a Stream so we yield once to let the
    // synchronous _onRecord handler run.
    await Future<void>.delayed(Duration.zero);

    final file = File(FileLogger.activeFilename!);
    expect(file.existsSync(), isTrue);

    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content).where((l) => l.trim().isNotEmpty).toList();
    expect(lines, isNotEmpty, reason: 'Logger must have flushed at least one line');

    // Find our specific line and parse it as JSON.
    final ourLine = lines.firstWhere((l) => l.contains('hello world'), orElse: () => '');
    expect(ourLine, isNotEmpty);

    final decoded = jsonDecode(ourLine) as Map<String, Object?>;
    expect(decoded['msg'], 'hello world');
    expect(decoded['level'], 'INFO');
    expect(decoded['logger'], 'test');
    expect(decoded['ts'], isA<String>());
  });

  test('bootstrap writes the active file path as the first record', () async {
    // Cross-check anchor for iOS sandbox-container UUID drift between
    // launches (BUG-009 logging audit, theory B.4): the path emitted at
    // bootstrap-time should be readable at the same path post-bootstrap.
    await FileLogger.bootstrap();
    await Future<void>.delayed(Duration.zero);

    final file = File(FileLogger.activeFilename!);
    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content).where((l) => l.trim().isNotEmpty).toList();
    expect(lines, isNotEmpty);
    final firstDecoded = jsonDecode(lines.first) as Map<String, Object?>;
    expect(firstDecoded['logger'], 'infrastructure.logging.file_logger');
    expect(firstDecoded['msg'], contains('FileLogger bootstrap'));
    expect(firstDecoded['msg'], contains(FileLogger.activeFilename!));
  });

  test('bootstrap is idempotent: calling twice does not throw', () async {
    await FileLogger.bootstrap();
    final firstFilename = FileLogger.activeFilename;
    expect(firstFilename, isNotNull);

    // Second bootstrap should close the first handle and reopen cleanly.
    await FileLogger.bootstrap();
    expect(FileLogger.activeFilename, isNotNull);

    Logger('test').info('post-rebootstrap');
    await Future<void>.delayed(Duration.zero);
    // No exception = pass. Best-effort content assertion:
    final f = File(FileLogger.activeFilename!);
    expect(f.existsSync(), isTrue);
  });

  test('concurrent log emission does not corrupt the file (regression for IOSink async race)', () async {
    // BUG-009 logging audit regression test. Pre-fix, the IOSink-based
    // sink raced itself under concurrent writes — `Stream.listen` doesn't
    // await async callbacks, so two records arriving back-to-back could
    // re-enter the body before the first `await sink.flush()` resolved
    // → `StateError: StreamSink is bound`, which the catch nulled the
    // sink for, dropping the rest of the session silently.
    //
    // With the RandomAccessFile + synchronous flushSync handler this is
    // no longer possible: the handler runs to completion before the next
    // record can be processed.
    await FileLogger.bootstrap();

    const recordCount = 100;
    for (var i = 0; i < recordCount; i++) {
      Logger('test').info('concurrent-record-$i');
    }
    // Yield once so the synchronous Stream listener drains every record.
    await Future<void>.delayed(Duration.zero);

    final file = File(FileLogger.activeFilename!);
    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content).where((l) => l.trim().isNotEmpty).toList();

    // Every emitted record must be present and correctly decodable.
    final recordedIndexes = <int>{};
    for (final line in lines) {
      final decoded = jsonDecode(line) as Map<String, Object?>;
      final msg = decoded['msg'] as String?;
      if (msg == null || !msg.startsWith('concurrent-record-')) continue;
      final idx = int.parse(msg.substring('concurrent-record-'.length));
      recordedIndexes.add(idx);
    }
    expect(recordedIndexes.length, equals(recordCount), reason: 'Every concurrent record must reach disk — none lost to the previous async race');
    for (var i = 0; i < recordCount; i++) {
      expect(recordedIndexes, contains(i), reason: 'Record $i missing — possible regression of the IOSink async race');
    }
  });
}
