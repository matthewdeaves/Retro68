#!/bin/bash
#
# Test script v2 for issue #305 - deeper investigation
#
# 1. Verify the glue fix is actually linked into the binary
# 2. Create a diagnostic test that reports exactly WHERE things hang
# 3. Test with AND without the fix
#

set -euo pipefail

WORKSPACE="${1:-/workspace}"
TEST_ENV="$WORKSPACE/.github/test-assets/minivmac-test"
TOOLCHAIN="/Retro68-build/toolchain"
GLUE_SRC="$TOOLCHAIN/multiversal/src/glue.c"
LIB_INTERFACE="$TOOLCHAIN/m68k-apple-macos/lib/libInterface.a"
MULTI_LIB="$TOOLCHAIN/multiversal/lib68k/libInterface.a"
GLUE_OBJ="$TOOLCHAIN/multiversal/obj/glue.o"

apt-get update -qq && apt-get install -y -qq xvfb libsdl2-2.0-0 > /dev/null 2>&1

# Configure LaunchAPPL
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
echo "PHASE 1: STOCK toolchain - run StdIO test"
echo "=========================================="
echo ""

BUILD="$WORKSPACE/build-305"
rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"
cmake "$WORKSPACE" \
    -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN/m68k-apple-macos/cmake/retro68.toolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN/m68k-apple-macos \
    > /dev/null 2>&1
make -j$(nproc) LaunchAPPL > /dev/null 2>&1
make -j$(nproc) -C AutomatedTests > /dev/null 2>&1

echo "=== Checking if HOpenDF in the linked binary has ioFVersNum zeroing ==="
echo "Disassembling HOpenDF from stock libInterface.a:"
m68k-apple-macos-objdump -d "$LIB_INTERFACE" 2>/dev/null | grep -A 30 "<HOpenDF>:" | head -35
echo ""

echo "=== Running StdIO test with STOCK toolchain ==="
cd "$BUILD/AutomatedTests"
STOCK_RESULT=0
xvfb-run -a ctest --output-on-failure --timeout 30 -R "StdIO" || STOCK_RESULT=$?
echo ">>> STOCK StdIO exit code: $STOCK_RESULT"
echo ""

echo "=========================================="
echo "PHASE 2: Create diagnostic test"
echo "=========================================="
echo ""

# Create a diagnostic test that writes output using ONLY direct
# PBHOpenSync with PROPERLY ZEROED ioFVersNum (bypassing both the glue bug AND Test.h bug)
cat > "$WORKSPACE/AutomatedTests/Diag305.c" << 'TESTEOF'
#include <Files.h>
#include <Devices.h>
#include <string.h>
#include <stdio.h>

/*
 * Diagnostic test for issue #305
 *
 * Uses direct PBHOpenSync with explicitly zeroed ioFVersNum for output
 * (bypassing both the glue.c bug and Test.h bug)
 * Then tests fopen/fclose to see if THAT path works.
 */

/* Write a string to the 'out' file using only direct File Manager calls
 * with properly zeroed parameter block */
static void safe_log(const char *str)
{
    HParamBlockRec hpb;
    short ref;
    unsigned char fileName[4];

    /* Zero the ENTIRE parameter block to be safe */
    memset(&hpb, 0, sizeof(hpb));

    fileName[0] = 3;
    fileName[1] = 'o';
    fileName[2] = 'u';
    fileName[3] = 't';

    hpb.ioParam.ioCompletion = NULL;
    hpb.ioParam.ioNamePtr = (StringPtr)fileName;
    hpb.ioParam.ioVRefNum = 0;
    hpb.fileParam.ioDirID = 0;
    hpb.fileParam.ioFVersNum = 0;  /* THE KEY FIX */
    hpb.ioParam.ioPermssn = fsRdWrPerm;
    hpb.ioParam.ioMisc = NULL;
    PBHOpenSync(&hpb);
    ref = hpb.ioParam.ioRefNum;

    hpb.ioParam.ioCompletion = NULL;
    hpb.ioParam.ioBuffer = (Ptr)str;
    hpb.ioParam.ioReqCount = strlen(str);
    hpb.ioParam.ioPosMode = fsFromLEOF;
    hpb.ioParam.ioPosOffset = 0;
    hpb.ioParam.ioRefNum = ref;
    hpb.ioParam.ioMisc = NULL;
    PBWriteSync((ParmBlkPtr)&hpb);

    /* Write newline */
    {
        char nl = '\n';
        hpb.ioParam.ioBuffer = &nl;
        hpb.ioParam.ioReqCount = 1;
        hpb.ioParam.ioPosMode = fsFromLEOF;
        hpb.ioParam.ioPosOffset = 0;
        PBWriteSync((ParmBlkPtr)&hpb);
    }

    hpb.ioParam.ioCompletion = NULL;
    hpb.ioParam.ioRefNum = ref;
    PBCloseSync((ParmBlkPtr)&hpb);

    hpb.ioParam.ioCompletion = NULL;
    hpb.ioParam.ioNamePtr = NULL;
    hpb.ioParam.ioVRefNum = 0;
    PBFlushVolSync((ParmBlkPtr)&hpb);
}

