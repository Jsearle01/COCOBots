#!/usr/bin/env python3
"""
render.py — PIL renders. Headlessly testable; the Tk app wraps the results.

ASPECT, and where it is applied. CoCo3 320x200 pixels are 5:6 (pixel_map.py), so
anything being JUDGED as output is drawn on the non-square 5x6 cell: the glyph
canvas and the composed-tile / Amiga-source comparison pair. The sheet on the
right is drawn SQUARE at integer zoom, because it is a navigation surface — you
pick tiles off it by recognising them, and stretching 384x384 to 1920x2304 makes
that worse, not better.

Renders are built at 1:1 and expanded by PIL's C-level NEAREST resize rather
than a Python per-zoomed-pixel loop, which is what made POP's sprite tool lag.
"""
import numpy as np
from PIL import Image, ImageDraw

import decor as D
from pixel_map import CELL_W, CELL_H

# Every colour drawn OVER the artwork comes from decor.py, which measures each
# one against the adopted palette (C6-A5). Defining them here is what let an
# amber marker sit at distance 0.0 from palette $34 for four dispatches.
BG = (40, 40, 40)
GRID = D._rgb(D.GLYPH_GRID)
CHANGED = D._rgb(D.CHANGED_PIXEL)      # baseline-differs highlight, an OUTLINE
CURSOR = D._rgb(D.MARK_LIGHT)
DARK = D._rgb(D.MARK_DARK)
NODATA = D._rgb(D.NODATA_FILL)         # a cell with no storage at all


def _expand(arr, cw, ch):
    img = Image.fromarray(np.ascontiguousarray(arr.astype(np.uint8)))
    return img.resize((arr.shape[1] * cw, arr.shape[0] * ch), Image.NEAREST)


def glyph_image(px, pal_rgb, zoom, changed=(), grid=True, cursor=None):
    """One 8x8 glyph, enlarged, aspect-correct. `changed` = {(x,y)} outlined."""
    cw, ch = CELL_W * zoom, CELL_H * zoom
    img = _expand(pal_rgb[np.asarray(px)], cw, ch).convert('RGB')
    d = ImageDraw.Draw(img)
    if grid:
        for i in range(9):
            d.line([(i * cw, 0), (i * cw, 8 * ch)], fill=GRID)
            d.line([(0, i * ch), (8 * cw, i * ch)], fill=GRID)
    for (x, y) in changed:       # last, so it never replaces a pixel's real colour
        d.rectangle([x * cw, y * ch, x * cw + cw - 1, y * ch + ch - 1], outline=CHANGED)
    if cursor is not None:
        x, y = cursor
        d.rectangle([x * cw, y * ch, x * cw + cw - 1, y * ch + ch - 1], outline=CURSOR)
    return img


def compose_tile(font, mapping, tile):
    """The 24x24 palette-index map a tile renders to from the CURRENT font.

    Returns (indices uint8[24,24], nodata mask bool[24,24]). The mask is how
    tile 255's bottom-right cell stays "no data" instead of becoming glyph $00.
    """
    out = np.zeros((24, 24), dtype=np.uint8)
    nod = np.zeros((24, 24), dtype=bool)
    for k in range(9):
        cy, cx = divmod(k, 3)
        sl = (slice(cy * 8, cy * 8 + 8), slice(cx * 8, cx * 8 + 8))
        g = mapping.glyphs[tile][k]
        if g is None or g >= len(font):
            nod[sl] = True
            continue
        px = font[g]
        if mapping.inverse[tile][k]:
            px = 15 - px             # NextRowInv: COMA/COMB, index i -> 15-i
        out[sl] = px
    return out, nod


SIBLING = D._rgb(D.CELL_SIBLING)    # another cell in THIS tile on the same glyph
EDITING = D._rgb(D.CELL_EDIT_TICK)  # corner ticks on the cell under edit


