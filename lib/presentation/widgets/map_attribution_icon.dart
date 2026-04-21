// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';

import 'attribution_link_handler.dart';

/// Small circular icon rendered bottom-right on the MapScreen that opens
/// an attribution bottom sheet listing the OSM + Protomaps copyright
/// lines (MAP-03).
///
/// The MapLibre default attribution button is hidden off-screen at the
/// adapter level (`attributionButtonMargins` — see
/// `lib/infrastructure/map/maplibre_map_view.dart`); this widget is the
/// MirkFall-branded replacement that carries the same legal surface
/// without MapLibre's fixed styling.
///
/// Link-handling strategy: copy-to-clipboard + snackbar. Rationale in
/// `attribution_link_handler.dart` — Phase 07 refuses to pull
/// `url_launcher` under the GOSL audit rule, and the clipboard idiom
/// degrades gracefully on platforms that may sandbox browser launches.
class MapAttributionIcon extends StatelessWidget {
  const MapAttributionIcon({super.key});

  static const double _kIconDiameter = 32.0;
  static const double _kBackgroundOpacity = 0.8;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openAttributionSheet(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: _kIconDiameter,
          height: _kIconDiameter,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: _kBackgroundOpacity),
            shape: BoxShape.circle,
            border: Border.all(color: cs.outline.withValues(alpha: _kBackgroundOpacity)),
          ),
          child: Icon(Icons.info_outline, size: 20.0, color: cs.onSurface),
        ),
      ),
    );
  }

  void _openAttributionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Attribution', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 12.0),
                TextButton(onPressed: () => openAttributionLink(sheetContext, kOpenStreetMapCopyrightUrl), child: const Text('© OpenStreetMap contributors')),
                TextButton(onPressed: () => openAttributionLink(sheetContext, kProtomapsUrl), child: const Text('© Protomaps')),
                const SizedBox(height: 8.0),
                Text('Les liens ouvrent le presse-papier; colle dans ton navigateur.', style: Theme.of(sheetContext).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
