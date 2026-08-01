#!/usr/bin/env python3
"""
repalette.py — re-derive the 16 palette entries against the ACTUAL rendering
configuration (221 glyphs, inverse removed) rather than against the art alone.

C2 chose the palette by `--objective floor`: minimise per-pixel quantisation
error of the artwork, with no glyph model in the loop. The complement pairing
was solved afterwards over those fixed 16. **So inverse video constrained the
slot ORDER, never the colour CHOICE** — removing it does not, by itself, free
the palette to be more colourful.

What DID limit colour was the glyph budget. Measured, mean chroma of rendered
pixels against the art's 50.5:

    128 glyphs   37.1   washed out - one pattern serving many disagreeing cells
                        averages toward grey
    221 glyphs   44.7   close to the source; the budget largely fixes it

So the remaining question is narrower and answerable: at 221 glyphs, is the
floor-optimal 16 still the right 16? Two slots are nearly dead in the render
($39 at 0.5%, $08 at 0.1%), which says no.

METHOD. The clustering is palette-INDEPENDENT — kmeans_cells groups cells by
their demanded colour vectors in RGB, which does not involve the palette. So the
cell-to-pattern assignment can be computed once and reused, after which any
candidate palette's exact rendering error is a cheap contraction of per-group
demand histograms against the 64x64 colour-distance matrix. That makes a real
local search over the 16 affordable.

Allocation (how many variants each group gets) DOES depend on the palette, so
this alternates: optimise colours at fixed allocation, re-allocate, repeat.

Usage:
    repalette.py --glyphs 221 --out build/c5
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
import fontbuild as fb
import ladder as L


def group_histograms(recs, glyphs, alloc=None):
    """Per pattern-group, a (64 pixel x 64 colour) demand histogram.

    Groups are (glyph, render-mode) — inverse removed — subdivided by the
    variant allocation. Palette-independent, so computed once.
    """
    by = collections.defaultdict(list)
    for r in recs:
        by[(r['glyph'], r['inverse'])].append(r)

    out = []
    for key, cells in by.items():
        want = np.stack([c['want'] for c in cells])
        inv = np.array([c['inverse'] for c in cells])
        k = alloc.get(key, 1) if alloc else 1
        for blk in pdv.kmeans_cells(want, inv, k):
            if not blk:
                continue
            h = np.zeros((64, 64))
            for i in blk:
                h[np.arange(64), want[i]] += 1
            out.append(h)
    return out


def error_of(pal, hists, npx):
    """Exact rendering error of a candidate palette, given fixed grouping."""
    pal_a = np.array(pal)
    tot = 0.0
    for h in hists:
        c = h @ pdv.D2                      # (64 px, 64 candidate colours)
        tot += float(c[:, pal_a].min(axis=1).sum())
    return float(np.sqrt(tot / npx))


import colorsys

HUE_BANDS = [(0, 20, 'red'), (20, 45, 'orange'), (45, 70, 'yellow'),
             (70, 150, 'green'), (150, 195, 'cyan'), (195, 255, 'blue'),
             (255, 290, 'violet'), (290, 340, 'magenta'), (340, 361, 'red')]


def hue_band(b):
    r, g, bl = [v / 255.0 for v in pdv.GAMUT[b]]
    if max(r, g, bl) - min(r, g, bl) < 1e-6:
        return 'grey'
    h = colorsys.rgb_to_hsv(r, g, bl)[0] * 360
    for lo, hi, n in HUE_BANDS:
        if lo <= h < hi:
            return n
    return 'red'


def coverage_seed(want, hists, npx, min_share=0.002):
    """A palette guaranteeing one slot per hue band the art actually uses.

    Frequency-weighted error starves low-frequency hues: it will spend five
    slots on blue (18.9% of pixels) and none on green (1.3%) or magenta (0.4%),
    because squared error does not care that a hue vanishing is more visible
    than a shade shifting. C2's own dispatch warned of this - "frequency is not
    importance" - and the floor objective ignored it anyway.

    This reserves one slot per band above min_share, then fills the rest by
    error as before.
    """
    tot = float(sum(want.values()))
    by_band = collections.defaultdict(list)
    for c, n in want.items():
        by_band[hue_band(c)].append((n, c))
    need = [b for b, v in by_band.items()
            if b != 'grey' and sum(n for n, _ in v) / tot >= min_share]

    sel = [0x00, 0x3F]                       # black and white are never optional
    for b in sorted(need):
        best = max(by_band[b])[1]            # highest-demand colour in the band
        if best not in sel:
            sel.append(best)
    # fill the rest by plain error
    while len(sel) < 16:
        bestc, bestv = None, None
        for c in range(64):
            if c in sel:
                continue
            v = error_of(sel + [c] + [sel[0]] * (16 - len(sel) - 1), hists, npx)
            if bestv is None or v < bestv:
                bestc, bestv = c, v
        sel.append(bestc)
    return sel[:16], need


def optimise_covered(pal, hists, npx, need, rounds=6):
    """Local search that may not drop a hue band's last representative."""
    def covered(p):
        bands = {hue_band(c) for c in p}
        return all(b in bands for b in need)
    best = list(pal)
    cur = error_of(best, hists, npx)
    for _ in range(rounds):
        improved = False
        for i in range(16):
            for c in range(64):
                if c in best:
                    continue
                trial = list(best); trial[i] = c
                if not covered(trial):
                    continue
                v = error_of(trial, hists, npx)
                if v < cur - 1e-9:
                    best, cur, improved = trial, v, True
        if not improved:
            break
    return best, cur


