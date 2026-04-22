# Phase 07 — Crash iOS sur `animateCamera` post-`onStyleLoaded`

_Document d'enquête. Rédigé 2026-04-22 pendant le device-smoke Phase 07-07._

## TL;DR

Sideload sur iPhone 17 Pro / iOS 26.3.1, ouverture de la carte depuis le
détail d'une session active → SIGABRT reproducible à 100 %.
Le backtrace natif (.ips) pointe invariablement sur la même
chaîne d'exception C++ dans `MapLibre.framework`, déclenchée au retour
d'un `invokeMethod` vers le plugin `maplibre_gl` 0.25.0.

Bisection terminée sur les 3 method-channel calls déclenchés par
`MapCameraController.openForSession` juste après `onStyleLoadedCallback` :

| Probe | Call unique laissé actif          | Résultat  |
|-------|-----------------------------------|-----------|
| 1     | `setUserLocation` → `addCircle`   | No crash  |
| 2     | `moveCameraTo` → `animateCamera`  | **Crash** |
| 3     | `setFollowMeEnabled`              | Non testé |

**Diagnostic partiel** : `animateCamera`, appelé dans la fenêtre temporelle
qui suit immédiatement `onStyleLoadedCallback`, traverse un code path C++
natif qui throw une exception non-catchée.

**Diagnostic non-final** : on ne sait PAS pourquoi cet `animateCamera`
précis échoue là. `animateCamera` en soi n'est pas cassé (API utilisée
partout). C'est l'interaction avec l'état interne du MLNMapView juste
après le style-load qui pose problème.

## Stack .ips (identique entre tous les crashs)

Fichiers : `Runner-2026-04-22-092721.ips`, `095930.ips`, `113807.ips`,
`122719.ips`.

```
 0  libsystem_kernel.dylib    __pthread_kill
 1  libsystem_pthread.dylib   pthread_kill
 2  libsystem_c.dylib         abort
 3  libc++abi.dylib           __abort_message
 4  libc++abi.dylib           demangling_terminate_handler()
 5  libobjc.A.dylib           _objc_terminate()
 6  libc++abi.dylib           std::__terminate(void (*)())
 7  libc++abi.dylib           __cxxabiv1::failed_throw(...)
 8  libc++abi.dylib           __cxa_throw
 9  MapLibre                  off=104588    (unsymbolicated)
10  MapLibre                  off=1835160   (unsymbolicated)
11  MapLibre                  off=1810356   (unsymbolicated)
12  MapLibre                  off=1792800   (unsymbolicated)
13  MapLibre                  off=725176    (unsymbolicated)
14  maplibre_gl               MapLibreMapController.onMethodCall +18872
15  maplibre_gl               closure in init(withFrame:...)
16+ Flutter / libdispatch / UIKit / CoreFoundation …
```

Signal : `EXC_CRASH / SIGABRT`. Exception : C++ (`__cxa_throw`) non-catchée
→ `std::terminate` → `abort`.

Les 5 frames MapLibre sont à des offsets très différents (104k, 1835k,
1810k, 1792k, 725k) — ce NE sont PAS 5 frames consécutives d'une même
fonction. Elles traversent plusieurs régions du binaire. Sans dSYM, on
ne peut pas les nommer.

## Environnement

- **Device** : iPhone 17 Pro, iOS 26.3.1 (build 23D771330a)
- **App** : MirkFall, bundle `app.gosl.mirkfall.5WY2W4L3PX`, sideload via iLoader
- **Plugin Flutter** : `maplibre_gl 0.25.0` (pinned)
- **SDK natif** : MapLibre Native iOS 6.14.0 (bundled par le plugin)
- **Scénario** : session active déjà lancée + "Ouvrir la carte" depuis le
  détail de session

## Hypothèses testées et invalidées

1. **Sideloaded apps exclus de `ReportCrash`** → FAUX. `idevicecrashreport`
   via libimobiledevice récupère bien les `.ips`. (Commit des
   CrashReporter natifs en signal-handler révertés dans `b550a49`.)