def _cell_marks(img, zoom, cells, cell):
    """Outline every cell of the tile that uses the selected glyph, then the
    cell being EDITED on top, in a visibly different mark.

    Two different facts, so two different marks (C6-A2 AC5):
      ORANGE, 1px          another cell of this tile drawing the same glyph.
                           Paint one stroke and every orange box moves with it,
                           because they are the same 64 nibbles (C6 §3).
      WHITE 3px + corners  the cell you are editing. Thicker, plus corner ticks,
                           so it reads as "here" at a glance even when it sits
                           inside the orange set — which it always does.
    """
    d = ImageDraw.Draw(img)
    cw, ch = CELL_W * zoom, CELL_H * zoom
    for k in cells:
        cy, cx = divmod(k, 3)
        d.rectangle([cx * 8 * cw, cy * 8 * ch,
                     (cx + 1) * 8 * cw - 1, (cy + 1) * 8 * ch - 1], outline=SIBLING)
    if cell is not None:
        cy, cx = divmod(cell, 3)
        x0, y0 = cx * 8 * cw, cy * 8 * ch
        x1, y1 = (cx + 1) * 8 * cw - 1, (cy + 1) * 8 * ch - 1
        # TWO-TONE, not white alone: white IS palette $3F, so a white box
        # disappears on a white cell. A dark line immediately outside it cannot
        # be hidden by the same flat colour (C6-A5).
        d.rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], outline=DARK, width=1)
        d.rectangle([x0, y0, x1, y1], outline=CURSOR, width=2)
        d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], outline=DARK, width=1)
        t = max(4, cw)                       # corner ticks, unmistakable at any zoom
        for (ax, ay, bx, by) in ((x0, y0, x0 + t, y0), (x0, y0, x0, y0 + t),
                                 (x1 - t, y0, x1, y0), (x1, y0, x1, y0 + t),
                                 (x0, y1 - t, x0, y1), (x0, y1, x0 + t, y1),
                                 (x1, y1 - t, x1, y1), (x1 - t, y1, x1, y1)):
            d.line([ax, ay, bx, by], fill=EDITING, width=3)
    return img


def tile_image(font, mapping, tile, pal_rgb, zoom, cell=None, cells=()):
    """Composed 24x24 tile, aspect-correct, with same-glyph cell outlines."""
    idx, nod = compose_tile(font, mapping, tile)
    rgb = pal_rgb[idx]
    rgb[nod] = NODATA
    cw, ch = CELL_W * zoom, CELL_H * zoom
    return _cell_marks(_expand(rgb, cw, ch).convert('RGB'), zoom, cells, cell)


def ref_tile_image(ref_rgb, zoom, cell=None, cells=()):
    """A 24x24 reference crop at the same aspect and zoom as the composed tile,
    so the pair is comparable pixel for pixel."""
    cw, ch = CELL_W * zoom, CELL_H * zoom
    img = _expand(np.asarray(ref_rgb), cw, ch).convert('RGB')
    return _cell_marks(img, zoom, cells, cell)


def sheet_image(ref_rgb, zoom):
    """The 384x384 sheet at integer zoom, SQUARE pixels (see the module note)."""
    a = np.asarray(ref_rgb)
    return Image.fromarray(a).resize((a.shape[1] * zoom, a.shape[0] * zoom),
                                     Image.NEAREST).convert('RGB')


def affected_strip(font, mapping, glyph, pal_rgb, zoom=2, per_row=16, limit=128):
    """The composed affected tiles as a contact sheet. OFF by default in the UI —
    Jay: showing all affected tiles as a strip 'would make the screen busy'. It
    exists behind a key for the cases where the outline scatter is not enough.

    `limit` is a real cap: $20 touches 121 tiles and $4D touches 122, and the
    caller is told how many were dropped rather than being shown a silent
    truncation."""
    tiles = sorted(mapping.tiles_of.get(glyph, ()))
    shown, dropped = tiles[:limit], max(0, len(tiles) - limit)
    if not shown:
        return None, 0, 0
    rows = (len(shown) + per_row - 1) // per_row
    cw, ch = 24 * zoom, 24 * zoom
    canvas = Image.new('RGB', (per_row * (cw + 2), rows * (ch + 2)), BG)
    for i, t in enumerate(shown):
        idx, nod = compose_tile(font, mapping, t)
        rgb = pal_rgb[idx]
        rgb[nod] = NODATA
        im = Image.fromarray(rgb).resize((cw, ch), Image.NEAREST)
        canvas.paste(im, ((i % per_row) * (cw + 2), (i // per_row) * (ch + 2)))
    return canvas, len(shown), dropped
