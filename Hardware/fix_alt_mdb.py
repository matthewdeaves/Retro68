#!/usr/bin/env python3
"""fix_alt_mdb.py — copy primary HFS MDB to alternate MDB position.

Both libhfs (used by hfsutils and Retro68's CMake) leave the alternate
MDB in the post-format "empty volume" state after files are added.
Mac OS X DiskImageMounter is lenient ("might be damaged" but mounts);
Disk Copy 6 on Mac OS 9 is stricter and crashes or rejects the image.

Apple's HFS spec places the alternate MDB at the SECOND-TO-LAST sector
of the volume — that is, two 512-byte sectors before EOF. The primary
MDB is at sector 2 (offset 0x400). Both are exactly 512 bytes.

Operates on raw HFS images. Does NOT process the DC42 wrapper — run
this BEFORE raw2dc42.py.

Usage: fix_alt_mdb.py [-i] FILE [FILE...]
       -i  modify in place (default: write FILE.fixed)
"""
import argparse
import struct
import sys
from pathlib import Path


def fix(path: Path, in_place: bool) -> None:
    data = bytearray(path.read_bytes())
    size = len(data)
    if size < 1024 or size % 512 != 0:
        raise ValueError(f"{path}: not a multiple of 512 bytes")

    sig_primary = bytes(data[0x400:0x402])
    if sig_primary != b"BD":
        raise ValueError(f"{path}: no HFS signature at 0x400 (got {sig_primary!r})")

    alt_off = size - 2 * 512   # second-to-last sector
    sig_alt = bytes(data[alt_off:alt_off + 2])
    if sig_alt != b"BD":
        raise ValueError(f"{path}: no HFS signature at alt MDB offset 0x{alt_off:x}")

    if bytes(data[0x400:0x600]) == bytes(data[alt_off:alt_off + 512]):
        print(f"{path}: alt MDB already matches primary (no change)")
        return

    data[alt_off:alt_off + 512] = data[0x400:0x600]

    out = path if in_place else path.with_suffix(path.suffix + ".fixed")
    out.write_bytes(data)
    print(f"{path}: copied primary MDB (0x400) -> alt MDB (0x{alt_off:x})  -> {out}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-i", "--in-place", action="store_true")
    ap.add_argument("files", nargs="+", type=Path)
    args = ap.parse_args()
    for f in args.files:
        fix(f, args.in_place)
    return 0


if __name__ == "__main__":
    sys.exit(main())