2. **iOS 26 a durci NSExpression (`mgl_does:have:`)** → extrapolation non
   prouvée. Le log syslog `NSPredicate: Use of 'mgl_does:have:'` existe
   depuis iOS 15.5, c'est du bruit de log, pas le crash fatal. Le
   backtrace .ips ne passe pas du tout par NSPredicate.
3. **Le `user_location` style layer avec `source-layer` manquant** →
   innocent. Retiré de `style.json` (code mort : le puck utilise
   `addCircle` via l'annotation manager, pas ce layer), mais le crash
   persistait quand même → ce n'était pas le trigger. Layer laissé
   retiré (dead code cleanup).
4. **PR #719 / `onStyleLoadedCallback` synchrone sur les CircleManagers
   non wirés** → partiellement invalidé. PR #719 aide pour les race
   conditions post-style-load, mais notre crash ne vient pas de l'annotation
   manager (Probe 1 a passé). Cela reste plausible comme mécanisme
   _général_ pour d'autres parts du plugin qui ne sont pas encore prêtes
   quand `onStyleLoadedCallback` fire — à garder en tête mais ce n'est
   plus suffisant à lui seul.
5. **Future.delayed(Duration.zero) suffirait à défèrer au-delà de la
   race** → FAUX. Ajouté dans `096b5f8`, le crash persistait tel quel.

## Ce qu'on a shipé (état au 2026-04-22)

### Tentative 1 — `jumpCameraTo` (commit `3b23c8d`) — **KO**

Workaround `jumpCameraTo` : port method `MapView.jumpCameraTo` qui route
vers le plugin `moveCamera` (no animator). Sideload : crash identique.
Nouvelle .ips (`Runner-2026-04-22-125955.ips`) :

- Frame 14 `imageOffset` changé : `79024` → `77368`. **Différent case**
  dans le switch Swift `onMethodCall` : le plugin a bien routé le nouveau
  Dart method vers un case différent.
- Frames 9-13 dans `MapLibre.framework` : **offsets rigoureusement
  identiques** (104588, 1835160, 1810356, 1792800, 725176).

Finding crucial : **deux entry points Dart différents, deux cases Swift
différents, MÊME code path C++ natif qui throw**. La conclusion "animateCamera
est le coupable" était faux diagnostic — c'est N'IMPORTE QUEL camera-op
dans cette fenêtre, pas spécifiquement l'animator.

### Tentative 2 — `initialCameraPosition` widget + pas de camera move dans openForSession (en cours)

Approche : supplier la position initiale via `MapLibreMap.initialCameraPosition`
au build du widget (lu depuis l'active session `lastFix`). Aucun
method-channel call touchant la caméra n'est émis post-style-load.
`openForSession` ne fait plus que : setUserLocation (innocent, prouvé
par Probe 1), setFollowMeEnabled, transition d'état.

**Question ouverte** (soulignée par le user) : les fix GPS subséquents
arrivent via `_onFix` → `_moveCameraTo` → `animateCamera`. Si le crash
n'est PAS fenêtre-spécifique mais lié à N'IMPORTE QUEL camera-op avec
notre config (style/source/tiles), le premier fix GPS après ouverture
de la carte re-crashera. Le prochain device-smoke tranchera.

## Questions restantes (pour le vrai diag)

1. **Que fait MapLibre à l'offset `+104588`** (frame 9, où l'exception est
   throwed) ? Nécessite le `MapLibre.framework.dSYM` — pas actuellement
   exporté par la CI Flutter. Option : ajouter un step artifact upload
   pour le dSYM dans `.github/workflows/ci.yml`.

2. **Quel case dans `MapLibreMapController.onMethodCall` correspond à
   l'offset `+18872`** ? Le method-channel case `"animateCamera"` de la
   source 0.25.0 se trouve dans `maplibre_gl/ios/maplibre_gl/Sources/maplibre_gl/MapLibreMapController.swift`.
   Compter les cases et estimer la taille de chaque bloc donnerait la
   confirmation. Déjà indirectement confirmé par la bisection mais à
   faire pour l'exactitude.

3. **Est-ce un bug connu du plugin / upstream** ? Le mini-reproducer
   (app Flutter vide + `animateCamera` dans `onStyleLoadedCallback` sur
   iOS 26.3.1) trancherait. Si reproductible sur l'example app officielle
   du plugin → ouvrir issue sur `maplibre/flutter-maplibre-gl` (séparée de
   #717, plus spécifique).

4. **Une `CameraPosition` avec un zoom particulier (`kInitialSessionMapZoom`)
   change-t-il quelque chose** ? Notre zoom initial c'est la constante
   `kInitialSessionMapZoom`. Tester avec une valeur banale (zoom 10) pour
   éliminer un edge case de valeur.

5. **`animateCamera` callé APRÈS un vrai `addCircle` aurait-il le même
   comportement** ? On a testé "addCircle seul = pas de crash". Mais
   "addCircle puis animateCamera" (l'ordre original) n'a pas été testé
   en isolation — on a seulement testé "tout désactivé sauf l'un ou
   l'autre". Pas critique mais documenter.

## Fichiers touchés pendant l'enquête

- `assets/maps/style.json` — `user_location` layer retiré (probe
  initial, layer dead code)
- `lib/infrastructure/map/style_layer_order.dart` — frozen order 8→7
- `lib/domain/map/map_view.dart` — ajout port `jumpCameraTo`
- `lib/infrastructure/map/maplibre_map_view.dart` — adapter `jumpCameraTo`
  → `moveCamera`
- `lib/application/controllers/map_camera_controller.dart` —
  `openForSession` utilise `jumpCameraTo` pour le positionnement initial
- `test/fakes/fake_map_view.dart` — implémente `jumpCameraTo`
- `test/application/controllers/map_camera_controller_test.dart` — tests
- `test/presentation/screens/map_screen_test.dart` — tests
- `test/infrastructure/map/style_layer_order_test.dart` — 8→7
- `test/presentation/map_style_layer_order_test.dart` — 8→7

## Commits clés

- `b550a49` — Revert des 4 commits CrashReporter iOS (prémisse fausse)
- `096b5f8` — Tentative `Future.delayed(Duration.zero)` dans `_onMapReady`
  (insuffisant — gardé car inoffensif)
- `f20c1bb` / `aa7dad6` — Probe A : retire `user_location` layer + désactive
  `openForSession` → no crash. Probe B : réactive `openForSession` seul →
  crash revient, donc layer innocent, openForSession coupable.
- `9bfe4a1` / `604988f` — Probes bisection 1 et 2 sur les 3 calls de
  `openForSession` → `animateCamera` isolé comme trigger.
- `3b23c8d` — Workaround `jumpCameraTo`. **État actuel de `main`.**

## Décisions prises / à revoir

- **Dropped** : ajout d'un `NSSetUncaughtExceptionHandler` + signal
  handlers natifs. `idevicecrashreport` fait le même job en plus clean.
- **Gardé** : `user_location` style layer retiré (dead code, rien à perdre).
- **Gardé temporairement** : workaround `jumpCameraTo`. À retirer / réécrire
  en vrai fix une fois qu'on a décodé les offsets MapLibre ou ouvert un
  issue upstream.
- **À trancher** : upgrader `maplibre_gl` à une build de `release-0.26.0`
  (en violant CLAUDE.md §Pin des versions avec un `git:` ref commit-pinned)
  vs attendre la release officielle pub.dev.

## Outils d'enquête utilisés

- **`idevicesyslog` / `idevicecrashreport`** (libimobiledevice via MSYS2
  sur Windows) — récupère les `.ips` et les flux de logs iOS live sans Mac.
  Setup dans `DEV_COMMANDS.md` (fichier perso non-commité).
- **Python + `json` stdlib** pour décoder les frames et mapper
  `imageIndex` → binary name.
- **`gh` CLI** pour inspecter les issues/PRs upstream
  (`maplibre/flutter-maplibre-gl` #710 #717 #719, `maplibre/maplibre-native`
  #331 #411).
