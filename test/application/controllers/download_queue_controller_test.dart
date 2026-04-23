// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/download_queue_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/downloads/pmtiles_download_controller.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this._root);
  final Directory _root;
  @override
  Future<String?> getApplicationSupportPath() async => _root.path;
  @override
  Future<String?> getApplicationDocumentsPath() async => _root.path;
  @override
  Future<String?> getTemporaryPath() async => _root.path;
}

/// Fake inner [PmtilesDownloadController] — records every method call +
/// exposes a broadcast state stream the wrapper can forward.
///
/// Constructs with the real class's minimum dependency set so the outer
/// `Riverpod` chain resolves; tests mutate state via [pushState]
/// directly rather than running real downloads.
class _FakeInnerController implements PmtilesDownloadController {
  _FakeInnerController();

  final StreamController<DownloadState> _ctrl = StreamController<DownloadState>.broadcast();
  DownloadState _state = const DownloadIdle();
  final List<CountryEntry> enqueueObservations = <CountryEntry>[];
  int rehydrateCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int cancelCalls = 0;

  void pushState(DownloadState next) {
    _state = next;
    _ctrl.add(next);
  }

  @override
  DownloadState get state => _state;

  @override
  Stream<DownloadState> get stateStream => _ctrl.stream;

  @override
  List<DownloadJob> get queuedJobs => const <DownloadJob>[];

  @override
  Future<void> enqueueCountry(CountryEntry entry) async {
    enqueueObservations.add(entry);
  }

  @override
  Future<void> rehydrate() async {
    rehydrateCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<void> cancelActive() async {
    cancelCalls++;
  }

  @override
  Future<void> dispose() async {
    await _ctrl.close();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CountryEntry _mkEntry(String alpha3) => CountryEntry(
  alpha3: CountryCode.parse(alpha3),
  name: alpha3.toUpperCase(),
  parts: [ChunkPart(sha256: 'a' * 64, size: 1024, url: 'https://github.com/example/mirkfall/releases/download/v20260419/$alpha3.part01')],
  reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1024),
);

DownloadJob _mkJob(String alpha3) => DownloadJob(alpha3: CountryCode.parse(alpha3), entry: _mkEntry(alpha3), enqueuedAtUtc: DateTime.utc(2026, 4, 21));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_download_queue_controller_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Windows temp cleanup race.
      }
    }
  });

  ProviderContainer makeContainer({required _FakeInnerController inner}) {
    return ProviderContainer(overrides: [pmtilesDownloadControllerProvider.overrideWith((ref) async => inner)]);
  }

  group('DownloadQueueController — enqueue + rehydrate', () {
    test('first enqueue rehydrates the inner controller exactly once then delegates', () async {
      final inner = _FakeInnerController();
      final container = makeContainer(inner: inner);
      addTearDown(container.dispose);

      final ctrl = container.read(downloadQueueControllerProvider.notifier);
      await ctrl.enqueue(_mkEntry('fra'));

      expect(inner.rehydrateCalls, equals(1));
      expect(inner.enqueueObservations, hasLength(1));
      expect(inner.enqueueObservations.single.alpha3.value, equals('fra'));
    });

    test('second enqueue does NOT rehydrate again', () async {
      final inner = _FakeInnerController();
      final container = makeContainer(inner: inner);
      addTearDown(container.dispose);

      final ctrl = container.read(downloadQueueControllerProvider.notifier);
      await ctrl.enqueue(_mkEntry('fra'));
      await ctrl.enqueue(_mkEntry('esp'));

      expect(inner.rehydrateCalls, equals(1));
      expect(inner.enqueueObservations.map((e) => e.alpha3.value).toList(), equals(<String>['fra', 'esp']));
    });
  });

  group('DownloadQueueController — state stream pass-through', () {
    test('state reflects the inner controller\'s latest emission', () async {
      final inner = _FakeInnerController();
      final container = makeContainer(inner: inner);
      addTearDown(container.dispose);

      // Read the notifier so the wrapper attaches to inner.stateStream.
      container.read(downloadQueueControllerProvider.notifier);
      // Wait a microtask for the eager-attach / _ensureInner path; since
      // we haven't called a public method yet, force-attach via enqueue.
      await container.read(downloadQueueControllerProvider.notifier).enqueue(_mkEntry('fra'));

      final DownloadState before = container.read(downloadQueueControllerProvider);
      // Push an InProgress state from the fake inner.
      inner.pushState(
        DownloadInProgress(
          active: _mkJob('fra'),
          snapshot: DownloadProgress(bytesDownloaded: 512, totalBytes: 1024, currentPartIndex: 0, totalParts: 1),
          remaining: const <DownloadJob>[],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final DownloadState after = container.read(downloadQueueControllerProvider);
      expect(before, isNot(isA<DownloadInProgress>()));
      expect(after, isA<DownloadInProgress>());
    });
  });

  group('DownloadQueueController — aggregateProgressFraction', () {
    test('null when state is Idle', () async {
      final inner = _FakeInnerController();
      final container = makeContainer(inner: inner);
      addTearDown(container.dispose);
      final ctrl = container.read(downloadQueueControllerProvider.notifier);
      expect(ctrl.aggregateProgressFraction, isNull);
    });

    test('matches in-flight snapshot.fractionDone when state is InProgress', () async {
      final inner = _FakeInnerController();
      final container = makeContainer(inner: inner);
      addTearDown(container.dispose);
      final ctrl = container.read(downloadQueueControllerProvider.notifier);
      await ctrl.enqueue(_mkEntry('fra'));

      inner.pushState(
        DownloadInProgress(
          active: _mkJob('fra'),
          snapshot: DownloadProgress(bytesDownloaded: 512, totalBytes: 1024, currentPartIndex: 0, totalParts: 1),
          remaining: <DownloadJob>[_mkJob('esp')],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // Expected: active job's fractionDone (0.5) — NOT a sum across the queue.
      expect(ctrl.aggregateProgressFraction, closeTo(0.5, 1e-9));
    });

    test('matches paused snapshot.fractionDone when state is Paused', () async {
      final inner = _FakeInnerController();
      final container = makeContainer(inner: inner);
      addTearDown(container.dispose);
      final ctrl = container.read(downloadQueueControllerProvider.notifier);
      await ctrl.enqueue(_mkEntry('fra'));

      inner.pushState(
        DownloadPaused(
          active: _mkJob('fra'),
          snapshot: DownloadProgress(bytesDownloaded: 300, totalBytes: 1000, currentPartIndex: 0, totalParts: 1),
          reason: PauseReason.manual,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(ctrl.aggregateProgressFraction, closeTo(0.3, 1e-9));
    });
  });

  group('DownloadQueueController — pause / resume / cancel delegation', () {
    test('pause / resume / cancelActive each delegate to the inner controller', () async {
      final inner = _FakeInnerController();
      final container = makeContainer(inner: inner);
      addTearDown(container.dispose);

      final ctrl = container.read(downloadQueueControllerProvider.notifier);
      await ctrl.pause();
      await ctrl.resume();
      await ctrl.cancelActive();

      expect(inner.pauseCalls, equals(1));
      expect(inner.resumeCalls, equals(1));
      expect(inner.cancelCalls, equals(1));
    });
  });
}
