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

# SHA-256 of the verified ROBOTSA.BIN. Update this ONLY alongside a deliberate,
# authorized change to the sources or assets.
#   A2  13b8b4c0...  the reference copy that shipped with the source package
#   C7  c0254b09...  assets/tileset.bin completed to its full 2,816 bytes
# C7 note: the tree no longer reproduces the A2-era dist/ROBOTSA.BIN, BY
# AUTHORIZATION — the tileset segment is one byte longer. That copy is kept
# locally as dist/ROBOTSA.BIN.pre-c7 and is deliberately NOT refreshed from our
# own build: a reference regenerated from the thing it checks proves nothing
# (CLAUDE.md 8). The pinned digest below is the gate.
EXPECT_SHA256=c0254b09aeb5498dc03956ebe8282dd574cf30edb3f231bbfed010d697f8e6c4

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
