// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// One-shot maintenance script that refreshes the bundled map glyphs +
/// sprites from the upstream Protomaps basemaps-assets repository at a
/// pinned commit SHA.
///
/// This script is intentionally **not** run by CI. It exists so a
/// maintainer can re-seed `assets/maps/glyphs/` + `assets/maps/sprites/`
/// deterministically when the upstream Protomaps repository publishes
/// new font stacks or sprite pack revisions. The output is committed
/// alongside the pin bump in a single dedicated chore commit.
///
/// ## Upstream pin + license
///
/// - Source : github.com/protomaps/basemaps-assets
/// - Pinned commit: **see `_kPinnedCommitSha` below**. The pin is the
///   source of truth; bump it here in a dedicated commit, re-run the
///   script, commit the resulting `assets/maps/glyphs/` +
///   `assets/maps/sprites/` tree.
/// - Licenses: fonts under SIL Open Font License 1.1 (`fonts/OFL.txt`);
///   sprites under CC0-1.0. Both covered in DEPENDENCIES.md
///   "Bundled assets (non-pub)" section. Audit at pin-bump time:
///   verify the upstream `OFL.txt` + `LICENSE` are still the same
///   SPDX identifiers before committing the refresh.
///
/// ## Protocol (run by a human with git + network)
///
/// 1. Clone the pinned commit into a temp dir:
///       `git clone --depth 1 --branch {sha}` \
///         `https://github.com/protomaps/basemaps-assets` \
///         `%TEMP%\\basemaps-assets-{sha}`
/// 2. Copy `fonts/{fontstack}/*.pbf` -> `assets/maps/glyphs/{fontstack}/`
/// 3. Copy `sprites/v4/light/{sprite.json,sprite.png,sprite@2x.png}`
///    → `assets/maps/sprites/` (renaming `sprite` stem, dropping `@2x`
///    suffix normalisation if required by maplibre_gl 0.25.0 runtime).
/// 4. Delete the temp clone.
/// 5. Run `dart run tool/check_headers.dart` + `flutter analyze` + the
///    rest of the gates suite; commit if green.
///
/// ## Why this is a Dart script and not a README / shell script
///
/// Keeping the protocol as executable Dart (even when large parts of
/// it proxy to `git` via `Process.run`) makes the pin SHA, the copy
/// layout, and the expected output paths live in a single file that
/// CLAUDE.md's GOSL header + `tool/check_headers.dart` already police.
/// A free-form README drifts; a Dart script tracks every constant
/// with analyzer + CI coverage.
///
/// ## Phase 07 plan 07-01 note
///
/// The Phase 07-01 initial drop ships **placeholder** glyph + sprite
/// READMEs, not the real Protomaps assets. Running this script
/// against a live network + git install is deferred to the first
/// plan that actually renders a MapLibre map (Phase 07 plan 07-06
/// "Presentation"). At that point, the maintainer runs this script
/// once, commits the assets, and the placeholder READMEs are
/// overwritten. Phase 07-03's first-launch world copier does not
/// require real glyphs (the PMTiles z0-2 bundle renders acceptably
/// without text labels at those zoom levels).
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : script completed (either "real run" or "placeholder
///     mode") without error
///   - exit 2 : misconfiguration — upstream clone not found, required
///     files missing, cannot write to target
///
/// Note: this script does NOT do the `git clone` itself — the clone
/// is manual (the maintainer must be on a network-enabled machine
/// with git installed + repo-write access for the resulting commit).
/// The script only validates that an expected-layout `--source <dir>`
/// was supplied and copies the files across.
/// Pin sentinel for the protomaps/basemaps-assets upstream commit SHA.
///
/// `UNPINNED` means the maintainer has not yet done the Phase 07-06 pin
/// bump. In that state, a real (non-placeholder) `runCheck` call is
/// refused by the `_pinnedShaGuard` below unless `allowUnpinned: true`
/// is explicitly passed — placeholder mode (no `--source`) stays
/// unaffected. This prevents copying an arbitrary non-reproducible
/// upstream clone into `assets/maps/` without an explicit opt-in.
///
/// When Phase 07-06 bumps this, replace `UNPINNED` with the full 40-char
/// commit SHA + remove the `allowUnpinned` override everywhere.
const String _kPinnedCommitSha = 'UNPINNED';
const String _kUnpinnedSentinel = 'UNPINNED';
const String _kDefaultGlyphsTarget = 'assets/maps/glyphs';
const String _kDefaultSpritesTarget = 'assets/maps/sprites';

/// Guard that refuses a real (non-placeholder) run when
/// [_kPinnedCommitSha] is still the `UNPINNED` sentinel, unless
/// [allowUnpinned] is explicitly opted-in. Returns `null` on pass,
/// non-null error message on refuse. Pure function — test seam.
String? _pinnedShaGuard({required String pinnedSha, required bool allowUnpinned}) {
  if (pinnedSha != _kUnpinnedSentinel) return null;
  if (allowUnpinned) return null;
  return 'prepare_style: _kPinnedCommitSha is "$_kUnpinnedSentinel" — refusing real run to keep assets reproducible.\n'
      'Either bump the constant to a real commit SHA (Phase 07-06 pin) or pass --allow-unpinned for an acknowledged throw-away copy.';
}

/// Runs the prepare-style copy. `sourceDir` is the path to a local clone
/// of github.com/protomaps/basemaps-assets at [_kPinnedCommitSha].
/// When `sourceDir` is null, the script emits the placeholder-mode
/// README sidecars (Phase 07-01 initial drop) and returns 0.
Future<int> runCheck({String? sourceDir, String? glyphsTarget, String? spritesTarget, bool allowUnpinned = false}) async {
  final String glyphsOut = glyphsTarget ?? _kDefaultGlyphsTarget;
  final String spritesOut = spritesTarget ?? _kDefaultSpritesTarget;

  // Placeholder mode (Phase 07-01) — no source supplied. Emit the
  // READMEs so downstream plans see the dir as intentional, not empty.
  if (sourceDir == null) {
    Directory(glyphsOut).createSync(recursive: true);
    Directory(spritesOut).createSync(recursive: true);
    File(p.join(glyphsOut, 'README.md')).writeAsStringSync(
      '# `assets/maps/glyphs/` — Protomaps basemaps-assets fonts (placeholder)\n\n'
      'This directory is intentionally a placeholder in Phase 07-01. The first\n'
      'plan that renders a live MapLibre map (Phase 07 plan 07-06) will run\n'
      '`dart run tool/prepare_style.dart --source <path-to-clone>` against a\n'
      'pinned clone of github.com/protomaps/basemaps-assets and populate this\n'
      'tree with `<fontstack>/<range>.pbf` glyph packs.\n\n'
      'Licensing: SIL Open Font License 1.1 (`fonts/OFL.txt` upstream).\n'
      'Documented in DEPENDENCIES.md "Bundled assets (non-pub)" section.\n\n'
      'At runtime, the style.json references these via\n'
      '`asset:///assets/maps/glyphs/{fontstack}/{range}.pbf`.\n',
    );
    File(p.join(spritesOut, 'README.md')).writeAsStringSync(
      '# `assets/maps/sprites/` — Protomaps basemaps-assets sprites (placeholder)\n\n'
      'Same placeholder convention as `glyphs/`. The prepare-style script\n'
      'populates this directory with `sprite.json`, `sprite.png`, and\n'
      '`sprite@2x.png` copied verbatim from the pinned upstream clone.\n\n'
      'Licensing: CC0-1.0 (sprites waive all rights).\n'
      'Documented in DEPENDENCIES.md "Bundled assets (non-pub)" section.\n\n'
      'At runtime, the style.json references these via\n'
      '`asset:///assets/maps/sprites/sprite` (maplibre_gl appends `.json` /\n'
      '`.png` / `@2x.png` automatically).\n',
    );
    stdout.writeln('prepare_style: placeholder mode — emitted READMEs under $glyphsOut and $spritesOut');
    stdout.writeln('prepare_style: bump _kPinnedCommitSha + rerun with --source <clone> to populate real assets.');
    return 0;
  }

  // Real run — guard the unpinned sentinel before we touch anything.
  final String? pinError = _pinnedShaGuard(pinnedSha: _kPinnedCommitSha, allowUnpinned: allowUnpinned);
  if (pinError != null) {
    stderr.writeln(pinError);
    return 2;
  }

  // Real run — validate + copy.
  final Directory src = Directory(sourceDir);
  if (!src.existsSync()) {
    stderr.writeln('prepare_style: source clone not found at $sourceDir');
    stderr.writeln('Clone first: git clone --depth 1 --branch $_kPinnedCommitSha https://github.com/protomaps/basemaps-assets $sourceDir');
    return 2;
  }
  final Directory srcFonts = Directory(p.join(sourceDir, 'fonts'));
  final Directory srcSprites = Directory(p.join(sourceDir, 'sprites', 'v4', 'light'));
  if (!srcFonts.existsSync() || !srcSprites.existsSync()) {
    stderr.writeln('prepare_style: expected fonts/ + sprites/v4/light/ under $sourceDir');
    return 2;
  }

  // Copy fonts/<fontstack>/*.pbf preserving sub-directory structure.
  final Directory glyphsDir = Directory(glyphsOut);
  if (glyphsDir.existsSync()) glyphsDir.deleteSync(recursive: true);
  glyphsDir.createSync(recursive: true);
  int copiedGlyphs = 0;
  for (final FileSystemEntity fontDir in srcFonts.listSync()) {
    if (fontDir is! Directory) continue;
    final String stackBasename = p.basename(fontDir.path);
    final Directory target = Directory(p.join(glyphsOut, stackBasename));
    target.createSync(recursive: true);
    for (final FileSystemEntity pbf in fontDir.listSync()) {
      if (pbf is! File || !pbf.path.endsWith('.pbf')) continue;
      final String targetPath = p.join(target.path, p.basename(pbf.path));
      pbf.copySync(targetPath);
      copiedGlyphs++;
    }
  }

  // Copy sprites/v4/light/sprite{.json,.png,@2x.png} → assets/maps/sprites/sprite.*
  final Directory spritesDir = Directory(spritesOut);
  if (spritesDir.existsSync()) spritesDir.deleteSync(recursive: true);
  spritesDir.createSync(recursive: true);
  int copiedSprites = 0;
  for (final String leafBasename in <String>['sprite.json', 'sprite.png', 'sprite@2x.png']) {
    final File src = File(p.join(srcSprites.path, leafBasename));
    if (!src.existsSync()) {
      stderr.writeln('prepare_style: expected $leafBasename under ${srcSprites.path}');
      return 2;
    }
    src.copySync(p.join(spritesOut, leafBasename));
    copiedSprites++;
  }

  stdout.writeln('prepare_style: OK — copied $copiedGlyphs glyph(s) + $copiedSprites sprite file(s) from $sourceDir');
  return 0;
}

Future<void> main(List<String> args) async {
  String? sourceDir;
  bool allowUnpinned = false;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--source' && i + 1 < args.length) {
      sourceDir = args[i + 1];
      i++;
      continue;
    }
    if (args[i] == '--allow-unpinned') {
      allowUnpinned = true;
      continue;
    }
  }
  final int code = await runCheck(sourceDir: sourceDir, allowUnpinned: allowUnpinned);
  exitCode = code;
}
