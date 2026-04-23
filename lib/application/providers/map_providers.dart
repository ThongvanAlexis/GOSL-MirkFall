// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/infrastructure/downloads/atomic_renamer.dart';
import 'package:mirkfall/infrastructure/downloads/binary_concatenator.dart';
import 'package:mirkfall/infrastructure/downloads/download_queue_store.dart';
import 'package:mirkfall/infrastructure/downloads/http_chunk_downloader.dart';
import 'package:mirkfall/infrastructure/downloads/pmtiles_download_controller.dart';
import 'package:mirkfall/infrastructure/downloads/sha256_verifier.dart';
import 'package:mirkfall/infrastructure/installed_maps/country_delete_service.dart';
import 'package:mirkfall/infrastructure/installed_maps/first_launch_bootstrap.dart';
import 'package:mirkfall/infrastructure/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/infrastructure/map/first_launch_world_copier.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:mirkfall/infrastructure/map/style_rewriter.dart';
import 'package:mirkfall/infrastructure/platform/disk_space_checker.dart';
import 'package:mirkfall/infrastructure/platform/ios_backup_excluder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_providers.g.dart';

/// Production path to `<app_support>/` resolved via `path_provider`.
///
/// All Phase 07 filesystem-owning components (manifest repository, download
/// queue, first-launch bootstrap) take an explicit `appSupportDir` string
/// rather than calling `path_provider` themselves — this keeps them free of
/// a platform-channel dependency and makes every unit test trivially able
/// to override with a `Directory.systemTemp.createTemp(...)` path.
///
/// `keepAlive: true` — the path is a process-lifetime constant; recomputing
/// it on every consumer subscription would thrash the platform channel.
@Riverpod(keepAlive: true)
Future<String> appSupportDir(Ref ref) async {
  final directory = await getApplicationSupportDirectory();
  return directory.path;
}

/// Parsed [CountryCatalog] loaded once from the bundled
/// `assets/maps/catalog.json`.
///
/// Read once at startup + cached — the catalog is an immutable build-time
/// artefact (MAP-04), so refreshing at runtime is never required. Consumers
/// that need the value synchronously (the Plan 07-06 download screen)
/// await `ref.watch(countryCatalogProvider.future)` once.
///
/// `keepAlive: true` — same rationale as [appSupportDirProvider]; the
/// parsed value is a 249-country document that would otherwise re-parse
/// on every Riverpod dispose/recreate cycle.
@Riverpod(keepAlive: true)
Future<CountryCatalog> countryCatalog(Ref ref) async {
  final raw = await rootBundle.loadString(kMapCatalogAssetPath);
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) {
    throw FormatException('countryCatalogProvider: expected top-level JSON object in $kMapCatalogAssetPath, got ${decoded.runtimeType}');
  }
  return CountryCatalog.fromJson(decoded);
}

/// Filesystem-backed [InstalledManifestRepository] adapter.
///
/// Single instance for the lifetime of the process — the repository owns a
/// broadcast stream of manifest updates + a single-writer mutex, both of
/// which must survive screen navigation so the Plan 07-06 installed-maps
/// list stays reactive across `/` → `/map` transitions.
@Riverpod(keepAlive: true)
Future<InstalledManifestRepository> installedManifestRepository(Ref ref) async {
  final supportDir = await ref.watch(appSupportDirProvider.future);
  final repo = JsonFileInstalledManifestRepository(appSupportDir: supportDir);
  ref.onDispose(() async {
    await repo.close();
  });
  return repo;
}

/// Reactive [InstalledManifest] snapshot.
///
/// Emits the current manifest on subscription (via a synchronous `read()`)
/// then forwards every subsequent `write()` via the port's broadcast
/// stream. The Plan 07-06 UI watches this provider to refresh the
/// installed-maps list without manual invalidation.
///
/// `keepAlive: true` — the manifest is process-global state; cycling the
/// subscription on every widget mount/unmount would create redundant disk
/// reads.
@Riverpod(keepAlive: true)
Stream<InstalledManifest> installedManifest(Ref ref) async* {
  final repo = await ref.watch(installedManifestRepositoryProvider.future);
  yield await repo.read();
  yield* repo.updates;
}

