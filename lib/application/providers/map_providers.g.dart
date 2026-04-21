// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(appSupportDir)
final appSupportDirProvider = AppSupportDirProvider._();

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

final class AppSupportDirProvider extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
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
  AppSupportDirProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSupportDirProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSupportDirHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appSupportDir(ref);
  }
}

String _$appSupportDirHash() => r'4cdfd257336a846b863e8afea65676f8f9277fd8';

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

@ProviderFor(countryCatalog)
final countryCatalogProvider = CountryCatalogProvider._();

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

final class CountryCatalogProvider extends $FunctionalProvider<AsyncValue<CountryCatalog>, CountryCatalog, FutureOr<CountryCatalog>>
    with $FutureModifier<CountryCatalog>, $FutureProvider<CountryCatalog> {
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
  CountryCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countryCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countryCatalogHash();

  @$internal
  @override
  $FutureProviderElement<CountryCatalog> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<CountryCatalog> create(Ref ref) {
    return countryCatalog(ref);
  }
}

String _$countryCatalogHash() => r'54dd56fe017f00ae2134865ce8b4349a0958ab00';

/// Filesystem-backed [InstalledManifestRepository] adapter.
///
/// Single instance for the lifetime of the process — the repository owns a
/// broadcast stream of manifest updates + a single-writer mutex, both of
/// which must survive screen navigation so the Plan 07-06 installed-maps
/// list stays reactive across `/` → `/map` transitions.

@ProviderFor(installedManifestRepository)
final installedManifestRepositoryProvider = InstalledManifestRepositoryProvider._();

/// Filesystem-backed [InstalledManifestRepository] adapter.
///
/// Single instance for the lifetime of the process — the repository owns a
/// broadcast stream of manifest updates + a single-writer mutex, both of
/// which must survive screen navigation so the Plan 07-06 installed-maps
/// list stays reactive across `/` → `/map` transitions.

final class InstalledManifestRepositoryProvider
    extends $FunctionalProvider<AsyncValue<InstalledManifestRepository>, InstalledManifestRepository, FutureOr<InstalledManifestRepository>>
    with $FutureModifier<InstalledManifestRepository>, $FutureProvider<InstalledManifestRepository> {
  /// Filesystem-backed [InstalledManifestRepository] adapter.
  ///
  /// Single instance for the lifetime of the process — the repository owns a
  /// broadcast stream of manifest updates + a single-writer mutex, both of
  /// which must survive screen navigation so the Plan 07-06 installed-maps
  /// list stays reactive across `/` → `/map` transitions.
  InstalledManifestRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedManifestRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedManifestRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<InstalledManifestRepository> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstalledManifestRepository> create(Ref ref) {
    return installedManifestRepository(ref);
  }
}

String _$installedManifestRepositoryHash() => r'550639af45771e75d798646448252c7a80f52139';

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

@ProviderFor(installedManifest)
final installedManifestProvider = InstalledManifestProvider._();

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

final class InstalledManifestProvider extends $FunctionalProvider<AsyncValue<InstalledManifest>, InstalledManifest, Stream<InstalledManifest>>
    with $FutureModifier<InstalledManifest>, $StreamProvider<InstalledManifest> {
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
  InstalledManifestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedManifestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedManifestHash();

  @$internal
  @override
  $StreamProviderElement<InstalledManifest> $createElement($ProviderPointer pointer) => $StreamProviderElement(pointer);

  @override
  Stream<InstalledManifest> create(Ref ref) {
    return installedManifest(ref);
  }
}

String _$installedManifestHash() => r'41d4b5fbd98931d5fa432a8870b933b965240c19';

/// [PmtilesSource] resolver — converts `CountryCode?` + manifest snapshot
/// into a `pmtiles://file:///…` URI for MapLibre's style source.

@ProviderFor(pmtilesSource)
final pmtilesSourceProvider = PmtilesSourceProvider._();

/// [PmtilesSource] resolver — converts `CountryCode?` + manifest snapshot
/// into a `pmtiles://file:///…` URI for MapLibre's style source.

final class PmtilesSourceProvider extends $FunctionalProvider<AsyncValue<PmtilesSource>, PmtilesSource, FutureOr<PmtilesSource>>
    with $FutureModifier<PmtilesSource>, $FutureProvider<PmtilesSource> {
  /// [PmtilesSource] resolver — converts `CountryCode?` + manifest snapshot
  /// into a `pmtiles://file:///…` URI for MapLibre's style source.
  PmtilesSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pmtilesSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pmtilesSourceHash();

  @$internal
  @override
  $FutureProviderElement<PmtilesSource> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<PmtilesSource> create(Ref ref) {
    return pmtilesSource(ref);
  }
}

