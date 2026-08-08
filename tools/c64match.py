#!/usr/bin/env python3
"""
c64match.py — build a CoCo3 font + tile table that matches the C64 tileset (C8).

  python tools/c64match.py [--out build/c8] [--renders docs/reports/C8-renders]

WHY THIS TARGET IS DIFFERENT. Every art route so far aimed at the Amiga sheet:
~1,962 distinct 8x8 appearances against 151 slots, 13:1, and the glyph averages
that come out of that are what Jay rejected as structurally wrong.

`art/image.png` is already PETSCII. Its shapes ARE the shapes in
`assets/tileset.bin`; only its colours are new. So nothing is averaged and no
shape is invented — every emitted glyph is an existing PETSCII pattern with two
colours substituted for its ink and paper.

THE EXTRACTION RULE, and why this one:

    ink   = dominant quantised sheet colour over pixels where the base glyph's
            nibble is NON-ZERO
    paper = dominant over pixels where it is zero
    combo = (base glyph code, ink, paper)

**The inverse bit needs no special handling, and that is not an oversight.** The
output configuration removes inverse (bit 7 becomes part of the glyph index,
C6 §3), so each slot holds a complete pattern. Reading the sheet AT THE PATTERN'S
OWN PIXEL POSITIONS reproduces what is on the sheet at those positions whether or
not the cell is currently drawn inverted — the colour pair absorbs the flip. An
"inverse-aware" rule that swapped ink/paper for bit-7 cells would only be right
if the emitted pattern were complemented too, which it is not.

That rule reproduces C8 §1's derivation figures exactly: 200 combos, 69 glyphs,
2,304 cells, 28 of 69 glyphs needing a single slot, and a pure top-151-by-count
allocation would leave 2,255 cells exact.

**But that allocation is infeasible here**, and the ALLOCATOR below differs
because of it. Ranking combos by cell count and keeping the top 151 orphans 17
glyphs — $0E $11 $15 $25 $31 $32 $33 $34 $5A $5B $69 $6D $6E $72 $75 $7B $7C —
whose 21 cells would then have to merge into a DIFFERENT shape. C8 §5 forbids
that, and seven of the seventeen are text slots. So every glyph is guaranteed its
own index first and variants compete for what is left.

JPEG NOISE. `art/image.png` is a JPEG, worst at cell edges where two colours
meet. Taking the DOMINANT colour of each class — a mode over ~32 pixels, not a
mean — is what makes this robust: ringing perturbs a handful of edge pixels and
cannot outvote the body of a flat region. No smoothing or pre-filtering is
applied, so nothing is invented to compensate.
"""
import argparse
import collections
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, 'tools')
sys.path.insert(0, os.path.join('tools', 'glyph_tool'))

import decbmerge                                              # noqa: E402
import palettederive as pdv                                   # noqa: E402
import tilecorr                                               # noqa: E402
import sheet as S                                             # noqa: E402

SHEET = 'art/image.png'
PLANES = ['TL', 'TM', 'TR', 'ML', 'MM', 'MR', 'BL', 'BM', 'BR']
N_SLOTS = 192


# ----------------------------------------------------------------- inputs ---
def text_slots():
    """Font slots the game's text actually addresses.

    `PRINT_INFO` (PETROBOTS_6809.asm:3589) subtracts $60 from any character
    >= $60, so `$60-$7F` draw from `$00-$1F` and everything below passes
    through. Derived from the 49 `.STR` literals in the two sources rather than
    assumed from the range: 53 slots, not the whole $00-$3F band.
    """
    import io
    import re
    src = (io.open('src/PETROBOTS_6809.asm', encoding='latin-1').read()
           + io.open('src/BACKGROUND_TASKS_6809.ASM', encoding='latin-1').read())
    out = set()
    for ln in re.split(r'\r\n|\r|\n', src):
        m = re.match(r'\s*\.STR\s+"([^"]*)"', ln)
        if m:
            for ch in m.group(1):
                c = ord(ch)
                out.add(c - 0x60 if c >= 0x60 else c)
    return out


