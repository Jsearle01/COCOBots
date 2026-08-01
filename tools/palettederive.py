#!/usr/bin/env python3
"""
palettederive.py — derive a 16-entry CoCo3 palette from the Amiga artwork, in
slot order, under the engine's ACTUAL glyph model.

C2 (re-derivation). Produces a proposal and its evidence. Applies nothing.

THE ENGINE MODEL — established from BITMAP_PLOTTER, not assumed
---------------------------------------------------------------
`DoRegular` copies a glyph's bytes to the framebuffer unmodified:

    NextRowRegular:  PULU D,Y / STD ,X / STY 2,X

Four bytes per row, 4bpp, so **every one of a glyph's 64 pixels is an
independent 4-bit palette index**. A glyph is fully 16-colour capable; the
shipped font is 2-colour by deliberate choice, not by format (CLAUDE.md §4).

`NextRowInv` applies COMA/COMB, complementing every nibble, so an inverted
glyph renders pixel p as palette[15 - I_p] — per pixel, independently.

    normal   cell shows  palette[I_p]        for each pixel p
    inverse  cell shows  palette[15 - I_p]   for each pixel p

An earlier version of this file modelled each 8x8 cell as one ink colour plus
one paper colour. That binary reduction is correct in tilecorr.py, where it
matches SHAPES against a monochrome font; as a COLOUR model it is wrong. Only
6.8% of art cells are describable with two colours, the reduction captured
69.4% of pixels, and it saw 26 of the 46 colours actually present.

WHY THE ORDERING IS A PAIRING, AND WHY THAT IS NOW THE WHOLE PROBLEM
--------------------------------------------------------------------
Choosing index i for a pixel selects BOTH what it shows normally (palette[i])
and what it shows inverted (palette[15-i]). So a palette is characterised
entirely by its 8 complement pairs: each pixel picks one of 16 options, being
8 pairs x 2 orientations. Which slot a pair occupies is irrelevant.

The optimisation is therefore: choose 8 unordered colour pairs from the GIME 64
minimising total rendering error. Solved here by greedy seed + local search over
candidate pairs, with the per-pixel index choice solved exactly (16-way argmin)
inside every evaluation.

ERROR DECOMPOSITION — what each constraint actually costs
---------------------------------------------------------
    floor        each cell picks freely per pixel      (palette quantisation only)
    + sharing    one pattern per glyph, but inverse
                 cells allowed their own pattern       (one-glyph-one-pattern, §2M inv. 1)
    + complement inverse forced through 15-i           (the ordering)

Reported as mean per-pixel RGB distance so the three are directly comparable.
This replaces the earlier "survival fraction", which a 1-colour palette
maximised at 100%.

Usage:
    palettederive.py --sheet art/Amiga_Artwork.png --json assets/palette.json
                     --render build/c2/preview.png
    palettederive.py --sheet art/coco_ArtworkSheet.png --control
"""

import argparse
import collections
import json
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, 'tools')
import tilecorr

CORRUPT = (0x55, 0x66)
NPIX = 64


# ------------------------------------------------------------------ gamut ---
def gime_rgb(byte):
    r = (((byte >> 5) & 1) << 1) | ((byte >> 2) & 1)
    g = (((byte >> 4) & 1) << 1) | ((byte >> 1) & 1)
    b = (((byte >> 3) & 1) << 1) | (byte & 1)
    return np.array([r * 85, g * 85, b * 85], dtype=float)


GAMUT = np.array([gime_rgb(b) for b in range(64)])
D2 = ((GAMUT[:, None, :] - GAMUT[None, :, :]) ** 2).sum(axis=2)   # 64x64 sq dist


def quantise_sheet(path):
    """Whole sheet -> GIME index per pixel, in one vectorised pass."""
    img = np.asarray(Image.open(path).convert('RGB')).astype(float)
    h, w, _ = img.shape
    flat = img.reshape(-1, 3)
    d = ((flat[:, None, :] - GAMUT[None, :, :]) ** 2).sum(axis=2)
    return np.argmin(d, axis=1).reshape(h, w).astype(np.uint8)


