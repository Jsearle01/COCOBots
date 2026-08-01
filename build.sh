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
"$PYTHON" tools/decbmerge.py compare build/ROBOTSA.BIN dist/ROBOTSA.BIN

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