String _$pmtilesSourceHash() => r'b1ba767fbacd9b1cc2cdcf9810ff48d4bca53097';

/// [StyleRewriter] — loads `assets/maps/style.json`, validates + swaps the
/// PMTiles placeholder for the resolved runtime URI.

@ProviderFor(styleRewriter)
final styleRewriterProvider = StyleRewriterProvider._();

/// [StyleRewriter] — loads `assets/maps/style.json`, validates + swaps the
/// PMTiles placeholder for the resolved runtime URI.

final class StyleRewriterProvider extends $FunctionalProvider<AsyncValue<StyleRewriter>, StyleRewriter, FutureOr<StyleRewriter>>
    with $FutureModifier<StyleRewriter>, $FutureProvider<StyleRewriter> {
  /// [StyleRewriter] — loads `assets/maps/style.json`, validates + swaps the
  /// PMTiles placeholder for the resolved runtime URI.
  StyleRewriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'styleRewriterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$styleRewriterHash();

  @$internal
  @override
  $FutureProviderElement<StyleRewriter> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<StyleRewriter> create(Ref ref) {
    return styleRewriter(ref);
  }
}

String _$styleRewriterHash() => r'16d32ddb9024e60da109b7d6018672d121272423';

/// Hand-rolled [DiskSpaceChecker] (Android `StatFs` + iOS
/// `FileManager.systemFreeSize` via platform channels). Process-wide
/// singleton — the underlying MethodChannel is stateless.

@ProviderFor(diskSpaceChecker)
final diskSpaceCheckerProvider = DiskSpaceCheckerProvider._();

/// Hand-rolled [DiskSpaceChecker] (Android `StatFs` + iOS
/// `FileManager.systemFreeSize` via platform channels). Process-wide
/// singleton — the underlying MethodChannel is stateless.

final class DiskSpaceCheckerProvider extends $FunctionalProvider<DiskSpaceChecker, DiskSpaceChecker, DiskSpaceChecker> with $Provider<DiskSpaceChecker> {
  /// Hand-rolled [DiskSpaceChecker] (Android `StatFs` + iOS
  /// `FileManager.systemFreeSize` via platform channels). Process-wide
  /// singleton — the underlying MethodChannel is stateless.
  DiskSpaceCheckerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diskSpaceCheckerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diskSpaceCheckerHash();

  @$internal
  @override
  $ProviderElement<DiskSpaceChecker> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  DiskSpaceChecker create(Ref ref) {
    return diskSpaceChecker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiskSpaceChecker value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<DiskSpaceChecker>(value));
  }
}

String _$diskSpaceCheckerHash() => r'534c7cc206ebc9b2b9da661b3364a6ae3e5d258c';

/// [IosBackupExcluder] — no-op on non-iOS; sets
/// `NSURLIsExcludedFromBackupKey` on iOS for per-country PMTiles files.

@ProviderFor(iosBackupExcluder)
final iosBackupExcluderProvider = IosBackupExcluderProvider._();

/// [IosBackupExcluder] — no-op on non-iOS; sets
/// `NSURLIsExcludedFromBackupKey` on iOS for per-country PMTiles files.

final class IosBackupExcluderProvider extends $FunctionalProvider<IosBackupExcluder, IosBackupExcluder, IosBackupExcluder> with $Provider<IosBackupExcluder> {
  /// [IosBackupExcluder] — no-op on non-iOS; sets
  /// `NSURLIsExcludedFromBackupKey` on iOS for per-country PMTiles files.
  IosBackupExcluderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'iosBackupExcluderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$iosBackupExcluderHash();

  @$internal
  @override
  $ProviderElement<IosBackupExcluder> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  IosBackupExcluder create(Ref ref) {
    return iosBackupExcluder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IosBackupExcluder value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<IosBackupExcluder>(value));
  }
}

String _$iosBackupExcluderHash() => r'48701b52ff139b008aca0ea7a4f58edededb8d06';

/// [FirstLaunchWorldCopier] — copies the bundled world PMTiles asset to
/// `<app_support>/maps/world.pmtiles` on first launch and auto-heals on
/// post-write sha256 mismatch. Consumed by [firstLaunchBootstrapProvider].