# --------------------------------------------------------------- sampling ---
def load_rows():
    with open('assets/tile-correspondence.json', encoding='utf-8') as f:
        rows = json.load(f)['rows']
    return [r for r in rows if r['live'] and r['informative']]


def sample(sheet, rows, tiles):
    """One record per sampled cell, carrying all 64 demanded GIME colours.

    Identity correspondence (C1): tile n -> art tile n, origin (0,0), pitch 24.
    """
    q = quantise_sheet(sheet)
    out = []
    for r in rows:
        t = r['tile']
        ty, tx = divmod(t, 16)
        tile = q[ty * 24:ty * 24 + 24, tx * 24:tx * 24 + 24]
        for k in range(9):
            code = tiles[t][k]
            if code is None or (code & 0x7F) in CORRUPT:
                continue
            cy, cx = divmod(k, 3)
            out.append(dict(tile=t, cell=k, glyph=code & 0x7F,
                            inverse=bool(code & 0x80),
                            want=tile[cy * 8:cy * 8 + 8,
                                      cx * 8:cx * 8 + 8].reshape(NPIX).copy()))
    return out


def build_histograms(recs):
    """Per (glyph, pixel), how many normal / inverse cells demand each colour.

    Returns hN, hI of shape (n_glyphs, 64 pixels, 64 colours) and the glyph list.
    Everything downstream is a contraction of these two arrays, which is what
    makes a full 64-pixel model cheap enough to optimise over.
    """
    glyphs = sorted({r['glyph'] for r in recs})
    gidx = {g: i for i, g in enumerate(glyphs)}
    hN = np.zeros((len(glyphs), NPIX, 64))
    hI = np.zeros((len(glyphs), NPIX, 64))
    for r in recs:
        h = hI if r['inverse'] else hN
        gi = gidx[r['glyph']]
        h[gi, np.arange(NPIX), r['want']] += 1
    return hN, hI, glyphs, gidx


def cost_tables(hN, hI):
    """costN[g,p,a] = squared error if the NORMAL-rendered colour is a.
       costI[g,p,b] = squared error if the INVERSE-rendered colour is b."""
    return hN @ D2, hI @ D2


# ----------------------------------------------------------- optimisation ---
def pair_option_cost(costN, costI, a, b):
    """Best of the two orientations of pair {a,b}, per (glyph, pixel)."""
    return np.minimum(costN[..., a] + costI[..., b],
                      costN[..., b] + costI[..., a])


def optimise_pairs(costN, costI, candidates, npairs=8, rounds=6):
    """Greedy seed then local search over 8 unordered colour pairs."""
    best = np.full(costN.shape[:2], np.inf)
    chosen = []
    for _ in range(npairs):
        bp, bv = None, None
        for (a, b) in candidates:
            v = float(np.minimum(best, pair_option_cost(costN, costI, a, b)).sum())
            if bv is None or v < bv:
                bp, bv = (a, b), v
        chosen.append(bp)
        best = np.minimum(best, pair_option_cost(costN, costI, *bp))

    for _ in range(rounds):
        improved = False
        for i in range(npairs):
            others = [p for j, p in enumerate(chosen) if j != i]
            base = np.full(costN.shape[:2], np.inf)
            for (a, b) in others:
                base = np.minimum(base, pair_option_cost(costN, costI, a, b))
            cur = float(np.minimum(
                base, pair_option_cost(costN, costI, *chosen[i])).sum())
            for (a, b) in candidates:
                if (a, b) in others:
                    continue
                v = float(np.minimum(
                    base, pair_option_cost(costN, costI, a, b)).sum())
                if v < cur - 1e-6:
                    chosen[i], cur, improved = (a, b), v, True
        if not improved:
            break
    return chosen


