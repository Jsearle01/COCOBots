#!/usr/bin/env python3
"""
glyphio.py — the 4bpp glyph font: load, pack, save, hash.

FORMAT (C6 §2). 8x8 pixels, 4bpp, 2 pixels per byte, 32 bytes per glyph.
**The HIGH nibble is the LEFT pixel.** Reversing that mirrors every glyph
horizontally and looks almost plausible, which is why pack/unpack are one pair
of functions used everywhere rather than open-coded shifts.

Each nibble is an independent palette index 0-15 (C2's correction: the plotter's
`PULU D,Y / STD ,X / STY 2,X` copies four bytes per row unmodified, so a glyph
is 16-colour capable, not 1-bit).

Round-trip is exact by construction: unpack and pack are inverses over the whole
byte range, so load -> save with no edits is byte-identical. selftest.py proves
it on the real artifact rather than trusting that sentence.
"""
import hashlib
import os

import numpy as np


def sha256_file(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def unpack(raw, n_glyphs):
    """bytes -> uint8 array (n_glyphs, 8, 8) of palette indices."""
    need = n_glyphs * 32
    if len(raw) < need:
        raise ValueError('font is %d bytes, need %d for %d glyphs'
                         % (len(raw), need, n_glyphs))
    b = np.frombuffer(raw[:need], dtype=np.uint8).reshape(n_glyphs, 8, 4)
    out = np.empty((n_glyphs, 8, 8), dtype=np.uint8)
    out[:, :, 0::2] = b >> 4         # HIGH nibble = LEFT pixel
    out[:, :, 1::2] = b & 0x0F
    return out


def pack(font):
    """uint8 array (n,8,8) of palette indices -> bytes, 32 per glyph."""
    f = np.asarray(font, dtype=np.uint8)
    if f.ndim != 3 or f.shape[1:] != (8, 8):
        raise ValueError('font must be (n,8,8), got %r' % (f.shape,))
    if f.max(initial=0) > 15:
        raise ValueError('palette index out of range 0-15')
    b = (f[:, :, 0::2] << 4) | f[:, :, 1::2]
    return b.astype(np.uint8).tobytes()


def load_font(path, n_glyphs, font_addr=None):
    """Load a raw font, or extract one from a DECB binary when font_addr is set."""
    if font_addr is None:
        with open(path, 'rb') as f:
            return unpack(f.read(), n_glyphs)
    import sys
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..'))
    import decbmerge
    segs, _ = decbmerge.read_decb(path)
    blob = dict(segs)[font_addr]
    return unpack(bytes(blob), n_glyphs)


def write_font(path, font):
    """Write atomically — a half-written font is the one failure that would cost
    hand-drawn work, so the bytes land in a temp file and are renamed."""
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    raw = pack(font)
    tmp = path + '.tmp'
    with open(tmp, 'wb') as f:
        f.write(raw)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)
    return raw
