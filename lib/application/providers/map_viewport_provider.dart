// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// TODO(09-05): rewrite as @Riverpod() generator target.
//
// Wave 0 emits this non-Riverpod stub so downstream scaffolds can
// reference `mapViewportProvider` as a compiling symbol. Plan 09-07 fills
// in the body — see S2 resolution in 09-RESEARCH for the source of the
// viewport bbox stream (MapView interface extension or throttled poll).

/// Provider stub — exposes the current map viewport bbox + zoom for the
/// mirk renderer paint context.
///
/// Plan 09-07 supplies the body.
void mapViewportProvider() => throw UnimplementedError('Wave 4 — plan 09-05');
