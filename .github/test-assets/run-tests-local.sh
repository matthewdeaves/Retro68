#!/bin/bash
#
# Run Retro68 automated tests locally using Docker
#
# Prerequisites:
#   1. Docker installed and running
#   2. Run ./setup-test-environment.sh first (or have minivmac set up)
#
# Usage: ./run-tests-local.sh
#
# Environment variables:
#   RETRO68_IMAGE - Docker image to use (default: ghcr.io/matthewdeaves/retro68:latest)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RETRO68_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_ENV_DIR="$SCRIPT_DIR/minivmac-test"

# Allow overriding the Docker image via environment variable
RETRO68_IMAGE="${RETRO68_IMAGE:-ghcr.io/matthewdeaves/retro68:latest}"

# Check if test environment exists
if [[ ! -d "$TEST_ENV_DIR" ]]; then
    echo "Test environment not found. Running setup..."
    "$SCRIPT_DIR/setup-test-environment.sh"
fi

# Check for required files
for file in minivmac vMac.ROM system6.dsk autoquit.dsk; do
    if [[ ! -f "$TEST_ENV_DIR/$file" ]]; then
        echo "Error: Missing $file in $TEST_ENV_DIR"
        echo "Run ./setup-test-environment.sh first"
        exit 1
    fi
done

echo "=== Running Retro68 Automated Tests ==="
echo "Docker image: $RETRO68_IMAGE"
echo "Test environment: $TEST_ENV_DIR"
echo "Retro68 source: $RETRO68_DIR"
echo

# Run tests using run-tests-docker.sh (handles SDL2, xvfb, etc.)
docker run --rm \
    -v "$RETRO68_DIR:/workspace" \
    "$RETRO68_IMAGE" \
    /workspace/.github/test-assets/run-tests-docker.sh /workspace

echo
echo "=== Tests Complete ==="