@ProviderFor(firstLaunchWorldCopier)
final firstLaunchWorldCopierProvider = FirstLaunchWorldCopierProvider._();

/// [FirstLaunchWorldCopier] — copies the bundled world PMTiles asset to
/// `<app_support>/maps/world.pmtiles` on first launch and auto-heals on
/// post-write sha256 mismatch. Consumed by [firstLaunchBootstrapProvider].

final class FirstLaunchWorldCopierProvider
    extends $FunctionalProvider<AsyncValue<FirstLaunchWorldCopier>, FirstLaunchWorldCopier, FutureOr<FirstLaunchWorldCopier>>
    with $FutureModifier<FirstLaunchWorldCopier>, $FutureProvider<FirstLaunchWorldCopier> {
  /// [FirstLaunchWorldCopier] — copies the bundled world PMTiles asset to
  /// `<app_support>/maps/world.pmtiles` on first launch and auto-heals on
  /// post-write sha256 mismatch. Consumed by [firstLaunchBootstrapProvider].
  FirstLaunchWorldCopierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstLaunchWorldCopierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstLaunchWorldCopierHash();

  @$internal
  @override
  $FutureProviderElement<FirstLaunchWorldCopier> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<FirstLaunchWorldCopier> create(Ref ref) {
    return firstLaunchWorldCopier(ref);
  }
}

String _$firstLaunchWorldCopierHash() => r'2c6dcfc8a745202d29dc9660a9a226f77ad4c7b1';

/// [HttpChunkDownloader] — pure dart:io `HttpClient` wrapper with Range
/// resume + 200-OK restart fallback + 302 redirect following.
///
/// `ref.onDispose` closes the underlying `HttpClient` so socket handles
/// are released cleanly at provider invalidation (e.g. app-level
/// re-bootstrap during development).

@ProviderFor(httpChunkDownloader)
final httpChunkDownloaderProvider = HttpChunkDownloaderProvider._();

/// [HttpChunkDownloader] — pure dart:io `HttpClient` wrapper with Range
/// resume + 200-OK restart fallback + 302 redirect following.
///
/// `ref.onDispose` closes the underlying `HttpClient` so socket handles
/// are released cleanly at provider invalidation (e.g. app-level
/// re-bootstrap during development).

final class HttpChunkDownloaderProvider extends $FunctionalProvider<HttpChunkDownloader, HttpChunkDownloader, HttpChunkDownloader>
    with $Provider<HttpChunkDownloader> {
  /// [HttpChunkDownloader] — pure dart:io `HttpClient` wrapper with Range
  /// resume + 200-OK restart fallback + 302 redirect following.
  ///
  /// `ref.onDispose` closes the underlying `HttpClient` so socket handles
  /// are released cleanly at provider invalidation (e.g. app-level
  /// re-bootstrap during development).
  HttpChunkDownloaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpChunkDownloaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpChunkDownloaderHash();

  @$internal
  @override
  $ProviderElement<HttpChunkDownloader> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  HttpChunkDownloader create(Ref ref) {
    return httpChunkDownloader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HttpChunkDownloader value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<HttpChunkDownloader>(value));
  }
}

String _$httpChunkDownloaderHash() => r'c1428b92161fb6d896123f8370244c2b4a2c804f';

/// [Sha256Verifier] — streaming sha256 over a [File] via `sha256.bind`.
/// Stateless; const-constructible.

@ProviderFor(sha256Verifier)
final sha256VerifierProvider = Sha256VerifierProvider._();

/// [Sha256Verifier] — streaming sha256 over a [File] via `sha256.bind`.
/// Stateless; const-constructible.

final class Sha256VerifierProvider extends $FunctionalProvider<Sha256Verifier, Sha256Verifier, Sha256Verifier> with $Provider<Sha256Verifier> {
  /// [Sha256Verifier] — streaming sha256 over a [File] via `sha256.bind`.
  /// Stateless; const-constructible.
  Sha256VerifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sha256VerifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sha256VerifierHash();

  @$internal
  @override
  $ProviderElement<Sha256Verifier> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  Sha256Verifier create(Ref ref) {
    return sha256Verifier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Sha256Verifier value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<Sha256Verifier>(value));
  }
}

String _$sha256VerifierHash() => r'3a6961df9dd9d010bfb8fb0316df537a33182a04';

