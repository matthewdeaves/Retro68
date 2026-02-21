#!/bin/bash
#
# Run Retro68 automated tests inside Docker container
# This script is called by the GitHub Actions nightly workflow
#

set -euo pipefail

WORKSPACE="${1:-/workspace}"
TEST_ENV="$WORKSPACE/.github/test-assets/minivmac-test"
BUILD_DIR="$WORKSPACE/build-test"

# Install dependencies (skip if running as non-root or already installed)
echo "=== Installing test dependencies ==="
if [ "$(id -u)" = "0" ]; then
    apt-get update && apt-get install -y xvfb libsdl2-2.0-0
else
    echo "Running as non-root, skipping apt-get (assuming dependencies are installed)"
fi

# Configure LaunchAPPL - use workspace location for config to avoid permission issues
echo "=== Configuring LaunchAPPL ==="
LAUNCHAPPL_CFG="$WORKSPACE/.github/test-assets/minivmac-test/.LaunchAPPL.cfg"
cat > "$LAUNCHAPPL_CFG" << EOF
emulator = minivmac
minivmac-dir = $TEST_ENV
minivmac-path = ./minivmac
minivmac-rom = ./vMac.ROM
system-image = ./system6.dsk
autoquit-image = ./autoquit.dsk
EOF
export HOME="$WORKSPACE/.github/test-assets/minivmac-test"

echo "=== Building tests ==="
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake "$WORKSPACE" \
    -DCMAKE_TOOLCHAIN_FILE=/Retro68-build/toolchain/m68k-apple-macos/cmake/retro68.toolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=/Retro68-build/toolchain/m68k-apple-macos

make -j$(nproc) LaunchAPPL
make -j$(nproc) -C AutomatedTests

echo "=== Running tests under Xvfb ==="
cd AutomatedTests

# Use dummy audio driver to avoid ALSA errors in Docker
export SDL_AUDIODRIVER=dummy

# Run tests, excluding 68020-specific tests (Mini vMac emulates 68000)
# PCRel32 requires 68020 instructions not available on Mac Plus
TEST_RESULT=0
xvfb-run -a ctest --output-on-failure --timeout 120 -E "PCRel32" || TEST_RESULT=$?

# Fix ownership of build directory if running as root, so host user can clean up
if [ "$(id -u)" = "0" ] && [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
    echo "=== Fixing file ownership ==="
    chown -R "$HOST_UID:$HOST_GID" "$BUILD_DIR"
fi

echo "=== Tests Complete ==="
exit $TEST_RESULT