int main(void)
{
    FILE *f;
    OSErr err;
    HParamBlockRec pb;
    short ref;
    unsigned char testName[9];

    safe_log("DIAG305: Starting diagnostics");

    /* Test 1: Direct HOpenDF call (uses glue code) */
    safe_log("TEST1: Calling HOpenDF via glue...");
    testName[0] = 8;
    testName[1] = 't'; testName[2] = 'e'; testName[3] = 's';
    testName[4] = 't'; testName[5] = 'f'; testName[6] = 'i';
    testName[7] = 'l'; testName[8] = 'e';

    err = HCreate(0, 0, testName, '????', 'TEXT');
    safe_log(err == noErr || err == dupFNErr ? "TEST1: HCreate OK" : "TEST1: HCreate FAILED");

    err = HOpenDF(0, 0, testName, fsRdWrPerm, &ref);
    if (err == noErr) {
        safe_log("TEST1: HOpenDF returned noErr - PASS");
        FSClose(ref);
    } else if (err == paramErr) {
        safe_log("TEST1: HOpenDF returned paramErr - THIS IS THE BUG");
        /* Try HOpen as fallback (same as syscalls.c does) */
        err = HOpen(0, 0, testName, fsRdWrPerm, &ref);
        if (err == noErr) {
            safe_log("TEST1: HOpen fallback returned noErr");
            FSClose(ref);
        } else if (err == paramErr) {
            safe_log("TEST1: HOpen fallback ALSO returned paramErr - BOTH BUGGED");
        } else {
            safe_log("TEST1: HOpen fallback returned other error");
        }
    } else {
        safe_log("TEST1: HOpenDF returned other error");
    }

    /* Test 2: Direct PBHOpenSync with zeroed ioFVersNum (known-good path) */
    safe_log("TEST2: Direct PBHOpenSync with zeroed ioFVersNum...");
    memset(&pb, 0, sizeof(pb));
    pb.ioParam.ioNamePtr = (StringPtr)testName;
    pb.ioParam.ioVRefNum = 0;
    pb.fileParam.ioDirID = 0;
    pb.fileParam.ioFVersNum = 0;
    pb.ioParam.ioPermssn = fsRdWrPerm;
    err = PBHOpenSync(&pb);
    if (err == noErr) {
        safe_log("TEST2: PBHOpenSync (zeroed) returned noErr - PASS");
        FSClose(pb.ioParam.ioRefNum);
    } else {
        safe_log("TEST2: PBHOpenSync (zeroed) FAILED");
    }

    /* Test 3: fopen via C library (uses HOpenDF glue internally) */
    safe_log("TEST3: Calling fopen via C library...");
    f = fopen("testfile", "w");
    if (f != NULL) {
        safe_log("TEST3: fopen returned non-NULL - PASS");
        safe_log("TEST3: Calling fprintf...");
        fprintf(f, "hello");
        safe_log("TEST3: fprintf done, calling fclose...");
        fclose(f);
        safe_log("TEST3: fclose done - PASS");
    } else {
        safe_log("TEST3: fopen returned NULL - FAIL (this is the bug!)");
    }

    safe_log("OK");
    return 0;
}
TESTEOF

echo "=== Adding diagnostic test to CMakeLists.txt ==="
# Add the test temporarily
cd "$WORKSPACE"
if ! grep -q "Diag305" AutomatedTests/CMakeLists.txt; then
    echo 'test(Diag305.c PROPERTIES PASS_REGULAR_EXPRESSION "OK" TIMEOUT 30)' >> AutomatedTests/CMakeLists.txt
fi

echo ""
echo "=========================================="
echo "PHASE 3: Run diagnostic with STOCK toolchain"
echo "=========================================="
echo ""

cd "$BUILD"
cmake "$WORKSPACE" \
    -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN/m68k-apple-macos/cmake/retro68.toolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN/m68k-apple-macos \
    > /dev/null 2>&1
