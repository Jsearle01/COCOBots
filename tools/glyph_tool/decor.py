#!/usr/bin/env python3
"""
decor.py — every colour the editor draws OVER the artwork, in one place (C6-A5).

  python tools/glyph_tool/decor.py        # print the collision sweep

WHY THIS FILE EXISTS. Since C6-A4 the sheet is rendered in the adopted palette,
so any decoration drawn in a palette hue can vanish into the content underneath.
That is not hypothetical: the sweep found **two markers at distance 0.0** — an
amber dot that IS palette `$34`, and white boxes that ARE palette `$3F`.

Scattering these constants across two modules is how that happened, so they live
here and `sweep()` measures every one of them against `assets/palette.json`.
A new decoration added anywhere else is a decoration nobody checked.

THE RULE: an outline that must read against arbitrary content needs either
  (a) a hue at least ~100 RGB units from every palette colour, or
  (b) NO hue at all — a two-tone edge (black beside white), which no single
      flat colour can hide, whatever it is.

(b) is what the selection markers use, because "here" wants to be neutral and
every neutral is close to one of the palette's four greys. There is no grey more
than ~75 units from {0, 85, 170, 255}, so hue separation is simply unavailable
for a neutral marker and structure has to do the work instead.
"""
import math
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

MIN_DISTANCE = 100.0


def _rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _hex(t):
    return '#%02X%02X%02X' % tuple(t)


# --- decorations drawn over the SHEET -------------------------------------
# Jay, 2026-08-01: "magenta is fine." It is also the one hue that cannot appear
# on the sheet: C5 §9 item 2 established magenta has ZERO slots in the adopted
# palette (0.44% of art pixels, displaced to blue). Recorded there as a gap; it
# is what makes it safe here. 208 units from the nearest palette colour, the
# furthest of any candidate tested.
SIBLING_OUTLINE = '#FF00FF'      # tiles sharing the selected glyph  (was #00E0FF)
AVAILABLE_MARK = '#00FF88'       # free slot corner tick             (136, kept)
UNVERIFIED_MARK = '#00FFFF'      # no-static-reference dot           (was #FFAA00 — dist 0.0)

# --- decorations drawn over the COMPOSED TILE ------------------------------
# Same meaning as SIBLING_OUTLINE, so deliberately the same colour: magenta says
# "this glyph is also somewhere else" on both panels.
CELL_SIBLING = '#FF00FF'         # other cells of THIS tile on the same glyph (was #FF7800)
CELL_EDIT_TICK = '#00FF88'       # corner ticks on the cell under edit        (136, kept)
NODATA_FILL = '#FF0080'          # a cell with no storage at all              (was #780078)

# --- decorations drawn over the GLYPH CANVAS -------------------------------
CHANGED_PIXEL = '#00FFC0'        # differs from the baseline                  (was #FFE400)
GLYPH_GRID = '#464646'           # 1px cell lattice — see EXCEPTIONS

# --- neutral, two-tone: structure instead of hue ---------------------------
MARK_LIGHT = '#FFFFFF'
MARK_DARK = '#000000'

# Decorations whose distance is deliberately not fixed, with the argument.
EXCEPTIONS = {
    'GLYPH_GRID': (
        'A neutral 1px lattice cannot satisfy the rule: every grey is within '
        '~75 units of one of the palette greys {0,85,170,255}, so no neutral '
        'passes. Its job is subdividing the 8x8 while drawing, never being read '
        'against content, and a saturated grid would obscure the pixels being '
        'edited. Argued exception, not an oversight.'),
    'MARK_LIGHT': (
        'White IS palette $3F. Never drawn alone — always paired with MARK_DARK '
        'as a two-tone edge, which no single flat colour can hide.'),
    'MARK_DARK': (
        'Black IS palette $00, and is never drawn alone either. It exists only '
        'as the companion edge to MARK_LIGHT: a dark line immediately outside a '
        'light one, so a black tile hides the dark half and a white tile hides '
        'the light half, but nothing hides both.'),
}

OVER_SHEET = ('SIBLING_OUTLINE', 'AVAILABLE_MARK', 'UNVERIFIED_MARK')
OVER_TILE = ('CELL_SIBLING', 'CELL_EDIT_TICK', 'NODATA_FILL')
OVER_GLYPH = ('CHANGED_PIXEL', 'GLYPH_GRID')
NEUTRAL = ('MARK_LIGHT', 'MARK_DARK')

WHERE = dict([(n, 'sheet') for n in OVER_SHEET]
             + [(n, 'composed tile') for n in OVER_TILE]
             + [(n, 'glyph canvas') for n in OVER_GLYPH]
             + [(n, 'both (two-tone)') for n in NEUTRAL])


def sweep(pal_rgb=None):
    """-> [(name, hex, where, distance, nearest_slot, verdict)] for every
    decoration, measured against the adopted palette."""
    if pal_rgb is None:
        import sheet as S
        pal_rgb, _, _ = S.load_palette()
    P = [tuple(c) for c in (pal_rgb.tolist() if hasattr(pal_rgb, 'tolist')
                            else pal_rgb)]
    rows = []
    for name in WHERE:
        c = _rgb(globals()[name])
        d = min(math.dist(c, p) for p in P)
        slot = min(range(len(P)), key=lambda i: math.dist(c, P[i]))
        if d >= MIN_DISTANCE:
            verdict = 'OK'
        elif name in EXCEPTIONS:
            verdict = 'EXCEPTION'
        else:
            verdict = 'COLLIDES'
        rows.append((name, globals()[name], WHERE[name], d, slot, verdict))
    return sorted(rows, key=lambda r: (r[5] != 'COLLIDES', -r[3]))


def collisions(pal_rgb=None):
    """Decorations that are too close AND have no argued exception. Must be
    empty — `uitest.py` asserts it."""
    return [r for r in sweep(pal_rgb) if r[5] == 'COLLIDES']


def main():
    import sheet as S
    pal, byts, names = S.load_palette()
    print('%-18s %-9s %-15s %8s  %-18s %s'
          % ('decoration', 'colour', 'drawn over', 'distance', 'nearest palette',
             'verdict'))
    for name, col, where, d, slot, verdict in sweep(pal):
        print('%-18s %-9s %-15s %8.1f  $%02X %-14s %s'
              % (name, col, where, d, byts[slot], names[slot], verdict))
    bad = collisions(pal)
    print('\nthreshold %.0f units. %d collision(s), %d argued exception(s).'
          % (MIN_DISTANCE, len(bad), len(EXCEPTIONS)))
    for k, v in EXCEPTIONS.items():
        print('  %s: %s' % (k, v.split('.')[0] + '.'))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
