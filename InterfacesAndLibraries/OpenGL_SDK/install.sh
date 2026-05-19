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
TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT
for bin in "$SCRIPT_DIR/Libraries/"*.bin; do
    stub_name=$(basename "$bin" .bin)     # OpenGLLibraryStub
    lib_name=${stub_name%Stub}            # OpenGLLibrary
    out="$PPC_LIB/lib${lib_name}.a"
    "$TOOLCHAIN/bin/MakeImport" "$bin" "$out"
    printf "    %-25s -> %s\n" "$(basename "$bin")" "lib${lib_name}.a"
done

echo
echo "Installed OpenGL SDK. Test with:"
echo "  echo '#include <agl.h>' | $TOOLCHAIN/bin/powerpc-apple-macos-gcc -E -x c - >/dev/null"
