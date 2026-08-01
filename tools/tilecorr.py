#!/usr/bin/env python3
"""
tilecorr.py — measure the correspondence between an artwork sheet's tile grid
and `tileset.bin`'s tile indices.

C1 recon. This VERIFIES a believed mapping (identity: sheet index n <-> tileset
index n); it does not search for an unknown one. It changes no data.

WHAT IT COMPARES

  tileset side (exact)
    Each tile is 9 character codes (TILE_DATA_TL..BR at $5200+512+k*256).
    Each code indexes the 128-glyph font at $41F6, 8x8 at 4bpp, 32 B/glyph.
    BITMAP_PLOTTER masks the code with $7F; a set high bit means inverse video
    (COMA/COMB complements every nibble, n -> 15-n). The font's live nibbles are
    0 and 1, and the captured palette has 0=$00 1=$3F 14=$00 15=$3F, so inverse
    is exactly an ink/paper swap. Each cell therefore reduces to an 8x8 BOOLEAN
    ink map with no loss.

  art side (lossy — the whole difficulty lives here)
    Each 24x24 tile is cut into nine 8x8 cells. Per CELL, independently:
      1. quantise every pixel to the CoCo3 GIME gamut (2 bits/channel ->
         {0,85,170,255}, 64 colours)
      2. take the two most frequent quantised colours in that cell
      3. assign each pixel to whichever of the two it is nearer in RGB
    That yields an 8x8 boolean map. Per-cell (not per-tile) because the engine's
    inverse bit is per character, and per-cell two-colour reduction is what the
    engine actually renders. A whole-tile luminance threshold — the earlier
    method — cannot represent that, which is where the 83.0% floor came from.

  masking
    Cells whose glyph (code & $7F) is $55 or $66 are EXCLUDED. Both are corrupt
    in the font (CLAUDE.md 2J) and are the only two glyphs in the font holding
    nibbles outside {0,1}, so they carry no correspondence information. 290 of
    2304 cells across 101 tiles; tiles 214 and 227 are fully masked.

SCORES

  score   mean over unmasked cells of max(m, 64-m)/64, where m is the count of
          agreeing pixels. Free polarity PER CELL. This is the dispatch's
          measure and is the one reported in the table.

  wscore  the same, weighted by cell informativeness
          info = min(ink, 64-ink)/32  (0 for a constant cell, 1 for balanced).
          A blank cell matches anything uniform under free polarity, so an
          unweighted mean rewards emptiness. wscore is used for best-match
          search, where that bias would otherwise manufacture a mapping.

Usage:
    tilecorr.py --sheet art/image.png [--json out.json] [--csv out.csv]
    tilecorr.py --geometry art/image.png
"""

import argparse
import json
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, 'tools')
import decbmerge

TILESET = 'assets/tileset.bin'
BINARY = 'build/ROBOTSA.BIN'
FONT_ADDR = 0x41F6
LEVELS = ['assets/levels/level_%s.bin' % c for c in 'abcdefghij']

CORRUPT_GLYPHS = (0x55, 0x66)          # CLAUDE.md 2J
PLANES = ['TL', 'TM', 'TR', 'ML', 'MM', 'MR', 'BL', 'BM', 'BR']


# ----------------------------------------------------------------- tileset --
def load_font():
    segs, _ = decbmerge.read_decb(BINARY)
    blob = dict(segs)[FONT_ADDR]
    g = np.zeros((128, 8, 8), dtype=np.uint8)
    for i in range(128):
        for row in range(8):
            for b in range(4):
                v = blob[i * 32 + row * 4 + b]
                g[i, row, b * 2] = v >> 4
                g[i, row, b * 2 + 1] = v & 0x0F
    return g


def load_tiles():
    segs, _ = decbmerge.read_decb(TILESET)
    (_, blob), = segs
    out = []
    for t in range(256):
        row = []
        for k in range(9):
            off = 512 + k * 256 + t
            row.append(blob[off] if off < len(blob) else None)
        out.append(row)
    return out


def render_cell(glyphs, code):
    """8x8 boolean ink map, or None if the cell has no data."""
    if code is None:
        return None
    ink = (glyphs[code & 0x7F] == 1)
    if code & 0x80:
        ink = ~ink
    return ink


