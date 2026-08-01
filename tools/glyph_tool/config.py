#!/usr/bin/env python3
"""
config.py — the (font, cell->glyph mapping) pairs the editor can open.

THE ONE THING THAT MUST NOT BE GOT WRONG. The two configurations disagree about
what bit 7 of a cell's code means, and reading one with the other's rule aliases
glyphs silently:

  shipped  assets/tileset.bin      glyph = code & $7F (0..127); bit 7 = INVERSE
                                   video (BITMAP_PLOTTER's NextRowInv COMA/COMB,
                                   nibble i -> 15-i). 69 distinct glyphs used.
  a192     build/c4/tileset-192.bin
                                   inverse REMOVED, so bit 7 is simply glyph
                                   index bit 7. Codes run 0..191 (max seen 178),
                                   151 distinct. Masking with $7F here would
                                   alias glyph 178 onto glyph 50 and the error
                                   would be invisible until an edit landed in
                                   the wrong slot.

`a192` is the configuration C5/C6 adopted and is the default. `shipped` is kept
because it is the mapping every sharing figure in the C6 dispatch is quoted
against, so AC6's outline verification is checkable in the same terms.
"""
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..'))


def _p(*parts):
    return os.path.join(REPO, *parts)


class Config:
    def __init__(self, name, font, tileset, n_glyphs, inverse_bit, note,
                 font_addr=None):
        self.name = name
        self.font = font                 # source font (read-only starting point)
        self.tileset = tileset           # DECB cell->glyph table
        self.n_glyphs = n_glyphs
        self.inverse_bit = inverse_bit   # True: bit 7 is the inverse flag
        self.note = note
        self.font_addr = font_addr       # set when the font lives inside a DECB binary

    def glyph_of(self, code):
        """Cell code -> glyph index, or None for a cell with no data."""
        if code is None:
            return None
        return (code & 0x7F) if self.inverse_bit else code

    def is_inverse(self, code):
        return bool(self.inverse_bit and code is not None and code & 0x80)

    # authored output lives on a TRACKED path (C4 §7 flag 7 / C6 §5), never build/
    _out_dir = None

    @property
    def out_dir(self):
        return self._out_dir or _p('assets', 'authored')

    @out_dir.setter
    def out_dir(self, value):
        """Only the selftest sets this — so proving the save path does not write
        into the authored asset it is supposed to protect."""
        self._out_dir = value

    @property
    def out_font(self):
        return os.path.join(self.out_dir, 'font-%s.bin' % self.name)

    @property
    def out_sidecar(self):
        return os.path.join(self.out_dir, 'font-%s.json' % self.name)

    @property
    def versions_dir(self):
        return os.path.join(self.out_dir, 'versions')

    @property
    def autosave(self):
        return os.path.join(self.out_dir, 'autosave', 'font-%s.autosave.bin' % self.name)


CONFIGS = {
    'a192': Config(
        'a192', _p('build', 'c4', 'font-192.bin'), _p('build', 'c4', 'tileset-192.bin'),
        192, False,
        'C4/C5 adopted budget: 192 glyphs, inverse removed, 151 slots in use.'),
    'shipped': Config(
        'shipped', _p('build', 'ROBOTSA.BIN'), _p('assets', 'tileset.bin'),
        128, True,
        'The font and mapping as the game ships today: 128 slots, bit 7 = inverse.',
        font_addr=0x41F6),
}

DEFAULT = 'a192'

# Sheets. §2B/§2M split the roles and the editor honours BOTH: colour judgement
# is against the Amiga art, structure judgement against the C64 oracle.
SHEET_AMIGA = _p('art', 'Amiga_Artwork.png')     # COLOUR source (§2B)
SHEET_ORACLE = _p('art', 'image.png')            # ART ORACLE, structure (§2B/§2M)

PALETTE_JSON = _p('assets', 'palette.json')
CORRESPONDENCE = _p('assets', 'tile-correspondence.json')
LADDER_JSON = _p('docs', 'reports', 'C4-renders', 'ladder.json')

# Glyphs also drawn by text/UI code — editing these changes messages, menus and
# the health bar, none of which are on the sheet (C6 §2).
#
# These are font SLOT indices and stay valid in BOTH configurations: the text
# routines emit a literal character code that indexes the font directly, so
# whatever pattern sits in slot $20 is what a space draws, no matter how the
# allocator got it there. That is why the warning keys on the slot, not on which
# tile group claimed it.
TEXT_GLYPHS = (0x03, 0x0E, 0x11, 0x14, 0x15, 0x1A, 0x20, 0x27,
               0x2D, 0x2E, 0x31, 0x32, 0x33, 0x34, 0x35)
HEALTH_BAR_GLYPH = 0x66          # LDA #$66 in DISPLAY_PLAYER_HEALTH
CORRUPT_GLYPHS = (0x55, 0x66)    # CLAUDE.md §2J — do NOT repair here (C6 §7)
