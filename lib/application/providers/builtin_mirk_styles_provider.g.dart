// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'builtin_mirk_styles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Surfaces the 4 built-in `MirkStyle` rows, lazy-seeding them into
/// `t_mirk_styles` on first read.
///
/// Behaviour:
/// 1. Reads the store via `ref.watch(mirkStyleStoreProvider)`.
/// 2. Loads the existing rows via `store.listAll()`.
/// 3. For each `kBuiltinMirkStyles` descriptor not yet present (id
///    match), constructs a `MirkStyle` entity with the deterministic id
///    + the descriptor's default config + a fixed creation timestamp,
///    inserts it, and adds it to the result list.
/// 4. Returns the final list of 4 builtins (all pre-existing or just
///    inserted).
///
/// Self-healing: if a builtin row was deleted out-of-band (manual SQL,
/// test setup, future user action), the next provider read re-inserts
/// it. Idempotent under repeated reads — invalidating + re-reading
/// never duplicates rows.
///
/// `keepAlive: true` because:
/// * The seed is a one-time effect; re-running it on widget-tree churn
///   wastes I/O.
/// * Downstream consumers (`activeMirkRendererProvider`, the burger
///   menu picker) read this provider repeatedly and expect a stable
///   list reference.
///
/// ## Why lazy here vs main.dart bootstrap?
///
/// Lazy seeding inside the provider keeps Phase 09 self-contained — no
/// `main.dart` edits, no FirstLaunchSeeder coupling. The trade-off is
/// that a consumer must read the provider to trigger the seed; plan
/// 09-07 (the picker sheet) is the natural first reader. Until then the
/// seed is dormant, which is fine because no Phase 09 path ALSO
/// dereferences the row directly via `store.findById`.
///
/// ## Seed timestamp
///
/// `createdAtUtc` uses the Phase 09 landing date (`2026-04-25`) at UTC
/// midnight, with offset 0. Stable across reproductions (no wall-clock
/// dependency), self-identifying in logs / SQL inspector — matches the
/// `cat_default` schema-sentinel pattern from `AppDatabase.onCreate`
/// (Phase 04 finding #2).

@ProviderFor(builtinMirkStyles)
final builtinMirkStylesProvider = BuiltinMirkStylesProvider._();

/// Surfaces the 4 built-in `MirkStyle` rows, lazy-seeding them into
/// `t_mirk_styles` on first read.
///
/// Behaviour:
/// 1. Reads the store via `ref.watch(mirkStyleStoreProvider)`.
/// 2. Loads the existing rows via `store.listAll()`.
/// 3. For each `kBuiltinMirkStyles` descriptor not yet present (id
///    match), constructs a `MirkStyle` entity with the deterministic id
///    + the descriptor's default config + a fixed creation timestamp,
///    inserts it, and adds it to the result list.
/// 4. Returns the final list of 4 builtins (all pre-existing or just
///    inserted).
///
/// Self-healing: if a builtin row was deleted out-of-band (manual SQL,
/// test setup, future user action), the next provider read re-inserts
/// it. Idempotent under repeated reads — invalidating + re-reading
/// never duplicates rows.
///
/// `keepAlive: true` because:
/// * The seed is a one-time effect; re-running it on widget-tree churn
///   wastes I/O.
/// * Downstream consumers (`activeMirkRendererProvider`, the burger
///   menu picker) read this provider repeatedly and expect a stable
///   list reference.
///
/// ## Why lazy here vs main.dart bootstrap?
///
/// Lazy seeding inside the provider keeps Phase 09 self-contained — no
/// `main.dart` edits, no FirstLaunchSeeder coupling. The trade-off is
/// that a consumer must read the provider to trigger the seed; plan
/// 09-07 (the picker sheet) is the natural first reader. Until then the
/// seed is dormant, which is fine because no Phase 09 path ALSO
/// dereferences the row directly via `store.findById`.
///
/// ## Seed timestamp
///
/// `createdAtUtc` uses the Phase 09 landing date (`2026-04-25`) at UTC
/// midnight, with offset 0. Stable across reproductions (no wall-clock
/// dependency), self-identifying in logs / SQL inspector — matches the
/// `cat_default` schema-sentinel pattern from `AppDatabase.onCreate`
/// (Phase 04 finding #2).

final class BuiltinMirkStylesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MirkStyle>>,
          List<MirkStyle>,
          FutureOr<List<MirkStyle>>
        >
    with $FutureModifier<List<MirkStyle>>, $FutureProvider<List<MirkStyle>> {
  /// Surfaces the 4 built-in `MirkStyle` rows, lazy-seeding them into
  /// `t_mirk_styles` on first read.
  ///
  /// Behaviour:
  /// 1. Reads the store via `ref.watch(mirkStyleStoreProvider)`.
  /// 2. Loads the existing rows via `store.listAll()`.
  /// 3. For each `kBuiltinMirkStyles` descriptor not yet present (id
  ///    match), constructs a `MirkStyle` entity with the deterministic id
  ///    + the descriptor's default config + a fixed creation timestamp,
  ///    inserts it, and adds it to the result list.
  /// 4. Returns the final list of 4 builtins (all pre-existing or just
  ///    inserted).
  ///
  /// Self-healing: if a builtin row was deleted out-of-band (manual SQL,
  /// test setup, future user action), the next provider read re-inserts
  /// it. Idempotent under repeated reads — invalidating + re-reading
  /// never duplicates rows.
  ///
  /// `keepAlive: true` because:
  /// * The seed is a one-time effect; re-running it on widget-tree churn
  ///   wastes I/O.
  /// * Downstream consumers (`activeMirkRendererProvider`, the burger
  ///   menu picker) read this provider repeatedly and expect a stable
  ///   list reference.
  ///
  /// ## Why lazy here vs main.dart bootstrap?
  ///
  /// Lazy seeding inside the provider keeps Phase 09 self-contained — no
  /// `main.dart` edits, no FirstLaunchSeeder coupling. The trade-off is
  /// that a consumer must read the provider to trigger the seed; plan
  /// 09-07 (the picker sheet) is the natural first reader. Until then the
  /// seed is dormant, which is fine because no Phase 09 path ALSO
  /// dereferences the row directly via `store.findById`.
  ///
  /// ## Seed timestamp
  ///
  /// `createdAtUtc` uses the Phase 09 landing date (`2026-04-25`) at UTC
  /// midnight, with offset 0. Stable across reproductions (no wall-clock
  /// dependency), self-identifying in logs / SQL inspector — matches the
  /// `cat_default` schema-sentinel pattern from `AppDatabase.onCreate`
  /// (Phase 04 finding #2).
  BuiltinMirkStylesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'builtinMirkStylesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$builtinMirkStylesHash();

  @$internal
  @override
  $FutureProviderElement<List<MirkStyle>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MirkStyle>> create(Ref ref) {
    return builtinMirkStyles(ref);
  }
}

String _$builtinMirkStylesHash() => r'82142db5ec4f5fcbfdda7ec9c6e584ab7538e0d7';