def live_tiles():
    """Tile indices appearing in the MAP region of any level.

    Level files load at $5D00; MAP is at $5F00, so the map is bytes
    [512 : 512+8192] of the segment.
    """
    seen = set()
    for path in LEVELS:
        segs, _ = decbmerge.read_decb(path)
        (_, blob), = segs
        seen |= set(blob[512:512 + 8192])
    return seen


# --------------------------------------------------------------------- art --
def quantise_gime(arr):
    """Snap RGB to the GIME gamut: 2 bits per channel -> {0,85,170,255}."""
    return (np.round(arr.astype(float) / 85.0) * 85).astype(np.uint8)


def cell_binary(cell_rgb):
    """8x8 boolean map from a cell's two dominant quantised colours.

    Returns (mask, n_distinct). A uniform cell yields an all-False mask.
    """
    q = quantise_gime(cell_rgb).reshape(-1, 3)
    colours, counts = np.unique(q, axis=0, return_counts=True)
    order = np.argsort(-counts)
    if len(colours) == 1:
        return np.zeros((8, 8), dtype=bool), 1
    c0 = colours[order[0]].astype(float)
    c1 = colours[order[1]].astype(float)
    d0 = ((q.astype(float) - c0) ** 2).sum(axis=1)
    d1 = ((q.astype(float) - c1) ** 2).sum(axis=1)
    return (d1 < d0).reshape(8, 8), len(colours)


def sheet_cells(path, origin=(0, 0), pitch=24):
    """[256][9] boolean 8x8 maps, row-major 16x16 grid, row-major 3x3 cells."""
    img = np.asarray(Image.open(path).convert('RGB'))
    ox, oy = origin
    out, distinct = [], []
    for idx in range(256):
        ty, tx = divmod(idx, 16)
        y0, x0 = oy + ty * pitch, ox + tx * pitch
        tile = img[y0:y0 + 24, x0:x0 + 24]
        cells, dn = [], []
        for cy in range(3):
            for cx in range(3):
                m, n = cell_binary(tile[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8])
                cells.append(m)
                dn.append(n)
        out.append(cells)
        distinct.append(dn)
    return out, distinct


def derive_geometry(path):
    """Recover pitch and phase from column/row edge energy. Reported, not assumed."""
    im = np.asarray(Image.open(path).convert('L')).astype(float)
    res = {}
    for axis, name in ((1, 'x'), (0, 'y')):
        g = np.abs(np.diff(im, axis=axis)).sum(axis=1 - axis)
        cand = []
        for p in range(20, 29):
            for o in range(p):
                idx = np.arange(o, len(g), p)
                cand.append((g[idx].mean() / g.mean(), p, o))
        cand.sort(reverse=True)
        res[name] = cand[:3]
    return res


