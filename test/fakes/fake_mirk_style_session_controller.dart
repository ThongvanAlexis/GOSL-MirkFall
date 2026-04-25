// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Observable fake for the Phase 09 `MirkStyleSessionController` (plan
/// 09-07). Lets the burger-menu widget suite assert that user style
/// picks invoke the controller with the right session id + style id,
/// without persisting through Drift.
///
/// Wave 0 keeps the surface dependency-free — does NOT
/// `implements MirkStyleSessionController` because that class lands in
/// plan 09-07. Wave 6 extends this fake to implement the real
/// controller surface so the type system enforces conformance.
///
/// Records use plain `String` for session + style ids rather than
/// `SessionId` / `MirkStyleId` extension types so this file can
/// compile in Wave 0 without dragging in
/// `lib/domain/ids/*` or the Wave 2 Freezed style schema.
class FakeMirkStyleSessionController {
  /// Every (sessionId, styleId) tuple passed to [select], in call order.
  /// Tests assert exact list contents (no count-only expects — the
  /// argument fidelity matters more than the count).
  final List<({String sessionId, String styleId})> selectCalls = <({String sessionId, String styleId})>[];

  /// When `true`, the next call to [select] throws [StateError]. Used
  /// by error-path tests (e.g. unknown style id surfaced by the
  /// burger menu).
  bool throwOnNextCall = false;

  /// Resets the recorded select calls. Helpful between sub-cases in a
  /// single test that wants to share the fake instance.
  void reset() {
    selectCalls.clear();
    throwOnNextCall = false;
  }

  /// Records a style selection. Returns immediately (sync surface in
  /// Wave 0; Wave 6 may flip to `Future<void>` if persistence becomes
  /// async — fakes track the real surface as it lands).
  void select({required String sessionId, required String styleId}) {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeMirkStyleSessionController.select forced throw');
    }
    selectCalls.add((sessionId: sessionId, styleId: styleId));
  }
}
