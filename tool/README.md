# tool/

Developer tooling for the MirkFall project. Scripts here are **not shipped in
the app binary** — they support development, CI gates, and manual POC / debug
workflows.

Contents live in two sections:

1. **Dart tooling** (`*.dart`) — runs via `dart run tool/<script>.dart`. Uses
   dependencies already declared in `pubspec.yaml` (under `dev_dependencies`
   or main deps). Unit tests in `tool/test/` run via `dart test tool/test/`.
2. **Python tooling (Phase 05)** — standalone `python` scripts. Dependencies
   pinned in `tool/requirements.txt`. See §Python tooling below.

---

## Dart tooling

### `check_headers.dart`

Scans `lib/**/*.dart` + `test/**/*.dart` for the mandatory GOSL v1.0 header
(`CLAUDE.md` §Rappel final). Exits 1 on any file missing the 3-line block.

### `check_licenses.dart`

Parses `pubspec.lock` + `pub` cache to verify every direct and transitive
dependency licence is on the allowlist (MIT / BSD / Apache-2.0 / Unlicense /
CC0 / ISC / zlib). Rejects GPL / AGPL / any copyleft-strong license.

### `check_dependencies_md.dart`

Cross-checks `DEPENDENCIES.md` against `pubspec.lock` — every direct
dependency must have a documented audit row.

### `check_domain_purity.dart`

Scans `lib/domain/` for forbidden imports (`package:flutter/*`,
`package:drift/*`, etc.). Keeps the domain layer testable under pure
`dart test`.

### `walk_db.dart`

Phase 04 smoke-test driver: opens `<app_support>/mirkfall.db`, runs a
sequence of store operations (create session / insert marker / flip active
flag / etc.) so a human can inspect the DB afterwards via `inspect_db.sql`.
Reruns cleanly on repeated invocations.

### `inspect_db.sql`

Canned sqlite3 query script for the DB produced by `walk_db.dart`. Works
under `sqlite3.exe mirkfall.db < tool/inspect_db.sql` on Windows/POSIX.

---

## Python tooling (Phase 05)

### `plot_session_fixes.py`

Renders a MirkFall session's `t_fixes` trajectory on an OSM static-map PNG.
Used by the Phase 05 POC walks (QUAL-01 / QUAL-02) to produce the visual
evidence committed to `docs/poc-artifacts/`.

**Inputs:**

| Arg              | Required | Default                                               |
| ---------------- | -------- | ----------------------------------------------------- |
| `--db`           | yes      | —                                                     |
| `--session-id`   | yes      | —                                                     |
| `--out`          | no       | `docs/poc-artifacts/<session-id>-<timestamp>.png`     |
| `--zoom`         | no       | auto-fit to bounding box                              |
| `--width`        | no       | 1600                                                  |
| `--height`       | no       | 1200                                                  |

**Outputs:**

- A PNG file at `--out` (or the default path).
- Stats printed to stdout: row count / duration / interval min/median/max /
  bounding box. These fields populate `docs/qual-01-02-poc.md` per POC
  entry.

### Install

Windows dev host (CLAUDE.md convention: use `python`, not `python3`):

```
python -m venv tool/.venv
tool/.venv/Scripts/activate
pip install -r tool/requirements.txt
python tool/plot_session_fixes.py --help
```

POSIX:

```
python -m venv tool/.venv
source tool/.venv/bin/activate
pip install -r tool/requirements.txt
python tool/plot_session_fixes.py --help
```

### Example invocation (Android POC)

```
adb pull /data/user/0/app.gosl.mirkfall/app_flutter/mirkfall.db poc-pixel-4a.db
python tool/plot_session_fixes.py --db poc-pixel-4a.db --session-id sess_01HV7PZXABCDEF
```

### Licences (Python deps)

Entries below are tool-only — these packages do NOT ship in the app binary,
so `DEPENDENCIES.md` (scoped to binary-shipped Dart deps) does not carry
them. They still must be allowlist-compatible per `CLAUDE.md` §Licences
acceptées.

| Package     | Version  | Licence                | Audit date   | Notes                                                    |
| ----------- | -------- | ---------------------- | ------------ | -------------------------------------------------------- |
| `staticmap` | 0.5.7    | MIT                    | 2026-04-19   | Pure Python + Pillow. No network telemetry.              |
| `Pillow`    | 12.2.0   | HPND (MIT-equivalent)  | 2026-04-19   | Transitively required by `staticmap` for image encoding. Pinned to 12.2.0 — 11.0.0 lacks Python 3.14 wheels on Windows. |

**HPND** (Historical Permission Notice and Disclaimer) is the original
Python Imaging Library licence. The SPDX registry flags it as
MIT-equivalent (permissive, no copyleft, no patent clauses). Acceptable
for tool-only usage under GOSL v1.0.

No analytics / crash reporting / network telemetry introduced by either
package. Both are well-established (`Pillow` is the canonical Python image
library; `staticmap` is a small MIT helper around tile fetching + Pillow
compositing).

### OSM tile usage policy

`plot_session_fixes.py` fetches tiles from `tile.openstreetmap.org` with
a distinct `User-Agent: MirkFall-POC-Plotter/1.0 (+<repo-url>)` header. Per
OSM's tile usage policy, this is the minimum responsible caller
identification. The tool is intended for occasional POC use — dozens of
tiles per plot, a handful of plots per POC session. Bulk downloads are
out of scope.

Reference: https://operations.osmfoundation.org/policies/tiles/
