// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirk_style_picker_sheet.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves the current `mirkStyleId` for [sessionId] from the session
/// store. Used by [MirkStylePickerSheet] to render the trailing
/// checkmark on the active style — the `Tracking` state does not
/// carry the style id directly (it lives on the persisted `Session`
/// row, behind `SessionStore.findById`).

@ProviderFor(currentSessionMirkStyleId)
final currentSessionMirkStyleIdProvider = CurrentSessionMirkStyleIdFamily._();

/// Resolves the current `mirkStyleId` for [sessionId] from the session
/// store. Used by [MirkStylePickerSheet] to render the trailing
/// checkmark on the active style — the `Tracking` state does not
/// carry the style id directly (it lives on the persisted `Session`
/// row, behind `SessionStore.findById`).

final class CurrentSessionMirkStyleIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<MirkStyleId?>,
          MirkStyleId?,
          FutureOr<MirkStyleId?>
        >
    with $FutureModifier<MirkStyleId?>, $FutureProvider<MirkStyleId?> {
  /// Resolves the current `mirkStyleId` for [sessionId] from the session
  /// store. Used by [MirkStylePickerSheet] to render the trailing
  /// checkmark on the active style — the `Tracking` state does not
  /// carry the style id directly (it lives on the persisted `Session`
  /// row, behind `SessionStore.findById`).
  CurrentSessionMirkStyleIdProvider._({
    required CurrentSessionMirkStyleIdFamily super.from,
    required SessionId super.argument,
  }) : super(
         retry: null,
         name: r'currentSessionMirkStyleIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$currentSessionMirkStyleIdHash();

  @override
  String toString() {
    return r'currentSessionMirkStyleIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MirkStyleId?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MirkStyleId?> create(Ref ref) {
    final argument = this.argument as SessionId;
    return currentSessionMirkStyleId(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentSessionMirkStyleIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$currentSessionMirkStyleIdHash() =>
    r'2f3a48c0d39664379bbc838f68139d6f9aca7a64';

/// Resolves the current `mirkStyleId` for [sessionId] from the session
/// store. Used by [MirkStylePickerSheet] to render the trailing
/// checkmark on the active style — the `Tracking` state does not
/// carry the style id directly (it lives on the persisted `Session`
/// row, behind `SessionStore.findById`).

final class CurrentSessionMirkStyleIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MirkStyleId?>, SessionId> {
  CurrentSessionMirkStyleIdFamily._()
    : super(
        retry: null,
        name: r'currentSessionMirkStyleIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves the current `mirkStyleId` for [sessionId] from the session
  /// store. Used by [MirkStylePickerSheet] to render the trailing
  /// checkmark on the active style — the `Tracking` state does not
  /// carry the style id directly (it lives on the persisted `Session`
  /// row, behind `SessionStore.findById`).

  CurrentSessionMirkStyleIdProvider call(SessionId sessionId) =>
      CurrentSessionMirkStyleIdProvider._(argument: sessionId, from: this);

  @override
  String toString() => r'currentSessionMirkStyleIdProvider';
}