def build_palette(pairs):
    pal = [None] * 16
    for slot, (a, b) in enumerate(pairs):
        pal[slot] = int(a)
        pal[15 - slot] = int(b)
    return pal


def choose16_floor(colour_counts, rounds=8):
    """The 16 colours minimising per-pixel quantisation error of the ART.

    §2M invariant 3: the palette is screen-wide, so colour use is computed
    across the whole sheet weighted by how often it is drawn. This decides
    WHICH 16 colours, and deliberately ignores the glyph model.

    It has to be decided this way. Optimising the palette jointly against
    one-pattern-per-glyph collapses it to 9 distinct colours: when a single
    pattern must serve many cells demanding different colours, extra palette
    entries buy almost nothing, so the optimiser spends slots on duplicates of
    the compromise colours. That is a correct answer to the wrong question —
    C3 will split glyphs, and a palette fitted to the unsplit case would be
    baked-in wrong. See --objective joint to reproduce the collapse.
    """
    w = np.zeros(64)
    for c, n in colour_counts.items():
        w[c] = n
    sel = []
    for _ in range(16):
        best, bv = None, None
        for c in range(64):
            if c in sel:
                continue
            cost = float((w * D2[sel + [c]].min(axis=0)).sum())
            if bv is None or cost < bv:
                best, bv = c, cost
        sel.append(best)
    for _ in range(rounds):
        improved = False
        cur = float((w * D2[sel].min(axis=0)).sum())
        for i in range(16):
            for c in range(64):
                if c in sel:
                    continue
                trial = list(sel)
                trial[i] = c
                v = float((w * D2[trial].min(axis=0)).sum())
                if v < cur - 1e-6:
                    sel, cur, improved = trial, v, True
        if not improved:
            break
    return sorted(sel)


def pair_chosen16(sel, costN, costI, rounds=200):
    """Pair 16 FIXED colours to minimise the complement cost.

    Exhaustive perfect matching over 16 nodes is 2,027,025 pairings, so this
    is a repeated best-improvement search over pair swaps from several starts —
    the objective here is flat enough that it converges immediately.
    """
    import itertools

    def total(pairs):
        best = np.full(costN.shape[:2], np.inf)
        for (a, b) in pairs:
            best = np.minimum(best, pair_option_cost(costN, costI, a, b))
        return float(best.sum())

    rng = list(range(16))
    best_pairs = [(sel[i], sel[15 - i]) for i in range(8)]
    best_val = total(best_pairs)
    for _ in range(rounds):
        improved = False
        for i, j in itertools.combinations(range(8), 2):
            for swap in ((0, 0), (0, 1), (1, 0), (1, 1)):
                trial = [list(p) for p in best_pairs]
                trial[i][swap[0]], trial[j][swap[1]] = \
                    trial[j][swap[1]], trial[i][swap[0]]
                trial = [tuple(p) for p in trial]
                v = total(trial)
                if v < best_val - 1e-6:
                    best_pairs, best_val, improved = trial, v, True
        if not improved:
            break
    return best_pairs


def candidate_pairs(recs, top=34):
    """Pairs drawn from the colours the art actually demands, plus self-pairs.

    A self-pair {c,c} places one colour at both i and 15-i, which is what a
    pixel needs when the art wants the SAME colour in normal and inverted
    instances of its glyph.
    """
    cnt = collections.Counter()
    for r in recs:
        cnt.update(r['want'].tolist())
    cols = [c for c, _ in cnt.most_common(top)]
    out = {(c, c) for c in cols}
    for i, a in enumerate(cols):
        for b in cols[i + 1:]:
            out.add((min(a, b), max(a, b)))
    return sorted(out), cnt


