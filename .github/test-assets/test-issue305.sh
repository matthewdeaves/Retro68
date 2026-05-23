#!/bin/bash
#
# Test script for issue #305: does the ioFVersNum fix in glue.c fix fclose?
#
# This script:
# 1. Builds and runs the StdIO test with the STOCK toolchain
# 2. Patches glue.o with the ioFVersNum fix
# 3. Rebuilds and runs the StdIO test with the PATCHED toolchain
#

set -euo pipefail

WORKSPACE="${1:-/workspace}"
TEST_ENV="$WORKSPACE/.github/test-assets/minivmac-test"
BUILD_STOCK="$WORKSPACE/build-stock"
BUILD_PATCHED="$WORKSPACE/build-patched"
TOOLCHAIN="/Retro68-build/toolchain"
GLUE_SRC="$TOOLCHAIN/multiversal/src/glue.c"
LIB_INTERFACE="$TOOLCHAIN/m68k-apple-macos/lib/libInterface.a"

# Install dependencies
echo "=== Installing dependencies ==="
apt-get update -qq && apt-get install -y -qq xvfb libsdl2-2.0-0 > /dev/null 2>&1

# Configure LaunchAPPL
echo "=== Configuring LaunchAPPL ==="
LAUNCHAPPL_CFG="$TEST_ENV/.LaunchAPPL.cfg"
cat > "$LAUNCHAPPL_CFG" << EOF
emulator = minivmac
minivmac-dir = $TEST_ENV
minivmac-path = ./minivmac
minivmac-rom = ./vMac.ROM
system-image = ./system6.dsk
autoquit-image = ./autoquit.dsk
EOF
export HOME="$TEST_ENV"
export SDL_AUDIODRIVER=dummy

echo ""
echo "=========================================="
echo "PHASE 1: STOCK TOOLCHAIN (no fix)"
echo "=========================================="
echo ""

# Show the unpatched glue code for HOpenDF
echo "=== Current HOpenDF in glue.c (no ioFVersNum init) ==="
grep -A 10 "pascal OSErr HOpenDF" "$GLUE_SRC" | head -12
echo ""

# Build with stock toolchain
echo "=== Building with stock toolchain ==="
mkdir -p "$BUILD_STOCK"
cd "$BUILD_STOCK"
cmake "$WORKSPACE" \
    -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN/m68k-apple-macos/cmake/retro68.toolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN/m68k-apple-macos \
    > /dev/null 2>&1
make -j$(nproc) LaunchAPPL > /dev/null 2>&1
make -j$(nproc) -C AutomatedTests StdIO > /dev/null 2>&1

echo "=== Running StdIO test with STOCK toolchain ==="
cd AutomatedTests
STOCK_RESULT=0
xvfb-run -a ctest --output-on-failure --timeout 30 -R "StdIO" || STOCK_RESULT=$?
echo ""
echo ">>> STOCK toolchain StdIO test exit code: $STOCK_RESULT"
if [ $STOCK_RESULT -ne 0 ]; then
    echo ">>> STOCK: StdIO FAILED (this reproduces issue #305)"
else
    echo ">>> STOCK: StdIO PASSED (issue #305 NOT reproduced)"
fi

echo ""
echo "=========================================="
echo "PHASE 2: PATCH glue.c with ioFVersNum fix"
echo "=========================================="
echo ""

# Backup original
cp "$GLUE_SRC" "$GLUE_SRC.bak"
cp "$LIB_INTERFACE" "$LIB_INTERFACE.bak"

# Apply the fix to glue.c
echo "=== Patching glue.c ==="
sed -i '/pascal OSErr HOpenRF/,/OSErr err = PBHOpenRFSync/{
    /pb.ioParam.ioPermssn = perm;/i\    pb.fileParam.ioFVersNum = 0;
}' "$GLUE_SRC"

sed -i '/pascal OSErr HOpen\b/,/OSErr err = PBHOpenSync/{
    /pb.ioParam.ioPermssn = perm;/i\    pb.fileParam.ioFVersNum = 0;
}' "$GLUE_SRC"

sed -i '/pascal OSErr HOpenDF/,/OSErr err = PBHOpenDFSync/{
    /pb.ioParam.ioPermssn = perm;/i\    pb.fileParam.ioFVersNum = 0;
}' "$GLUE_SRC"

