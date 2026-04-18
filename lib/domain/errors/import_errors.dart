// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Thrown by the import pipeline when a payload fails validation
/// before any DB write (PORT-09 — tout-ou-rien).
///
/// `reason` is the user-facing message ("Format de date invalide à la
/// ligne 12"); callers surface it directly in the import-result toast.
class ImportValidationException implements Exception {
  const ImportValidationException({required this.reason});

  final String reason;

  @override
  String toString() => 'ImportValidationException(reason=$reason)';
}
