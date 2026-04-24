// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../prepare_style.dart' as prep;

/// Fixture-based paired tests for `tool/prepare_style.dart` (§3 row
/// #16 — Phase 07 tool scripts needed paired tests).
///
/// Drives the `runCheck({sourceDir, glyphsTarget, spritesTarget,
/// allowUnpinned})` seam against tempdirs so we exercise the real
/// copy shape without mutating `assets/maps/glyphs|sprites/`.
/// Covers the two documented exit codes (Phase 01 CLI contract):
///   0 — placeholder READMEs emitted OR real run completed
///   2 — misconfiguration (missing source / missing sub-trees / unpinned
///       sentinel without --allow-unpinned)
///
/// Phase 07-01 context: `_kPinnedCommitSha` is still `UNPINNED`, so a
/// real run without `--allow-unpinned` refuses up-front. Tests either
/// exercise placeholder mode (no sourceDir) or pass the opt-in flag
/// explicitly.
void main() {
  group('prepare_style.runCheck — placeholder mode', () {
    late Directory tempDir;
    late String glyphsTarget;
    late String spritesTarget;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('prepare_style_test_');
      glyphsTarget = p.join(tempDir.path, 'glyphs');
      spritesTarget = p.join(tempDir.path, 'sprites');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } on FileSystemException {
          // Windows temp cleanup — same pattern as the sibling tests.
        }
      }
    });

    test('emits placeholder READMEs + exit 0 when sourceDir is null', () async {
      final int code = await prep.runCheck(glyphsTarget: glyphsTarget, spritesTarget: spritesTarget);
      expect(code, equals(0));

      final File glyphReadme = File(p.join(glyphsTarget, 'README.md'));
      final File spriteReadme = File(p.join(spritesTarget, 'README.md'));
      expect(glyphReadme.existsSync(), isTrue);
      expect(spriteReadme.existsSync(), isTrue);
      // Content spot-check: the README must name the pin-bump protocol
      // + the SPDX so a reader knows why the dir is empty.
      expect(glyphReadme.readAsStringSync(), contains('SIL Open Font License'));
      expect(glyphReadme.readAsStringSync(), contains('--source'));
      expect(spriteReadme.readAsStringSync(), contains('CC0-1.0'));
    });

    test('placeholder mode creates missing parent directories', () async {
      // Nested targets — the script must create them before writing.
      final String nestedGlyphs = p.join(tempDir.path, 'deep', 'glyphs');
      final String nestedSprites = p.join(tempDir.path, 'deep', 'sprites');
      final int code = await prep.runCheck(glyphsTarget: nestedGlyphs, spritesTarget: nestedSprites);
      expect(code, equals(0));
      expect(File(p.join(nestedGlyphs, 'README.md')).existsSync(), isTrue);
      expect(File(p.join(nestedSprites, 'README.md')).existsSync(), isTrue);
    });
  });

  group('prepare_style.runCheck — real run (--allow-unpinned)', () {
    late Directory tempDir;
    late String sourceDir;
    late String glyphsTarget;
    late String spritesTarget;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('prepare_style_real_');
      sourceDir = p.join(tempDir.path, 'basemaps-assets');
      glyphsTarget = p.join(tempDir.path, 'out_glyphs');
      spritesTarget = p.join(tempDir.path, 'out_sprites');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } on FileSystemException {
          // Windows temp cleanup.
        }
      }
    });

    /// Builds a minimal upstream clone layout under [sourceDir] with two
    /// font stacks + the three sprite files the real protomaps repo
    /// ships at `sprites/v4/light/`. Content is arbitrary bytes — the
    /// script only copies + counts, it does not parse.
    void seedMinimalUpstreamFixture() {
      // fonts/<stack>/<range>.pbf
      final Directory stackA = Directory(p.join(sourceDir, 'fonts', 'NotoSansRegular'));
      final Directory stackB = Directory(p.join(sourceDir, 'fonts', 'NotoSansMedium'));
      stackA.createSync(recursive: true);
      stackB.createSync(recursive: true);
      File(p.join(stackA.path, '0-255.pbf')).writeAsBytesSync(<int>[0x01, 0x02, 0x03]);
      File(p.join(stackA.path, '256-511.pbf')).writeAsBytesSync(<int>[0x04, 0x05]);
      File(p.join(stackB.path, '0-255.pbf')).writeAsBytesSync(<int>[0xFF]);
      // Non-pbf sidecar — must NOT be copied (the script filters on .pbf).
      File(p.join(stackA.path, 'NOTICE.txt')).writeAsStringSync('licence blurb');

      // sprites/v4/light/{sprite.json, sprite.png, sprite@2x.png}
      final Directory spritesSrc = Directory(p.join(sourceDir, 'sprites', 'v4', 'light'));
      spritesSrc.createSync(recursive: true);
      File(p.join(spritesSrc.path, 'sprite.json')).writeAsStringSync('{"icon":{"width":16,"height":16,"x":0,"y":0,"pixelRatio":1}}');
      File(p.join(spritesSrc.path, 'sprite.png')).writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
      File(p.join(spritesSrc.path, 'sprite@2x.png')).writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D]);
    }

    test('copies fonts/<stack>/*.pbf + sprite trio → glyphs + sprites targets (exit 0)', () async {
      seedMinimalUpstreamFixture();

      final int code = await prep.runCheck(sourceDir: sourceDir, glyphsTarget: glyphsTarget, spritesTarget: spritesTarget, allowUnpinned: true);
      expect(code, equals(0));

      // Glyphs: per-stack directories preserved; only .pbf files copied.
      expect(File(p.join(glyphsTarget, 'NotoSansRegular', '0-255.pbf')).existsSync(), isTrue);
      expect(File(p.join(glyphsTarget, 'NotoSansRegular', '256-511.pbf')).existsSync(), isTrue);
      expect(File(p.join(glyphsTarget, 'NotoSansMedium', '0-255.pbf')).existsSync(), isTrue);
      // NOTICE.txt is NOT a .pbf → must be filtered out.
      expect(File(p.join(glyphsTarget, 'NotoSansRegular', 'NOTICE.txt')).existsSync(), isFalse);

      // Sprites: all three files present with identical bytes.
      expect(File(p.join(spritesTarget, 'sprite.json')).existsSync(), isTrue);
      expect(File(p.join(spritesTarget, 'sprite.png')).existsSync(), isTrue);
      expect(File(p.join(spritesTarget, 'sprite@2x.png')).existsSync(), isTrue);
      expect(File(p.join(spritesTarget, 'sprite.png')).readAsBytesSync(), equals(<int>[0x89, 0x50, 0x4E, 0x47]));
    });

    test('clears pre-existing target directories before copying', () async {
      seedMinimalUpstreamFixture();

      // Pre-seed stale content that MUST be wiped by the real run —
      // otherwise a stale pre-pin glyph would survive a re-seed and
      // misrepresent the committed tree.
      Directory(glyphsTarget).createSync(recursive: true);
      Directory(spritesTarget).createSync(recursive: true);
      File(p.join(glyphsTarget, 'stale_glyph.pbf')).writeAsStringSync('leftover');
      File(p.join(spritesTarget, 'stale_sprite.png')).writeAsStringSync('leftover');

      final int code = await prep.runCheck(sourceDir: sourceDir, glyphsTarget: glyphsTarget, spritesTarget: spritesTarget, allowUnpinned: true);
      expect(code, equals(0));

      expect(File(p.join(glyphsTarget, 'stale_glyph.pbf')).existsSync(), isFalse, reason: 'stale glyph must be cleared on re-seed');
      expect(File(p.join(spritesTarget, 'stale_sprite.png')).existsSync(), isFalse, reason: 'stale sprite must be cleared on re-seed');
    });

    test('refuses with exit 2 when _kPinnedCommitSha is UNPINNED and --allow-unpinned is absent', () async {
      seedMinimalUpstreamFixture();

      // Same fixture — but do NOT pass allowUnpinned: true. The
      // _pinnedShaGuard must stop the run before any file is touched.
      final int code = await prep.runCheck(sourceDir: sourceDir, glyphsTarget: glyphsTarget, spritesTarget: spritesTarget);
      expect(code, equals(2));
      // Targets were not created (guard fires before mkdir).
      expect(Directory(glyphsTarget).existsSync(), isFalse);
      expect(Directory(spritesTarget).existsSync(), isFalse);
    });

    test('returns 2 when sourceDir does not exist', () async {
      final int code = await prep.runCheck(
        sourceDir: p.join(tempDir.path, 'does_not_exist'),
        glyphsTarget: glyphsTarget,
        spritesTarget: spritesTarget,
        allowUnpinned: true,
      );
      expect(code, equals(2));
    });

    test('returns 2 when fonts/ sub-tree is missing', () async {
      // Only sprites — no fonts.
      final Directory spritesSrc = Directory(p.join(sourceDir, 'sprites', 'v4', 'light'));
      spritesSrc.createSync(recursive: true);
      File(p.join(spritesSrc.path, 'sprite.json')).writeAsStringSync('{}');
      File(p.join(spritesSrc.path, 'sprite.png')).writeAsBytesSync(<int>[0x89]);
      File(p.join(spritesSrc.path, 'sprite@2x.png')).writeAsBytesSync(<int>[0x89]);

      final int code = await prep.runCheck(sourceDir: sourceDir, glyphsTarget: glyphsTarget, spritesTarget: spritesTarget, allowUnpinned: true);
      expect(code, equals(2));
    });

    test('returns 2 when sprites/v4/light/ sub-tree is missing', () async {
      // Only fonts — no sprites.
      final Directory stack = Directory(p.join(sourceDir, 'fonts', 'NotoSansRegular'));
      stack.createSync(recursive: true);
      File(p.join(stack.path, '0-255.pbf')).writeAsBytesSync(<int>[0x01]);

      final int code = await prep.runCheck(sourceDir: sourceDir, glyphsTarget: glyphsTarget, spritesTarget: spritesTarget, allowUnpinned: true);
      expect(code, equals(2));
    });

    test('returns 2 when an expected sprite file is absent from a present sprite dir', () async {
      // fonts present + sprite dir present but missing sprite@2x.png.
      final Directory stack = Directory(p.join(sourceDir, 'fonts', 'NotoSansRegular'));
      stack.createSync(recursive: true);
      File(p.join(stack.path, '0-255.pbf')).writeAsBytesSync(<int>[0x01]);
      final Directory spritesSrc = Directory(p.join(sourceDir, 'sprites', 'v4', 'light'));
      spritesSrc.createSync(recursive: true);
      File(p.join(spritesSrc.path, 'sprite.json')).writeAsStringSync('{}');
      File(p.join(spritesSrc.path, 'sprite.png')).writeAsBytesSync(<int>[0x89]);
      // sprite@2x.png deliberately omitted.

      final int code = await prep.runCheck(sourceDir: sourceDir, glyphsTarget: glyphsTarget, spritesTarget: spritesTarget, allowUnpinned: true);
      expect(code, equals(2));
    });
  });
}
