#!/usr/bin/env python3
"""
pixel_map.py — CoCo3 pixel aspect + exact screen<->glyph pixel mapping.

Same derivation as POP's sprite tool, different mode. This port runs GIME
320x200x16 (4bpp, 160 B/row), not POP's 320x192:

  display width:height = 4:3; the 320x200 pixel grid fills it.
  pixel_w = display_w/320, pixel_h = display_h/200
  pixel_aspect = (4/3)*(200/320) = 800/960 = 5/6  -> pixels NARROWER than tall
  5/6 -> the integer non-square base cell is 5 (wide) x 6 (tall)

Rendering: each glyph pixel is a NON-SQUARE INTEGER cell (5z x 6z at integer
zoom z), nearest-neighbour, never fractional. Mapping is exact:
  screen (sx,sy) -> glyph (floor(sx/(CELL_W*z)), floor(sy/(CELL_H*z)))
"""
from math import gcd

# derived, not assumed:
PIXEL_ASPECT_NUM = 4 * 200   # 800
PIXEL_ASPECT_DEN = 3 * 320   # 960
_g = gcd(PIXEL_ASPECT_NUM, PIXEL_ASPECT_DEN)
ASPECT_W, ASPECT_H = PIXEL_ASPECT_NUM // _g, PIXEL_ASPECT_DEN // _g   # 5, 6
PIXEL_ASPECT = ASPECT_W / ASPECT_H                                    # 0.8333
CELL_W, CELL_H = ASPECT_W, ASPECT_H                                   # base cell 5x6


def screen_to_glyph(screen_x, screen_y, zoom):
    return screen_x // (CELL_W * zoom), screen_y // (CELL_H * zoom)


def glyph_to_screen_rect(px, py, zoom):
    x0 = px * CELL_W * zoom
    y0 = py * CELL_H * zoom
    return x0, y0, CELL_W * zoom, CELL_H * zoom
