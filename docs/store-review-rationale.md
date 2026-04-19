# MirkFall — Store Review Rationale

Document used to justify MirkFall's background-location permission usage
and data-handling claims when the app is submitted for store review, as
free-and-open-source software distributed exclusively through sideload
channels (GitHub releases and GOSL v1.0 redistribution).

The document is written in English — store reviewers are anglophone even
when the app itself ships in French-first copy.

## Project description

MirkFall is a personal, offline-first travel journal. As the user walks or
otherwise explores the world, a "fog of war" layer over a map progressively
reveals itself in the places they have actually been, building up a private
visual record of where they have travelled. The app is aimed at enthusiasts
who want to own their exploration data on their own device.

The project is distributed as free open-source software under the Good Old
Software License v1.0 (see https://github.com/saibashirudo/GOSL-MirkFall/
for the full source and the LICENSE file). MirkFall has no servers,
no advertising, no analytics, no automatic crash reporting, no in-app
purchases, no subscriptions, and no mandatory accounts. It is a single-
developer project; any revenue from MirkFall would be explicitly prohibited
by the GOSL v1.0 license under which every released build is distributed.

## Why Always location is required

A MirkFall exploration session is expected to last many hours — a typical
use pattern is "start a session at the trailhead, lock the phone, put it
in a pocket, walk for the day, stop the session on return". The fog-of-war
reveal is driven by GPS updates that arrive while the app is in the
background and the screen is off. Without the `Always` location
authorization (or its Android equivalent `ACCESS_BACKGROUND_LOCATION`),
iOS and Android suspend location callbacks shortly after the screen turns
off, which produces multi-minute to multi-tens-of-minutes gaps in the
session's trajectory. Those gaps degrade the journal from "a record of
where I actually went" to "a record of where I had the app in the
foreground", which defeats the app's central value proposition.

MirkFall requests `When In Use` first and then, only after a user-facing
pre-prompt rationale screen explains what the tracking does and why, the
second-step `Always` upgrade. Users who decline `Always` can still use the
app in a degraded "foreground-only" mode; the UI surfaces the degradation
clearly rather than hiding it.

## Data handling

MirkFall is local-only by design. All GPS fixes, all session metadata, all
marker annotations, and all optional user photos are stored exclusively on
the user's device — in an on-device SQLite database (`mirkfall.db`) and a
filesystem photos directory inside the app's sandbox.

**No data is ever transmitted to any server, no analytics SDK is embedded
inside the binary, no crash reporting is automatically forwarded, and no
third-party tracker is present.** The GOSL v1.0 license explicitly
prohibits adding any of these to redistributed or derived builds — so this
property is not just observed in the source, it is enforceable against
forks.

The only outbound network requests the app makes are:

1. Map tile fetches to `tile.openstreetmap.org`, for rendering the base
   map the user sees. These are user-initiated (the user scrolls / zooms
   the map) and respect the OpenStreetMap tile usage policy (distinct
   `User-Agent`, bounded cache).
2. User-initiated exports via the OS share sheet — the user exports a
   session archive (`.mirkfall` ZIP file) to a destination of their own
   choice (email, cloud drive, another app). The app never initiates the
   share; the user always does.

No background sync, no silent update checks, no license-validation
"phone home", no opt-out telemetry pretending to be essential. An airplane-
mode smoke test is part of the Phase 15 release checklist (requirement
QUAL-05) and captures zero outbound traffic other than the OSM tile
fetches described above.

## Source code accessibility

The full source code is publicly hosted at
https://github.com/saibashirudo/GOSL-MirkFall under the Good Old Software
License v1.0. Store reviewers and interested users are welcome to audit
the codebase for any claim in this document. In particular:

- `DEPENDENCIES.md` at the repository root lists every third-party
  library with its SPDX licence and a telemetry-audit entry. Each
  dependency has been manually inspected for analytics SDKs, automatic
  crash reporters, and unsolicited network calls (zero found).
- `tool/check_licenses.dart` is a CI gate that fails the build if any
  dependency resolves to a GPL, AGPL, or other copyleft-strong licence.
- `tool/check_headers.dart` enforces the GOSL v1.0 copyright header on
  every source file.
- The `.github/workflows/ci.yml` pipeline runs these gates on every push,
  so the claims above remain continuously verifiable rather than being
  frozen at one reviewer moment.

## Contact

- Developer email: saibashirudo@protonmail.com
- GitHub issues: https://github.com/saibashirudo/GOSL-MirkFall/issues
- Expected response time: within 7 days for store-review follow-ups.

The developer acknowledges that MirkFall's sideload-only distribution and
zero-revenue model mean store-review expectations differ from those for a
paid commercial app. Questions about the app's data-handling posture,
permission usage, or licence terms are welcome at the contact address
above.

---

*Last updated: 2026-04-19.*
*Distributed under the Good Old Software License v1.0.*
