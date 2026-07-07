#!/usr/bin/env bash
# Install Apple's OpenGL 1.2 SDK into a built Retro68 PowerPC toolchain.
# Idempotent: re-running just refreshes the installed files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN="${RETRO68_TOOLCHAIN:-$HOME/Retro68-build/toolchain}"

if [[ ! -x "$TOOLCHAIN/bin/MakeImport" ]]; then
    echo "[!!] MakeImport not found at $TOOLCHAIN/bin/MakeImport" >&2
    echo "     Build the Retro68 toolchain first (./setup.sh)." >&2
    exit 1
fi

PPC_INCLUDE="$TOOLCHAIN/powerpc-apple-macos/include"
PPC_LIB="$TOOLCHAIN/powerpc-apple-macos/lib"

echo "Installing Apple OpenGL 1.2 SDK into $TOOLCHAIN"

# ── Headers ─────────────────────────────────────────────────────
echo "  Headers -> $PPC_INCLUDE/ and $PPC_INCLUDE/GL/"
mkdir -p "$PPC_INCLUDE/GL"
for h in "$SCRIPT_DIR/Headers/"*.h; do
    cp "$h" "$PPC_INCLUDE/"
    cp "$h" "$PPC_INCLUDE/GL/"
done

# ── Import libraries (PEF stubs -> Retro68 .a archives) ─────────
echo "  Libraries -> $PPC_LIB/"
mkdir -p "$PPC_LIB"
TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT
for bin in "$SCRIPT_DIR/Libraries/"*.bin; do
    stub_name=$(basename "$bin" .bin)     # OpenGLLibraryStub
    lib_name=${stub_name%Stub}            # OpenGLLibrary
    out="$PPC_LIB/lib${lib_name}.a"
    "$TOOLCHAIN/bin/MakeImport" "$bin" "$out"
    printf "    %-25s -> %s\n" "$(basename "$bin")" "lib${lib_name}.a"
done

# ── Verify: headers compile and the stubs link (best-effort) ────
# Non-fatal on purpose: the headers/libs are installed regardless. The smoke
# test needs <Quickdraw.h> (pulled in by agl.h). Apple's Universal Interfaces
# provide that spelling; the open-source multiversal interfaces generate
# QuickDraw.h (capital D), so on a case-sensitive filesystem the compile can't
# find it. We still want the SDK installed in that configuration, so a failed
# smoke test warns rather than aborting the whole toolchain build.
GCC="$TOOLCHAIN/bin/powerpc-apple-macos-gcc"
if [[ -x "$GCC" ]]; then
    echo "  Verifying install..."
    printf '#include <agl.h>\n#include <gl.h>\n#include <glu.h>\nint main(void){glClear(GL_COLOR_BUFFER_BIT);gluErrorString(0);aglGetError();return 0;}\n' \
        > "$TMP/glcheck.c"
    if "$GCC" "$TMP/glcheck.c" -o "$TMP/glcheck" \
            -lOpenGLLibrary -lOpenGLUtility -lOpenGLMemory 2>"$TMP/glcheck.log"; then
        echo "  [ok] headers + libOpenGLLibrary/Utility/Memory compile and link"
    else
        echo "  [warn] OpenGL smoke test did not build — headers and libs are still installed." >&2
        echo "         Expected with the multiversal interfaces (agl.h needs <Quickdraw.h>," >&2
        echo "         which Apple's Universal Interfaces provide). Build with Universal" >&2
        echo "         Interfaces to compile AGL/OpenGL apps." >&2
        sed 's/^/           | /' "$TMP/glcheck.log" >&2 || true
    fi
fi

echo
echo "Installed Apple OpenGL 1.2 SDK into $TOOLCHAIN"