echo "=== Patched HOpenDF in glue.c ==="
grep -A 12 "pascal OSErr HOpenDF" "$GLUE_SRC" | head -14
echo ""

# Recompile glue.o
echo "=== Recompiling glue.o ==="
GLUE_OBJ="$TOOLCHAIN/multiversal/obj/glue.o"
m68k-apple-macos-gcc -c "$GLUE_SRC" -o "$GLUE_OBJ" \
    -I"$TOOLCHAIN/multiversal/src" \
    -I"$TOOLCHAIN/m68k-apple-macos/include" \
    -O2

# Replace in libInterface.a (properly: delete old, add new with same name)
echo "=== Replacing glue.o in libInterface.a ==="
cd "$(dirname "$LIB_INTERFACE")"
m68k-apple-macos-ar d "$LIB_INTERFACE" glue.o
m68k-apple-macos-ar r "$LIB_INTERFACE" "$GLUE_OBJ"
m68k-apple-macos-ranlib "$LIB_INTERFACE"

# Also replace in the multiversal lib directory
MULTI_LIB="$TOOLCHAIN/multiversal/lib68k/libInterface.a"
cd "$(dirname "$MULTI_LIB")"
m68k-apple-macos-ar d "$MULTI_LIB" glue.o
m68k-apple-macos-ar r "$MULTI_LIB" "$GLUE_OBJ"
m68k-apple-macos-ranlib "$MULTI_LIB"

# Verify the fix is in the library
echo "=== Verifying glue.o in libInterface.a ==="
m68k-apple-macos-ar t "$LIB_INTERFACE" | grep glue
echo "(should show exactly one glue.o)"

echo ""
echo "=========================================="
echo "PHASE 3: PATCHED TOOLCHAIN (with fix)"
echo "=========================================="
echo ""

# Build with patched toolchain (clean build to ensure re-linking)
echo "=== Building with PATCHED toolchain ==="
mkdir -p "$BUILD_PATCHED"
cd "$BUILD_PATCHED"
cmake "$WORKSPACE" \
    -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN/m68k-apple-macos/cmake/retro68.toolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN/m68k-apple-macos \
    > /dev/null 2>&1
make -j$(nproc) LaunchAPPL > /dev/null 2>&1
make -j$(nproc) -C AutomatedTests StdIO > /dev/null 2>&1

echo "=== Running StdIO test with PATCHED toolchain ==="
cd AutomatedTests
PATCHED_RESULT=0
xvfb-run -a ctest --output-on-failure --timeout 30 -R "StdIO" || PATCHED_RESULT=$?
echo ""
echo ">>> PATCHED toolchain StdIO test exit code: $PATCHED_RESULT"
if [ $PATCHED_RESULT -ne 0 ]; then
    echo ">>> PATCHED: StdIO FAILED (fix did NOT help)"
else
    echo ">>> PATCHED: StdIO PASSED (fix WORKS!)"
fi

echo ""
echo "=========================================="
echo "PHASE 4: Run FULL test suite with patched toolchain"
echo "=========================================="
echo ""

cd "$BUILD_PATCHED/AutomatedTests"
make -j$(nproc) > /dev/null 2>&1
FULL_RESULT=0
xvfb-run -a ctest --output-on-failure --timeout 120 -E "PCRel32" || FULL_RESULT=$?

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "Stock toolchain:   StdIO exit code = $STOCK_RESULT"
echo "Patched toolchain: StdIO exit code = $PATCHED_RESULT"
echo "Full test suite:   exit code = $FULL_RESULT"
echo ""
if [ $STOCK_RESULT -ne 0 ] && [ $PATCHED_RESULT -eq 0 ]; then
    echo "CONCLUSION: ioFVersNum fix in glue.c FIXES issue #305"
elif [ $STOCK_RESULT -eq 0 ]; then
    echo "CONCLUSION: Could not reproduce issue #305 (stock passed)"
else
    echo "CONCLUSION: Fix did NOT resolve the issue"
fi

# Restore originals
cp "$GLUE_SRC.bak" "$GLUE_SRC"
cp "$LIB_INTERFACE.bak" "$LIB_INTERFACE"