/// [PmtilesSource] resolver — converts `CountryCode?` + manifest snapshot
/// into a `pmtiles://file:///…` URI for MapLibre's style source.
@Riverpod(keepAlive: true)
Future<PmtilesSource> pmtilesSource(Ref ref) async {
  final repo = await ref.watch(installedManifestRepositoryProvider.future);
  final supportDir = await ref.watch(appSupportDirProvider.future);
  return PmtilesSource(installedManifestPort: repo, appSupportDir: supportDir);
}

/// [StyleRewriter] — loads `assets/maps/style.json`, validates + swaps the
/// PMTiles placeholder for the resolved runtime URI.
@Riverpod(keepAlive: true)
Future<StyleRewriter> styleRewriter(Ref ref) async {
  final source = await ref.watch(pmtilesSourceProvider.future);
  return StyleRewriter(source);
}

/// Hand-rolled [DiskSpaceChecker] (Android `StatFs` + iOS
/// `FileManager.systemFreeSize` via platform channels). Process-wide
/// singleton — the underlying MethodChannel is stateless.
@Riverpod(keepAlive: true)
DiskSpaceChecker diskSpaceChecker(Ref ref) => DiskSpaceChecker();

/// [IosBackupExcluder] — no-op on non-iOS; sets
/// `NSURLIsExcludedFromBackupKey` on iOS for per-country PMTiles files.
@Riverpod(keepAlive: true)
IosBackupExcluder iosBackupExcluder(Ref ref) => IosBackupExcluder();

/// [FirstLaunchWorldCopier] — copies the bundled world PMTiles asset to
/// `<app_support>/maps/world.pmtiles` on first launch and auto-heals on
/// post-write sha256 mismatch. Consumed by [firstLaunchBootstrapProvider].
@Riverpod(keepAlive: true)
Future<FirstLaunchWorldCopier> firstLaunchWorldCopier(Ref ref) async {
  final supportDir = await ref.watch(appSupportDirProvider.future);
  // Expected sha defaults to kWorldBundleSha256; explicit arg omitted so a
  // future change to the bundled asset hash flows through a single
  // constant — no provider update needed.
  return FirstLaunchWorldCopier(appSupportDir: supportDir);
}

/// [HttpChunkDownloader] — pure dart:io `HttpClient` wrapper with Range
/// resume + 200-OK restart fallback + 302 redirect following.
///
/// `ref.onDispose` closes the underlying `HttpClient` so socket handles
/// are released cleanly at provider invalidation (e.g. app-level
/// re-bootstrap during development).
@Riverpod(keepAlive: true)
HttpChunkDownloader httpChunkDownloader(Ref ref) {
  final downloader = HttpChunkDownloader();
  ref.onDispose(downloader.close);
  return downloader;
}

/// [Sha256Verifier] — streaming sha256 over a [File] via `sha256.bind`.
/// Stateless; const-constructible.
@Riverpod(keepAlive: true)
Sha256Verifier sha256Verifier(Ref ref) => const Sha256Verifier();

/// [BinaryConcatenator] — streams N part files into a single destination
/// via `IOSink`. Stateless.
@Riverpod(keepAlive: true)
BinaryConcatenator binaryConcatenator(Ref ref) => const BinaryConcatenator();

/// [AtomicRenamer] — `File.rename` with cross-volume `EXDEV`
/// copy+delete fallback. Stateless. The ctor takes a logger so it is
/// non-const; a single instance per process is enough.
@Riverpod(keepAlive: true)
AtomicRenamer atomicRenamer(Ref ref) => AtomicRenamer();

