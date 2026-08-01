#!/usr/bin/env python3
"""
palettederive.py — derive a 16-entry CoCo3 palette from the Amiga artwork,
IN SLOT ORDER, and measure whether that order survives inverse video.

C2 recon. Produces a proposal and its evidence. Applies nothing.

THE TWO PROBLEMS, WHICH ARE SEPARATE

  which 16 colours   The GIME palette is screen-wide ($FFB0-$FFBF, no per-tile
                     palette), so colour use is computed across the whole sheet
                     and weighted by how often it is actually drawn.

  which slot each    NextRowInv implements inverse video with COMA/COMB, which
  goes in            complements all four bits: index i pairs with 15-i. 852 of
                     2,303 tile cells use the inverse bit. Get the order wrong
                     and a third of the tileset inverts to arbitrary colours.

WHY THE ORDERING REDUCES TO A PAIRING

A glyph carries palette INDICES in its nibbles. Say glyph g uses index I for its
ink pixels and P for its paper pixels. Rendered normally a cell shows
(palette[I], palette[P]); rendered inverse it shows (palette[15-I], palette[15-P]).

The same glyph is used in both kinds of cell. So if the art wants (A_ink, A_paper)
where g appears normally and (C_ink, C_paper) where it appears inverted, then A_ink
and C_ink must sit at complementary indices, and so must A_paper and C_paper.

Consequence: WHICH index-pair a colour-pair occupies does not matter — every pair
(i, 15-i) is equivalent, and swapping within a pair only relabels I and P. The
whole ordering problem is therefore **partitioning the 16 chosen colours into 8
complement pairs**, which is a maximum-weight perfect matching, solved exactly
here by DP over subsets (16 nodes).

SAMPLING

Rows of assets/tile-correspondence.json with live AND informative true (C1 §8:
filter on informative, not confidence — a blank tile scores 1.000 against any
uniform art tile and carries no colour). Cells whose glyph is $55 or $66 are
excluded; both are corrupt (CLAUDE.md §2J) and are the only two glyphs in the
addressable font with nibbles outside {0,1}. 186 tiles, 1,417 cells, 55 glyphs.

Usage:
    palettederive.py --sheet art/Amiga_Artwork.png --json assets/palette.json
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
import decbmerge

CORRUPT = (0x55, 0x66)
LEVELS = ['assets/levels/level_%s.bin' % c for c in 'abcdefghij']


# ------------------------------------------------------------------ gamut ---
def gime_rgb(byte):
    r = (((byte >> 5) & 1) << 1) | ((byte >> 2) & 1)
    g = (((byte >> 4) & 1) << 1) | ((byte >> 1) & 1)
    b = (((byte >> 3) & 1) << 1) | (byte & 1)
    return np.array([r * 85, g * 85, b * 85], dtype=float)


GAMUT = np.array([gime_rgb(b) for b in range(64)])       # 64 x 3
RGB_TO_BYTE = {tuple(GAMUT[b].astype(int)): b for b in range(64)}


def snap_index(px):
    """Nearest GIME byte index for an RGB triple."""
    return int(np.argmin(((GAMUT - px) ** 2).sum(axis=1)))


# ----------------------------------------------------------------- weights --
def level_tile_counts():
    """How often each tile index appears across the ten level maps."""
    c = collections.Counter()
    for path in LEVELS:
        segs, _ = decbmerge.read_decb(path)
        (_, blob), = segs
        c.update(blob[512:512 + 8192])
    return c


# ----------------------------------------------------------------- sampling --
def sample(sheet, rows, tiles, glyph_ink):
    """One record per sampled cell.

    Each record carries the two dominant GIME colours of the art cell, split
    into ink and paper by MAJORITY VOTE against the glyph's own ink mask — so
    the assignment comes from the tileset side, not from guessing which of the
    two art colours is foreground.
    """
    img = np.asarray(Image.open(sheet).convert('RGB'))
    out = []
    for r in rows:
        t = r['tile']
        ty, tx = divmod(t, 16)
        tile_img = img[ty * 24:ty * 24 + 24, tx * 24:tx * 24 + 24]
        for k in range(9):
            code = tiles[t][k]
            if code is None or (code & 0x7F) in CORRUPT:
                continue
            g = code & 0x7F
            inv = bool(code & 0x80)
            cy, cx = divmod(k, 3)
            cell = tile_img[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]

            q = np.array([[snap_index(cell[y, x]) for x in range(8)]
                          for y in range(8)])
            vals, counts = np.unique(q, return_counts=True)
            order = np.argsort(-counts)
            c0 = int(vals[order[0]])
            c1 = int(vals[order[1]]) if len(vals) > 1 else c0

            # which of c0/c1 sits under the glyph's ink pixels?
            mask = glyph_ink[g]
            if inv:
                mask = ~mask
            d0 = ((GAMUT[q] - GAMUT[c0]) ** 2).sum(axis=2)
            d1 = ((GAMUT[q] - GAMUT[c1]) ** 2).sum(axis=2)
            near0 = d0 <= d1
            ink_is_c0 = (near0 & mask).sum() >= (near0 & ~mask).sum()
            ink, paper = (c0, c1) if ink_is_c0 else (c1, c0)

            out.append(dict(tile=t, cell=k, glyph=g, inverse=inv,
                            ink=ink, paper=paper))
    return out


# ------------------------------------------------------- colour selection ---
def choose16(weights, seed_error_only=True):
    """Pick 16 GIME indices minimising weighted squared error to the demand.

    weights: {gime_index: weight}. Greedy seed, then local search over swaps.
    """
    demand = np.array(sorted(weights.items()))
    idx = demand[:, 0].astype(int)
    w = demand[:, 1].astype(float)
    pts = GAMUT[idx]

    def cost(sel):
        d = ((pts[:, None, :] - GAMUT[list(sel)][None, :, :]) ** 2).sum(axis=2)
        return float((w * d.min(axis=1)).sum())

    sel = []
    for _ in range(16):
        best, bc = None, None
        for c in range(64):
            if c in sel:
                continue
            v = cost(sel + [c])
            if bc is None or v < bc:
                best, bc = c, v
        sel.append(best)

    improved = True
    while improved:
        improved = False
        cur = cost(sel)
        for i in range(16):
            for c in range(64):
                if c in sel:
                    continue
                trial = list(sel)
                trial[i] = c
                v = cost(trial)
                if v < cur - 1e-9:
                    sel, cur, improved = trial, v, True
    return sorted(sel)


def weighted_mean_error(sel, weights):
    """Mean per-pixel Euclidean RGB distance to the nearest chosen entry."""
    tot = num = 0.0
    for gi, wt in weights.items():
        d = np.sqrt(((GAMUT[list(sel)] - GAMUT[gi]) ** 2).sum(axis=1)).min()
        num += wt * d
        tot += wt
    return num / tot if tot else 0.0


# ------------------------------------------------------------- the pairing --
def best_matching(nodes, pairw):
    """Exact maximum-weight perfect matching on 16 nodes, DP over subsets."""
    n = len(nodes)
    full = 1 << n
    best = [None] * full
    best[0] = (0.0, [])
    for mask in range(full):
        if best[mask] is None:
            continue
        # lowest unmatched node
        i = 0
        while i < n and (mask >> i) & 1:
            i += 1
        if i == n:
            continue
        for j in range(i + 1, n):
            if (mask >> j) & 1:
                continue
            nm = mask | (1 << i) | (1 << j)
            w = best[mask][0] + pairw.get(frozenset((nodes[i], nodes[j])), 0.0)
            if best[nm] is None or w > best[nm][0]:
                best[nm] = (w, best[mask][1] + [(nodes[i], nodes[j])])
    return best[full - 1]


def build_palette(pairs):
    """Lay 8 colour-pairs into slots so each pair sits at (i, 15-i)."""
    pal = [None] * 16
    for slot, (a, b) in enumerate(pairs):
        pal[slot] = a
        pal[15 - slot] = b
    return pal


# ------------------------------------------------------ complement demand ---
def complement_demand(recs):
    """Which colours the art requires to sit at complementary indices.

    Only glyphs used BOTH normally and inverted constrain anything: a glyph that
    never renders inverted can take any pair of indices.

    Built as a SOFT outer product over cell pairs rather than a majority vote.
    Majority is brittle here — dominance of the modal colour ranges from 22% to
    99% across glyphs, so a hard vote would assert a constraint from a 22%
    plurality with the same confidence as one from a 95% consensus.
    Each glyph contributes total weight (n_normal + n_inverse), spread over the
    pairs its cells actually witness.
    """
    byg = collections.defaultdict(lambda: {'n': [], 'i': []})
    for r in recs:
        byg[r['glyph']]['i' if r['inverse'] else 'n'].append(r)

    dem = collections.Counter()
    stats = []
    for g, d in byg.items():
        n, i = d['n'], d['i']
        if not n or not i:
            continue
        wt = (len(n) + len(i)) / float(len(n) * len(i))
        for a in n:
            for b in i:
                dem[frozenset((a['ink'], b['ink']))] += wt
                dem[frozenset((a['paper'], b['paper']))] += wt
        stats.append((len(n) + len(i), g, len(n), len(i)))
    return dem, sorted(stats, reverse=True), byg


def satisfied_weight(pal, dem):
    """Demand weight whose pair sits at complementary slots in `pal`."""
    have = {frozenset((pal[i], pal[15 - i])) for i in range(8)}
    ok = sum(w for p, w in dem.items() if p in have)
    return ok, sum(dem.values())


# -------------------------------------------------------- inverse-cell test --
def assign_glyph_indices(recs, pal):
    """Per glyph, the (ink, paper) palette indices C3 would most plausibly pick.

    Votes from normal cells are direct; votes from inverse cells go through the
    complement, because that is how they will render. Weighted equally per cell.
    """
    def nearest_slot(c):
        d = ((np.array([GAMUT[p] for p in pal]) - GAMUT[c]) ** 2).sum(axis=1)
        return int(np.argmin(d))

    near = {c: nearest_slot(c) for c in range(64)}
    votes = collections.defaultdict(lambda: (collections.Counter(),
                                             collections.Counter()))
    for r in recs:
        vi, vp = votes[r['glyph']]
        si, sp = near[r['ink']], near[r['paper']]
        if r['inverse']:
            si, sp = 15 - si, 15 - sp
        vi[si] += 1
        vp[sp] += 1
    return {g: (vi.most_common(1)[0][0], vp.most_common(1)[0][0])
            for g, (vi, vp) in votes.items()}, near


def inverse_test(recs, pal):
    """Fraction of inverse-coded cells whose colours survive COMA/COMB.

    A cell survives when the COLOUR the glyph renders after complementing is
    the colour the art wants there. Compared as colours, not slot indices: a
    palette may hold the same colour in more than one slot (the art demands
    19.3% of its complement weight as self-pairs), and an index comparison
    would spuriously fail whenever the right colour sits at a different slot.
    """
    gi, near = assign_glyph_indices(recs, pal)
    tot = ok = ok_ink = ok_paper = 0
    fails = collections.Counter()
    for r in recs:
        if not r['inverse']:
            continue
        I, P = gi[r['glyph']]
        rendered_i, rendered_p = pal[15 - I], pal[15 - P]
        want_i, want_p = pal[near[r['ink']]], pal[near[r['paper']]]
        tot += 1
        i_ok, p_ok = (rendered_i == want_i), (rendered_p == want_p)
        ok_ink += i_ok
        ok_paper += p_ok
        if i_ok and p_ok:
            ok += 1
        else:
            fails[r['tile']] += 1
    return dict(total=tot, both=ok, ink=ok_ink, paper=ok_paper,
                fails_by_tile=fails)


# ------------------------------------------------------------- the variants --
def colour_weights(recs):
    w = collections.Counter()
    for r in recs:
        w[r['ink']] += 1
        w[r['paper']] += 1
    return w


def variant_error_first(recs, weights):
    """Best 16 by weighted error; pairing chosen optimally afterwards."""
    sel = choose16(weights)
    dem, _, _ = complement_demand(recs)
    pairw = {}
    for p, w in dem.items():
        a = sorted(p)
        x, y = (a[0], a[0]) if len(a) == 1 else (a[0], a[1])
        if x in sel and y in sel and x != y:
            pairw[frozenset((x, y))] = w
    _, pairs = best_matching(sel, pairw)
    return build_palette(pairs)


def variant_demand_first(recs, weights, dem):
    """The 8 heaviest demanded pairs, taken literally."""
    pairs = []
    for p, _ in dem.most_common():
        a = sorted(p)
        pairs.append((a[0], a[0]) if len(a) == 1 else (a[0], a[1]))
        if len(pairs) == 8:
            break
    return build_palette(pairs)


def variant_balanced(recs, weights, dem, lam=180.0):
    """Greedy over pairs, scoring demand satisfied AND coverage gained.

    lam converts colour-coverage improvement (in weighted RGB error) into the
    same units as demand weight. Chosen so neither term dominates; the frontier
    either side of it is reported rather than hidden.
    """
    cands = set()
    for p in dem:
        a = sorted(p)
        cands.add((a[0], a[0]) if len(a) == 1 else (a[0], a[1]))
    for c in list(weights)[:24]:
        for d in list(weights)[:24]:
            cands.add((min(c, d), max(c, d)))

    chosen, cols = [], []
    for _ in range(8):
        base_err = weighted_mean_error(cols, weights) if cols else None
        best, bs = None, None
        for pr in cands:
            if pr in chosen:
                continue
            new = cols + [pr[0], pr[1]]
            err = weighted_mean_error(new, weights)
            gain = (base_err - err) if base_err is not None else (255.0 - err)
            d = dem.get(frozenset(pr), 0.0)
            s = d + lam * gain
            if bs is None or s > bs:
                best, bs = pr, s
        chosen.append(best)
        cols += [best[0], best[1]]
    return build_palette(chosen)


def survival(pal, recs):
    """Cells rendering the colour the art wants, split by render mode.

    NORMAL cells face no complement constraint, so their rate is the ceiling
    imposed by one-glyph-one-colour (§2M invariant 1) alone. The INVERSE rate
    sits under it, and the ratio between them isolates what the slot ORDER
    costs — which the raw inverse fraction cannot, because that fraction is
    trivially maximised by a coarse palette (a 1-colour palette scores 100%).
    """
    gi, near = assign_glyph_indices(recs, pal)
    out = {'normal': [0, 0], 'inverse': [0, 0]}
    for r in recs:
        I, P = gi[r['glyph']]
        if r['inverse']:
            ri, rp = pal[15 - I], pal[15 - P]
        else:
            ri, rp = pal[I], pal[P]
        wi, wp = pal[near[r['ink']]], pal[near[r['paper']]]
        k = 'inverse' if r['inverse'] else 'normal'
        out[k][1] += 1
        if ri == wi and rp == wp:
            out[k][0] += 1
    return out


def frontier_search(recs, weights, dem, err_cap, base=None, rounds=3):
    """Maximise satisfied complement demand subject to weighted error <= cap.

    Colour choice and slot order are not separable — optimising them in turn
    gives a good set in a bad arrangement — so this searches colours while
    re-solving the pairing exactly (DP matching) at every step.
    """
    sel = list(base) if base else choose16(weights)

    def pair_and_score(cols):
        pw = {}
        for p, w in dem.items():
            a = sorted(p)
            if len(a) == 1:
                continue
            if a[0] in cols and a[1] in cols:
                pw[frozenset((a[0], a[1]))] = w
        sc, pairs = best_matching(list(cols), pw)
        return sc, pairs

    best_cols = list(sel)
    best_sc, best_pairs = pair_and_score(best_cols)
    for _ in range(rounds):
        improved = False
        for i in range(16):
            for c in range(64):
                if c in best_cols:
                    continue
                trial = list(best_cols)
                trial[i] = c
                if weighted_mean_error(trial, weights) > err_cap:
                    continue
                sc, pairs = pair_and_score(trial)
                if sc > best_sc + 1e-9:
                    best_cols, best_sc, best_pairs = trial, sc, pairs
                    improved = True
        if not improved:
            break
    return build_palette(best_pairs)


def render_comparison(sheet, pal, out_path, scale=2):
    """Original sheet beside itself quantised to the proposed 16, plus swatches.

    Mechanical. Whether it looks right is Jay's call, not this tool's (§3).
    """
    img = np.asarray(Image.open(sheet).convert('RGB')).astype(float)
    h, w, _ = img.shape
    pal_rgb = np.array([GAMUT[c] for c in pal])
    flat = img.reshape(-1, 3)
    d = ((flat[:, None, :] - pal_rgb[None, :, :]) ** 2).sum(axis=2)
    quant = pal_rgb[np.argmin(d, axis=1)].reshape(h, w, 3)

    gap, strip = 8, 24
    canvas = np.zeros((h + gap + strip, w * 2 + gap, 3), dtype=np.uint8)
    canvas[:, :] = 32
    canvas[:h, :w] = img.astype(np.uint8)
    canvas[:h, w + gap:] = quant.astype(np.uint8)
    for s in range(16):                                   # slot order, left to right
        x0 = s * (w * 2 + gap) // 16
        x1 = (s + 1) * (w * 2 + gap) // 16
        canvas[h + gap:, x0:x1] = GAMUT[pal[s]].astype(np.uint8)

    out = Image.fromarray(canvas)
    out = out.resize((out.width * scale, out.height * scale), Image.NEAREST)
    out.save(out_path)
    return out_path


def evaluate(pal, recs, weights, dem):
    ok, tot = satisfied_weight(pal, dem)
    inv = inverse_test(recs, pal)
    return dict(
        palette=[int(c) for c in pal],
        distinct=len(set(pal)),
        weighted_mean_error=round(weighted_mean_error(pal, weights), 3),
        demand_satisfied=round(100.0 * ok / tot, 1),
        inverse_cells=inv['total'],
        inverse_both=inv['both'],
        inverse_both_pct=round(100.0 * inv['both'] / inv['total'], 1),
        inverse_ink_pct=round(100.0 * inv['ink'] / inv['total'], 1),
        inverse_paper_pct=round(100.0 * inv['paper'] / inv['total'], 1),
        fails_by_tile=inv['fails_by_tile'])


# ---------------------------------------------------------------- pipeline --
def load_rows():
    with open('assets/tile-correspondence.json', encoding='utf-8') as f:
        rows = json.load(f)['rows']
    return [r for r in rows if r['live'] and r['informative']]


def derive(recs, weights, dem, j=1):
    """j slot-pairs spent on the heaviest demanded complements, the rest on
    coverage. j=1 is the knee of the frontier — see docs/project/palette.md."""
    pairs = []
    for p, _ in dem.most_common(j):
        a = sorted(p)
        pairs.append((a[0], a[0]) if len(a) == 1 else (a[0], a[1]))
    used = [c for pr in pairs for c in pr]
    fill, pool = [], [c for c, _ in weights.most_common()]
    for _ in range((8 - j) * 2):
        best, bv = None, None
        for c in pool:
            if c in used + fill:
                continue
            v = weighted_mean_error(used + fill + [c], weights)
            if bv is None or v < bv:
                best, bv = c, v
        fill.append(best)
    pairs += [(fill[2 * i], fill[2 * i + 1]) for i in range(8 - j)]
    return build_palette(pairs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sheet', default='art/Amiga_Artwork.png')
    ap.add_argument('--j', type=int, default=1)
    ap.add_argument('--json')
    ap.add_argument('--render')
    ap.add_argument('--frontier', action='store_true')
    args = ap.parse_args()

    rows = load_rows()
    tiles = tilecorr.load_tiles()
    glyphs = tilecorr.load_font()
    ink = {g: (glyphs[g] == 1) for g in range(128)}

    recs = sample(args.sheet, rows, tiles, ink)
    weights = colour_weights(recs)
    dem, stats, byg = complement_demand(recs)

    if args.frontier:
        for j in range(9):
            pal = derive(recs, weights, dem, j)
            r = evaluate(pal, recs, weights, dem)
            s = survival(pal, recs)
            n = 100.0 * s['normal'][0] / s['normal'][1]
            i = 100.0 * s['inverse'][0] / s['inverse'][1]
            print('j=%d demand %.1f%% err %.2f distinct %d normal %.1f%% '
                  'inverse %.1f%% eff %.1f%%'
                  % (j, r['demand_satisfied'], r['weighted_mean_error'],
                     r['distinct'], n, i, 100 * i / n))
        return 0

    pal = derive(recs, weights, dem, args.j)
    r = evaluate(pal, recs, weights, dem)
    s = survival(pal, recs)
    print('%s  j=%d' % (args.sheet, args.j))
    print('  palette ' + ' '.join('$%02X' % c for c in pal))
    print('  distinct %d  weighted mean error %.3f  demand satisfied %.1f%%'
          % (r['distinct'], r['weighted_mean_error'], r['demand_satisfied']))
    print('  normal %d/%d (%.1f%%)   inverse %d/%d (%.1f%%)'
          % (s['normal'][0], s['normal'][1],
             100.0 * s['normal'][0] / s['normal'][1],
             s['inverse'][0], s['inverse'][1],
             100.0 * s['inverse'][0] / s['inverse'][1]))

    if args.render:
        print('  render -> %s' % render_comparison(args.sheet, pal, args.render))

    if args.json:
        pairs = [{'slots': [i, 15 - i],
                  'colours': ['$%02X' % pal[i], '$%02X' % pal[15 - i]],
                  'self_paired': pal[i] == pal[15 - i],
                  'demand_weight': round(
                      dem.get(frozenset((pal[i], pal[15 - i])), 0.0), 1)}
                 for i in range(8)]
        slots = []
        for i, c in enumerate(pal):
            rgb = GAMUT[c].astype(int).tolist()
            slots.append({'slot': i, 'value': '$%02X' % c, 'byte': int(c),
                          'rgb': rgb, 'complement_slot': 15 - i,
                          'complement_value': '$%02X' % pal[15 - i],
                          'demand_weight': int(weights.get(c, 0))})
        fails = sorted(r['fails_by_tile'].items(), key=lambda kv: -kv[1])
        doc = {
            'source_sheet': args.sheet,
            'derived': '2026-08-01, dispatch C2',
            'applied': False,
            'note': 'Proposal only. C3 applies this; graphics.asm is untouched.',
            'slots': slots,
            'complement_pairs': pairs,
            'metrics': {
                'weighted_mean_error': r['weighted_mean_error'],
                'distinct_colours': r['distinct'],
                'complement_demand_satisfied_pct': r['demand_satisfied'],
                'cells_sampled': len(recs),
                'normal_cells': s['normal'][1],
                'normal_survival_pct': round(
                    100.0 * s['normal'][0] / s['normal'][1], 1),
                'inverse_cells': s['inverse'][1],
                'inverse_survival_pct': round(
                    100.0 * s['inverse'][0] / s['inverse'][1], 1),
                'ordering_efficiency_pct': round(
                    100.0 * (s['inverse'][0] / s['inverse'][1])
                    / (s['normal'][0] / s['normal'][1]), 1)},
            'inverse_failures_by_tile': [
                {'tile': t, 'cells': n} for t, n in fails],
        }
        with open(args.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(doc, f, indent=1)
            f.write('\n')
        print('  json   -> %s' % args.json)
    return 0


if __name__ == '__main__':
    sys.exit(main())
