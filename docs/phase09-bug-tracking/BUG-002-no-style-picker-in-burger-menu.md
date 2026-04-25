# BUG-002 — Pas d'option "choix de style mirk" dans le burger menu

**Status:** invalid (stale build — code never deployed)
**Reported:** 2026-04-25 (iOS sideloaded walk)
**Platform:** iOS (sideloaded, real device)
**Phase context:** Phase 09 plan 09-07 a livré `MirkStylePickerSheet` + une "burger menu wire-up". L'utilisateur ne voit aucune option pour ouvrir cette feuille.

## Comportement attendu

Le burger menu (probablement celui du `SessionDetailScreen` ou du `MapScreen` — à vérifier) doit contenir une entrée "Style de brouillard" (ou équivalent) qui ouvre `MirkStylePickerSheet`. La feuille liste les 4 builtins (atmospheric, solid, candlelight, heavenly clouds) et persiste le choix via `MirkStyleSessionController.select()`.

## Comportement observé

- Le burger menu s'ouvre normalement.
- Aucune option visible permettant de choisir un style mirk.
- L'utilisateur a navigué dans le menu sans trouver de point d'entrée vers `MirkStylePickerSheet`.

## Hypothèses

1. **Mauvais burger menu wiré** — Plan 09-07 a peut-être ajouté l'item au `SessionBurgerMenu` du `MapScreen`, alors que l'utilisateur regarde celui du `SessionDetailScreen` (les logs montrent du trafic dans `_SessionDetailScreenState`).
2. **Item conditionnellement caché** — l'option n'est rendue que si une session est active / si des styles sont chargés / si `builtinMirkStylesProvider` a fini de seed-er.
3. **Feature flag ou import_styles requirement** — l'option attend que `mirkStyleStoreProvider` ait au moins une entrée, mais le seeding idempotent a échoué silencieusement.
4. **L'item a été ajouté à un mauvais endroit du widget tree** — par exemple dans une `Column` de la home page jamais affichée.
5. **Plan 09-07 a wiré uniquement la mécanique d'ouverture mais pas le `ListTile` / l'item visible** — la commit `bfcfe2c` dit "burger menu wire-up" mais peut-être que ça concerne uniquement le `onTap` callback.

## Diagnostic à mener

- Inspecter `lib/presentation/widgets/session_burger_menu.dart` : la liste d'items contient-elle un trigger `MirkStylePickerSheet` ?
- Inspecter le `SessionBurgerMenu` utilisé dans `MapScreen` vs `SessionDetailScreen` — sont-ils différents ?
- Vérifier où est appelé `MirkStylePickerSheet.show()` ou équivalent (`Grep "MirkStylePickerSheet"`).
- Vérifier `builtinMirkStylesProvider` log : seeding effectué ? Combien d'entrées dans `mirkStyleStoreProvider` au moment où le menu s'ouvre ?

## Resolutions

**2026-04-25** — Faux positif. Même cause que BUG-001 : Phase 09 jamais poussée sur `origin/main` après closure, l'IPA sideloadé est un build pré-Phase-09 sans le code de plan 09-07 (qui contient le wire-up burger menu → MirkStylePickerSheet, commit `bfcfe2c`).

**Action :** push effectué. Re-test après CI rebuild.