make -j$(nproc) LaunchAPPL > /dev/null 2>&1
make -j$(nproc) -C AutomatedTests Diag305 > /dev/null 2>&1

echo "=== Running Diag305 with STOCK toolchain ==="
cd "$BUILD/AutomatedTests"
DIAG_STOCK=0
xvfb-run -a ctest --output-on-failure --timeout 30 -R "Diag305" -V || DIAG_STOCK=$?
echo ">>> STOCK Diag305 exit code: $DIAG_STOCK"

echo ""
echo "=========================================="
echo "PHASE 4: PATCH glue.c, rebuild, re-test"
echo "=========================================="
echo ""

# Backup
cp "$GLUE_SRC" "$GLUE_SRC.bak"
cp "$LIB_INTERFACE" "$LIB_INTERFACE.bak"
cp "$MULTI_LIB" "$MULTI_LIB.bak"

# Apply fix
sed -i '/pascal OSErr HOpenRF/,/OSErr err = PBHOpenRFSync/{
    /pb.ioParam.ioPermssn = perm;/i\    pb.fileParam.ioFVersNum = 0;
}' "$GLUE_SRC"
sed -i '/pascal OSErr HOpen\b/,/OSErr err = PBHOpenSync/{
    /pb.ioParam.ioPermssn = perm;/i\    pb.fileParam.ioFVersNum = 0;
}' "$GLUE_SRC"
sed -i '/pascal OSErr HOpenDF/,/OSErr err = PBHOpenDFSync/{
    /pb.ioParam.ioPermssn = perm;/i\    pb.fileParam.ioFVersNum = 0;
}' "$GLUE_SRC"

echo "=== Patched glue.c - verifying ==="
grep -B2 -A2 "ioFVersNum" "$GLUE_SRC"
echo ""

# Recompile and replace
m68k-apple-macos-gcc -c "$GLUE_SRC" -o "$GLUE_OBJ" \
    -I"$TOOLCHAIN/multiversal/src" \
    -I"$TOOLCHAIN/m68k-apple-macos/include" \
    -O2 2>/dev/null

for lib in "$LIB_INTERFACE" "$MULTI_LIB"; do
    m68k-apple-macos-ar d "$lib" glue.o
    m68k-apple-macos-ar r "$lib" "$GLUE_OBJ"
    m68k-apple-macos-ranlib "$lib"
done

# CLEAN rebuild to ensure re-linking
echo "=== Clean rebuild with patched toolchain ==="
BUILD_FIXED="$WORKSPACE/build-305-fixed"
rm -rf "$BUILD_FIXED"
mkdir -p "$BUILD_FIXED"
cd "$BUILD_FIXED"
cmake "$WORKSPACE" \
    -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN/m68k-apple-macos/cmake/retro68.toolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN/m68k-apple-macos \
    > /dev/null 2>&1
make -j$(nproc) LaunchAPPL > /dev/null 2>&1
make -j$(nproc) -C AutomatedTests Diag305 StdIO > /dev/null 2>&1

echo "=== Running Diag305 with PATCHED toolchain ==="
cd "$BUILD_FIXED/AutomatedTests"
DIAG_PATCHED=0
xvfb-run -a ctest --output-on-failure --timeout 30 -R "Diag305" -V || DIAG_PATCHED=$?
echo ">>> PATCHED Diag305 exit code: $DIAG_PATCHED"

echo ""
echo "=== Running StdIO with PATCHED toolchain ==="
STDIO_PATCHED=0
xvfb-run -a ctest --output-on-failure --timeout 30 -R "StdIO" -V || STDIO_PATCHED=$?
echo ">>> PATCHED StdIO exit code: $STDIO_PATCHED"

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "STOCK toolchain:"
echo "  StdIO:   exit=$STOCK_RESULT"
echo "  Diag305: exit=$DIAG_STOCK"
echo ""
echo "PATCHED toolchain (glue.c ioFVersNum fix):"
echo "  Diag305: exit=$DIAG_PATCHED"
echo "  StdIO:   exit=$STDIO_PATCHED"

# Restore
cp "$GLUE_SRC.bak" "$GLUE_SRC"
cp "$LIB_INTERFACE.bak" "$LIB_INTERFACE"
cp "$MULTI_LIB.bak" "$MULTI_LIB"

# Clean up diagnostic test
cd "$WORKSPACE"
sed -i '/Diag305/d' AutomatedTests/CMakeLists.txt
rm -f AutomatedTests/Diag305.c
