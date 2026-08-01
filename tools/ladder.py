#!/usr/bin/env python3
"""
ladder.py — render the glyph-budget ladder for visual comparison.

C4. Renders only. Applies nothing, implements no memory-map change.

ONE VARIABLE. The palette is C2's throughout, the allocation is fontbuild's
(k-means clustering, exact DP over glyph/slot), the sampling is C1's identity
correspondence. Only the glyph budget moves — and the inverse-video premise,
which is part of what each configuration IS:

    128   inverse KEPT, as today. 69 tile glyph slots + 11 variants from the
          free $60-$7F band. This is C2's shipped configuration and the render
          Jay has already judged.
    192   inverse REMOVED. Cells are grouped by (glyph, render-mode) so an
    221   inverted cell gets its own slot holding the final colours directly —
    256   the engine no longer complements, so nothing is pre-complemented at
          draw time. 142 slots is the floor (C3), the rest are variants.

ENGINE-FAITHFUL. Every panel is drawn cell by cell from an allocated 8x8 glyph
pattern, exactly as BITMAP_PLOTTER composes one — not a per-pixel quantisation
of the artwork, which is an upper bound and flatters every budget equally
(C2 §9 item 1 records that mistake). Verified by emitting a real font and a
real remapped tileset per budget and re-rendering from those FILES.

ALL 256 TILES. Not the 186 live-and-informative ones the palette derivation
samples from — filtering the render the same way leaves 70 tiles black
(C2 §6 item 5).

Usage:
    ladder.py --out build/c4
"""

import argparse
import collections
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, 'tools')
import tilecorr
import palettederive as pdv
import fontbuild as fb
import decbmerge

NPIX = 64
BASE_SLOTS_NOINV = 142          # C3: drawing data + text, once inverse is removed

# The glyphs text renders from, as derived in C3: letters, space, digits and the
# punctuation the code emits. Its overlap with the tile glyphs comes to 37, which
# is exactly §2M invariant 2's "37 glyph slots serve both tiles and text/UI" —
# two derivations, different methods, same number.
TEXT_SLOTS = (set(range(0x01, 0x1B)) | {0x00, 0x20}
              | set(range(0x30, 0x3A)) | {0x2E, 0x3A, 0x2C, 0x2D, 0x21, 0x3F})


def group_cells(recs, keep_inverse):
    """Group sampled cells into what will become one glyph pattern each.

    keep_inverse: group by glyph only — the two render modes share a pattern and
                  are coupled through COMA/COMB (i <-> 15-i).
    otherwise:    group by (glyph, mode) — each gets its own slot and its own
                  free choice of indices, which is what removing inverse buys.
    """
    g = collections.defaultdict(list)
    for r in recs:
        g[r['glyph'] if keep_inverse else (r['glyph'], r['inverse'])].append(r)
    return g


def solve(cells, pal, keep_inverse):
    """Best 64-index pattern for one group, and its squared error."""
    hN = np.zeros((NPIX, 64))
    hI = np.zeros((NPIX, 64))
    for c in cells:
        h = hI if (keep_inverse and c['inverse']) else hN
        h[np.arange(NPIX), c['want']] += 1
    cN, cI = hN @ pdv.D2, hI @ pdv.D2
    opts = np.stack([cN[:, pal[i]] + cI[:, pal[15 - i]] for i in range(16)],
                    axis=-1)
    return opts.argmin(axis=1).astype(np.uint8), float(opts.min(axis=1).sum())


def costs_for(cells, pal, keep_inverse, kmax=10):
    want = np.stack([c['want'] for c in cells])
    inv = np.array([c['inverse'] for c in cells])
    out = {}
    for K in range(1, min(kmax, len(cells)) + 1):
        tot, pats, members = 0.0, [], []
        for blk in pdv.kmeans_cells(want, inv, K):
            if not blk:
                continue
            sub = [cells[i] for i in blk]
            p, e = solve(sub, pal, keep_inverse)
            tot += e
            pats.append(p)
            members.append(sub)
        out[K] = dict(cost=tot, patterns=pats, members=members)
    return out


