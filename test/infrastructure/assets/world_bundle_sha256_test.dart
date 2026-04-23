// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// World-bundle sha256 regression guard (Plan 08-04 Task 3, Test #5).
//
// Asserts that the sha256 of `assets/maps/world.pmtiles` equals
// `kWorldBundleSha256` from `lib/config/world_bundle_sha256.dart`. If
// the asset changes without regenerating the constant (via
// `dart run tool/generate_world_sha256.dart`), the
// `FirstLaunchWorldCopier` auto-heal path would loop on every launch —
// this test catches the drift at CI time.
//
// Inertness guard: the bundle file exists + has non-zero length. A
// refactor that renames the asset (or the constant's path) without
// updating the test would otherwise produce a deceptively-green run.
//
// Streams the file through `sha256.bind` rather than loading all bytes
// at once — Phase 07-01 bundled asset is 856 KB, the Phase 07 + V1.x
// roadmap may grow it significantly (e.g. include richer landcover).
// Streaming keeps the test bounded in memory regardless.
//
// Mutation experiment (author-time, Plan 08-04 Task 3):
//   1. Temporarily overrode `kWorldBundleSha256` to a known-wrong
//      constant (flipped one hex digit) via a local edit.
//   2. Ran `dart test test/infrastructure/assets/world_bundle_sha256_test.dart`
//      → FAILED loudly with the "world.pmtiles asset drifted from
//      kWorldBundleSha256 constant" message.
//   3. Reverted the edit → green.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mirkfall/config/world_bundle_sha256.dart';
import 'package:test/test.dart';

void main() {
  test('assets/maps/world.pmtiles sha256 matches kWorldBundleSha256 constant', () async {
    final File bundleFile = File('assets/maps/world.pmtiles');

    // Inertness guard: the bundle asset must exist on disk where we
    // expect it. A refactor that renames or moves the asset without
    // updating this path would silently pass a zero-byte check — the
    // streamed sha256 of an empty stream is well-defined
    // (e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855)
    // but unrelated to the real bundle, so the equality check could
    // accidentally pass if kWorldBundleSha256 were the empty-stream
    // hash. Size > 0 locks that loophole.
    expect(
      bundleFile.existsSync(),
      isTrue,
      reason:
          'assets/maps/world.pmtiles missing — test inert. A refactor '
          'that renames the asset without updating this path would '
          'silently pass on an empty-stream sha256 comparison.',
    );
    expect(
      bundleFile.lengthSync(),
      greaterThan(0),
      reason: 'assets/maps/world.pmtiles is empty — test inert (empty-stream sha256 would be compared).',
    );

    // Main assert: streamed sha256 matches the committed constant.
    final Digest digest = await sha256.bind(bundleFile.openRead()).first;
    expect(
      digest.toString(),
      equals(kWorldBundleSha256),
      reason:
          'assets/maps/world.pmtiles drifted from kWorldBundleSha256 — '
          'rebuild the world bundle OR regenerate the constant via '
          '`dart run tool/generate_world_sha256.dart`. If both drifted '
          'together, check that FirstLaunchWorldCopier auto-heal is not '
          'about to loop on every launch.',
    );
  });
}
