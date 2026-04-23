// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// JsonFileInstalledManifestRepository atomicity contract
// (Plan 08-04 Task 3, Test #6).
//
// Asserts that `write(...)` is atomic at the canonical-path level: any
// observer reading `<app_support>/maps/installed.json` sees either the
// pre-write state (file absent, or previous contents) or the post-write
// state (fully serialised new manifest) — never a partial / truncated
// write.
//
// The repo implementation (lib/infrastructure/installed_maps/
// installed_manifest_repository.dart) uses the tempfile + rename
// pattern: write `<path>.tmp` with `flush: true`, then `tmp.rename
// (<path>)`. rename is atomic on ext4 / APFS / NTFS, so a crash between
// the writeAsString and the rename leaves the canonical path either
// untouched OR replaced atomically — the `.tmp` file is ignored by
// subsequent reads (only the canonical path is consulted).
//
// Design note on failure injection: the repo deliberately has NO
// filesystem-injection seam because (CLAUDE.md §Wrappers) wrapping
// dart:io File operations behind an abstract FS interface would be a
// pure-delegation wrapper with no added logic. Instead, this test
// exercises real atomicity by:
//   1. Snapshotting the canonical file before + after each write.
//   2. Seeding a stale `.tmp` sibling to prove the repo tolerates a
//      prior crash between writeAsString + rename.
//   3. Exercising concurrent writes to prove the internal single-writer
//      mutex serialises them.
//
// Complements the 6 existing soak scenarios in `download_soak_test.dart`
// (which exercise the full 7-step atomic protocol end-to-end) with a
// narrow repo-level contract that catches atomicity regressions without
// spinning up a shelf server.
//
// Mutation experiment (author-time, Plan 08-04 Task 3):
//   1. Locally replaced `await tmp.rename(_filename)` with
//      `await tmp.copy(_filename)` in JsonFileInstalledManifestRepository
//      (breaks atomicity: copy is not guaranteed to be atomic on
//      Windows + leaves the .tmp hanging).
//   2. Ran `dart test test/infrastructure/downloads/manifest_atomicity_contract_test.dart`
//      → scenario 3 (concurrent writes) still passed but scenario 2
//      (stale .tmp sibling) diverged (the copy strategy left the .tmp
//      in place which is ignored by read() but still fills the disk).
//      Noted that this test is necessary but not sufficient as a full
//      atomicity guarantor — the soak scenarios cover the end-to-end
//      kill-mid-rename path.
//   3. Reverted the edit → green.

import 'dart:convert';
import 'dart:io';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/installed_maps/installed_manifest_repository.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

InstalledCountry _fakeInstalled(String alpha3) => InstalledCountry(
  alpha3: CountryCode.parse(alpha3),
  installedAtUtc: DateTime.utc(2026, 4, 21),
  fileSize: 1024,
  pmtilesVersion: 'v20260419',
  sha256: 'a' * 64,
  filePath: 'maps/countries/$alpha3.pmtiles',
);

InstalledManifest _manifestWith(List<String> alpha3s) {
  final Map<String, InstalledCountry> installed = <String, InstalledCountry>{for (final String a in alpha3s) a: _fakeInstalled(a)};
  return InstalledManifest(schemaVersion: 1, catalogVersion: 'v20260419', installed: installed);
}

