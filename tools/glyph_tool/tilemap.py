#!/usr/bin/env python3
"""
tilemap.py — the cell->glyph table, and the blast-radius index built from it.

`tileset.bin` is READ-ONLY here (C6 §4/§7). This module only reads it.

Layout at $5200 (C1): DESTRUCT_PATH(256), TILE_ATTRIB(256), then the nine cell
planes TL TM TR ML MM MR BL BM BR, 256 bytes each. Cell k of tile t is at
offset 512 + k*256 + t.

**Tile 255's bottom-right cell has no data** — the file is 2,815 bytes, one
short of 2,816. It is carried as None throughout and rendered as "no data",
never as glyph $00 (C6 §8).
"""
import collections
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import decbmerge                                              # noqa: E402

import config as C                                            # noqa: E402

PLANES = ['TL', 'TM', 'TR', 'ML', 'MM', 'MR', 'BL', 'BM', 'BR']


def load_codes(path):
    """-> list[256][9] of raw code bytes, None where the file has no byte."""
    segs, _ = decbmerge.read_decb(path)
    (_, blob), = segs
    out = []
    for t in range(256):
        row = []
        for k in range(9):
            off = 512 + k * 256 + t
            row.append(blob[off] if off < len(blob) else None)
        out.append(row)
    return out


class Mapping:
    """Cell codes plus the indexes the UI needs: which tiles a glyph touches,
    how each tile is classified, and the per-tile glyph SET.

    The glyph set matters because a tile may use the same glyph more than once
    (C6 §3) — editing one instance changes every instance, and showing nine
    independent things would misrepresent that.
    """

    def __init__(self, cfg):
        self.cfg = cfg
        self.codes = load_codes(cfg.tileset)
        self.glyphs = [[cfg.glyph_of(c) for c in row] for row in self.codes]
        self.inverse = [[cfg.is_inverse(c) for c in row] for row in self.codes]

        self.tiles_of = collections.defaultdict(set)   # glyph -> {tile}
        self.cells_of = collections.defaultdict(list)  # glyph -> [(tile,cell)]
        for t in range(256):
            for k in range(9):
                g = self.glyphs[t][k]
                if g is None:
                    continue
                self.tiles_of[g].add(t)
                self.cells_of[g].append((t, k))

        # C6-A1: three categories, DERIVED. There is no "dead tile" concept —
        # C6's original 67 counted only what a level designer placed and would
        # have written off explosion frames, bullets, the player's animation and
        # the teleport sequence. Nothing here is skippable; `available` means a
        # free slot for new content, not wasted space.
        import tileclass
        self.cls = tileclass.classify()
        self.kind = self.cls['kind']
        self.available = set(self.cls['available'])
        self.referenced = set(self.cls['referenced'])
        self.unverified = set(self.cls['unverified'])

    def tile_note(self, tile):
        import tileclass
        return tileclass.note(tile, self.cls)

    # ---- queries the UI asks -----------------------------------------------
    def tile_glyph_set(self, tile):
        """Ordered distinct glyphs in one tile, with the cells each occupies."""
        seen = {}
        for k in range(9):
            g = self.glyphs[tile][k]
            if g is None:
                continue
            seen.setdefault(g, []).append(k)
        return seen

    def n_tiles(self, glyph):
        return len(self.tiles_of.get(glyph, ()))

    def n_cells(self, glyph):
        return len(self.cells_of.get(glyph, ()))

    def warnings(self, glyph):
        """Consumers that are NOT on the sheet, so they can only surface as text
        (C6 §3). Keyed on the font SLOT — text routines emit a literal character
        code that indexes the font directly."""
        w = []
        if glyph in C.TEXT_GLYPHS:
            w.append('also used by text')
        if glyph == C.HEALTH_BAR_GLYPH:
            w.append('health bar')
        if glyph in C.CORRUPT_GLYPHS:
            w.append('corrupt in source font (CLAUDE.md 2J) - do not repair here')
        return w

    def header(self, glyph):
        """`glyph $3A - 108 tiles, 396 cells  ! also used by text`"""
        if glyph is None:
            return 'no glyph selected'
        s = 'glyph $%02X - %d tiles, %d cells' % (glyph, self.n_tiles(glyph),
                                                  self.n_cells(glyph))
        for w in self.warnings(glyph):
            s += '   ! ' + w
        ts = self.tiles_of.get(glyph, ())
        s += '  (%dR %dU %dA)' % (
            len([t for t in ts if t in self.referenced]),
            len([t for t in ts if t in self.unverified]),
            len([t for t in ts if t in self.available]))
        return s

    def used_glyphs(self):
        return sorted(self.tiles_of)
