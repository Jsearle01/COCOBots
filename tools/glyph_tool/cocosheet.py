#!/usr/bin/env python3
"""
cocosheet.py — emit the CoCo-palette reference sheets at native 384x384 (C6-A4).

  python tools/glyph_tool/cocosheet.py [--out DIR] [--glyphs 192]

TWO SHEETS, AND THE DIFFERENCE IS THE WHOLE POINT (C6-A4 §2). C4 §9 item 1
records presenting a per-pixel quantisation as though it were an engine render,
which is an upper bound mistaken for machine output. So both are emitted, both
are measured, and each is labelled by what it is:

  coco-quantised   every Amiga pixel snapped to the adopted 16. ALL distinct
                   cell appearances survive. This is the CEILING — correct
                   colours, NOT reachable in 151 glyph slots.
  coco-engine      drawn through the glyph model: each cell is whatever glyph
                   tileset-192.bin points at, rendered from font-192.bin. This
                   is a REACHABLE target — what the machine can actually show.

The test that separates them is the count of distinct 8x8 cell appearances:
~1,962 means per-pixel, a couple of hundred means engine render. Measured, not
assumed.

**Regenerated from source at 1:1, never rescaled.** C5's composite is 1592 px
per panel with label text baked in; resampling that back to 384 would resample
the colours too and produce off-palette pixels.

NOT emitted by repalette.py — that module derives palettes and writes JSON, and
has no render path at all (C6-A4 §7). C5's PNGs were produced ad hoc in a
conversational thread with no dispatch, so there was no committed script to
re-run. This file is that script.
"""
import argparse
import collections
import hashlib
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config as C                                            # noqa: E402
import glyphio                                                # noqa: E402
import sheet as S                                             # noqa: E402
from tilemap import Mapping                                   # noqa: E402

GRID = S.GRID           # 384
PITCH = S.PITCH         # 24


def quantised_sheet(pal_rgb):
    """Per-pixel: the Amiga art snapped to the adopted 16. The ceiling."""
    _, rgb = S.quantise(S.load_sheet(C.SHEET_AMIGA), pal_rgb)
    return rgb


def engine_sheet(cfg, pal_rgb, font=None):
    """Engine render: every cell drawn from the glyph its tile table points at.

    This is what the machine shows, so it is bounded by the glyph budget and
    inherits every merge the allocator made.
    """
    m = Mapping(cfg)
    if font is None:
        src = cfg.out_font if os.path.exists(cfg.out_font) else cfg.font
        font = glyphio.load_font(src, cfg.n_glyphs,
                                 cfg.font_addr if src == cfg.font else None)
    idx = np.zeros((GRID, GRID), dtype=np.uint8)
    for t in range(256):
        ty, tx = divmod(t, 16)
        for k in range(9):
            cy, cx = divmod(k, 3)
            g = m.glyphs[t][k]
            px = (np.zeros((8, 8), np.uint8) if g is None or g >= len(font)
                  else font[g])
            if g is not None and m.inverse[t][k]:
                px = 15 - px
            y, x = ty * PITCH + cy * 8, tx * PITCH + cx * 8
            idx[y:y + 8, x:x + 8] = px
    return pal_rgb[idx]


def distinct_cells(rgb):
    """How many distinct 8x8 cell appearances the sheet holds — the measurement
    that classifies it (C6-A4 AC2)."""
    seen = set()
    for t in range(256):
        ty, tx = divmod(t, 16)
        for k in range(9):
            cy, cx = divmod(k, 3)
            y, x = ty * PITCH + cy * 8, tx * PITCH + cx * 8
            seen.add(rgb[y:y + 8, x:x + 8].tobytes())
    return len(seen)


def off_palette(rgb, pal_rgb):
    """Pixels that are not one of the 16 adopted colours. Must be zero."""
    flat = rgb.reshape(-1, 3)
    ok = np.zeros(len(flat), dtype=bool)
    for c in pal_rgb:
        ok |= (flat == c).all(axis=1)
    return int((~ok).sum())


def classify(n_cells):
    return 'per-pixel quantisation' if n_cells > 600 else 'engine render'


def emit(path, rgb):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    Image.fromarray(rgb).save(path)          # 1:1, no scaling, ever
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='art')
    ap.add_argument('--renders', default='docs/reports/C6-A4-renders')
    ap.add_argument('--config', default='a192', choices=sorted(C.CONFIGS))
    args = ap.parse_args()

    pal_rgb, pal_bytes, _ = S.load_palette()
    cfg = C.CONFIGS[args.config]
    print('palette from assets/palette.json: %s'
          % ' '.join('$%02X' % b for b in pal_bytes))

    out = {}
    for name, rgb in (('coco-quantised', quantised_sheet(pal_rgb)),
                      ('coco-engine', engine_sheet(cfg, pal_rgb))):
        n = distinct_cells(rgb)
        bad = off_palette(rgb, pal_rgb)
        for d in (args.out, args.renders):
            sha = emit(os.path.join(C.REPO, d, '%s.png' % name), rgb)
        print('%-15s %dx%d  distinct 8x8 cells %5d  -> %-24s off-palette px %d  sha256 %s'
              % (name, rgb.shape[1], rgb.shape[0], n, classify(n), bad, sha[:32]))
        out[name] = (n, bad, sha)
    return 0


if __name__ == '__main__':
    sys.exit(main())