# ------------------------------------------------------------ measurement ---
def decompose(pal, costN, costI, hN, hI):
    """Mean per-pixel RGB distance under each successive constraint."""
    npx = float(hN.sum() + hI.sum())
    pal_a = np.array(pal)

    # floor: every cell free to pick its own best palette entry per pixel
    best_col = D2[:, :][pal_a].min(axis=0)                  # (64,) over demand colour
    floor = float((hN * best_col).sum() + (hI * best_col).sum())

    # sharing: one pattern per glyph, but inverse allowed a separate pattern
    shareN = costN[..., pal_a].min(axis=2).sum()
    shareI = costI[..., pal_a].min(axis=2).sum()
    sharing = float(shareN + shareI)

    # actual: one pattern, inverse forced through 15-i
    opts = np.stack([costN[..., pal[i]] + costI[..., pal[15 - i]]
                     for i in range(16)], axis=-1)
    actual = float(opts.min(axis=2).sum())

    rms = lambda s: float(np.sqrt(s / npx))
    return dict(pixels=int(npx),
                floor=round(rms(floor), 2),
                sharing=round(rms(sharing), 2),
                actual=round(rms(actual), 2),
                cost_of_sharing=round(rms(sharing) - rms(floor), 2),
                cost_of_complement=round(rms(actual) - rms(sharing), 2))


def glyph_patterns(pal, costN, costI):
    """The index each glyph assigns to each of its 64 pixels."""
    opts = np.stack([costN[..., pal[i]] + costI[..., pal[15 - i]]
                     for i in range(16)], axis=-1)
    return opts.argmin(axis=2)                              # (n_glyphs, 64)


def kmeans_cells(want, inv, k, iters=25):
    """Group a glyph's cells into k clusters by their demanded colour vectors.

    Distance is RGB over all 64 pixels. Normal and inverse cells are separated
    first: they render through different transforms, so a cluster mixing them
    is being asked to satisfy a colour and its complement at once.
    Deterministic seeding (farthest-point) — no RNG, so the analysis is
    reproducible.
    """
    n = len(want)
    if k >= n:
        return [[i] for i in range(n)]

    pts = GAMUT[want]                                   # (n, 64, 3)
    if k == 1:
        return [list(range(n))]                         # one pattern, no split

    groups = [m for m in (np.where(~inv)[0], np.where(inv)[0]) if len(m)]
    if len(groups) == 2:
        share = int(round(k * len(groups[0]) / float(n)))
        share = min(max(share, 1), k - 1)               # at least 1 each
        alloc = [share, k - share]
    else:
        alloc = [k]

    out = []
    for mask, kk in zip(groups, alloc):
        sub = pts[mask]
        if kk >= len(mask):
            out += [[int(i)] for i in mask]
            continue
        cen = [sub[0]]
        for _ in range(kk - 1):
            d = np.min(np.stack([((sub - c) ** 2).sum(axis=(1, 2))
                                 for c in cen]), axis=0)
            cen.append(sub[int(np.argmax(d))])
        cen = np.stack(cen)
        assign = None
        for _ in range(iters):
            d = np.stack([((sub - c) ** 2).sum(axis=(1, 2)) for c in cen])
            new = d.argmin(axis=0)
            if assign is not None and (new == assign).all():
                break
            assign = new
            for j in range(kk):
                sel = sub[assign == j]
                if len(sel):
                    cen[j] = sel.mean(axis=0)
        for j in range(kk):
            out.append([int(i) for i in mask[assign == j]])
    return [g for g in out if g]