# ------------------------------------------------------------------ scoring --
def score_pair(ts_cells, art_cells, mask):
    """(score, wscore, cells_scored) for one tileset tile vs one art tile."""
    tot = wnum = wden = 0.0
    n = 0
    for k in range(9):
        if mask[k] or ts_cells[k] is None:
            continue
        a, b = ts_cells[k], art_cells[k]
        m = int((a == b).sum())
        s = max(m, 64 - m) / 64.0
        ink = int(a.sum())
        info = min(ink, 64 - ink) / 32.0
        tot += s
        n += 1
        wnum += s * info
        wden += info
    if n == 0:
        return None, None, 0
    return tot / n, (wnum / wden if wden > 0 else None), n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sheet', default='art/image.png')
    ap.add_argument('--json')
    ap.add_argument('--csv')
    ap.add_argument('--geometry', action='store_true')
    ap.add_argument('--origin', default='0,0')
    ap.add_argument('--pitch', type=int, default=24)
    ap.add_argument('--high', type=float, default=0.90)
    ap.add_argument('--low', type=float, default=0.75)
    args = ap.parse_args()

    if args.geometry:
        for name, rows in derive_geometry(args.sheet).items():
            print('%s: ' % name + '  '.join(
                'pitch=%d phase=%d (%.2fx)' % (p, o, r) for r, p, o in rows))
        return 0

    glyphs = load_font()
    tiles = load_tiles()
    live = live_tiles()
    ox, oy = (int(v) for v in args.origin.split(','))
    art, _ = sheet_cells(args.sheet, (ox, oy), args.pitch)

    ts = [[render_cell(glyphs, tiles[t][k]) for k in range(9)] for t in range(256)]
    masks = [[(tiles[t][k] is not None and (tiles[t][k] & 0x7F) in CORRUPT_GLYPHS)
              for k in range(9)] for t in range(256)]

    # full 256x256 so identity can be compared against every alternative
    S = np.full((256, 256), np.nan)
    W = np.full((256, 256), np.nan)
    for t in range(256):
        for a in range(256):
            s, w, _ = score_pair(ts[t], art[a], masks[t])
            if s is not None:
                S[t, a] = s
                W[t, a] = w if w is not None else np.nan

    # Confidence is scored on TWO axes, because either alone is misleading:
    #   absolute agreement  — a low score means the pair genuinely disagrees
    #   rank of identity    — a high score is worthless if 40 other indices
    #                         score as well; that is agreement without
    #                         discrimination
    # A blank tile scores 1.00 at rank 1 (nothing beats it) and is labelled
    # high, with a note that the agreement is unconstrained: blank-matches-blank
    # is true, needs no cleanup, and must not clog the queue — but it is weak
    # evidence and C3 should filter on `informative`, not on `confidence`.
    EPS = 1e-9
    rows = []
    for t in range(256):
        n = sum(1 for k in range(9)
                if not masks[t][k] and ts[t][k] is not None)
        notes = []
        if n == 0:
            rows.append(dict(tile=t, art_index=None, score=None, wscore=None,
                             confidence='unmatched', cells_scored=0,
                             live=t in live, informative=False, rank=None,
                             margin=None, best_score_index=None,
                             notes='all cells masked (glyphs $55/$66); '
                                   'unscoreable by construction, not a failure'))
            continue

        ident = float(S[t, t])
        widen = float(W[t, t]) if not np.isnan(W[t, t]) else None
        rank = int((S[t] > ident + EPS).sum()) + 1
        others = np.delete(S[t], t)
        margin = ident - float(np.nanmax(others))
        best_s = int(np.nanargmax(S[t]))

        if ident >= args.high and rank <= 3:
            conf = 'high'
        elif ident >= args.low:
            conf = 'low'
        else:
            conf = 'unmatched'

        if widen is None:
            notes.append('no informative cells (every unmasked cell is constant) '
                         '- agreement is unconstrained, weak evidence')
        if rank > 3:
            notes.append('identity ranks %d of 256' % rank)
        if margin < -0.05:
            notes.append('index %d beats identity by %.3f' % (best_s, -margin))
        if tiles[t][8] is None:
            notes.append('BR cell absent from tileset.bin (file is 1 byte short)')
        if n < 5:
            notes.append('only %d of 9 cells scored (%d masked)' % (n, 9 - n))

        rows.append(dict(tile=t, art_index=t, score=round(ident, 4),
                         wscore=(round(widen, 4) if widen is not None else None),
                         confidence=conf, cells_scored=n, live=t in live,
                         informative=widen is not None,
                         rank=rank, margin=round(margin, 4),
                         best_score_index=best_s,
                         notes='; '.join(notes)))

    if args.json:
        with open(args.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump({'sheet': args.sheet,
                       'origin': [ox, oy], 'pitch': args.pitch,
                       'thresholds': {'high': args.high, 'low': args.low},
                       'rows': rows}, f, indent=1)
            f.write('\n')
    if args.csv:
        import csv
        cols = ['tile', 'art_index', 'score', 'wscore', 'confidence',
                'cells_scored', 'live', 'informative', 'rank', 'margin',
                'best_score_index', 'notes']
        with open(args.csv, 'w', encoding='utf-8', newline='') as f:
            w = csv.DictWriter(f, fieldnames=cols, extrasaction='ignore')
            w.writeheader()
            for r in rows:
                w.writerow(r)

    np.save('build/S.npy', S)
    np.save('build/W.npy', W)
    scored = [r for r in rows if r['score'] is not None]
    print('%s: %d tiles scored, mean identity %.4f, median %.4f'
          % (args.sheet, len(scored),
             float(np.mean([r['score'] for r in scored])),
             float(np.median([r['score'] for r in scored]))))
    return 0


if __name__ == '__main__':
    sys.exit(main())
