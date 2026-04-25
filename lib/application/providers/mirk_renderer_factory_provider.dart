// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/infrastructure/mirk/mirk_renderer_factory.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mirk_renderer_factory_provider.g.dart';

/// Production [MirkRendererFactory] — pure singleton (no DB / no IO).
///
/// `keepAlive: true` matches the rest of the Phase 03/05 provider
/// graph: the factory has zero state and replacing it on widget-tree
/// changes would needlessly churn `activeMirkRendererProvider` (which
/// watches it). Tests override with a stub by passing
/// `mirkRendererFactoryProvider.overrideWithValue(otherFactory)`.
@Riverpod(keepAlive: true)
MirkRendererFactory mirkRendererFactory(Ref ref) => const MirkRendererFactory();
