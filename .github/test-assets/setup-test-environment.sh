#!/bin/bash
#
# Setup test environment for running Retro68 AutomatedTests with Mini vMac.
# Downloads the ROM from archive.org and assembles a self-contained directory
# with everything LaunchAPPL needs (ROM, emulator, system + AutoQuit disks and
# a LaunchAPPL.cfg pointing at them).
#
# Cross-platform: the committed Mini vMac binary in this directory is a Linux
# x86-64 ELF, used as-is on Linux/Ubuntu. On macOS (including Apple Silicon)
# that binary can't run, so this script obtains the native Mini vMac.app via
# Homebrew (LaunchAPPL takes the .app bundle directly on macOS -- see the
# "minivmac-path = ./Mini vMac.app" note in LaunchAPPL.cfg.example).
#
# Usage: ./setup-test-environment.sh [target-dir]
#   target-dir defaults to ./minivmac-test
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-$SCRIPT_DIR/minivmac-test}"
OS="$(uname -s)"

# ROM hosted on archive.org
ROM_URL="https://archive.org/download/vmac_20260209/vMac.ROM"

echo "=== Retro68 Test Environment Setup ==="
echo "Host: $OS $(uname -m)"
echo "Target directory: $TARGET_DIR"
echo

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Download ROM if not present
if [[ ! -f "vMac.ROM" ]]; then
    echo "Downloading Mac Plus ROM from archive.org..."
    curl -L -o vMac.ROM "$ROM_URL"
    echo "ROM downloaded: $(ls -lh vMac.ROM | awk '{print $5}')"
else
    echo "ROM already exists, skipping download"
fi

# Obtain Mini vMac for the host platform and record how LaunchAPPL should
# reference it (relative to TARGET_DIR).
if [[ "$OS" == "Darwin" ]]; then
    # macOS: LaunchAPPL wants the .app bundle, not a raw executable. Copy the
    # native Mini vMac.app into TARGET_DIR so the setup stays self-contained,
    # installing it with Homebrew first if it isn't already present.
    MINIVMAC_CFG_PATH="./Mini vMac.app"
    if [[ ! -d "Mini vMac.app" ]]; then
        APP_SRC=""
        for cand in "/Applications/Mini vMac.app" "$HOME/Applications/Mini vMac.app"; do
            [[ -d "$cand" ]] && APP_SRC="$cand" && break
        done
        if [[ -z "$APP_SRC" ]]; then
            if ! command -v brew >/dev/null 2>&1; then
                echo "Error: Mini vMac.app not found and Homebrew is not installed." >&2
                echo "Install Homebrew (https://brew.sh) or place Mini vMac.app in /Applications, then re-run." >&2
                exit 1
            fi
            echo "Installing Mini vMac via Homebrew (brew install --cask mini-vmac)..."
            brew install --cask mini-vmac
            for cand in "/Applications/Mini vMac.app" "$HOME/Applications/Mini vMac.app"; do
                [[ -d "$cand" ]] && APP_SRC="$cand" && break
            done
        fi
        if [[ -z "$APP_SRC" ]]; then
            echo "Error: Mini vMac.app still not found after install." >&2
            exit 1
        fi
        echo "Copying $APP_SRC ..."
        cp -R "$APP_SRC" "Mini vMac.app"
        echo "Mini vMac.app ready ($(du -sh "Mini vMac.app" | awk '{print $1}'))"
    else
        echo "Mini vMac.app already exists, skipping"
    fi
else
    # Linux/Ubuntu (and anything else): use the committed x86-64 ELF binary.
    MINIVMAC_CFG_PATH="./minivmac"
    if [[ ! -f "minivmac" ]]; then
        echo "Copying Mini vMac binary (Linux x86-64)..."
        cp "$SCRIPT_DIR/minivmac" minivmac
        chmod +x minivmac
        echo "Mini vMac copied: $(ls -lh minivmac | awk '{print $5}')"
    else
        echo "Mini vMac already exists, skipping copy"
    fi
fi

# Copy AutoQuit from test-assets
if [[ ! -f "autoquit.dsk" ]]; then
    echo "Copying AutoQuit disk..."
    cp "$SCRIPT_DIR/autoquit.dsk" autoquit.dsk
    echo "AutoQuit copied: $(ls -lh autoquit.dsk | awk '{print $5}')"
else
    echo "AutoQuit already exists, skipping copy"
fi

# Copy System 6 disk from test-assets
if [[ ! -f "system6.dsk" ]]; then
    echo "Copying System 6.0.8 disk..."
    cp "$SCRIPT_DIR/system6.dsk" system6.dsk
    echo "System disk copied: $(ls -lh system6.dsk | awk '{print $5}')"
else
    echo "System 6 disk already exists, skipping copy"
fi

# Create LaunchAPPL config (minivmac-path differs by platform, everything else
# is the same for Linux and macOS).
cat > LaunchAPPL.cfg << EOF
emulator = minivmac
minivmac-dir = $TARGET_DIR
minivmac-path = $MINIVMAC_CFG_PATH
minivmac-rom = ./vMac.ROM
system-image = ./system6.dsk
autoquit-image = ./autoquit.dsk
EOF

echo
echo "=== Setup Complete ==="
echo "Contents:"
ls -lh 2>/dev/null
echo
if [[ "$OS" == "Darwin" ]]; then
    echo "Run tests natively with the toolchain's LaunchAPPL, e.g.:"
    echo "  LaunchAPPL --config-file \"$TARGET_DIR/LaunchAPPL.cfg\" your-app.bin"
    echo "(Linux/Ubuntu users can instead run the full suite in Docker: ./run-tests-local.sh)"
else
    echo "To run tests locally with Docker:"
    echo "  ./run-tests-local.sh"
fi