def variant_analysis(recs, pal, gidx, kmax=6):
    """Error if a glyph may split into K variants, against the 128-slot budget.

    Cells of a glyph are clustered by their demanded colour vectors; each
    cluster gets its own pattern. Shows how much of the sharing cost is
    recoverable and how many glyph slots that costs.
    """
    pal_a = np.array(pal)
    bycell = collections.defaultdict(list)
    for r in recs:
        bycell[r['glyph']].append(r)

    expect_px = float(sum(NPIX for _ in recs))
    out = []
    for K in range(1, kmax + 1):
        tot = npx = 0.0
        slots = 0
        for g, cells in bycell.items():
            want = np.stack([c['want'] for c in cells])
            inv = np.array([c['inverse'] for c in cells])
            k = min(K, len(cells))
            slots += k
            # k-means over the cells' demanded colour vectors, in RGB space.
            # (A lexicographic split of the 64-dim demand vectors was tried
            # first and is near-worthless — it groups by the top-left pixel.)
            for blk in kmeans_cells(want, inv, k):
                if len(blk) == 0:
                    continue
                hN = np.zeros((NPIX, 64))
                hI = np.zeros((NPIX, 64))
                for r_i in blk:
                    h = hI if inv[r_i] else hN
                    h[np.arange(NPIX), want[r_i]] += 1
                cN, cI = hN @ D2, hI @ D2
                opts = np.stack([cN[:, pal[i]] + cI[:, pal[15 - i]]
                                 for i in range(16)], axis=-1)
                tot += float(opts.min(axis=1).sum())
                npx += float(hN.sum() + hI.sum())
        # every sampled pixel must be accounted for at every K, or the rms is
        # computed over a subset and is not comparable across rows
        assert abs(npx - expect_px) < 1e-6, (
            'K=%d accounted %d pixels, expected %d' % (K, npx, expect_px))
        out.append(dict(variants=K, glyph_slots=slots,
                        rms=round(float(np.sqrt(tot / npx)), 2)))
    return out


# ----------------------------------------------------------------- render ---
def render_engine(sheet, pal, recs, patterns, gidx, out_path, scale=2):
    """Left: the sheet. Right: what the ENGINE would draw under this palette.

    The right panel is built from the glyph patterns actually solved for, with
    inverse cells rendered through 15-i — so it is what the tileset would put on
    screen, not a per-pixel quantisation of the art. Mechanical; whether it looks
    right is Jay's call (§3).
    """
    img = np.asarray(Image.open(sheet).convert('RGB'))
    h, w, _ = img.shape
    out = np.zeros_like(img)
    pal_rgb = np.array([GAMUT[c] for c in pal], dtype=np.uint8)

    for r in recs:
        idx = patterns[gidx[r['glyph']]].copy()
        if r['inverse']:
            idx = 15 - idx
        block = pal_rgb[idx].reshape(8, 8, 3)
        ty, tx = divmod(r['tile'], 16)
        cy, cx = divmod(r['cell'], 3)
        y = ty * 24 + cy * 8
        x = tx * 24 + cx * 8
        out[y:y + 8, x:x + 8] = block

    gap, strip = 8, 24
    canvas = np.zeros((h + gap + strip, w * 2 + gap, 3), dtype=np.uint8)
    canvas[:, :] = 32
    canvas[:h, :w] = img
    canvas[:h, w + gap:] = out
    for s in range(16):
        x0 = s * (w * 2 + gap) // 16
        x1 = (s + 1) * (w * 2 + gap) // 16
        canvas[h + gap:, x0:x1] = GAMUT[pal[s]].astype(np.uint8)

    im = Image.fromarray(canvas)
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(out_path)
    return out_path


