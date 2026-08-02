#!/usr/bin/env python3
"""
accept.py — take the QUANTISED reference as an authored edit (C6-A3).

WHAT IT IS. The quantised view is the Amiga art with every pixel snapped to the
adopted 16 colours: **full structure, only colour moved**. It is the ceiling — the
best any glyph can do (C6 §3). For a cell whose glyph is not heavily shared,
accepting those pixels wholesale is correct art for free, and the hand effort
goes to the contested glyphs instead.

WHAT MAKES IT DANGEROUS, and it is not an edge case:

  intra-tile conflict   A tile writes the same glyph from two or more of its nine
                        cells, and the art under those cells DIFFERS. 253 of 256
                        tiles in the shipped mapping, 252 of 256 in a192. A naive
                        loop over the nine cells is silently last-write-wins.
  blast radius          Glyphs are shared across tiles. Accepting one tile's nine
                        cells changes up to 231 other tiles from one click, and
                        there is no safe floor: 0 tiles in the shipped mapping
                        (1 in a192) have all nine cells on glyphs unique to them.

So this module's job is not "copy pixels" — that is four lines. It is to compute
the cost BEFORE the write and to make the conflict resolution explicit.

CONFLICT RULE: **first cell in TL->BR order wins.** Deterministic, explainable,
and the losing cells are named in the result so the outcome is never silent.

SOURCE IS ALWAYS THE QUANTISED REFERENCE — never the raw Amiga, never the C64
oracle. Which view happens to be on screen does not change what accept does.
"""
import collections

import numpy as np

import sheet as S
from tilemap import PLANES


def quantised_cell(qidx, tile, cell):
    """The 8x8 palette indices the quantised reference holds for this cell.

    Identity correspondence (C1): sheet tile n <-> tileset tile n, origin (0,0),
    pitch 24, cell offset by its TL/TM/.../BR position.
    """
    x, y, _, _ = S.tile_rect(tile)
    cy, cx = divmod(cell, 3)
    return qidx[y + cy * 8:y + cy * 8 + 8, x + cx * 8:x + cx * 8 + 8].copy()


def wanted(qidx, mapping, tile, cell):
    """What must be STORED in the glyph for this cell to render as the quantised
    art — which is not the same thing when the cell is inverse-coded.

    In the shipped mapping a cell with bit 7 set is drawn through NextRowInv's
    COMA/COMB, complementing every nibble (i -> 15-i). Storing the wanted pixels
    directly there would render the complement. a192 has no inverse cells, so
    this is a no-op in the configuration actually being authored — but getting it
    wrong in the other one would be invisible until someone looked at the game.
    """
    px = quantised_cell(qidx, tile, cell)
    if mapping.inverse[tile][cell]:
        px = 15 - px
    return px


def plan(qidx, mapping, tile, cells):
    """Work out exactly what an accept would do, without doing any of it.

    Returns a dict with:
      changes    {glyph: 8x8}      what would be written
      winners    {glyph: cell}     the cell each glyph took its art from
      dropped    {glyph: [cells]}  cells whose art lost the TL->BR tie-break
      conflicts  {glyph: [cells]}  every glyph written from more than one cell
      identical  {glyph: [cells]}  ...of those, the ones whose art happens to agree
      tiles      set               every tile whose rendering changes, incl. `tile`
      text       [glyph]           glyphs that text/UI also draws
      nodata     [cell]            cells with no glyph (tile 255 BR pre-C7)
    """
    changes, winners, dropped = {}, {}, collections.defaultdict(list)
    conflicts, identical, nodata = collections.defaultdict(list), {}, []

    for k in sorted(cells):                      # TL->BR: first one wins
        g = mapping.glyphs[tile][k]
        if g is None:
            nodata.append(k)
            continue
        px = wanted(qidx, mapping, tile, k)
        if g in changes:
            dropped[g].append(k)
            conflicts[g].append(k)
        else:
            changes[g] = px
            winners[g] = k
            conflicts[g].append(k)

    # a conflict whose competing art is identical costs nothing — worth saying,
    # because it is the difference between "4 glyphs conflict" and "4 glyphs
    # conflict and you will lose art in 4 places"
    for g, ks in list(conflicts.items()):
        if len(ks) < 2:
            del conflicts[g]
            continue
        arts = [wanted(qidx, mapping, tile, k) for k in ks]
        if all(np.array_equal(arts[0], a) for a in arts[1:]):
            identical[g] = ks

    tiles = {tile}
    for g in changes:
        tiles |= mapping.tiles_of.get(g, set())

    text = [g for g in sorted(changes) if mapping.warnings(g)]

    return {'changes': changes, 'winners': winners, 'dropped': dict(dropped),
            'conflicts': dict(conflicts), 'identical': identical,
            'tiles': tiles, 'text': text, 'nodata': nodata}