/// [BinaryConcatenator] — streams N part files into a single destination
/// via `IOSink`. Stateless.

@ProviderFor(binaryConcatenator)
final binaryConcatenatorProvider = BinaryConcatenatorProvider._();

/// [BinaryConcatenator] — streams N part files into a single destination
/// via `IOSink`. Stateless.

final class BinaryConcatenatorProvider extends $FunctionalProvider<BinaryConcatenator, BinaryConcatenator, BinaryConcatenator>
    with $Provider<BinaryConcatenator> {
  /// [BinaryConcatenator] — streams N part files into a single destination
  /// via `IOSink`. Stateless.
  BinaryConcatenatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'binaryConcatenatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$binaryConcatenatorHash();

  @$internal
  @override
  $ProviderElement<BinaryConcatenator> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  BinaryConcatenator create(Ref ref) {
    return binaryConcatenator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BinaryConcatenator value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<BinaryConcatenator>(value));
  }
}

String _$binaryConcatenatorHash() => r'a04a485140685cf756cca3e1112795f27db7fb3e';

/// [AtomicRenamer] — `File.rename` with cross-volume `EXDEV`
/// copy+delete fallback. Stateless. The ctor takes a logger so it is
/// non-const; a single instance per process is enough.

@ProviderFor(atomicRenamer)
final atomicRenamerProvider = AtomicRenamerProvider._();

/// [AtomicRenamer] — `File.rename` with cross-volume `EXDEV`
/// copy+delete fallback. Stateless. The ctor takes a logger so it is
/// non-const; a single instance per process is enough.

final class AtomicRenamerProvider extends $FunctionalProvider<AtomicRenamer, AtomicRenamer, AtomicRenamer> with $Provider<AtomicRenamer> {
  /// [AtomicRenamer] — `File.rename` with cross-volume `EXDEV`
  /// copy+delete fallback. Stateless. The ctor takes a logger so it is
  /// non-const; a single instance per process is enough.
  AtomicRenamerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'atomicRenamerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$atomicRenamerHash();

  @$internal
  @override
  $ProviderElement<AtomicRenamer> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  AtomicRenamer create(Ref ref) {
    return atomicRenamer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AtomicRenamer value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<AtomicRenamer>(value));
  }
}

String _$atomicRenamerHash() => r'09eace52f7b27885efea2bebbc9cd127129bd8c3';

/// Persistent JSON-backed [DownloadQueueStore].

@ProviderFor(downloadQueueStore)
final downloadQueueStoreProvider = DownloadQueueStoreProvider._();

/// Persistent JSON-backed [DownloadQueueStore].

final class DownloadQueueStoreProvider extends $FunctionalProvider<AsyncValue<DownloadQueueStore>, DownloadQueueStore, FutureOr<DownloadQueueStore>>
    with $FutureModifier<DownloadQueueStore>, $FutureProvider<DownloadQueueStore> {
  /// Persistent JSON-backed [DownloadQueueStore].
  DownloadQueueStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadQueueStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadQueueStoreHash();

  @$internal
  @override
  $FutureProviderElement<DownloadQueueStore> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadQueueStore> create(Ref ref) {
    return downloadQueueStore(ref);
  }
}

String _$downloadQueueStoreHash() => r'dbc25867a00e58d83faaff43b514953dd3a27513';

/// [PmtilesDownloadController] — plain-Dart orchestrator for the 7-step
/// atomic download protocol. Wrapped in a Riverpod provider so the Plan
/// 07-05 `DownloadQueueController` (and the Plan 07-06 UI via that
/// wrapper) can reach it through `ref.watch`.
///
/// Lifetime: `ref.onDispose` calls `controller.dispose()` so the in-flight
/// HTTP request + the broadcast state stream get cleaned up at process
/// shutdown.

@ProviderFor(pmtilesDownloadController)
final pmtilesDownloadControllerProvider = PmtilesDownloadControllerProvider._();

/// [PmtilesDownloadController] — plain-Dart orchestrator for the 7-step
/// atomic download protocol. Wrapped in a Riverpod provider so the Plan
/// 07-05 `DownloadQueueController` (and the Plan 07-06 UI via that
/// wrapper) can reach it through `ref.watch`.
///
/// Lifetime: `ref.onDispose` calls `controller.dispose()` so the in-flight
/// HTTP request + the broadcast state stream get cleaned up at process
/// shutdown.

