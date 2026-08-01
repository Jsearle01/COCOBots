#!/usr/bin/env python3
"""
fontbuild.py — build a 16-colour PETSCII font and a remapped tileset, using a
non-uniform glyph-variant allocation.

Produces artifacts under build/c3/. **Writes nothing into assets/ or src/.**
`tileset.bin` and `PETSCII_COCO.asm` are protected (CLAUDE.md §2B) and applying
this is a separate authorised step.

THE SLOT BUDGET IS THE BINDING CONSTRAINT, AND IT IS SMALL
-----------------------------------------------------------
The engine addresses 128 glyphs. Naively 59 are unused by `tileset.bin`, but
most cannot be repurposed: the font is also the TEXT font. `PETROBOTS_6809.asm`
maps character codes `$60-$7F` down to `$00-$1F` before lookup, so letters,
digits and punctuation are rendered out of `$00-$3F`. Overwriting a free slot
there replaces a letterform with a tile fragment.

    $00-$1F  letters          9 used by tiles, 23 free   NOT usable (text)
    $20-$3F  digits/punct    14 used by tiles, 18 free   NOT usable (text)
    $40-$5F  graphics        25 used by tiles,  7 free   usable pending a text audit
    $60-$7F  graphics        21 used by tiles, 11 free   USABLE

So the extra-variant budget is **11 slots** conservatively, 18 if the `$40-$5F`
graphics band is cleared. Not 59. That is what forces a non-uniform allocation:
the contested glyphs get the variants, everything else keeps one.

ALLOCATION
----------
For each glyph, error is computed as a function of K variants (cells clustered
by demanded colour, normal and inverse separated since they render through
different transforms). Extra slots go by marginal gain — repeatedly to whichever
glyph's next variant reduces total error most.

TEXT GLYPHS
-----------
Glyphs not used by any tile keep their shapes and are re-indexed from the old
monochrome pair (0=black, 1=white) onto the new palette's black and white slots,
so text still renders as text.

Usage:
    fontbuild.py --budget 11 [--extra-band] --out build/c3
"""

import argparse
import collections
import json
import os
import sys

import numpy as np

sys.path.insert(0, 'tools')
import tilecorr
import palettederive as pdv

NPIX = 64
SAFE_BAND = range(0x60, 0x80)          # text maps $60-$7F away before lookup
EXTRA_BAND = range(0x40, 0x60)         # PETSCII graphics; needs a text audit


def tile_used_slots(tiles):
    used = set()
    for t in range(256):
        for k in range(9):
            c = tiles[t][k]
            if c is not None:
                used.add(c & 0x7F)
    return used


def cluster_costs(recs, pal, kmax=6):
    """Per glyph: for each K, the error and the (clusters, patterns) achieving it."""
    bycell = collections.defaultdict(list)
    for r in recs:
        bycell[r['glyph']].append(r)

    out = {}
    for g, cells in bycell.items():
        want = np.stack([c['want'] for c in cells])
        inv = np.array([c['inverse'] for c in cells])
        per_k = {}
        for K in range(1, min(kmax, len(cells)) + 1):
            groups = pdv.kmeans_cells(want, inv, K)
            tot = 0.0
            pats, members = [], []
            for blk in groups:
                if not blk:
                    continue
                hN = np.zeros((NPIX, 64))
                hI = np.zeros((NPIX, 64))
                for i in blk:
                    h = hI if inv[i] else hN
                    h[np.arange(NPIX), want[i]] += 1
                cN, cI = hN @ pdv.D2, hI @ pdv.D2
                opts = np.stack([cN[:, pal[i]] + cI[:, pal[15 - i]]
                                 for i in range(16)], axis=-1)
                tot += float(opts.min(axis=1).sum())
                pats.append(opts.argmin(axis=1))
                members.append([cells[i] for i in blk])
            per_k[K] = dict(cost=tot, patterns=pats, members=members)
        out[g] = per_k
    return out


