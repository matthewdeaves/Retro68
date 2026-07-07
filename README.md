# Retro68 — matthewdeaves fork

A GCC-based cross-compiler for classic **68k and PowerPC Macintosh**, forked from
[autc04/Retro68](https://github.com/autc04/Retro68).

> **Looking for the full Retro68 documentation?** How the toolchain works, the
> Docker image, the sample programs, the individual tools (`Rez`, `MakePEF`,
> `ConvertObj`, …) and Windows/Cygwin builds all live in the upstream project and
> its README: <https://github.com/autc04/Retro68>.
>
> This README covers only what *this fork* adds and how to build it. The fork
> tracks upstream but **does not send pull requests back**.

## What this fork adds

- **`./setup.sh` — one command to a working toolchain.** Installs prerequisites,
  sets up the interfaces, builds the toolchain, and records the env
  vars. Works on **Ubuntu 24/25** and **macOS including Apple Silicon** (verified
  end-to-end on both). Handles Homebrew's keg-only `bison`/`flex`/`texinfo` and the
  too-old macOS system `bison` automatically, and runs unattended in CI.
- **Builds against Apple's Universal Interfaces** (Carbon, MacTCP, OpenTransport
  and other post-System-7 APIs the multiversal interfaces don't cover); `setup.sh`
  sets them up. See [Interfaces](#interfaces).
- **Apple OpenGL 1.2 SDK — built in** (`InterfacesAndLibraries/OpenGL_SDK/` — `agl`/
  `gl`/`glu`/`glext` headers + CFM stub libraries) for classic **PowerPC** OpenGL.
  Installed automatically by `build-toolchain.bash`, so it lands in *every* build
  path — `setup.sh`, the Docker image, and CI — with no extra step. See
  [OpenGL](#opengl).
- **`Hardware/` — real-Mac deployment helpers.** Post-processing scripts
  (`raw2dc42.py`, `fix_alt_mdb.py`, `patch_creator.py`) for the rough edges you hit
  writing Retro68's output to *real* Classic Macs instead of emulators. See
  [`Hardware/README.md`](Hardware/README.md).
- **PPC XCOFF `.debug` linker fix** — sizes the `.debug` output section after the
  stabs string table is built; write-up in
  [`XCOFF-DEBUG-FIX-NOTES.md`](XCOFF-DEBUG-FIX-NOTES.md).
- **CI** (`.github/workflows/`) and a File Manager regression test
  ([`AutomatedTests/Diag305.c`](AutomatedTests/Diag305.c), issue #305).
- Local patch notes: [`BINUTILS-PATCHES.md`](BINUTILS-PATCHES.md),
  [`GCC-PATCHES.md`](GCC-PATCHES.md).

## Quick start

```sh
git clone --recursive https://github.com/matthewdeaves/Retro68.git
cd Retro68
./setup.sh
```

`setup.sh` builds into `$HOME/Retro68-build` (override with `RETRO68_BUILD`) and
appends `RETRO68_TOOLCHAIN`, `RETRO68_SRC` and the toolchain `bin/` to your shell
rc. Reload it and the cross compilers are on your `PATH`:

```sh
source ~/.zshrc      # or ~/.bashrc
m68k-apple-macos-gcc --version
powerpc-apple-macos-gcc --version
```

Extract the interfaces without building the whole toolchain:

```sh
./setup.sh --mpw-only
```

### Prerequisites

`setup.sh` installs these for you (via `apt` or Homebrew). To do it by hand:

- **Ubuntu:** `sudo apt-get install build-essential cmake git unzip libgmp-dev libmpfr-dev libmpc-dev libboost-all-dev bison flex texinfo ruby`
- **macOS:** `brew install boost cmake gmp mpfr libmpc bison flex texinfo ruby`

  Homebrew's `bison`/`flex`/`texinfo` are keg-only and macOS's system `bison` (2.3)
  is older than the 3.0.2 the build needs, so a manual build must put the Homebrew
  copies first (`setup.sh` does this for you):

  ```sh
  export PATH="$(brew --prefix bison)/bin:$(brew --prefix flex)/bin:$(brew --prefix texinfo)/bin:$PATH"
  ```

## Building a program

Same model as upstream — point CMake at the generated toolchain file:

```sh
cmake -S yourapp -B build \
  -DCMAKE_TOOLCHAIN_FILE=$RETRO68_TOOLCHAIN/m68k-apple-macos/cmake/retro68.toolchain.cmake
cmake --build build
```

Use `powerpc-apple-macos` in place of `m68k-apple-macos` for PowerPC. The upstream
README documents the full build model, the `add_application` CMake helper, the
samples, and every tool.

## Interfaces

The toolchain builds against **Apple's Universal Interfaces** when they're present
in `InterfacesAndLibraries/`, and falls back to the open-source **multiversal**
interfaces if that directory is absent (the build auto-detects which; remove the
directory to switch). Apple's interfaces cover Carbon, MacTCP, OpenTransport and
the rest of post-System-7; multiversal does not. See the upstream README for more
on both.

## OpenGL

Apple's **OpenGL 1.2 SDK** (January 2001) is packaged in
[`InterfacesAndLibraries/OpenGL_SDK/`](InterfacesAndLibraries/OpenGL_SDK/) and
installed into the toolchain automatically by `build-toolchain.bash` — so a plain
`./setup.sh`, a Docker build, or a CI run all produce a toolchain you can build
OpenGL apps with. No separate step. The installer self-verifies by compiling and
linking a small `agl`/`gl`/`glu` program at the end of the build.

**PowerPC only** — Apple never shipped OpenGL for 68k Macs, so it is skipped when
PPC is not being built. Works for classic CFM (Mac OS 8.x/9.x) and Carbon CFM
(CarbonLib / Mac OS X).

**Build with Apple's Universal Interfaces** to *compile* AGL/OpenGL apps: `agl.h`
includes `<Quickdraw.h>`, the spelling Apple's interfaces use. `./setup.sh`
selects Universal Interfaces automatically when present. Under the open-source
multiversal interfaces the headers and stub libs are still installed, but
`agl.h` won't compile on a case-sensitive filesystem (multiversal ships
`QuickDraw.h`); the installer prints a warning rather than failing the build.

Use it from a project:

```c
#include <agl.h>
#include <gl.h>
```

```cmake
add_application(myglapp myglapp.c myglapp.r)
target_link_libraries(myglapp PRIVATE
    "-lOpenGLLibrary"   # gl* + agl*
    "-lOpenGLUtility"   # glu*  (only if used)
    "-lOpenGLMemory")   # Apple memory helpers (only if used)
```

To (re)install into an already-built toolchain without a full rebuild:

```sh
RETRO68_TOOLCHAIN=$RETRO68_TOOLCHAIN ./InterfacesAndLibraries/OpenGL_SDK/install.sh
```

More detail — provenance, layout, licensing — in
[`InterfacesAndLibraries/OpenGL_SDK/README.md`](InterfacesAndLibraries/OpenGL_SDK/README.md).

## License

GPL v3 — see [`COPYING`](COPYING), same as upstream. Retro68 is
Copyright © Wolfgang Thaller and contributors.
