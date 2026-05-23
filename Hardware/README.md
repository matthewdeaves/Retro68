# Hardware helpers

Small post-processing scripts for the artefacts Retro68 emits when you're
deploying to **real** Classic Macs (System 7 / Mac OS 8 / 9 / Mac OS X
Classic) rather than to an emulator.

In emulators (Mini vMac, Basilisk II, SheepShaver) the stock `.bin` and
`.dsk` outputs work fine. On real hardware they hit three rough edges,
one per script.

All three are standalone Python 3 scripts with no third-party deps. Run
them on the host that produced the build, after `make` and before you
ship the artefacts to the Mac.

## raw2dc42.py — wrap raw HFS in DiskCopy 4.2 format

**Why:** Retro68's CMake emits `.dsk` as a *raw* HFS volume. Mini vMac
and Basilisk II read raw fine, but Disk Copy 6.x on Mac OS 8/9 and
`DiskImageMounter` on Mac OS X both require a DiskCopy 4.2 / NDIF / UDIF
header. Without one, OS 9 reports *"file format not recognised (-8816)"*
or worse.

**What:** prepends Apple's 84-byte DC42 header (Pascal name + sizes +
rotating-right checksum + format/magic bytes 0x0100). Output is
byte-for-byte identical to lampmerchant/dsk2dc and recognised by
libmagic / `file` as *"Apple DiskCopy 4.2 image"*.

```
./raw2dc42.py -n "My App" build/MyApp.dsk build/MyApp.image
```

After upload to the Mac, set Finder type/creator to `dImg` / `dCpy` so
Disk Copy picks the file up automatically (Finder AppleScript on OS X,
ResEdit on OS 9, or a MacBinary wrapper).

## fix_alt_mdb.py — fix the libhfs alternate-MDB bug

**Why:** libhfs (used by Retro68's CMake AND by hfsutils) writes the
*primary* HFS Master Directory Block at sector 2 (offset `0x400`)
correctly when you add a file, but never propagates the same edits to
the *alternate* MDB at the second-to-last sector. The alt MDB stays
frozen in the post-format empty-disk state. OS X's `DiskImageMounter`
is lenient ("might be damaged" but mounts); Disk Copy 6 on OS 9
cross-checks the two and crashes or rejects the image.

**What:** copies the 512-byte primary MDB over the alternate MDB.
Operates on a raw HFS image — run it **before** `raw2dc42.py`.

```
./fix_alt_mdb.py -i build/MyApp.dsk          # in-place
./fix_alt_mdb.py build/MyApp.dsk             # writes .dsk.fixed
```

Verify with:

```
cmp <(tail -c +1025 build/MyApp.dsk | head -c 512) \
    <(tail -c +$(($(stat -c%s build/MyApp.dsk)-1023)) build/MyApp.dsk | head -c 512)
```

(`cmp` exits 0 when alt == primary.) The underlying fix really belongs
in `hfsutils/libhfs/`, not in a post-process; this script exists until
that lands.

## patch_creator.py — MacBinary creator + CRC patch

**Why:** Apps built with a custom creator code (e.g. `add_application(...
CREATOR "R68L")`) decode fine through Stuffit Expander and Disk Copy,
but Mini vMac's binUnpk produces a file the Finder treats as a *document*
rather than an application — *"could not be opened because the
application program that created it could not be found"*. The same `.bin`
with creator `????` (Retro68's default) decodes correctly.

The actual root cause is in binUnpk's handling of custom creator codes;
patching the `.bin` to `????` is a workaround until that's fixed
upstream.

**What:** in-place edit of the MacBinary FInfo creator field at offset
69, then re-computes the XMODEM CRC at offset 124. Data + resource forks
pass through untouched.

```
./patch_creator.py build/MyApp.bin build/MyApp-clean.bin       # default ????
./patch_creator.py -c MyCo build/MyApp.bin build/MyApp.bin     # custom
```

## Typical pipeline for real-hardware deployment

```
make MyApp
./Hardware/patch_creator.py build/MyApp.bin   build/ship/MyApp.bin
./Hardware/fix_alt_mdb.py  -i build/MyApp.dsk
./Hardware/raw2dc42.py     -n "MyApp"         build/MyApp.dsk  build/ship/MyApp.image
# upload build/ship/* to the target Mac
# on OS X: SetFile -t dImg -c dCpy  build/ship/MyApp.image  (or Finder AppleScript)
```
