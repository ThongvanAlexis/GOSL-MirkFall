// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_generator_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [IdGenerator] — [`RandomIdGenerator`] backed by
/// `Random.secure()` (safe across trust boundaries).
///
/// Tests override with `SeededIdGenerator(seed: ...)` via
/// `ProviderContainer(overrides: [idGeneratorProvider.overrideWith(...)])`
/// to get deterministic id sequences. Phase 03 unit tests build stores
/// directly (bypassing the provider graph) — provider overrides are
/// exercised in widget tests from Phase 07 onward.

@ProviderFor(idGenerator)
final idGeneratorProvider = IdGeneratorProvider._();

/// Production [IdGenerator] — [`RandomIdGenerator`] backed by
/// `Random.secure()` (safe across trust boundaries).
///
/// Tests override with `SeededIdGenerator(seed: ...)` via
/// `ProviderContainer(overrides: [idGeneratorProvider.overrideWith(...)])`
/// to get deterministic id sequences. Phase 03 unit tests build stores
/// directly (bypassing the provider graph) — provider overrides are
/// exercised in widget tests from Phase 07 onward.

final class IdGeneratorProvider extends $FunctionalProvider<IdGenerator, IdGenerator, IdGenerator> with $Provider<IdGenerator> {
  /// Production [IdGenerator] — [`RandomIdGenerator`] backed by
  /// `Random.secure()` (safe across trust boundaries).
  ///
  /// Tests override with `SeededIdGenerator(seed: ...)` via
  /// `ProviderContainer(overrides: [idGeneratorProvider.overrideWith(...)])`
  /// to get deterministic id sequences. Phase 03 unit tests build stores
  /// directly (bypassing the provider graph) — provider overrides are
  /// exercised in widget tests from Phase 07 onward.
  IdGeneratorProvider._()
    : super(from: null, argument: null, retry: null, name: r'idGeneratorProvider', isAutoDispose: false, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$idGeneratorHash();

  @$internal
  @override
  $ProviderElement<IdGenerator> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  IdGenerator create(Ref ref) {
    return idGenerator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdGenerator value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<IdGenerator>(value));
  }
}

String _$idGeneratorHash() => r'33d878f6e343af1c672e0184b3b113cc4ea75cb3';