def build(recs, tiles, oldfont, pal, total_glyphs, keep_inverse):
    """Return (font array, per-cell code table, error, slots used)."""
    black = pal.index(0x00)
    white = pal.index(0x3F)
    groups = group_cells(recs, keep_inverse)
    costs = {k: costs_for(v, pal, keep_inverse) for k, v in groups.items()}

    used_by_tiles = fb.tile_used_slots(tiles)
    if keep_inverse:
        # C2's shipped configuration exactly: 69 tile glyph slots in place,
        # variants only from the provably-safe $60-$7F band (11 slots). Not
        # "all free slots" — text renders out of $00-$3F and those are spoken
        # for (C3). Reproducing 100.85 depends on this being 11, not 52.
        pool = [g for g in fb.SAFE_BAND if g not in used_by_tiles]
        extra = len(pool)
    else:
        # inverse removed: the font is being relaid out anyway, so the only
        # reservation is the text-only glyphs. 142 is the floor (C3).
        extra = max(0, total_glyphs - BASE_SLOTS_NOINV)
        text_only = TEXT_SLOTS - used_by_tiles
        pool = [i for i in range(total_glyphs) if i not in text_only]

    K, _ = fb.allocate(costs, extra)

    npx = float(sum(len(v) for v in groups.values()) * NPIX)
    err = float(np.sqrt(sum(costs[k][K[k]]['cost'] for k in costs) / npx))

    font = np.zeros((max(total_glyphs, 128), NPIX), dtype=np.uint8)
    for g in range(128):
        old = oldfont[g].reshape(NPIX)
        font[g] = np.where(old == 1, white, black)

    # Slot assignment. A glyph's PRIMARY variant keeps that glyph's own index
    # where it can — the pool is only for the slots a configuration adds. In the
    # inverse-kept case that pool is the 11-slot safe band and primaries must not
    # touch it, or the variants have nowhere to go.
    taken = set()
    pool = [s for s in pool if s not in taken]

    def claim(preferred):
        if preferred is not None and preferred not in taken:
            taken.add(preferred)
            if preferred in pool:
                pool.remove(preferred)
            return preferred
        while pool:
            s = pool.pop(0)
            if s not in taken:
                taken.add(s)
                return s
        raise RuntimeError('glyph slot pool exhausted at %d slots' % len(taken))

    codes = [[None] * 9 for _ in range(256)]
    slots_used = 0
    for key, per_k in sorted(costs.items(), key=lambda kv: str(kv[0])):
        glyph = key if keep_inverse else key[0]
        is_norm = keep_inverse or (key[1] is False)
        entry = per_k[K[key]]
        for vi, (pat, members) in enumerate(zip(entry['patterns'],
                                                entry['members'])):
            # primary of a normally-rendered group keeps the original index;
            # inverse-only groups and every extra variant come from the pool
            slot = claim(glyph if (vi == 0 and is_norm) else None)
            slots_used += 1
            font[slot] = pat
            for c in members:
                # inverse kept -> keep the flag, the engine complements at draw.
                # inverse removed -> flag cleared, the pattern IS the output.
                hi = 0x80 if (keep_inverse and c['inverse']) else 0x00
                codes[c['tile']][c['cell']] = slot | hi
    return font, codes, err, slots_used


def draw(font, codes, tiles, pal, keep_inverse):
    """Compose 256 tiles exactly as BITMAP_PLOTTER would."""
    prgb = np.array([pdv.GAMUT[c] for c in pal], dtype=np.uint8)
    out = np.zeros((392, 392, 3), dtype=np.uint8)
    chk = np.indices((8, 8)).sum(axis=0) % 2
    mark = np.stack([np.where(chk, 255, 96)] * 3, axis=-1).astype(np.uint8)
    drawn = 0
    for t in range(256):
        ty, tx = divmod(t, 16)
        for k in range(9):
            cy, cx = divmod(k, 3)
            y, x = ty * 24 + cy * 8, tx * 24 + cx * 8
            c = codes[t][k]
            if c is None:
                out[y:y + 8, x:x + 8] = mark      # tile 255 BR, absent from file
                continue
            idx = font[c & 0x7F].copy() if keep_inverse else font[c].copy()
            if keep_inverse and (c & 0x80):
                idx = 15 - idx
            out[y:y + 8, x:x + 8] = prgb[idx].reshape(8, 8, 3)
            drawn += 1
    return out, drawn


