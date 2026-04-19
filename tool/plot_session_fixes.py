#!/usr/bin/env python3
# Copyright (c) 2026 THONGVAN Alexis
# Licensed under the Good Old Software License v1.0
# See LICENSE file for details
"""Plot a MirkFall session's t_fixes on an OSM static map (Phase 05 POC tool).

Standalone Python 3 CLI. Does NOT ship in the app binary — Python deps are
pinned in tool/requirements.txt (licences + install instructions in
tool/README.md). User-Agent set per OSM tile usage policy even for dev
tooling.

Usage:
    python tool/plot_session_fixes.py --db <path-to-mirkfall.db> \\
        --session-id <sess_...> [--out <png>] [--zoom <int>]

Exits:
    0 on success (PNG saved, stats printed)
    1 on invalid input (missing DB, zero fixes for the session)
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional, Tuple

from staticmap import CircleMarker, Line, StaticMap

# OSM tile server. Respects OSM usage policy (User-Agent identifies the tool
# + links to the public repo) — see https://operations.osmfoundation.org/policies/tiles/
OSM_TILE_TEMPLATE = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
USER_AGENT = (
    "MirkFall-POC-Plotter/1.0 "
    "(+https://github.com/saibashirudo/GOSL-MirkFall)"
)

# Defaults for the output image — 1600x1200 = printable A4 at ~200 DPI,
# balances detail vs tile-download count. Override via --width / --height.
DEFAULT_WIDTH_PX = 1600
DEFAULT_HEIGHT_PX = 1200

# Marker radii: distinct enough to be obvious on the PNG, small enough not
# to hide the trajectory line underneath.
START_MARKER_RADIUS_PX = 10
END_MARKER_RADIUS_PX = 10
LINE_WIDTH_PX = 3


Fix = Tuple[float, float, int]  # (latitude, longitude, recorded_at_utc_ms)


def parse_args() -> argparse.Namespace:
    """Build and parse the CLI argument list."""
    parser = argparse.ArgumentParser(
        description=(
            "Plot a MirkFall session's t_fixes trajectory on an OSM basemap."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--db",
        required=True,
        help="Path to mirkfall.db (pulled via adb, Xcode container, etc.)",
    )
    parser.add_argument(
        "--session-id",
        required=True,
        help="Session ID to plot (e.g. sess_01HV7...). Exact-match on column.",
    )
    parser.add_argument(
        "--out",
        default=None,
        help=(
            "Output PNG path. Default: "
            "docs/poc-artifacts/<session-id>-<timestamp>.png"
        ),
    )
    parser.add_argument(
        "--zoom",
        type=int,
        default=None,
        help="OSM zoom level (int). Default: auto-fit bounding box.",
    )
    parser.add_argument("--width", type=int, default=DEFAULT_WIDTH_PX)
    parser.add_argument("--height", type=int, default=DEFAULT_HEIGHT_PX)
    return parser.parse_args()


def fetch_fixes(db_path: str, session_id: str) -> List[Fix]:
    """Read ordered t_fixes rows for the given session.

    Returns empty list if the session has no rows. Order is ASC by
    recorded_at_utc so the line rendering traces time, not insertion order.
    """
    connection = sqlite3.connect(db_path)
    try:
        cursor = connection.execute(
            "SELECT latitude, longitude, recorded_at_utc FROM t_fixes "
            "WHERE session_id = ? ORDER BY recorded_at_utc ASC",
            (session_id,),
        )
        return [(row[0], row[1], row[2]) for row in cursor.fetchall()]
    finally:
        connection.close()


def print_stats(fixes: List[Fix]) -> None:
    """Dump the POC acceptance-criteria stats to stdout.

    Matches the fields docs/qual-01-02-poc.md expects per entry: row count,
    duration, min/median/max interval, bounding box.
    """
    count = len(fixes)
    if count < 2:
        print(f"Fixes: {count} — not enough for interval stats.")
        return

    timestamps_ms = [f[2] for f in fixes]
    intervals_s = [
        (timestamps_ms[i] - timestamps_ms[i - 1]) / 1000.0
        for i in range(1, count)
    ]
    start_utc = datetime.fromtimestamp(
        timestamps_ms[0] / 1000.0, tz=timezone.utc
    )
    end_utc = datetime.fromtimestamp(
        timestamps_ms[-1] / 1000.0, tz=timezone.utc
    )
    duration_minutes = (timestamps_ms[-1] - timestamps_ms[0]) / 1000.0 / 60.0
    latitudes = [f[0] for f in fixes]
    longitudes = [f[1] for f in fixes]

    print(f"Fixes:        {count}")
    print(f"Start (UTC):  {start_utc.isoformat()}")
    print(f"End   (UTC):  {end_utc.isoformat()}")
    print(f"Duration:     {duration_minutes:.1f} min")
    print(f"Interval min: {min(intervals_s):.1f} s")
    print(f"Interval med: {statistics.median(intervals_s):.1f} s")
    print(f"Interval max: {max(intervals_s):.1f} s")
    print(
        f"Bbox lat:     [{min(latitudes):.5f}, {max(latitudes):.5f}]"
    )
    print(
        f"Bbox lon:     [{min(longitudes):.5f}, {max(longitudes):.5f}]"
    )


def render(
    fixes: List[Fix],
    out_path: str,
    width: int,
    height: int,
    zoom: Optional[int],
) -> None:
    """Render trajectory + start/end markers to out_path.

    Note: staticmap expects (lon, lat) tuples — NOT (lat, lon). Easy to
    miss since t_fixes carries (latitude, longitude). The unpacking below
    swaps explicitly to make the convention visible at the call site.
    """
    static_map = StaticMap(
        width=width,
        height=height,
        url_template=OSM_TILE_TEMPLATE,
        headers={"User-Agent": USER_AGENT},
    )
    trajectory = [(longitude, latitude) for (latitude, longitude, _) in fixes]
    static_map.add_line(Line(trajectory, "red", LINE_WIDTH_PX))

    if fixes:
        start_lat, start_lon, _ = fixes[0]
        end_lat, end_lon, _ = fixes[-1]
        static_map.add_marker(
            CircleMarker((start_lon, start_lat), "green", START_MARKER_RADIUS_PX)
        )
        static_map.add_marker(
            CircleMarker((end_lon, end_lat), "blue", END_MARKER_RADIUS_PX)
        )

    image = static_map.render(zoom=zoom) if zoom is not None else static_map.render()

    output_dir = os.path.dirname(out_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    image.save(out_path)
    print(f"Saved: {out_path}")


def build_default_out_path(session_id: str) -> str:
    """Build the default output path when --out is not provided."""
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    # forward slashes on purpose: the path is documented in
    # docs/qual-01-02-poc.md as docs/poc-artifacts/..., stable across
    # Windows + POSIX when Markdown renders the path.
    return f"docs/poc-artifacts/{session_id}-{timestamp}.png"


def main() -> int:
    args = parse_args()

    if not Path(args.db).is_file():
        print(f"DB not found: {args.db}", file=sys.stderr)
        return 1

    fixes = fetch_fixes(args.db, args.session_id)
    if not fixes:
        print(
            f"No fixes for session {args.session_id} in {args.db}",
            file=sys.stderr,
        )
        return 1

    print_stats(fixes)
    out_path = args.out or build_default_out_path(args.session_id)
    render(fixes, out_path, args.width, args.height, args.zoom)
    return 0


if __name__ == "__main__":
    sys.exit(main())
