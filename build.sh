#!/bin/sh
# build.sh — reproduce the CoCo3 PETSCII Robots binary and its boot disk.
#
# Produces, all under build/ (gitignored):
#   petrobots.bin   the assembled game            15,931 B, 9 segments
#   build.lst       lwasm listing
#   ROBOTSA.BIN     game + tileset + level_a      27,460 B, 11 segments
#   robots.dsk      DECB disk carrying ROBOTSA.BIN
#
# ROBOTSA.BIN is byte-compared against dist/ROBOTSA.BIN, the pre-verified
# reference copy. A mismatch means the tree no longer reproduces what was
# verified — the script fails rather than carrying on.
#
# Expect EXACTLY ONE lwasm warning:
#   Warning (src/PETROBOTS_6809.asm:3146): Operand size larger than required
# Any other warning or error is a regression (CLAUDE.md §1).
#
# NEVER mount build/robots.dsk in MAME directly — MAME opens floppies
# read-write and will rewrite it (mame-idioms-coco3-port.md §24). Mount a
# copy; run.sh does this for you.

set -e

LWASM=${LWASM:-lwasm}
IMGTOOL=${IMGTOOL:-imgtool}
PYTHON=${PYTHON:-python}

# SHA-256 of the verified ROBOTSA.BIN, established in A2 against the reference
# copy dist/ROBOTSA.BIN that shipped with the source package. Update this ONLY
# alongside a deliberate, authorized change to the sources or assets.
EXPECT_SHA256=13b8b4c078174abba8f059ebd35a1e9fb0b892b83a42ce8dd5fb34134b8f6c9a

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
mkdir -p build

echo "=== 1/4  assemble ==="
"$LWASM" --format=decb \
         --output=build/petrobots.bin \
         --list=build/build.lst \
         src/PETROBOTS_6809.asm

echo ""
echo "=== 2/4  merge game + tileset + level_a ==="
"$PYTHON" tools/decbmerge.py merge \
    --out build/ROBOTSA.BIN \
    --exec 0x0E01 \
    build/petrobots.bin \
    assets/tileset.bin \
    assets/levels/level_a.bin

echo ""
echo "=== 3/4  verify against the pre-verified reference ==="
# The pinned digest is the primary gate: /dist/ is gitignored, so a CLEAN
# CHECKOUT HAS NO dist/ROBOTSA.BIN and the byte-compare below cannot run there.
"$PYTHON" tools/decbmerge.py sha256 build/ROBOTSA.BIN --expect "$EXPECT_SHA256"
if [ -f dist/ROBOTSA.BIN ]; then
    "$PYTHON" tools/decbmerge.py compare build/ROBOTSA.BIN dist/ROBOTSA.BIN
else
    echo "  (dist/ROBOTSA.BIN absent — gitignored, so absent on a clean"
    echo "   checkout. The pinned digest above is the gate.)"
fi

echo ""
echo "=== 4/4  disk image ==="
rm -f build/robots.dsk
"$IMGTOOL" create coco_jvc_rsdos build/robots.dsk \
    --heads=1 --tracks=35 --sectors=18 --sectorlength=256
"$IMGTOOL" put coco_jvc_rsdos build/robots.dsk \
    build/ROBOTSA.BIN ROBOTSA.BIN --ftype=binary --ascii=binary
"$IMGTOOL" dir coco_jvc_rsdos build/robots.dsk

echo ""
echo "build OK — build/ROBOTSA.BIN and build/robots.dsk"
