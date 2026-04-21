// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';

import '../../config/constants.dart';

/// Placeholder for the Phase 13 "exporter un style de mirk" flow.
///
/// Mirror of [StyleImportPlaceholderScreen] — same reasoning : pre-wire the
/// Settings › Styles navigation stack so Phase 13 lands the export pipeline
/// without touching routing.
class StyleExportPlaceholderScreen extends StatelessWidget {
  const StyleExportPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exporter un style de mirk')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(kScreenBodyPaddingLogicalPx),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.construction_outlined, size: 48.0),
              SizedBox(height: 16.0),
              Text(
                'En construction — disponible en Phase 13',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
