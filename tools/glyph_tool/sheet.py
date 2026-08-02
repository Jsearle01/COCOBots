#!/usr/bin/env python3
"""
sheet.py — the reference artwork, and the adopted palette it is quantised to.

**CROP, DO NOT RESIZE** (C6 §8). Both sheets are 392x392; the tile grid is
384x384 at origin (0,0) with pitch 24. Resizing 392 -> 384 was an early error
that produced garbage, because it moves every cell boundary by a sub-pixel
amount that compounds across sixteen tiles.

Correspondence is IDENTITY (C1): sheet tile n <-> tileset tile n, row-major,
16 per row.

The art is a JPEG despite the .png extension, so the quantised view shows ringing
around edges. That is the source, not a bug (C6 §8).

FOUR reference views (C6-A4), because they answer four different questions:

  amiga_raw    Amiga_Artwork.png as-is    colour source, colours the CoCo has not
  amiga_quant  the same, nearest-of-16    the CEILING - already the ADOPTED CoCo
                                          palette, which is why its label no
                                          longer says "Amiga"
  coco_engine  drawn through the glyphs   REACHABLE - what the machine shows
  oracle       image.png (C64 tileset)    ART ORACLE for glyph use + structure

raw vs quantised answers "is this flatness my drawing or the palette?".
quantised vs engine answers "is this flatness the palette or the glyph budget?"
- the question C6-A4 exists to make askable. The oracle is there because §2B is
  explicit that Amiga art is "COLOUR source only; NOT a shape/construction
  reference", and this tool's whole purpose is hand-authoring shape.
"""
import json

import numpy as np
from PIL import Image

import config as C

GRID = 384
PITCH = 24


def load_palette(path=None):
    """-> (rgb uint8[16,3], list of GIME bytes, list of names)."""
    with open(path or C.PALETTE_JSON, encoding='utf-8') as f:
        slots = json.load(f)['slots']
    rgb = np.array([s['rgb'] for s in slots], dtype=np.uint8)
    return rgb, [s['byte'] for s in slots], [s['name'] for s in slots]


def load_sheet(path):
    """RGB uint8 [384,384,3], cropped from the 392x392 source at origin (0,0)."""
    im = np.asarray(Image.open(path).convert('RGB'))
    if im.shape[0] < GRID or im.shape[1] < GRID:
        raise ValueError('%s is %dx%d, smaller than the %d grid'
                         % (path, im.shape[1], im.shape[0], GRID))
    return im[:GRID, :GRID].copy()          # crop. never resize.


def quantise(rgb_img, pal_rgb):
    """Nearest of the adopted 16 in RGB. Returns (index map, rgb image)."""
    a = rgb_img.reshape(-1, 3).astype(np.int32)
    d = ((a[:, None, :] - pal_rgb[None, :, :].astype(np.int32)) ** 2).sum(axis=2)
    idx = d.argmin(axis=1).astype(np.uint8)
    return (idx.reshape(rgb_img.shape[:2]),
            pal_rgb[idx].reshape(rgb_img.shape))


def tile_rect(tile):
    """Pixel rect of tile n on the 384 grid."""
    ty, tx = divmod(tile, 16)
    return tx * PITCH, ty * PITCH, PITCH, PITCH


def tile_of_point(x, y):
    """Sheet pixel -> tile index, or None outside the grid."""
    if not (0 <= x < GRID and 0 <= y < GRID):
        return None
    return (y // PITCH) * 16 + (x // PITCH)


def cell_of_point(x, y):
    """Sheet pixel -> (tile, cell 0..8).

    SUB-CELL RESOLUTION — C6 §8 calls this the first thing to get wrong. A tile
    is 24 px and a cell is 8, so the cell index is the 8-px subdivision WITHIN
    the tile, taken row-major (TL TM TR / ML MM MR / BL BM BR) to match the
    plane order in tileset.bin. Doing the division against the sheet coordinate
    instead of the within-tile offset is the off-by-one that puts the wrong
    glyph on the canvas.
    """
    t = tile_of_point(x, y)
    if t is None:
        return None, None
    ox, oy = x % PITCH, y % PITCH
    return t, (oy // 8) * 3 + (ox // 8)


class Reference:
    """The four reference views, each as a full 384x384 RGB image.

    C6-A4 added `coco_engine`. The measurement that separates it from the others
    is the count of distinct 8x8 cell appearances:

      amiga_quant   1,799 distinct cells — PER-PIXEL. Every appearance in the art
                    survives. Already in the ADOPTED CoCo palette, which is why
                    its label had to change: it said "Amiga quantised", which
                    reads as Amiga colours, and they are not.
      coco_engine     143 distinct cells — ENGINE RENDER, drawn through the glyph
                    model, so bounded by the 151 slots in use and carrying every
                    merge the allocator made.

    The first is the CEILING and the second is REACHABLE, and confusing them is
    the mistake C4 §9 item 1 records. Hence both, both labelled.

    `coco_engine` is rendered LIVE from the font being edited, so it tracks the
    work rather than going stale the moment a glyph changes.
    """

    VIEWS = ('amiga_raw', 'amiga_quant', 'coco_engine', 'oracle')
    LABELS = {'amiga_raw': 'Amiga raw — NOT reachable',
              'amiga_quant': 'CoCo palette, per-pixel — the CEILING (1,799 cells)',
              'coco_engine': 'CoCo ENGINE, live — REACHABLE (143 cells)',
              'oracle': 'C64 oracle — structure authority (2B)'}

    def __init__(self, pal_rgb):
        self.pal_rgb = pal_rgb
        self.images = {}
        raw = load_sheet(C.SHEET_AMIGA)
        self.images['amiga_raw'] = raw
        self.qidx, self.images['amiga_quant'] = quantise(raw, pal_rgb)
        try:
            self.images['oracle'] = load_sheet(C.SHEET_ORACLE)
        except OSError:
            self.images['oracle'] = raw          # oracle absent: degrade, don't crash
        self.images['coco_engine'] = np.zeros_like(raw)
        self._engine_key = None

    def refresh_engine(self, font, mapping):
        """Re-render the engine view if the font has moved since last time.

        Keyed on the font's bytes: cheap to compute, and it cannot go stale the
        way a saved PNG would. Returns True if it re-rendered.
        """
        key = font.tobytes()
        if key == self._engine_key:
            return False
        import cocosheet
        self.images['coco_engine'] = cocosheet.engine_sheet(
            mapping.cfg, self.pal_rgb, font)
        self._engine_key = key
        return True

    def image(self, view):
        return self.images[view]

    def tile(self, view, tile):
        x, y, w, h = tile_rect(tile)
        return self.images[view][y:y + h, x:x + w]
