# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-17)

**Core value:** Ne jamais perdre sa progression — import/export JSON versionné durable entre instances.
**Current focus:** Phase 01 — Foundation (pas encore commencée)

## Current Position

Phase: 01 of 16 (Foundation)
Plan: — of — in current phase (plans non encore détaillés)
Status: Ready to plan
Last activity: 2026-04-17 — Roadmap créé par gsd-roadmapper, 86/86 requirements mappés, 8 code phases + 8 review gates

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 h

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| — | — | — | — |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions carried from research (2026-04-17) :

- Phase 03: Revealed area = zoom-14 parent tiles + 64×64 sub-tile bitmaps (D3)
- Phase 03: Single Drift DB pour toute donnée structurée (D4)
- Phase 03: Envelope JSON `{schemaVersion, type, payload}` pour import/export (D9)
- Phase 05: Pas de `flutter_background_geolocation` — clé de licence payante incompatible GOSL ; geolocator + foreground service Android + iOS background mode à la place
- Phase 05: Exclusivité session enforced par partial unique index Drift, pas par discipline caller (D13)
- Phase 07: `TileSource` seam — V1.0 online OSM, V1.1 MBTiles offline en pur ajout (D7)
- Phase 09: `MirkRenderer` seam — expose uniquement `paint(Canvas, Size, MirkPaintContext)`, aucun détail d'implémentation (D6)
- Project-wide: Riverpod comme unique state management + DI (D5)

### Pending Todos

None yet.

### Blockers/Concerns

**Phase 05 (POC GPS background):** Risque #1 projet. Si la validation background sur OEM Android ou iOS échoue, toute la V1.0 est remise en question. Doit être validé avant d'investir dans Map/Fog/Markers.

**Phase 05 (store policy):** Les strings de justification "Always" location doivent être rédigées humainement pour résister à une revue App Store / Play Store. Texte finalisé en Phase 15.

**Phase 09 (fog perf):** Sub-tile grid size (32/64/128) et batch-flush interval à profiler sur fixture 50k-tiles avant de finaliser les constantes.

**Phase 11 (EXIF strip):** `image_picker` ne strippe pas EXIF nativement ; approche lightweight à évaluer en début de Phase 11.

**Phase 13 (ZIP archive format):** Format ZIP final (.mirkfall extension, layout manifest/photos/) à confirmer au démarrage de la phase ; audit licence du package `archive` à documenter dans DEPENDENCIES.md (O11).

## Session Continuity

Last session: 2026-04-17 — roadmapping
Stopped at: ROADMAP.md + STATE.md écrits, REQUIREMENTS.md traceability mise à jour
Resume file: None (prochaine commande : `/gsd:plan-phase 1`)