def cost_line(p, mapping, tile, cells):
    """The one- or two-line consequence shown BEFORE the write.

    C6-A3 §3 asks for the actual numbers rather than a reflex confirm dialog:
    what it costs is the thing that should make you hesitate, not a yes/no box.
    """
    n = len(cells)
    if not p['changes']:
        return 'nothing to accept — %s has no glyph' % (
            ','.join(PLANES[k] for k in p['nodata']) or 'selection')
    head = ('accept tile $%02X (%d cell%s) -> %d distinct glyph%s -> changes %d tiles'
            % (tile, n, '' if n == 1 else 's', len(p['changes']),
               '' if len(p['changes']) == 1 else 's', len(p['tiles'])))
    if n == 1:
        k = sorted(cells)[0]
        g = mapping.glyphs[tile][k]
        head = ('accept cell %s ($%02X) -> changes %d tiles'
                % (PLANES[k], g, len(p['tiles'])) if g is not None
                else 'accept cell %s -> no glyph, nothing to write' % PLANES[k])

    lines = [head]
    real = {g: ks for g, ks in p['conflicts'].items() if g not in p['identical']}
    if real:
        lines.append('  ! %d glyph%s receive conflicting art: %s'
                     % (len(real), '' if len(real) == 1 else 's',
                        ', '.join('$%02X x%d' % (g, len(ks))
                                  for g, ks in sorted(real.items()))))
        lines.append('  ! TL->BR wins: keeping %s, dropping %s'
                     % (', '.join('$%02X<-%s' % (g, PLANES[p['winners'][g]])
                                  for g in sorted(real)),
                        ', '.join('%s' % PLANES[k]
                                  for g in sorted(real) for k in p['dropped'][g])))
    if p['identical']:
        lines.append('  (%d glyph%s written twice with identical art — no loss: %s)'
                     % (len(p['identical']), '' if len(p['identical']) == 1 else 's',
                        ', '.join('$%02X' % g for g in sorted(p['identical']))))
    if p['text']:
        lines.append('  ! also drawn by text/UI: %s'
                     % ', '.join('$%02X (%s)' % (g, '; '.join(mapping.warnings(g)))
                                 for g in p['text']))
    if p['nodata']:
        lines.append('  (%s has no glyph — skipped)'
                     % ','.join(PLANES[k] for k in p['nodata']))
    return '\n'.join(lines)


def outcome_line(p, mapping, tile):
    """What is stated AFTER the write. C6-A3 §3: the outcome must be reported,
    not merely the intent."""
    parts = ['accepted %d glyph%s from tile $%02X — %d tiles now render differently'
             % (len(p['changes']), '' if len(p['changes']) == 1 else 's', tile,
                len(p['tiles']))]
    real = {g: ks for g, ks in p['conflicts'].items() if g not in p['identical']}
    if real:
        parts.append('applied %s; DROPPED %s (same glyph, different art)'
                     % (', '.join('%s->$%02X' % (PLANES[p['winners'][g]], g)
                                  for g in sorted(real)),
                        ', '.join(PLANES[k] for g in sorted(real)
                                  for k in p['dropped'][g])))
    if p['nodata']:
        parts.append('skipped %s (no glyph)'
                     % ','.join(PLANES[k] for k in p['nodata']))
    return '  |  '.join(parts)


def blast_radius(mapping):
    """{tile: number of tiles whose rendering changes if all nine cells are
    accepted}, counting the tile itself — the figure C6-A3 §2 quotes."""
    out = {}
    for t in range(256):
        tiles = {t}
        for g in mapping.tile_glyph_set(t):
            tiles |= mapping.tiles_of.get(g, set())
        out[t] = len(tiles)
    return out