/// Persistent JSON-backed [DownloadQueueStore].
@Riverpod(keepAlive: true)
Future<DownloadQueueStore> downloadQueueStore(Ref ref) async {
  final supportDir = await ref.watch(appSupportDirProvider.future);
  return DownloadQueueStore(appSupportDir: supportDir);
}

/// [PmtilesDownloadController] — plain-Dart orchestrator for the 7-step
/// atomic download protocol. Wrapped in a Riverpod provider so the Plan
/// 07-05 `DownloadQueueController` (and the Plan 07-06 UI via that
/// wrapper) can reach it through `ref.watch`.
///
/// Lifetime: `ref.onDispose` calls `controller.dispose()` so the in-flight
/// HTTP request + the broadcast state stream get cleaned up at process
/// shutdown.
@Riverpod(keepAlive: true)
Future<PmtilesDownloadController> pmtilesDownloadController(Ref ref) async {
  final supportDir = await ref.watch(appSupportDirProvider.future);
  final http = ref.watch(httpChunkDownloaderProvider);
  final cat = ref.watch(binaryConcatenatorProvider);
  final renamer = ref.watch(atomicRenamerProvider);
  final repo = await ref.watch(installedManifestRepositoryProvider.future);
  final disk = ref.watch(diskSpaceCheckerProvider);
  final queue = await ref.watch(downloadQueueStoreProvider.future);
  final backup = ref.watch(iosBackupExcluderProvider);

  final controller = PmtilesDownloadController(
    appSupportDir: supportDir,
    httpDownloader: http,
    concatenator: cat,
    renamer: renamer,
    manifestRepository: repo,
    diskSpaceChecker: disk,
    queueStore: queue,
    iosBackupExcluder: backup,
  );
  ref.onDispose(() async {
    await controller.dispose();
  });
  return controller;
}

/// [CountryDeleteService] — world-bundle-guarded per-country uninstall.
@Riverpod(keepAlive: true)
Future<CountryDeleteService> countryDeleteService(Ref ref) async {
  final repo = await ref.watch(installedManifestRepositoryProvider.future);
  final supportDir = await ref.watch(appSupportDirProvider.future);
  return CountryDeleteService(manifestRepository: repo, appSupportDir: supportDir);
}

/// [FirstLaunchBootstrap] — composes the world copy, orphan staging scan,
/// pmtiles-heal recovery path, and iOS backup-exclude side effect.
///
/// Declared as a [FutureProvider] that awaits the bootstrap's `run()`;
/// a caller (Plan 07-06 main.dart or the top-level app shell) watches the
/// provider and renders a "Préparation de la carte…" placeholder until
/// the future resolves. See [main.dart]'s Plan 07-05 wiring for the
/// pre-runApp invocation pattern described in 07-05-PLAN Task 3.
///
/// Throws [MapAssetMissingException] if the bundled world asset is
/// corrupt — which the UI layer surfaces as a fatal "Application bundle
/// corrupt" banner (MAP-07 floor: the world basemap MUST be present).
@Riverpod(keepAlive: true)
Future<FirstLaunchBootstrap> firstLaunchBootstrap(Ref ref) async {
  final worldCopier = await ref.watch(firstLaunchWorldCopierProvider.future);
  final supportDir = await ref.watch(appSupportDirProvider.future);
  final repo = await ref.watch(installedManifestRepositoryProvider.future);
  final catalog = await ref.watch(countryCatalogProvider.future);
  final queueStore = await ref.watch(downloadQueueStoreProvider.future);
  final backup = ref.watch(iosBackupExcluderProvider);

  final bootstrap = FirstLaunchBootstrap(
    worldCopier: worldCopier,
    appSupportDir: supportDir,
    manifestRepository: repo,
    downloadQueueStore: queueStore,
    catalog: catalog,
    iosBackupExcluder: backup,
  );
  await bootstrap.run();
  return bootstrap;
}

