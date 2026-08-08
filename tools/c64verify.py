#!/usr/bin/env python3
"""
c64verify.py — verify C8's emitted artifacts from the FILES ALONE.

  python tools/c64verify.py [--dir build/c8] [--renders docs/reports/C8-renders]

Deliberately independent of `c64match.py`: it imports none of its functions and
shares none of its state. It opens `font-c64.bin` and `tileset-c64.bin`, rebuilds
the render from those bytes, and compares it to the PNG that was shipped. A
checker that shares the thing-under-test's inputs proves nothing (CLAUDE.md §8),
and the whole value of AC7 is that the render shows what the machine would draw.

What it establishes:
  AC3  every cell's glyph is the ORIGINAL PETSCII mask for that cell, in two
       colours — read back from assets/tileset.bin + the shipped font, not from
       anything c64match computed
  AC5  DECB structure: type $00, load $5200, 2,816 payload, nine 256-byte tables
  AC6  no nibble outside 0-15
  AC7  the shipped PNG is reproduced pixel-for-pixel from the two binaries
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, 'tools')
sys.path.insert(0, os.path.join('tools', 'glyph_tool'))

import decbmerge                                              # noqa: E402
import tilecorr                                               # noqa: E402
import sheet as S                                             # noqa: E402

FAILS = []


def check(name, ok, detail=''):
    print('%-4s %-46s %s' % ('PASS' if ok else 'FAIL', name, detail))
    if not ok:
        FAILS.append(name)


def unpack(raw, n):
    b = np.frombuffer(raw[:n * 32], dtype=np.uint8).reshape(n, 8, 4)
    out = np.empty((n, 8, 8), dtype=np.uint8)
    out[:, :, 0::2] = b >> 4                     # HIGH nibble is the LEFT pixel
    out[:, :, 1::2] = b & 0x0F
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', default='build/c8')
    ap.add_argument('--renders', default='docs/reports/C8-renders')
    ap.add_argument('--result', default='c8-result.png')
    args = ap.parse_args()

    fp = os.path.join(args.dir, 'font-c64.bin')
    tp = os.path.join(args.dir, 'tileset-c64.bin')
    with open(fp, 'rb') as f:
        raw = f.read()
    check('AC5 font is 6,144 B (192 x 32)', len(raw) == 6144, '%d B' % len(raw))
    font = unpack(raw, 192)
    check('AC6 every nibble is a palette index 0-15', int(font.max()) <= 15,
          'max nibble $%X' % int(font.max()))

    segs, _ = decbmerge.read_decb(tp)
    (addr, blob), = segs
    check('AC5 DECB: one segment, load $5200, 2,816 B',
          len(segs) == 1 and addr == 0x5200 and len(blob) == 2816,
          '$%04X-$%04X, %d B, file %d B'
          % (addr, addr + len(blob) - 1, len(blob), os.path.getsize(tp)))
    sizes = [len(blob[512 + i * 256:512 + (i + 1) * 256]) for i in range(9)]
    check('AC5 nine TILE_DATA tables of 256 B', sizes == [256] * 9, str(set(sizes)))

    codes = [[blob[512 + k * 256 + t] for k in range(9)] for t in range(256)]
    check('AC5 every cell has data', all(c is not None for r in codes for c in r),
          '2,304 cells (tile 255 BR present, post-C7)')

    # ---- AC3, from the ORIGINAL artifacts -------------------------------
    old_tiles = tilecorr.load_tiles()
    old_font = tilecorr.load_font()
    bad, flat = [], 0
    for t in range(256):
        for k in range(9):
            oc = old_tiles[t][k]
            if oc is None:
                continue
            mask = old_font[oc & 0x7F] != 0
            g = font[codes[t][k]]
            vals = set(g.reshape(-1).tolist())
            if len(vals) == 1:
                flat += 1
                continue                          # C64 cell is one flat colour
            if len(vals) != 2:
                bad.append((t, k, 'more than two colours'))
                continue
            c1 = int(g[mask][0]) if mask.any() else None
            c0 = int(g[~mask][0]) if (~mask).any() else None
            if not np.array_equal(g, np.where(mask, c1, c0)):
                bad.append((t, k, 'not the original mask'))
    check('AC3 every cell is its ORIGINAL PETSCII mask, recoloured', not bad,
          '%d cells checked, %d flat (source is one colour), %d bad'
          % (2304, flat, len(bad)))

    # ---- AC7, rebuild the render from the two binaries -------------------
    pal, _, _ = S.load_palette()
    idx = np.zeros((384, 384), dtype=np.uint8)
    for t in range(256):
        ty, tx = divmod(t, 16)
        for k in range(9):
            cy, cx = divmod(k, 3)
            idx[ty * 24 + cy * 8:ty * 24 + cy * 8 + 8,
                tx * 24 + cx * 8:tx * 24 + cx * 8 + 8] = font[codes[t][k]]
    rebuilt = pal[idx]
    shipped = np.asarray(Image.open(os.path.join(args.renders, args.result))
                         .convert('RGB'))
    same = int((rebuilt == shipped).all(axis=2).sum())
    check('AC7 render reproduced from the binaries alone',
          np.array_equal(rebuilt, shipped),
          '%d of %d pixels match' % (same, rebuilt.shape[0] * rebuilt.shape[1]))

    print('\n%d checks failed' % len(FAILS))
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