final class PmtilesDownloadControllerProvider
    extends $FunctionalProvider<AsyncValue<PmtilesDownloadController>, PmtilesDownloadController, FutureOr<PmtilesDownloadController>>
    with $FutureModifier<PmtilesDownloadController>, $FutureProvider<PmtilesDownloadController> {
  /// [PmtilesDownloadController] — plain-Dart orchestrator for the 7-step
  /// atomic download protocol. Wrapped in a Riverpod provider so the Plan
  /// 07-05 `DownloadQueueController` (and the Plan 07-06 UI via that
  /// wrapper) can reach it through `ref.watch`.
  ///
  /// Lifetime: `ref.onDispose` calls `controller.dispose()` so the in-flight
  /// HTTP request + the broadcast state stream get cleaned up at process
  /// shutdown.
  PmtilesDownloadControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pmtilesDownloadControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pmtilesDownloadControllerHash();

  @$internal
  @override
  $FutureProviderElement<PmtilesDownloadController> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<PmtilesDownloadController> create(Ref ref) {
    return pmtilesDownloadController(ref);
  }
}

String _$pmtilesDownloadControllerHash() => r'7ea4e0ba79af31c5daaf73e357066e9187b3d439';

/// [CountryDeleteService] — world-bundle-guarded per-country uninstall.

@ProviderFor(countryDeleteService)
final countryDeleteServiceProvider = CountryDeleteServiceProvider._();

/// [CountryDeleteService] — world-bundle-guarded per-country uninstall.

final class CountryDeleteServiceProvider extends $FunctionalProvider<AsyncValue<CountryDeleteService>, CountryDeleteService, FutureOr<CountryDeleteService>>
    with $FutureModifier<CountryDeleteService>, $FutureProvider<CountryDeleteService> {
  /// [CountryDeleteService] — world-bundle-guarded per-country uninstall.
  CountryDeleteServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countryDeleteServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countryDeleteServiceHash();

  @$internal
  @override
  $FutureProviderElement<CountryDeleteService> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<CountryDeleteService> create(Ref ref) {
    return countryDeleteService(ref);
  }
}

String _$countryDeleteServiceHash() => r'5049b16bcb8c0fb944d8506fd36e57c62309d03e';

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

@ProviderFor(firstLaunchBootstrap)
final firstLaunchBootstrapProvider = FirstLaunchBootstrapProvider._();

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

final class FirstLaunchBootstrapProvider extends $FunctionalProvider<AsyncValue<FirstLaunchBootstrap>, FirstLaunchBootstrap, FutureOr<FirstLaunchBootstrap>>
    with $FutureModifier<FirstLaunchBootstrap>, $FutureProvider<FirstLaunchBootstrap> {
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
  FirstLaunchBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstLaunchBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstLaunchBootstrapHash();

  @$internal
  @override
  $FutureProviderElement<FirstLaunchBootstrap> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<FirstLaunchBootstrap> create(Ref ref) {
    return firstLaunchBootstrap(ref);
  }
}

String _$firstLaunchBootstrapHash() => r'06b7e60c5e8738a2ee14c3805c318dc94fc3f1fc';

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

@ProviderFor(MapViewHolder)
final mapViewHolderProvider = MapViewHolderProvider._();

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
final class MapViewHolderProvider extends $NotifierProvider<MapViewHolder, MapView?> {
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
  MapViewHolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapViewHolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapViewHolderHash();

  @$internal
  @override
  MapViewHolder create() => MapViewHolder();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MapView? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<MapView?>(value));
  }
}

String _$mapViewHolderHash() => r'739d28b349134f824f98e79904c03ca479c78bca';

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

abstract class _$MapViewHolder extends $Notifier<MapView?> {
  MapView? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MapView?, MapView?>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<MapView?, MapView?>, MapView?, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

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

@ProviderFor(MapViewportZoom)
final mapViewportZoomProvider = MapViewportZoomProvider._();

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
final class MapViewportZoomProvider extends $NotifierProvider<MapViewportZoom, double?> {
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
  MapViewportZoomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapViewportZoomProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapViewportZoomHash();

  @$internal
  @override
  MapViewportZoom create() => MapViewportZoom();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<double?>(value));
  }
}

String _$mapViewportZoomHash() => r'bf741c02f1968e52657fc30a3631df2e22de2301';

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

abstract class _$MapViewportZoom extends $Notifier<double?> {
  double? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double?, double?>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<double?, double?>, double?, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
