#!/usr/bin/env python3
"""raw2dc42.py — wrap a raw HFS .dsk image in DiskCopy 4.2 format.

Disk Copy 6.x on Mac OS 8/9 and DiskImageMounter on Mac OS X both mount
DC42 images natively; they do NOT mount raw HFS images. Retro68's CMake
emits raw HFS, so this script wraps the data with the canonical 84-byte
DC42 header (Pascal name + sizes + Apple checksum + format/magic bytes).

Usage: raw2dc42.py [-n NAME] INPUT.dsk OUTPUT.image
"""
import argparse
import struct
import sys
from pathlib import Path


def dc42_checksum(data: bytes) -> int:
    """Disk Copy 4.2 data checksum: sum 16-bit BE words with rotate-right."""
    s = 0
    if len(data) & 1:
        data = data + b"\x00"
    for i in range(0, len(data), 2):
        word = (data[i] << 8) | data[i + 1]
        s = (s + word) & 0xFFFFFFFF
        s = ((s >> 1) | ((s & 1) << 31)) & 0xFFFFFFFF
    return s


def disk_format(size_bytes: int) -> tuple[int, int]:
    """Return (diskFormat, formatByte) for a standard floppy size."""
    if size_bytes == 400 * 1024:
        return 0x00, 0x12
    if size_bytes == 800 * 1024:
        return 0x01, 0x22
    if size_bytes == 720 * 1024:
        return 0x02, 0x22
    if size_bytes == 1440 * 1024:
        return 0x03, 0x96
    return 0x01, 0x22


def wrap(src: Path, dst: Path, name: str) -> None:
    data = src.read_bytes()
    size = len(data)
    diskFmt, fmtByte = disk_format(size)
    chk = dc42_checksum(data)

    name_bytes = name.encode("mac_roman", errors="replace")[:63]
    header = struct.pack(">B63sIIIIBBH",
                         len(name_bytes),
                         name_bytes.ljust(63, b"\x00"),
                         size,        # data block size
                         0,           # tag block size
                         chk,         # data checksum
                         0,           # tag checksum
                         diskFmt,
                         fmtByte,
                         0x0100)      # magic
    assert len(header) == 84, len(header)
    dst.write_bytes(header + data)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-n", "--name", help="Image name (default: input stem, max 63 chars)")
    ap.add_argument("input", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()

    name = args.name or args.input.stem
    wrap(args.input, args.output, name)
    print(f"{args.input} ({args.input.stat().st_size} B) -> {args.output} (+84 B DC42 header)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