def allocate(costs, budget):
    """Exact allocation of `budget` extra slots across glyphs, by DP.

    NOT greedy. Marginal gain here is genuinely non-monotone: for glyph $66 the
    step from 2 to 3 variants is worth several times the step from 1 to 2,
    because at K=2 the clustering is forced to spend its only split separating
    normal from inverse cells, leaving one still-heterogeneous group. Greedy
    assumes diminishing returns and would take the wrong slots first.

    dp[b] = best (cost, choices) using the glyphs processed so far and b slots.
    """
    glyphs = sorted(costs)
    NEG = float('inf')
    dp = [(NEG, None)] * (budget + 1)
    dp[0] = (0.0, ())
    for g in glyphs:
        per_k = costs[g]
        nxt = [(NEG, None)] * (budget + 1)
        for b in range(budget + 1):
            if dp[b][0] == NEG:
                continue
            for K, entry in per_k.items():
                extra = K - 1
                if b + extra > budget:
                    continue
                cand = dp[b][0] + entry['cost']
                if cand < nxt[b + extra][0]:
                    nxt[b + extra] = (cand, dp[b][1] + ((g, K),))
        dp = nxt
    best_b = min(range(budget + 1), key=lambda b: dp[b][0])
    K = {g: 1 for g in costs}
    for g, k in dp[best_b][1]:
        K[g] = k
    return K, [(g, k) for g, k in dp[best_b][1] if k > 1]


