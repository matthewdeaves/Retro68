#!/usr/bin/env python3
"""patch_creator.py — in-place edit MacBinary FInfo creator + recompute CRC.

Reads a MacBinary II file, replaces the 4-byte creator code at offset 69,
recomputes the XMODEM CRC at offset 124, and writes the result. The data
and resource forks pass through untouched.

Usage: patch_creator.py [-c CCCC] INPUT.bin OUTPUT.bin
       (default creator: ????)
"""
import argparse
import struct
import sys
from pathlib import Path


def crc16_xmodem(data: bytes) -> int:
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-c", "--creator", default="????",
                    help="4-character creator code (default: ????)")
    ap.add_argument("input", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()

    if len(args.creator) != 4:
        ap.error("creator must be exactly 4 characters")

    data = bytearray(args.input.read_bytes())
    if len(data) < 128:
        ap.error("not a MacBinary file (too small)")

    old_type = bytes(data[65:69]).decode("mac_roman", errors="replace")
    old_creator = bytes(data[69:73]).decode("mac_roman", errors="replace")
    data[69:73] = args.creator.encode("mac_roman")
    new_crc = crc16_xmodem(bytes(data[0:124]))
    struct.pack_into(">H", data, 124, new_crc)

    args.output.write_bytes(data)
    print(f"{args.input.name}: type={old_type!r} creator {old_creator!r} -> {args.creator!r}  "
          f"CRC=0x{new_crc:04x}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
