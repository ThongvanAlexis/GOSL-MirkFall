// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/infrastructure/ids/random_id_generator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'id_generator_provider.g.dart';

/// Production [IdGenerator] — [`RandomIdGenerator`] backed by
/// `Random.secure()` (safe across trust boundaries).
///
/// Tests override with `SeededIdGenerator(seed: ...)` via
/// `ProviderContainer(overrides: [idGeneratorProvider.overrideWith(...)])`
/// to get deterministic id sequences. Phase 03 unit tests build stores
/// directly (bypassing the provider graph) — provider overrides are
/// exercised in widget tests from Phase 07 onward.
@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => RandomIdGenerator();
