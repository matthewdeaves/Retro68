#!/bin/bash
#
# Setup test environment for running Retro68 AutomatedTests with Mini vMac
# Downloads ROM from archive.org, copies other assets from test-assets
#
# Usage: ./setup-test-environment.sh [target-dir]
#   target-dir defaults to ./minivmac-test
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-$SCRIPT_DIR/minivmac-test}"

# ROM hosted on archive.org
ROM_URL="https://archive.org/download/vmac_20260209/vMac.ROM"

echo "=== Retro68 Test Environment Setup ==="
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

# Copy Mini vMac binary from test-assets
if [[ ! -f "minivmac" ]]; then
    echo "Copying Mini vMac binary..."
    cp "$SCRIPT_DIR/minivmac" minivmac
    chmod +x minivmac
    echo "Mini vMac copied: $(ls -lh minivmac | awk '{print $5}')"
else
    echo "Mini vMac already exists, skipping copy"
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

# Create LaunchAPPL config
cat > LaunchAPPL.cfg << EOF
emulator = minivmac
minivmac-dir = $TARGET_DIR
minivmac-path = ./minivmac
minivmac-rom = ./vMac.ROM
system-image = ./system6.dsk
autoquit-image = ./autoquit.dsk
EOF

echo
echo "=== Setup Complete ==="
echo "Contents:"
ls -lh *.dsk *.ROM minivmac 2>/dev/null || ls -lh
echo
echo "To run tests locally with Docker:"
echo "  ./run-tests-local.sh"