# ------------------------------------------------------------------- main ---
def run(sheet, objective='floor'):
    rows = load_rows()
    tiles = tilecorr.load_tiles()
    recs = sample(sheet, rows, tiles)
    hN, hI, glyphs, gidx = build_histograms(recs)
    costN, costI = cost_tables(hN, hI)
    cnt = collections.Counter()
    for r in recs:
        cnt.update(r['want'].tolist())

    if objective == 'joint':
        cands, _ = candidate_pairs(recs)
        pairs = optimise_pairs(costN, costI, cands)
    else:
        sel = choose16_floor(cnt)
        pairs = pair_chosen16(sel, costN, costI)
    pal = build_palette(pairs)
    return dict(recs=recs, hN=hN, hI=hI, costN=costN, costI=costI,
                glyphs=glyphs, gidx=gidx, pal=pal, pairs=pairs,
                colour_counts=cnt, tiles=tiles)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sheet', default='art/Amiga_Artwork.png')
    ap.add_argument('--json')
    ap.add_argument('--render')
    ap.add_argument('--control')
    ap.add_argument('--objective', default='floor', choices=['floor','joint'])
    args = ap.parse_args()

    st = run(args.sheet, args.objective)
    pal, recs = st['pal'], st['recs']
    dec = decompose(pal, st['costN'], st['costI'], st['hN'], st['hI'])
    pats = glyph_patterns(pal, st['costN'], st['costI'])

    print('%s' % args.sheet)
    print('  palette ' + ' '.join('$%02X' % c for c in pal))
    print('  distinct %d   cells %d   pixels %d'
          % (len(set(pal)), len(recs), dec['pixels']))
    print('  mean per-pixel RGB error:')
    print('    floor (palette only)            %6.2f' % dec['floor'])
    print('    + one pattern per glyph         %6.2f   (+%.2f)'
          % (dec['sharing'], dec['cost_of_sharing']))
    print('    + inverse through 15-i          %6.2f   (+%.2f)'
          % (dec['actual'], dec['cost_of_complement']))

    var = variant_analysis(recs, pal, st['gidx'])
    print('  glyph variants (budget 128 slots):')
    for v in var:
        print('    %d variant(s): %3d slots, rms %6.2f%s'
              % (v['variants'], v['glyph_slots'], v['rms'],
                 '' if v['glyph_slots'] <= 128 else '   EXCEEDS BUDGET'))

    if args.control:
        cst = run(args.control, args.objective)
        cdec = decompose(cst['pal'], st['costN'], st['costI'], st['hN'], st['hI'])
        own = decompose(cst['pal'], cst['costN'], cst['costI'],
                        cst['hN'], cst['hI'])
        mine_on_ctrl = decompose(pal, cst['costN'], cst['costI'],
                                 cst['hN'], cst['hI'])
        print('  CONTROL %s' % args.control)
        print('    palette ' + ' '.join('$%02X' % c for c in cst['pal']))
        print('    control-derived on THIS sheet   %6.2f  (mine %.2f)'
              % (cdec['actual'], dec['actual']))
        print('    control-derived on its own      %6.2f  (mine %.2f)'
              % (own['actual'], mine_on_ctrl['actual']))

    if args.render:
        print('  render -> %s'
              % render_engine(args.sheet, pal, recs, pats, st['gidx'],
                              args.render))

    if args.json:
        doc = {
            'source_sheet': args.sheet,
            'derived': '2026-08-01, dispatch C2 (re-derived under the 16-colour glyph model)',
            'applied': False,
            'note': 'Proposal only. C3 applies this; graphics.asm is untouched.',
            'engine_model': ('every glyph pixel is an independent 4-bit palette '
                             'index; NextRowInv complements each one (i -> 15-i)'),
            'slots': [{'slot': i, 'value': '$%02X' % pal[i], 'byte': int(pal[i]),
                       'rgb': GAMUT[pal[i]].astype(int).tolist(),
                       'complement_slot': 15 - i,
                       'complement_value': '$%02X' % pal[15 - i],
                       'demand_pixels': int(st['colour_counts'].get(pal[i], 0))}
                      for i in range(16)],
            'complement_pairs': [{'slots': [i, 15 - i],
                                  'colours': ['$%02X' % pal[i],
                                              '$%02X' % pal[15 - i]],
                                  'self_paired': pal[i] == pal[15 - i]}
                                 for i in range(8)],
            'error_decomposition': dec,
            'glyph_variants': var,
            'cells_sampled': len(recs),
        }
        with open(args.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(doc, f, indent=1)
            f.write('\n')
        print('  json   -> %s' % args.json)
    return 0


if __name__ == '__main__':
    sys.exit(main())
