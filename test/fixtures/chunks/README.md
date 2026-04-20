<!-- Copyright (c) 2026 THONGVAN Alexis -->
<!-- Licensed under the Good Old Software License v1.0 -->
<!-- See LICENSE file for details -->

# `test/fixtures/chunks/` — download soak-test chunk fixtures

Phase 07 plan 07-04 (download pipeline) uses this directory for
deterministic chunk binaries exercising the MockHTTPServer-backed
download controller. Each fixture chunk is a repeated single-byte
pattern of fixed size, matching the synthetic `sha256` entries
declared in `test/fixtures/catalogs/mini_catalog.json`.

## Layout (populated by Plan 07-04 Task 2)

```text
test/fixtures/chunks/
├── aru.part01     4 MB of 0x01 — ARU single-part happy-path
├── esp.part01    10 MB of 0x02 — ESP single-part
├── deu.part01    20 MB of 0x03 — DEU first chunk of 2-part concat
├── deu.part02    20 MB of 0x04 — DEU second chunk
├── gbr.part01    30 MB of 0x05 — GBR single-part larger-size case
├── fra.part01    40 MB of 0x06 — FRA 3-part concat (part 1)
├── fra.part02    40 MB of 0x07 — FRA part 2
├── fra.part03    40 MB of 0x08 — FRA part 3
├── usa.part01    50 MB of 0x09 — USA 4-part concat (part 1)
├── usa.part02    50 MB of 0x0A — USA part 2
├── usa.part03    50 MB of 0x0B — USA part 3
└── usa.part04    50 MB of 0x0C — USA part 4
```

## sha256 seed recipe

The sha256 entries in `mini_catalog.json` were computed once at plan
time via:

```python
import hashlib
def h(b, n): return hashlib.sha256(bytes([b]) * n).hexdigest()
```

The reassembled sha256 is computed over the concatenation of the
constituent part byte patterns (in order). Every value in
`mini_catalog.json` is derivable from this recipe, so a future plan
that adds a new fixture country only needs to pick a fresh byte
pattern + size and recompute.

## Why chunks are not committed in Plan 07-01

The full set (10 files, totaling ~400 MB) is **not committed** in
Plan 07-01 — that would bloat the repo with binary blobs for a test
path no existing suite exercises yet. Plan 07-04 Task 2 ships them
alongside the MockHTTPServer harness that consumes them, using the
same recipe above. This README freezes the contract so the catalog
fixture + consumer plan stay in sync.
