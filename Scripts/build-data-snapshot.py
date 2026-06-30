#!/usr/bin/env python3
"""
build-data-snapshot.py

Turns the raw Tokyo-area rail data in ./data into the compressed, bundle-ready
snapshot consumed by the macOS app at Sources/Timemenu/Resources/Data.

Output layout (each *.deflate is a RAW DEFLATE stream, RFC 1951, wbits=-15, so
it round-trips with Swift's `NSData.decompressed(using: .zlib)`):

    Resources/Data/
      meta/
        railways.deflate
        stations.deflate
        rail-directions.deflate
        train-types.deflate
        train-vehicles.deflate
        station-groups.deflate
        through-services.deflate
        railway-timetable-index.deflate   # generated: railwayId -> timetable stem
      timetables/
        <stem>.deflate                    # one per line, e.g. jreast-yamanote.deflate

Run from the repo root:   python3 Scripts/build-data-snapshot.py
"""

import json
import os
import sys
import zlib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "data"
OUT = REPO / "Sources" / "Timemenu" / "Resources" / "Data"

META_FILES = [
    "railways.json",
    "stations.json",
    "rail-directions.json",
    "train-types.json",
    "train-vehicles.json",
    "station-groups.json",
    "through-services.json",
]


def deflate(data: bytes) -> bytes:
    """Raw DEFLATE (no zlib/gzip header or checksum) so Swift `.zlib` can read it."""
    co = zlib.compressobj(9, zlib.DEFLATED, -15)
    return co.compress(data) + co.flush()


def write_deflate(path: Path, raw: bytes) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    blob = deflate(raw)
    path.write_bytes(blob)
    return len(blob)


def main() -> int:
    if not SRC.exists():
        print(f"error: source data not found at {SRC}", file=sys.stderr)
        return 1

    if OUT.exists():
        # Clean previous output so removed lines don't linger in the bundle.
        for p in sorted(OUT.rglob("*"), reverse=True):
            p.unlink() if p.is_file() else p.rmdir()

    total_raw = 0
    total_comp = 0

    # --- metadata files (copied 1:1, just compressed) -----------------------
    for name in META_FILES:
        src = SRC / name
        if not src.exists():
            print(f"error: missing metadata file {src}", file=sys.stderr)
            return 1
        raw = src.read_bytes()
        out = OUT / "meta" / (src.stem + ".deflate")
        comp = write_deflate(out, raw)
        total_raw += len(raw)
        total_comp += comp
        print(f"  meta/{src.stem:<26} {len(raw):>9,} -> {comp:>8,}  ({len(raw)/comp:5.1f}x)")

    # --- per-line timetables + railwayId -> stem index ----------------------
    tt_dir = SRC / "train-timetables"
    files = sorted(tt_dir.glob("*.json"))
    if not files:
        print(f"error: no timetables found in {tt_dir}", file=sys.stderr)
        return 1

    index: dict[str, str] = {}
    n_lines = 0
    for src in files:
        raw = src.read_bytes()
        stem = src.stem  # e.g. "jreast-yamanote"
        out = OUT / "timetables" / (stem + ".deflate")
        comp = write_deflate(out, raw)
        total_raw += len(raw)
        total_comp += comp
        n_lines += 1

        # Map every railway id appearing in this file to this stem. A single
        # file is one line, but through-services can mix ids; first-wins keeps
        # each railway pointed at the file it actually owns.
        try:
            entries = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"error: {src.name} is not valid JSON: {e}", file=sys.stderr)
            return 1
        rid_counts: dict[str, int] = {}
        for e in entries:
            rid = e.get("r")
            if rid:
                rid_counts[rid] = rid_counts.get(rid, 0) + 1
        # The owning railway is the most common `r` in the file.
        if rid_counts:
            owner = max(rid_counts, key=rid_counts.get)
            index.setdefault(owner, stem)

    index_raw = json.dumps(index, ensure_ascii=False, sort_keys=True).encode("utf-8")
    comp = write_deflate(OUT / "meta" / "railway-timetable-index.deflate", index_raw)
    total_raw += len(index_raw)
    total_comp += comp

    print()
    print(f"  lines:              {n_lines}")
    print(f"  railways indexed:   {len(index)}")
    print(f"  raw total:          {total_raw/1024/1024:7.1f} MB")
    print(f"  snapshot total:     {total_comp/1024/1024:7.1f} MB  ({total_raw/total_comp:.1f}x)")
    print(f"  written to:         {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