def derive(tiles, font, qidx):
    """-> (combo counter, per-cell combo map). One pass, no allocation yet."""
    combo = collections.Counter()
    cellmap = {}
    for t in range(256):
        for k in range(9):
            code = tiles[t][k]
            if code is None:
                continue
            g = code & 0x7F
            pat = font[g]
            x, y, _, _ = S.tile_rect(t)
            cy, cx = divmod(k, 3)
            q = qidx[y + cy * 8:y + cy * 8 + 8, x + cx * 8:x + cx * 8 + 8]
            ink = pat != 0
            c1 = int(np.bincount(q[ink], minlength=16).argmax()) if ink.any() else 0
            c0 = int(np.bincount(q[~ink], minlength=16).argmax()) if (~ink).any() else 0
            key = (g, c1, c0)
            combo[key] += 1
            cellmap[(t, k)] = key
    return combo, cellmap


# -------------------------------------------------------------- allocation --
def allocate(combo, tileglyphs, reserved, pal_rgb):
    """Assign combos to slots.

    A combo's PRIMARY placement is the base glyph's own index. That is what
    keeps the 21 slots serving both text and tiles readable: the shape at slot
    $41 is still the 'A' shape, only its two colours moved. Variants take free
    slots; `reserved` (text-only) are never touched.

    Leftovers MERGE into the surviving combo with the SAME GLYPH and the nearest
    colour pair — never into a different shape. Shape is exact for every cell by
    construction; only colour degrades.
    """
    per_glyph = collections.defaultdict(list)
    for key, n in combo.most_common():
        per_glyph[key[0]].append((key, n))

    slot_of, assign = {}, {}
    for g in sorted(tileglyphs):                    # primaries at their own index
        key = per_glyph[g][0][0]
        slot_of[key] = g
        assign[g] = key

    free = [s for s in range(N_SLOTS)
            if s not in tileglyphs and s not in reserved]
    variants = [(key, n) for key, n in combo.most_common() if key not in slot_of]

    placed, overflow = [], []
    for key, n in variants:
        if free:
            s = free.pop(0)
            slot_of[key] = s
            assign[s] = key
            placed.append((key, n))
        else:
            overflow.append((key, n))

    # merge what did not fit, into the nearest surviving pair of the same glyph
    merges = []
    for key, n in overflow:
        g, c1, c0 = key
        cands = [k for k in slot_of if k[0] == g]
        best = min(cands, key=lambda k: (np.linalg.norm(
            pal_rgb[k[1]].astype(int) - pal_rgb[c1].astype(int))
            + np.linalg.norm(pal_rgb[k[2]].astype(int) - pal_rgb[c0].astype(int))))
        dist = float(np.linalg.norm(pal_rgb[best[1]].astype(int) - pal_rgb[c1].astype(int))
                     + np.linalg.norm(pal_rgb[best[2]].astype(int) - pal_rgb[c0].astype(int)))
        slot_of[key] = slot_of[best]
        merges.append(dict(wanted=key, got=best, cells=n, distance=round(dist, 1)))
    return slot_of, assign, merges, len(placed)


def build_font(assign, font, reserved):
    """Emit the 192-glyph font. Reserved text slots keep their current 0/1
    content; every other used slot is a PETSCII pattern with two colours."""
    out = np.zeros((N_SLOTS, 8, 8), dtype=np.uint8)
    for s in sorted(reserved):
        if s < len(font):
            out[s] = font[s]                     # untouched: 0/1 = black/white
    for s, (g, c1, c0) in assign.items():
        pat = font[g]
        out[s] = np.where(pat != 0, c1, c0)
    return out


def build_tileset(tiles, cellmap, slot_of):
    """Rewrite the nine cell planes to point at colour-variant slots."""
    segs, _ = decbmerge.read_decb(tilecorr.TILESET)
    (addr, blob), = segs
    nb = bytearray(blob)
    for (t, k), key in cellmap.items():
        off = 512 + k * 256 + t
        if off < len(nb):
            nb[off] = slot_of[key]
    return addr, bytes(nb)


