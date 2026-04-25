# BUG-001 — No mirk visible during active session

**Status:** invalid (stale build — code never deployed)
**Reported:** 2026-04-25 (iOS sideloaded walk)
**Platform:** iOS (sideloaded, real device)
**Phase context:** Phase 09 (fog-rendering) just shipped — full pipeline supposed to be live.

## Comportement attendu

Au lancement de l'app et/ou au démarrage d'une session, l'utilisateur doit voir un overlay "brouillard de guerre" (mirk) recouvrant la zone non-révélée de la carte. Par défaut (session sans `mirkStyleId` défini), le fallback est `AtmosphericMirkRenderer` (Simplex noise displacement, MaskFilter.blur).

## Comportement observé

- Aucun overlay mirk visible.
- La carte (MapLibre tiles France PMTiles) s'affiche correctement.
- Le puck utilisateur est positionné correctement à (48.52851, 2.65507).
- Une session a bien été démarrée (`sess_01KQ24ZJW22NXGZZTEV6E42V5N`) puis arrêtée — durée ~70s, 1 fix émis, 1 rejeté (stationnaire).
- **Aucun log mirk** : zéro entrée pour `application.controllers.reveal_streaming_controller`, `infrastructure.mirk.*`, ou tout autre logger lié au pipeline mirk.

## Hypothèses

1. **MirkOverlay non monté dans MapScreen** — le widget n'est pas dans la `Stack` rendue par `map_screen.dart` (ou est monté dans une branche conditionnelle qui ne se déclenche pas).
2. **`activeMirkRendererProvider` retourne `NoopMirkRenderer`** — la chaîne `activeSessionControllerProvider → mirkStyleStoreProvider → mirkRendererFactoryProvider` short-circuit silencieusement avant d'atteindre le fallback `AtmosphericMirkRenderer`.
3. **`visibleMirkTilesProvider` retourne vide ET `MirkOverlay.paint()` short-circuit dessus** — erreur de design : un store vide devrait quand même peindre du fog plein-viewport (c'est tout l'intérêt d'un fog-of-war : opaque par défaut, on soustrait les cellules révélées).
4. **`mapViewportProvider` jamais alimenté** — si la viewport bbox est `null`, `MirkOverlay` n'a rien à projeter, donc paint vide.
5. **RepaintBoundary z-order incorrect** — l'overlay est rendu mais derrière les tiles MapLibre (impossible de voir).
6. **`MirkInitialRevealFade` opacity coincée à 0** — l'AnimationController n'a jamais démarré, le widget enfant est invisible.
7. **`RevealStreamingController.onFix` jamais appelé** — pas de logs reveal = pas de masques calculés = store vide. Mais ce n'est pas la cause du fog absent : le fog devrait être présent AVANT toute révélation.

## Diagnostic à mener

- Vérifier `lib/presentation/screens/map_screen.dart` (lignes ~279) : `MirkOverlay` est-il dans le `Widget tree` actif ? Sous quelle condition ?
- Vérifier `lib/presentation/widgets/mirk_overlay.dart` : que peint `paint()` quand `visibleTiles.isEmpty` ?
- Vérifier `lib/application/providers/active_mirk_renderer_provider.dart` : la cascade de fallback fonctionne-t-elle quand `activeSession.mirkStyleId == null` ?
- Vérifier `lib/application/providers/map_viewport_provider.dart` : la `MirkViewportBbox` est-elle alimentée par les events MapLibre ?
- Vérifier qu'il n'y a pas de log au niveau `MirkOverlay.paint()` ou `activeMirkRendererProvider` (devrait y en avoir au moins un INFO/FINE pour confirmer le mount).

## Logs pertinents

```
2026-04-25T13:04:19.634935  gps.stream  stream start · session=sess_01KQ24ZJW22NXGZZTEV6E42V5N
2026-04-25T13:04:19.651405  gps.stream  fix emitted #1 · lat=48.52851 lng=2.65507 ± 4.1m
2026-04-25T13:04:23.054173  infrastructure.map.maplibre  setUserLocation: puck source+layer INSTALLED
2026-04-25T13:04:27.430397  infrastructure.map.maplibre  showMap(fra): preserving camera
[ZÉRO log mirk pendant les 70 secondes de session]
2026-04-25T13:05:29.820176  gps.stream  stream cancel · received=2 emitted=1 droppedStationary=1
```

Note : `MissingPluginException` sur `iOS_significant_change_watchdog` est attendu (Phase 15) — non lié.

## Resolutions

**2026-04-25** — Faux positif. L'orchestrateur Phase 09 (moi) n'a pas push sur `origin/main` après la closure du phase. Le user a sideloadé un IPA généré sur un commit pré-Phase 09 (`9cd0a66 docs(08.1-05): complete fix-loop + closure plan`). 66 commits Phase 09 manquants sur le device.

**Action :** push effectué après détection. CI rebuild attendu. Re-test quand le nouvel IPA est dispo.

**Follow-up suggéré :** ajouter un print du commit SHA au démarrage du logger (suggestion utilisateur lors de cette walk) pour détecter ce type de drift visuellement dans les logs. À traiter dans une phase dédiée ou un quick.