def total_error(costs, K):
    tot = sum(costs[g][K[g]]['cost'] for g in costs)
    npx = sum(len(m) * NPIX
              for g in costs for m in costs[g][K[g]]['members'])
    return float(np.sqrt(tot / npx))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--palette', default='assets/palette.json')
    ap.add_argument('--sheet', default='art/Amiga_Artwork.png')
    ap.add_argument('--budget', type=int, default=11)
    ap.add_argument('--extra-band', action='store_true',
                    help='also use the $40-$5F graphics band (needs a text audit)')
    ap.add_argument('--out', default='build/c3')
    ap.add_argument('--render')
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    with open(args.palette, encoding='utf-8') as f:
        pal = [s['byte'] for s in json.load(f)['slots']]
    black = pal.index(0x00) if 0x00 in pal else 0
    white = pal.index(0x3F) if 0x3F in pal else 15

    tiles = tilecorr.load_tiles()
    oldfont = tilecorr.load_font()
    used = tile_used_slots(tiles)

    free = [g for g in SAFE_BAND if g not in used]
    if args.extra_band:
        free += [g for g in EXTRA_BAND if g not in used]
    budget = min(args.budget, len(free))

    recs = pdv.sample_all(args.sheet, tiles)
    costs = cluster_costs(recs, pal)

    K1 = {g: 1 for g in costs}
    K, log = allocate(costs, budget)

    print('palette   ' + ' '.join('$%02X' % c for c in pal))
    print('black at slot %d, white at slot %d' % (black, white))
    print('tile glyph slots used %d, free-and-safe %d, budget %d'
          % (len(used), len(free), budget))
    print('error  1 variant everywhere : %.2f' % total_error(costs, K1))
    print('       allocated            : %.2f' % total_error(costs, K))
    print('allocation (exact, by DP):')
    for g, k in sorted(log, key=lambda x: -x[1]):
        cells = sum(len(m) for m in costs[g][k]['members'])
        print('   $%02X -> %d variants  (%d cells, +%d slots)'
              % (g, k, cells, k - 1))

    # ---------------------------------------------------------------- build --
    font = np.zeros((128, NPIX), dtype=np.uint8)
    # text and any glyph without art: keep the shape, re-index onto the new palette
    for g in range(128):
        old = oldfont[g].reshape(NPIX)
        font[g] = np.where(old == 1, white, black)

    slots = iter(free)
    remap = {}                       # (glyph, id(cell)) -> slot
    variants_used = 0
    for g, per_k in costs.items():
        entry = per_k[K[g]]
        for vi, (pat, members) in enumerate(zip(entry['patterns'],
                                                entry['members'])):
            if vi == 0:
                slot = g                      # primary keeps the original slot
            else:
                slot = next(slots)
                variants_used += 1
            font[slot] = pat.astype(np.uint8)
            for c in members:
                remap[(c['tile'], c['cell'])] = slot

    # ---------------------------------------------------------------- emit ---
    raw = bytearray()
    for g in range(128):
        px = font[g]
        for row in range(8):
            for b in range(4):
                raw.append((px[row * 8 + b * 2] << 4) | px[row * 8 + b * 2 + 1])
    assert len(raw) == 4096
    with open(os.path.join(args.out, 'font-colour.bin'), 'wb') as f:
        f.write(raw)

    lines = ['; Generated by tools/fontbuild.py - 16-colour PETSCII font',
             '; Palette: ' + ' '.join('$%02X' % c for c in pal),
             '; Derived from %s via the C2 palette. NOT hand-edited.' % args.sheet,
             '  ORG $41F6', '']
    for g in range(128):
        lines.append('\t; 0x%02X' % g)
        for row in range(8):
            off = g * 32 + row * 4
            lines.append('  .BYTE ' + ','.join('0x%02X' % raw[off + i]
                                               for i in range(4)))
    with open(os.path.join(args.out, 'font-colour.asm'), 'w',
              encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')

    # remapped tile planes, same DECB layout as assets/tileset.bin
    import decbmerge
    segs, _ = decbmerge.read_decb('assets/tileset.bin')
    (addr, blob), = segs
    nb = bytearray(blob)
    changed = 0
    for t in range(256):
        for k in range(9):
            code = tiles[t][k]
            if code is None:
                continue
            slot = remap.get((t, k), code & 0x7F)
            new = slot | (code & 0x80)
            off = 512 + k * 256 + t
            if nb[off] != new:
                nb[off] = new
                changed += 1
    decbmerge.write_decb(os.path.join(args.out, 'tileset-remapped.bin'),
                         [(addr, bytes(nb))], 0x0000)

    # three-panel comparison: source | one variant everywhere | allocated
    if args.render:
        from PIL import Image, ImageDraw
        src = np.asarray(Image.open(args.sheet).convert('RGB'))
        h, w, _ = src.shape
        pal_rgb = np.array([pdv.GAMUT[c] for c in pal], dtype=np.uint8)

        def draw(fontarr, codes):
            out = np.zeros_like(src)
            chk = np.indices((8, 8)).sum(axis=0) % 2
            mark = np.stack([np.where(chk, 255, 96)] * 3, axis=-1).astype(np.uint8)
            for t in range(256):
                ty, tx = divmod(t, 16)
                for k in range(9):
                    cy, cx = divmod(k, 3)
                    y, x = ty * 24 + cy * 8, tx * 24 + cx * 8
                    c = codes[t][k]
                    if c is None:
                        out[y:y + 8, x:x + 8] = mark
                        continue
                    idx = fontarr[c & 0x7F].copy()
                    if c & 0x80:
                        idx = 15 - idx
                    out[y:y + 8, x:x + 8] = pal_rgb[idx].reshape(8, 8, 3)
            return out

        base_font = np.zeros((128, NPIX), dtype=np.uint8)
        for g in range(128):
            old = oldfont[g].reshape(NPIX)
            base_font[g] = np.where(old == 1, white, black)
        for g, per_k in costs.items():
            base_font[g] = per_k[1]['patterns'][0].astype(np.uint8)
        newcodes = [[None if tiles[t][k] is None
                     else remap.get((t, k), tiles[t][k] & 0x7F) | (tiles[t][k] & 0x80)
                     for k in range(9)] for t in range(256)]

        panels = [('Amiga_Artwork.png (source)', src),
                  ('1 variant per glyph  err %.1f' % total_error(costs, K1),
                   draw(base_font, tiles)),
                  ('allocated %d slots  err %.1f' % (budget, total_error(costs, K)),
                   draw(font, newcodes))]
        gap, lab, strip, sc = 8, 14, 24, 2
        cw = w * 3 + gap * 2
        canvas = np.full((lab + h + gap + strip, cw, 3), 32, dtype=np.uint8)
        for i, (_, p) in enumerate(panels):
            canvas[lab:lab + h, i * (w + gap):i * (w + gap) + w] = p
        for s in range(16):
            canvas[lab + h + gap:, s * cw // 16:(s + 1) * cw // 16] = \
                pdv.GAMUT[pal[s]].astype(np.uint8)
        im = Image.fromarray(canvas).resize((cw * sc,
                                             canvas.shape[0] * sc), Image.NEAREST)
        d = ImageDraw.Draw(im)
        for i, (name, _) in enumerate(panels):
            d.text((i * (w + gap) * sc + 4, 3), name, fill=(210, 210, 210))
        d.text((4, (lab + h + gap) * sc + 2), 'palette slots 0-15',
               fill=(230, 230, 230))
        im.save(args.render)
        print('render -> %s' % args.render)

    print('variants placed %d, tile cells repointed %d' % (variants_used, changed))
    print('wrote %s/font-colour.bin, font-colour.asm, tileset-remapped.bin'
          % args.out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
