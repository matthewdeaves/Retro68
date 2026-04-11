#!/bin/bash
# Retro68 Toolchain Setup
#
# Installs prerequisites, extracts MPW Interfaces, builds the toolchain,
# and registers env vars in ~/.bashrc.
#
# Works on Ubuntu 24/25 and macOS with Homebrew.
#
# Usage:
#   ./setup.sh              # Full build (1-2 hours)
#   ./setup.sh --mpw-only   # Just extract MPW Interfaces (seconds)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${RETRO68_BUILD:-$HOME/Retro68-build}"
TOOLCHAIN_DIR="$BUILD_DIR/toolchain"
MPW_ZIP="$SCRIPT_DIR/resources/MPW_Interfaces.zip"
INTERFACES_DIR="$SCRIPT_DIR/InterfacesAndLibraries"

MPW_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --mpw-only) MPW_ONLY=true ;;
        --help|-h)
            echo "Usage: $0 [--mpw-only]"
            echo "  --mpw-only   Just extract MPW Interfaces, skip toolchain build"
            exit 0
            ;;
    esac
done

echo "Retro68 Toolchain Setup"
echo "======================="
echo ""

# ── Helpers ──────────────────────────────────────────────────────

check_tool() {
    if command -v "$1" &>/dev/null; then
        echo "  [ok] $1"
        return 0
    else
        echo "  [!!] $1 not found"
        return 1
    fi
}

detect_shell_rc() {
    case "$(basename "$SHELL")" in
        zsh)  echo "$HOME/.zshrc" ;;
        *)    echo "$HOME/.bashrc" ;;
    esac
}

SHELL_RC="$(detect_shell_rc)"

ensure_shell_export() {
    local var_name="$1" var_value="$2"
    if ! grep -q "export ${var_name}=" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Added by Retro68/setup.sh" >> "$SHELL_RC"
        echo "export ${var_name}=\"${var_value}\"" >> "$SHELL_RC"
        echo "  [ok] Added ${var_name} to $SHELL_RC"
    else
        echo "  [ok] ${var_name} already in $SHELL_RC"
    fi
}

# ── Extract MPW Interfaces ──────────────────────────────────────

echo "Checking MPW Interfaces..."
MPW_CINCLUDES="$INTERFACES_DIR/MPW_Interfaces/Interfaces&Libraries/Interfaces/CIncludes"

if [ -f "$MPW_CINCLUDES/MacTCP.h" ] && [ -f "$MPW_CINCLUDES/OpenTransport.h" ]; then
    echo "  [ok] MacTCP.h and OpenTransport.h found"
elif [ -f "$MPW_ZIP" ]; then
    echo "  [--] Extracting MPW Interfaces..."
    mkdir -p "$INTERFACES_DIR"
    unzip -o "$MPW_ZIP" -d "$INTERFACES_DIR/"
    if [ -f "$MPW_CINCLUDES/MacTCP.h" ] && [ -f "$MPW_CINCLUDES/OpenTransport.h" ]; then
        echo "  [ok] MPW Interfaces extracted successfully"
    else
        echo "  [!!] Extraction succeeded but headers not found at expected path"
        exit 1
    fi
else
    echo "  [!!] MPW_Interfaces.zip not found at $MPW_ZIP"
    echo "       The Multiversal Interfaces will be used instead (no MacTCP/OT support)"
fi

if [ "$MPW_ONLY" = true ]; then
    echo ""
    echo "MPW extraction complete. Use './setup.sh' (without --mpw-only) to build the full toolchain."
    exit 0
fi

# ── Check prerequisites ─────────────────────────────────────────

echo ""
echo "Checking prerequisites..."
MISSING=0
check_tool gcc || MISSING=1
check_tool g++ || MISSING=1
check_tool cmake || MISSING=1
check_tool make || MISSING=1
check_tool bison || MISSING=1
check_tool flex || MISSING=1
check_tool makeinfo || MISSING=1
check_tool ruby || MISSING=1

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo "Installing missing prerequisites..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential cmake git unzip \
            libgmp-dev libmpfr-dev libmpc-dev libboost-all-dev \
            bison flex texinfo ruby
    elif command -v brew &>/dev/null; then
        brew install cmake gmp mpfr libmpc boost bison flex texinfo ruby
    else
        echo "  [!!] No supported package manager found (need apt or brew)"
        exit 1
    fi

    echo ""
    echo "Verifying prerequisites after install..."
    STILL_MISSING=0
    for tool in gcc g++ cmake make bison flex makeinfo ruby; do
        check_tool "$tool" || STILL_MISSING=1
    done
    if [ "$STILL_MISSING" -eq 1 ]; then
        echo "  [!!] Some prerequisites are still missing after install. Please install them manually."
        exit 1
    fi
fi

# ── Initialize submodules ────────────────────────────────────────

echo ""
echo "Checking submodules..."
if [ -f "$SCRIPT_DIR/gcc/configure" ] && [ -f "$SCRIPT_DIR/multiversal/make-multiverse.rb" ]; then
    echo "  [ok] Submodules already initialized"
else
    echo "  [--] Initializing submodules (this downloads ~500MB)..."
    (cd "$SCRIPT_DIR" && git submodule update --init --recursive)
    echo "  [ok] Submodules initialized"
fi

# ── Build toolchain ──────────────────────────────────────────────

echo ""
echo "Building toolchain (this takes 1-2 hours)..."
echo "  Source:    $SCRIPT_DIR"
echo "  Build:     $BUILD_DIR"
echo "  Toolchain: $TOOLCHAIN_DIR"
echo ""

mkdir -p "$BUILD_DIR"
(cd "$BUILD_DIR" && "$SCRIPT_DIR/build-toolchain.bash")

echo ""
echo "  [ok] Toolchain build complete"

# ── Register environment variables ──────────────────────────────

echo ""
echo "Checking environment..."
ensure_shell_export "RETRO68_TOOLCHAIN" "$TOOLCHAIN_DIR"
ensure_shell_export "RETRO68_SRC" "$SCRIPT_DIR"

# Add to PATH if not already there
if ! grep -q 'RETRO68_TOOLCHAIN/bin' "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$RETRO68_TOOLCHAIN/bin:$PATH"' >> "$SHELL_RC"
    echo "  [ok] Added toolchain bin to PATH in $SHELL_RC"
else
    echo "  [ok] Toolchain bin already in PATH"
fi

export RETRO68_TOOLCHAIN="$TOOLCHAIN_DIR"
export RETRO68_SRC="$SCRIPT_DIR"
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

# ── Summary ─────────────────────────────────────────────────────

echo ""
echo "======================="
echo "Setup complete!"
echo ""
echo "  Toolchain:       $TOOLCHAIN_DIR"
echo "  m68k gcc:        $TOOLCHAIN_DIR/bin/m68k-apple-macos-gcc"
echo "  PPC gcc:         $TOOLCHAIN_DIR/bin/powerpc-apple-macos-gcc"
[ -f "$MPW_CINCLUDES/MacTCP.h" ] && \
echo "  MPW Interfaces:  $INTERFACES_DIR/MPW_Interfaces/"
echo ""
echo "Run 'source $SHELL_RC' to pick up env vars in this shell."
echo ""