/// Mutable [MapView] reference published by the Plan 07-06
/// `MapLibreMapViewWidget` via its `onReady` callback.
///
/// Starts as `null`; consumers (MapCameraController, CountryResolverController)
/// `ref.watch(mapViewProvider)` and no-op until the widget's `onStyleLoaded`
/// fires. When the widget is rebuilt (e.g. hot-reload on dev host), it
/// re-publishes the fresh adapter via
/// `ref.read(mapViewProvider.notifier).set(...)` — subscribers get the
/// new instance automatically.
///
/// `StateProvider` was removed in Riverpod 3.x — the canonical replacement
/// is an `@Riverpod` notifier whose build() returns the held value and
/// whose mutator method updates `state`. Class name `MapView` collides
/// with the domain port, so the notifier is named `MapViewHolder` but the
/// auto-generated provider is aliased to `mapViewProvider` below for
/// call-site ergonomics.
@Riverpod(keepAlive: true)
class MapViewHolder extends _$MapViewHolder {
  @override
  MapView? build() => null;

  /// Publishes a newly-ready [MapView] adapter. Called from the Plan
  /// 07-06 `MapLibreMapViewWidget.onReady` callback.
  void set(MapView? next) {
    state = next;
  }
}

/// Alias exposing the [MapViewHolder] notifier under the shorter name
/// consumers actually read. Downstream tasks `ref.watch(mapViewProvider)`
/// for the value and `ref.read(mapViewProvider.notifier).set(...)` for
/// publishing.
// ignore: non_constant_identifier_names — `final` alias; the naming follows
// the "xxxProvider" convention dictated by Riverpod's public surface, not
// a lower-camel-case variable name (the non-const identifier lint applies
// to CONSTANTS, not to this alias which is an object reference).
final mapViewProvider = mapViewHolderProvider;

/// Current MapLibre viewport zoom level. Null until the MapView is ready
/// and the first `onCameraIdle` viewport event fires.
///
/// Subscribes to [`MapView.viewportUpdates`] and mirrors the `zoom`
/// field. Used by diagnostic UI (the burger-menu zoom readout) — the
/// [`MapCameraController`] tracks its own internal `_currentZoom` for
/// the follow-me pending-move logic and does not consume this provider
/// to avoid a two-way subscription loop.
///
/// `keepAlive: true` — zoom is a long-lived observable value; tearing
/// down the subscription every time the drawer closes would drop events
/// during the gap and surface a stale zoom the next time the drawer
/// opens.
@Riverpod(keepAlive: true)
class MapViewportZoom extends _$MapViewportZoom {
  @override
  double? build() {
    final MapView? view = ref.watch(mapViewProvider);
    if (view == null) return null;
    final StreamSubscription<({double latitude, double longitude, double zoom})> sub = view.viewportUpdates.listen(
      (v) => state = v.zoom,
      onError: (Object _, StackTrace _) {
        // Viewport stream errors are not fatal — they're typically a
        // transient MapLibre callback ordering glitch. Silently drop; the
        // next successful update rewrites state.
      },
    );
    ref.onDispose(sub.cancel);
    // Seed from the adapter's current viewport snapshot. Without this
    // read the provider state stays null until the user pinches — any
    // camera move that settled BEFORE this provider first attached
    // (e.g. the auto-center from MapScreen._onMapReady →
    // MapCameraController.openForSession firing moveCameraTo before
    // the burger-menu consumer watches this notifier) is missed.
    // Async read is safe: if the adapter is disposed before the future
    // completes, the `state =` assignment hits a disposed notifier and
    // Riverpod's own guard short-circuits — no exception surfaces.
    unawaited(() async {
      try {
        final v = await view.queryViewport();
        state = v.zoom;
      } on Object {
        // queryViewport can throw on an adapter whose MapLibre surface
        // hasn't finished loading. Benign — the viewportUpdates stream
        // will emit once the camera settles.
      }
    }());
    return null;
  }
}
