// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// TODO(09-05): rewrite as @Riverpod() generator target.
//
// Wave 0 emits this non-Riverpod stub so downstream scaffolds can
// reference `visibleMirkTilesProvider` as a compiling symbol. Plan 09-07
// fills in the body — the provider derives `List<VisibleMirkTile>` from
// the current viewport bbox + the RevealedTileStore.

/// Provider stub — exposes the parent tiles currently visible in the
/// viewport, pre-projected for the renderer.
///
/// Plan 09-07 supplies the body.
void visibleMirkTilesProvider() => throw UnimplementedError('Wave 4 — plan 09-05');