def chroma(b):
    r, g, bl = pdv.GAMUT[b]
    return float(max(r, g, bl) - min(r, g, bl))


def biased_error(pal, hists, npx, bias):
    """Error with chromatic demand upweighted.

    bias=0 is the true error. Above that, getting a COLOURFUL pixel wrong costs
    more than getting a grey one wrong, so the search spends slots on chroma.
    This is a deliberate stylistic thumb on the scale, not a better estimate —
    the true error is always reported alongside.
    """
    w = np.array([1.0 + bias * chroma(c) / 255.0 for c in range(64)])
    pal_a = np.array(pal)
    tot = 0.0
    for h in hists:
        tot += float(((h * w) @ pdv.D2)[:, pal_a].min(axis=1).sum())
    return tot


def optimise(pal, hists, npx, rounds=6, bias=0.0):
    """Best-improvement local search over the 16 entries."""
    if bias > 0:
        best = list(pal)
        cur = biased_error(best, hists, npx, bias)
        for _ in range(rounds):
            improved = False
            for i in range(16):
                for c in range(64):
                    if c in best:
                        continue
                    trial = list(best); trial[i] = c
                    v = biased_error(trial, hists, npx, bias)
                    if v < cur - 1e-9:
                        best, cur, improved = trial, v, True
            if not improved:
                break
        return best, error_of(best, hists, npx)
    best = list(pal)
    cur = error_of(best, hists, npx)
    for _ in range(rounds):
        improved = False
        for i in range(16):
            for c in range(64):
                if c in best:
                    continue
                trial = list(best)
                trial[i] = c
                v = error_of(trial, hists, npx)
                if v < cur - 1e-9:
                    best, cur, improved = trial, v, True
        if not improved:
            break
    return best, cur


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--glyphs', type=int, default=221)
    ap.add_argument('--sheet', default='art/Amiga_Artwork.png')
    ap.add_argument('--palette', default='assets/palette.json')
    ap.add_argument('--out', default='build/c5')
    ap.add_argument('--sweep-bias', action='store_true',
                    help='trace the colourfulness/accuracy trade instead')
    ap.add_argument('--hue-coverage', action='store_true',
                    help='reserve a slot per hue band the art uses')
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    with open(args.palette, encoding='utf-8') as f:
        base = [s['byte'] for s in json.load(f)['slots']]
    tiles = tilecorr.load_tiles()
    oldfont = tilecorr.load_font()
    recs = pdv.sample_all(args.sheet, tiles)
    npx = float(len(recs) * 64)

    if args.hue_coverage:
        groups = L.group_cells(recs, False)
        costs = {k: L.costs_for(v, base, False) for k, v in groups.items()}
        K, _ = fb.allocate(costs, max(0, args.glyphs - L.BASE_SLOTS_NOINV))
        hists = group_histograms(recs, args.glyphs, K)
        want = collections.Counter()
        for r in recs:
            want.update(r['want'].tolist())
        seed, need = coverage_seed(want, hists, npx)
        pal, err = optimise_covered(seed, hists, npx, need)
        print('hue bands the art uses (>=0.2%% of pixels): %s' % ', '.join(sorted(need)))
        print('baseline  %s  err %.2f' % (' '.join('$%02X' % c for c in base),
                                          error_of(base, hists, npx)))
        print('covered   %s  err %.2f' % (' '.join('$%02X' % c for c in pal), err))
        bb = collections.Counter(hue_band(c) for c in base)
        pb = collections.Counter(hue_band(c) for c in pal)
        print()
        print('%-10s %-10s %s' % ('band', 'baseline', 'covered'))
        for b in ['grey'] + sorted(need):
            print('%-10s %-10d %d' % (b, bb.get(b, 0), pb.get(b, 0)))
        with open(os.path.join(args.out, 'palette-hue-covered.json'), 'w',
                  encoding='utf-8', newline='\n') as f:
            json.dump({'glyphs': args.glyphs, 'error': round(err, 2),
                       'bands_required': sorted(need),
                       'slots': [{'slot': i, 'value': '$%02X' % pal[i],
                                  'byte': int(pal[i]),
                                  'band': hue_band(pal[i]),
                                  'rgb': pdv.GAMUT[pal[i]].astype(int).tolist()}
                                 for i in range(16)]}, f, indent=1)
            f.write('\n')
        return 0

    if args.sweep_bias:
        groups = L.group_cells(recs, False)
        costs = {k: L.costs_for(v, base, False) for k, v in groups.items()}
        K, _ = fb.allocate(costs, max(0, args.glyphs - L.BASE_SLOTS_NOINV))
        hists = group_histograms(recs, args.glyphs, K)
        art_ch = 50.5
        print('%-7s %-9s %-9s %-7s %s' % ('bias', 'true err', 'mean chr',
                                          'greys', 'palette'))
        for b in (0.0, 0.5, 1.0, 2.0, 4.0, 8.0):
            p, e = optimise(list(base), hists, npx, bias=b)
            mc = np.mean([chroma(c) for c in p])
            print('%-7.1f %-9.2f %-9.1f %-7d %s'
                  % (b, e, mc, sum(chroma(c) <= 1 for c in p),
                     ' '.join('$%02X' % c for c in p)))
        print('')
        print('  (the ART itself has mean chroma %.1f across its pixels)' % art_ch)
        return 0

    pal = list(base)
    for it in range(3):
        groups = L.group_cells(recs, False)
        costs = {k: L.costs_for(v, pal, False) for k, v in groups.items()}
        K, _ = fb.allocate(costs, max(0, args.glyphs - L.BASE_SLOTS_NOINV))
        hists = group_histograms(recs, args.glyphs, K)
        before = error_of(pal, hists, npx)
        pal, after = optimise(pal, hists, npx)
        print('round %d: %.3f -> %.3f   %s'
              % (it + 1, before, after, ' '.join('$%02X' % c for c in pal)))
        if abs(before - after) < 1e-6:
            break

    print('\nbaseline  ' + ' '.join('$%02X' % c for c in base))
    print('rederived ' + ' '.join('$%02X' % c for c in pal))
    kept = len(set(base) & set(pal))
    print('%d of 16 colours unchanged; %d swapped' % (kept, 16 - kept))
    print('mean chroma  baseline %.1f -> rederived %.1f'
          % (np.mean([chroma(c) for c in base]), np.mean([chroma(c) for c in pal])))
    print('pure greys   baseline %d -> rederived %d'
          % (sum(chroma(c) <= 1 for c in base), sum(chroma(c) <= 1 for c in pal)))

    with open(os.path.join(args.out, 'repalette.json'), 'w',
              encoding='utf-8', newline='\n') as f:
        json.dump({'glyphs': args.glyphs,
                   'baseline': ['$%02X' % c for c in base],
                   'rederived': ['$%02X' % c for c in pal],
                   'slots': [{'slot': i, 'value': '$%02X' % pal[i],
                              'byte': int(pal[i]),
                              'rgb': pdv.GAMUT[pal[i]].astype(int).tolist()}
                             for i in range(16)]}, f, indent=1)
        f.write('\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