# ------------------------------------------------------------ verification --
def render_engine(font, codes):
    """Draw the whole 384x384 sheet through the glyph model, from the EMITTED
    files only — the independent path AC7 needs."""
    idx = np.zeros((384, 384), dtype=np.uint8)
    for t in range(256):
        ty, tx = divmod(t, 16)
        for k in range(9):
            cy, cx = divmod(k, 3)
            c = codes[t][k]
            px = np.zeros((8, 8), np.uint8) if c is None else font[c]
            idx[ty * 24 + cy * 8:ty * 24 + cy * 8 + 8,
                tx * 24 + cx * 8:tx * 24 + cx * 8 + 8] = px
    return idx


def shape_exact(font_new, tiles, cellmap, slot_of, font_old):
    """AC3 — every cell's ink/paper mask must equal the one it has today.
    Compared against the current font, not asserted."""
    bad = []
    for (t, k), key in cellmap.items():
        g = tiles[t][k] & 0x7F
        old = font_old[g] != 0
        new = font_new[slot_of[key]]
        # the emitted glyph's two colours are (c1 where old, c0 elsewhere)
        _, c1, c0 = key if slot_of[key] not in (None,) else key
        got = new != new[~old][0] if (~old).any() else np.ones_like(old)
        if (~old).any() and (old).any():
            got = new == new[old][0]
        elif not old.any():
            got = np.zeros_like(old)
        else:
            got = np.ones_like(old)
        if not np.array_equal(got, old):
            bad.append((t, k))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='build/c8')
    ap.add_argument('--renders', default='docs/reports/C8-renders')
    ap.add_argument('--slots', type=int, default=None,
                    help='cap tile slots (default: everything not reserved)')
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    os.makedirs(args.renders, exist_ok=True)

    pal_rgb, pal_bytes, pal_names = S.load_palette()
    tiles = tilecorr.load_tiles()
    font_old = tilecorr.load_font()
    qidx, _ = S.quantise(S.load_sheet(SHEET), pal_rgb)

    combo, cellmap = derive(tiles, font_old, qidx)
    tileglyphs = {k[0] for k in combo}
    text = text_slots()
    reserved = text - tileglyphs

    print('cells with data      : %d' % len(cellmap))
    print('distinct glyph codes : %d' % len(tileglyphs))
    print('distinct combos      : %d' % len(combo))
    print('text slots addressed : %d  (shared with tiles %d, text-only %d reserved)'
          % (len(text), len(text & tileglyphs), len(reserved)))

    if args.slots:                                # honour an explicit cap
        # Every glyph MUST keep its best combo, or it has no slot to point at.
        # Trimming by global rank alone orphans a rare glyph whose own best pair
        # falls below the cap — which is a crash, not a merge.
        primary = {}
        for key, n in combo.most_common():
            primary.setdefault(key[0], key)
        keep = set(primary.values())
        for key, _ in combo.most_common():
            if len(keep) >= args.slots:
                break
            keep.add(key)
        trimmed = collections.Counter({k: v for k, v in combo.items() if k in keep})
        drop = collections.Counter({k: v for k, v in combo.items() if k not in keep})
        slot_of, assign, merges, placed = allocate(trimmed, tileglyphs, reserved, pal_rgb)
        for key, n in drop.most_common():
            g, c1, c0 = key
            cands = [k for k in slot_of if k[0] == g]
            best = min(cands, key=lambda k: (
                np.linalg.norm(pal_rgb[k[1]].astype(int) - pal_rgb[c1].astype(int))
                + np.linalg.norm(pal_rgb[k[2]].astype(int) - pal_rgb[c0].astype(int))))
            dist = float(np.linalg.norm(pal_rgb[best[1]].astype(int) - pal_rgb[c1].astype(int))
                         + np.linalg.norm(pal_rgb[best[2]].astype(int) - pal_rgb[c0].astype(int)))
            slot_of[key] = slot_of[best]
            merges.append(dict(wanted=key, got=best, cells=n, distance=round(dist, 1)))
    else:
        slot_of, assign, merges, placed = allocate(combo, tileglyphs, reserved, pal_rgb)

    exact = sum(n for k, n in combo.items() if not any(m['wanted'] == k for m in merges))
    total = sum(combo.values())
    merged_cells = total - exact
    merged_tiles = {t for (t, k), key in cellmap.items()
                    if any(m['wanted'] == key for m in merges)}
    tile_slots = len(tileglyphs) + placed
    print('\ntile slots used      : %d  (%d primaries + %d variants)'
          % (tile_slots, len(tileglyphs), placed))
    print('cells EXACT          : %d of %d  (%.2f%%)' % (exact, total, 100.0 * exact / total))
    print('cells merged         : %d, touching %d tiles' % (merged_cells, len(merged_tiles)))

    font_new = build_font(assign, font_old, reserved)
    addr, blob = build_tileset(tiles, cellmap, slot_of)
    codes = [[blob[512 + k * 256 + t] if 512 + k * 256 + t < len(blob) else None
              for k in range(9)] for t in range(256)]

    # ---- checks ----------------------------------------------------------
    # AC3. The claim is "no shape was invented", and the way to test it is that
    # every emitted glyph is EXACTLY the cell's own PETSCII mask with two colours
    # substituted — including for merged cells, which take a different colour
    # pair but always from a combo of the SAME glyph.
    #
    # NOT "can the mask be read back out of the emitted glyph": where the C64
    # cell is a single flat colour the two colours coincide and the glyph is
    # uniform, so the mask is unrecoverable by inspection while still having
    # driven every pixel. Checking recoverability failed 27 cells that are
    # correct — the check was wrong, not the output.
    bad_shape, bad_glyph, flat = [], [], 0
    for (t, k), key in cellmap.items():
        g = tiles[t][k] & 0x7F
        slot = slot_of[key]
        sg, sc1, sc0 = assign[slot]
        if sg != g:                              # would be a WRONG SHAPE
            bad_glyph.append((t, k))
            continue
        if sc1 == sc0:
            flat += 1
        if not np.array_equal(font_new[slot], np.where(font_old[g] != 0, sc1, sc0)):
            bad_shape.append((t, k))
    off_pal = int((font_new > 15).sum())
    print('\nAC3 shape exact      : %d of %d cells  (%d wrong glyph, %d mis-coloured)'
          % (len(cellmap) - len(bad_shape) - len(bad_glyph), len(cellmap),
             len(bad_glyph), len(bad_shape)))
    print('    of which flat     : %d cells where the C64 cell is one colour, so '
          'ink==paper' % flat)
    print('AC6 off-palette      : %d nibbles' % off_pal)

    # ---- error, same metric as C2-C5 -------------------------------------
    q64 = pdv.quantise_sheet(SHEET)
    tot_cost, npix = 0.0, 0
    for t in range(256):
        ty, tx = divmod(t, 16)
        for k in range(9):
            if tiles[t][k] is None:
                continue
            cy, cx = divmod(k, 3)
            want = q64[ty * 24 + cy * 8:ty * 24 + cy * 8 + 8,
                       tx * 24 + cx * 8:tx * 24 + cx * 8 + 8].reshape(-1)
            got = font_new[slot_of[cellmap[(t, k)]]].reshape(-1)
            tot_cost += float(pdv.D2[want, [pal_bytes[g] for g in got]].sum())
            npix += 64
    err = float(np.sqrt(tot_cost / npix))
    print('AC9 error (vs C64)   : %.2f   over %d pixels' % (err, npix))

    # ---- emit ------------------------------------------------------------
    raw = bytearray()
    for g in range(N_SLOTS):
        for r in range(8):
            for b in range(4):
                raw.append((font_new[g][r][b * 2] << 4) | font_new[g][r][b * 2 + 1])
    fp = os.path.join(args.out, 'font-c64.bin')
    with open(fp, 'wb') as f:
        f.write(raw)
    tp = os.path.join(args.out, 'tileset-c64.bin')
    decbmerge.write_decb(tp, [(addr, blob)], 0x0000)
    print('\n%s  %d B  sha256 %s' % (fp, len(raw), hashlib.sha256(raw).hexdigest()[:32]))
    with open(tp, 'rb') as f:
        tb = f.read()
    print('%s  %d B (payload %d)  sha256 %s'
          % (tp, len(tb), len(blob), hashlib.sha256(tb).hexdigest()[:32]))

    # ---- renders ---------------------------------------------------------
    idx = render_engine(font_new, codes)
    out_rgb = pal_rgb[idx]
    src_rgb = pal_rgb[qidx]
    Image.fromarray(out_rgb).save(os.path.join(args.renders, 'c8-result.png'))
    Image.fromarray(src_rgb).save(os.path.join(args.renders, 'c8-source-c64-quantised.png'))
    gap, lab = 16, 34
    pair = np.full((384 + lab, 384 * 2 + gap, 3), 24, dtype=np.uint8)
    pair[lab:, :384] = src_rgb
    pair[lab:, 384 + gap:] = out_rgb
    im = Image.fromarray(pair).resize(((384 * 2 + gap) * 2, (384 + lab) * 2),
                                      Image.NEAREST)
    d = ImageDraw.Draw(im)
    d.text((8, 8), 'C64 SOURCE  art/image.png quantised to the adopted 16',
           fill=(230, 230, 230))
    d.text((8, 30), 'all 256 tiles, 24px pitch, identity correspondence (C1)',
           fill=(150, 150, 150))
    d.text(((384 + gap) * 2 + 8, 8),
           'CoCo3 RESULT  %d tile slots of %d, %d/%d cells exact (%.2f%%)'
           % (tile_slots, N_SLOTS, exact, total, 100.0 * exact / total),
           fill=(230, 230, 230))
    d.text(((384 + gap) * 2 + 8, 30),
           'engine render: every glyph an existing PETSCII shape, recoloured. '
           '%d cells merged across %d tiles' % (merged_cells, len(merged_tiles)),
           fill=(150, 150, 150))
    im.save(os.path.join(args.renders, 'c8-pair.png'))

    # ---- merge queue -----------------------------------------------------
    merges.sort(key=lambda m: -m['distance'])
    rows = []
    for m in merges:
        for (t, k), key in cellmap.items():
            if key == m['wanted']:
                rows.append(dict(tile=t, cell=PLANES[k],
                                 glyph='$%02X' % key[0],
                                 wanted='ink $%02X / paper $%02X'
                                        % (pal_bytes[key[1]], pal_bytes[key[2]]),
                                 got='ink $%02X / paper $%02X'
                                     % (pal_bytes[m['got'][1]], pal_bytes[m['got'][2]]),
                                 distance=m['distance']))
    with open(os.path.join(args.out, 'merge-queue.json'), 'w',
              encoding='utf-8', newline='\n') as f:
        json.dump(dict(merged_cells=merged_cells, merged_tiles=sorted(merged_tiles),
                       rows=rows), f, indent=1)
        f.write('\n')
    print('\nmerge queue: %d cells across %d tiles -> %s/merge-queue.json'
          % (len(rows), len(merged_tiles), args.out))
    for r in rows[:8]:
        print('  tile %3d %s glyph %s  want %s  got %s  dist %.1f'
              % (r['tile'], r['cell'], r['glyph'], r['wanted'], r['got'], r['distance']))

    summary = dict(cells=len(cellmap), glyphs=len(tileglyphs), combos=len(combo),
                   text_slots=len(text), reserved=sorted(reserved),
                   tile_slots=tile_slots, primaries=len(tileglyphs), variants=placed,
                   exact=exact, merged_cells=merged_cells,
                   merged_tiles=len(merged_tiles), error=round(err, 2),
                   shape_mismatches=len(bad_shape), wrong_glyph=len(bad_glyph),
                   flat_cells=flat, off_palette=off_pal,
                   font_sha256=hashlib.sha256(raw).hexdigest(),
                   tileset_sha256=hashlib.sha256(tb).hexdigest())
    with open(os.path.join(args.out, 'c8.json'), 'w',
              encoding='utf-8', newline='\n') as f:
        json.dump(summary, f, indent=1)
        f.write('\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
