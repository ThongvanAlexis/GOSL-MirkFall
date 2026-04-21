// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';

import '../../config/constants.dart';

/// Placeholder for the Phase 13 "importer un style de mirk" flow.
///
/// Phase 07 ships the entry point under Settings › Styles so the navigation
/// stack is already wired when Phase 13 lands the real import pipeline.
/// The placeholder surfaces a single line of explanatory copy + a back
/// button (default AppBar leading) so the user is never trapped on a dead
/// end.
class StyleImportPlaceholderScreen extends StatelessWidget {
  const StyleImportPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer un style de mirk')),
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