def label(im, text, x, y, fill=(215, 215, 215)):
    ImageDraw.Draw(im).text((x, y), text, fill=fill)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='build/c4')
    ap.add_argument('--sheet', default='art/Amiga_Artwork.png')
    ap.add_argument('--palette', default='assets/palette.json')
    ap.add_argument('--scale', type=int, default=2)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    with open(args.palette, encoding='utf-8') as f:
        pal = [s['byte'] for s in json.load(f)['slots']]
    tiles = tilecorr.load_tiles()
    oldfont = tilecorr.load_font()
    recs = pdv.sample_all(args.sheet, tiles)
    src = np.asarray(Image.open(args.sheet).convert('RGB'))

    configs = [(128, True), (192, False), (221, False), (256, False)]
    panels, rows = [], []
    for total, keep in configs:
        font, codes, err, used = build(recs, tiles, oldfont, pal, total, keep)
        img, drawn = draw(font, codes, tiles, pal, keep)
        tag = '%d glyphs, inverse %s' % (total, 'kept' if keep else 'removed')
        rows.append(dict(total=total, keep_inverse=keep, error=round(err, 2),
                         slots_used=used, cells_drawn=drawn))
        panels.append((tag, err, img))

        # full-resolution single render
        p = Image.fromarray(img).resize((392 * 3, 392 * 3), Image.NEAREST)
        label(p, '%s   err %.2f   %d/2304 cells' % (tag, err, drawn), 4, 3)
        p.save(os.path.join(args.out, 'render-%d.png' % total))

        # emit real artifacts so the render can be re-derived from files
        raw = bytearray()
        for g in range(max(total, 128)):
            px = font[g]
            for r in range(8):
                for b in range(4):
                    raw.append((px[r * 8 + b * 2] << 4) | px[r * 8 + b * 2 + 1])
        with open(os.path.join(args.out, 'font-%d.bin' % total), 'wb') as f:
            f.write(raw)
        segs, _ = decbmerge.read_decb('assets/tileset.bin')
        (addr, blob), = segs
        nb = bytearray(blob)
        for t in range(256):
            for k in range(9):
                if codes[t][k] is None:
                    continue
                off = 512 + k * 256 + t
                if off < len(nb):
                    nb[off] = codes[t][k]
        decbmerge.write_decb(os.path.join(args.out, 'tileset-%d.bin' % total),
                             [(addr, bytes(nb))], 0x0000)
        print('%-34s err %6.2f  slots %3d  cells %d'
              % (tag, err, used, drawn))

    # ------------------------------------------------------------- ladder ---
    sc, gap, lab, strip = args.scale, 8, 14, 20
    w = h = 392
    cw = w * 5 + gap * 4
    canvas = np.full((lab + h + gap + strip, cw, 3), 32, dtype=np.uint8)
    canvas[lab:lab + h, 0:w] = src
    for i, (_, _, img) in enumerate(panels):
        x = (i + 1) * (w + gap)
        canvas[lab:lab + h, x:x + w] = img
    for s in range(16):
        canvas[lab + h + gap:, s * cw // 16:(s + 1) * cw // 16] = \
            pdv.GAMUT[pal[s]].astype(np.uint8)
    im = Image.fromarray(canvas).resize((cw * sc, canvas.shape[0] * sc),
                                        Image.NEAREST)
    label(im, 'Amiga_Artwork.png (source)', 4, 3)
    for i, (tag, err, _) in enumerate(panels):
        label(im, '%s  err %.2f' % (tag, err), (i + 1) * (w + gap) * sc + 4, 3)
    label(im, 'C2 palette, slots 0-15', 4, (lab + h + gap) * sc + 2)
    im.save(os.path.join(args.out, 'ladder.png'))
    print('ladder -> %s/ladder.png' % args.out)

    # -------------------------------------------------------- worst tiles ---
    # Per-tile residual at 221 — the configuration on the decision. The aggregate
    # scalar hides WHERE error lands; this is where a structural failure shows.
    font221, codes221, _, _ = build(recs, tiles, oldfont, pal, 221, False)
    img221, _ = draw(font221, codes221, tiles, pal, False)
    qsrc = pdv.quantise_sheet(args.sheet)
    per_tile = []
    for t in range(256):
        ty, tx = divmod(t, 16)
        got = img221[ty * 24:ty * 24 + 24, tx * 24:tx * 24 + 24].astype(float)
        wantq = qsrc[ty * 24:ty * 24 + 24, tx * 24:tx * 24 + 24]
        want = pdv.GAMUT[wantq]
        n = 0
        e = 0.0
        for k in range(9):
            if tiles[t][k] is None:
                continue
            cy, cx = divmod(k, 3)
            g = got[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            wv = want[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            e += float(((g - wv) ** 2).sum())
            n += 64
        if n:
            per_tile.append((float(np.sqrt(e / n)), t))
    per_tile.sort(reverse=True)
    worst = per_tile[:16]

    tw, cols = 24, 8
    rowsN = (len(worst) + cols - 1) // cols
    cell_h = tw * 2 + 12
    canvas = np.full((lab + rowsN * cell_h, cols * (tw + 6), 3), 32,
                     dtype=np.uint8)
    for i, (e, t) in enumerate(worst):
        r, c = divmod(i, cols)
        ty, tx = divmod(t, 16)
        x = c * (tw + 6)
        y = lab + r * cell_h
        canvas[y:y + tw, x:x + tw] = src[ty * 24:ty * 24 + 24,
                                         tx * 24:tx * 24 + 24]
        canvas[y + tw:y + tw * 2, x:x + tw] = img221[ty * 24:ty * 24 + 24,
                                                    tx * 24:tx * 24 + 24]
    wi = Image.fromarray(canvas).resize((canvas.shape[1] * 4,
                                         canvas.shape[0] * 4), Image.NEAREST)
    label(wi, 'worst 16 tiles at 221 glyphs — top row of each pair: Amiga source, '
              'below it: engine render', 4, 3)
    for i, (e, t) in enumerate(worst):
        r, c = divmod(i, cols)
        label(wi, '%d  %.0f' % (t, e), c * (tw + 6) * 4 + 2,
              (lab + r * cell_h + tw * 2) * 4 + 1, (170, 170, 170))
    wi.save(os.path.join(args.out, 'worst-tiles.png'))
    print('worst tiles at 221: ' + ', '.join('%d(%.0f)' % (t, e)
                                             for e, t in worst[:8]))

    with open(os.path.join(args.out, 'ladder.json'), 'w',
              encoding='utf-8', newline='\n') as f:
        json.dump({'palette': ['$%02X' % c for c in pal], 'configs': rows,
                   'worst_tiles_221': [{'tile': t, 'rms': round(e, 1)}
                                       for e, t in per_tile[:32]]},
                  f, indent=1)
        f.write('\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