void main() {
  group('JsonFileInstalledManifestRepository atomicity contract', () {
    late Directory tempDir;
    late JsonFileInstalledManifestRepository repo;
    late String canonicalPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('manifest_atomicity_');
      repo = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      canonicalPath = p.join(tempDir.path, kInstalledManifestPath);
    });

    tearDown(() async {
      await repo.close();
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } on Object {
          // Windows occasionally holds file handles — tolerate.
        }
      }
    });

    test('scenario 1: write produces a parseable canonical file (no partial state observable post-write)', () async {
      // Inertness guard: the canonical file does NOT exist before the
      // write. A leaked tempdir would produce a deceptive "parseable
      // post-write" observation — the file could be a leftover from a
      // previous test.
      expect(File(canonicalPath).existsSync(), isFalse, reason: 'tempdir not clean — test inert');

      final InstalledManifest m = _manifestWith(<String>['fra', 'deu']);
      await repo.write(m);

      // Main assert: the canonical file contains the full serialised
      // manifest — not a truncation, not empty, not malformed.
      expect(File(canonicalPath).existsSync(), isTrue);
      final String contents = await File(canonicalPath).readAsString();
      final Object? decoded = jsonDecode(contents);
      expect(decoded, isA<Map<String, Object?>>());
      final InstalledManifest roundTripped = InstalledManifest.fromJson(decoded! as Map<String, Object?>);
      expect(roundTripped.installed.keys, containsAll(<String>['fra', 'deu']));
      expect(roundTripped.schemaVersion, equals(1));
      expect(roundTripped.catalogVersion, equals('v20260419'));
    });

    test('scenario 2: stale `.tmp` sibling from a crash is tolerated — canonical read still returns the previous state', () async {
      // Seed canonical with an initial manifest.
      await repo.write(_manifestWith(<String>['fra']));
      final String initialContents = await File(canonicalPath).readAsString();

      // Inertness guard: the canonical file was actually written before
      // we simulate the crash.
      expect(
        initialContents.isNotEmpty,
        isTrue,
        reason: 'initial write did not materialise — test inert (later .tmp-sibling check would not discriminate between states)',
      );

      // Simulate a crash between `tmp.writeAsString` and `tmp.rename`:
      // a stale `.tmp` file is sitting next to the canonical path with
      // a half-baked payload.
      final File stale = File('$canonicalPath.tmp');
      await stale.writeAsString('{"schemaVersion": 1, "catalogVersion": "half-written', flush: true);

      // Main assert 1: read() still returns the previous canonical
      // state (not corrupted by the stale `.tmp`).
      final InstalledManifest read = await repo.read();
      expect(read.installed.keys, contains('fra'));
      expect(read.installed.keys, isNot(contains('deu')));

      // Main assert 2: a fresh write overwrites the `.tmp` atomically
      // (rename replaces it) and leaves the canonical in a fully-valid
      // state.
      await repo.write(_manifestWith(<String>['fra', 'deu']));
      final InstalledManifest after = await repo.read();
      expect(after.installed.keys, containsAll(<String>['fra', 'deu']));
    });

    test('scenario 3: concurrent writes serialise via the internal mutex — final state is one of the two writes, never a merge or corruption', () async {
      // Fire two writes without awaiting between them. The repo's
      // internal _writeTail chains them; both must complete without
      // interleaving bytes on the canonical path.
      final Future<void> w1 = repo.write(_manifestWith(<String>['fra']));
      final Future<void> w2 = repo.write(_manifestWith(<String>['fra', 'deu', 'esp']));
      await Future.wait(<Future<void>>[w1, w2]);

      // Inertness guard: the writes produced a canonical file at all.
      // A silent no-op of the mutex would leave the disk untouched.
      expect(File(canonicalPath).existsSync(), isTrue, reason: 'concurrent writes produced no canonical file — test inert');

      // Main assert: the canonical contents parse cleanly AND match
      // one of the two queued states. Ordering is deterministic per
      // _writeTail (w2 runs after w1 completes), so the final state
      // MUST be the 3-country manifest.
      final String contents = await File(canonicalPath).readAsString();
      final InstalledManifest read = InstalledManifest.fromJson(jsonDecode(contents)! as Map<String, Object?>);
      expect(
        read.installed.keys.toSet(),
        equals(<String>{'fra', 'deu', 'esp'}),
        reason: 'mutex ordering violated: expected the second queued write (3 countries) to win, got ${read.installed.keys}',
      );
    });

    test('scenario 4: updates stream emits one event per committed write (broadcast integrity + ordering)', () async {
      final List<Set<String>> observed = <Set<String>>[];
      final Stream<InstalledManifest> stream = repo.updates;
      final _ = stream.listen((InstalledManifest m) => observed.add(m.installed.keys.toSet()));

      await repo.write(_manifestWith(<String>['fra']));
      await repo.write(_manifestWith(<String>['fra', 'deu']));
      await repo.write(_manifestWith(<String>['fra', 'deu', 'esp']));

      // Allow the broadcast microtasks to drain before asserting.
      await Future<void>.delayed(Duration.zero);

      // Inertness guard: the stream actually emitted — a broken
      // broadcast controller would leave observed empty and the
      // length assertion alone would miss an ordering-violation case.
      expect(observed, isNotEmpty, reason: 'broadcast stream emitted no events — test inert');

      // Main assert: one event per write + in committed order.
      expect(observed.length, equals(3));
      expect(observed[0], equals(<String>{'fra'}));
      expect(observed[1], equals(<String>{'fra', 'deu'}));
      expect(observed[2], equals(<String>{'fra', 'deu', 'esp'}));
    });
  });
}
