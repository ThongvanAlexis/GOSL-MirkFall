// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'installed_manifest.dart';

/// Abstract port over the installed-maps manifest storage.
///
/// Mirrors the Phase 03 store-port pattern (`SessionStore`,
/// `FixStore`, …): domain exposes an abstract class; infrastructure
/// supplies the concrete adapter. In Plan 07-04 this is implemented by
/// `JsonFileInstalledManifestRepository` backed by
/// `<app_support>/maps/installed.json`, with an in-memory fake for tests
/// (`test/fakes/fake_installed_manifest_repository.dart`).
///
/// Contract:
/// - [read] always returns a valid [InstalledManifest]; if no file
///   exists yet the adapter synthesises [InstalledManifest.empty].
/// - [write] is atomic — a partial on-disk write must not leave a
///   corrupted manifest visible to subsequent [read]s (implementations
///   write-to-temp-then-rename).
/// - [updates] is a broadcast stream emitting the new manifest after
///   every successful [write]. Emits the current manifest on subscription
///   when a cached state is available, but implementations MAY skip the
///   initial emission — consumers should call [read] once on wire-up.
abstract class InstalledManifestRepository {
  /// Reads the current manifest from the backing store.
  Future<InstalledManifest> read();

  /// Persists [manifest] to the backing store. Returns after the write
  /// is durable on disk. Emits on [updates] once the write succeeds.
  Future<void> write(InstalledManifest manifest);

  /// Broadcast stream of manifest updates — one event per successful
  /// [write]. Used by the Phase 07-05 UI to react to
  /// install/uninstall/update-completion events without re-reading the
  /// file.
  Stream<InstalledManifest> get updates;
}
