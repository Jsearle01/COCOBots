#!/usr/bin/env python3
"""
edit_model.py — paint model over the font: strokes, undo/redo, baseline, revert.

Same shape as POP's sprite tool so the muscle memory transfers: one undo step
per STROKE (mouse-down .. mouse-up), a redo stack cleared by any new paint, a
baseline that a save re-bases, Revert-to-baseline, and a one-shot Undo-Revert.

What differs, and why:

  the unit is a GLYPH, not a cel. There are 192 of them and they are SHARED — a
  glyph is 13 cells on average and up to 396. So `dirty` is per glyph, undo
  stacks are per glyph, and switching glyphs does NOT need a guard dialog: the
  edit stays live on the glyph you left. All live edits are held in one font
  array and saved together. Guarding every glyph switch would be intolerable
  when the job is to walk 151 of them.

  a pixel is a 4-bit palette INDEX, not a colour+opacity pair. There is no
  opacity layer here; the plotter copies nibbles unmodified (C2).
"""
import copy
import time

import numpy as np

MAX_UNDO = 200


class GlyphEdit:
    """One glyph's editable 8x8, its stroke stacks, and its baseline."""

    def __init__(self, index, px):
        self.index = index
        self.px = px                              # a VIEW into the font array
        self.baseline = px.copy()
        self.undo, self.redo = [], []
        self._pre_revert = None
        self._just_reverted = False

    # ---- strokes ------------------------------------------------------------
    def begin_stroke(self):
        self.undo.append(self.px.copy())
        self.redo.clear()
        if len(self.undo) > MAX_UNDO:
            self.undo.pop(0)

    def paint(self, x, y, index):
        if not (0 <= x < 8 and 0 <= y < 8):
            return False
        if not 0 <= index <= 15:
            raise ValueError('palette index %r out of range 0-15' % index)
        if self.px[y, x] == index:
            return False
        self.px[y, x] = index
        self._just_reverted = False
        return True

    def undo_stroke(self):
        if not self.undo:
            return False
        self.redo.append(self.px.copy())
        self.px[:] = self.undo.pop()
        self._just_reverted = False
        return True

    def redo_stroke(self):
        if not self.redo:
            return False
        self.undo.append(self.px.copy())
        self.px[:] = self.redo.pop()
        self._just_reverted = False
        return True

    def can_undo(self):
        return bool(self.undo)

    def can_redo(self):
        return bool(self.redo)

    # ---- baseline / revert --------------------------------------------------
    def is_dirty(self):
        return not np.array_equal(self.px, self.baseline)

    def changed(self):
        """{(x,y)} differing from the baseline — the yellow highlight set."""
        ys, xs = np.nonzero(self.px != self.baseline)
        return set(zip(xs.tolist(), ys.tolist()))

    def revert(self):
        if not self.is_dirty():
            return False
        self._pre_revert = (self.px.copy(), copy.deepcopy(self.undo),
                            copy.deepcopy(self.redo))
        self.px[:] = self.baseline
        self.undo.clear()
        self.redo.clear()
        self._just_reverted = True
        return True

    def can_undo_revert(self):
        return bool(self._just_reverted and self._pre_revert is not None)

    def undo_revert(self):
        if not self.can_undo_revert():
            return False
        px, u, r = self._pre_revert
        self.px[:] = px
        self.undo, self.redo = u, r               # restored WHOLESALE, never replayed
        self._pre_revert = None
        self._just_reverted = False
        return True

    def mark_saved(self):
        self.baseline = self.px.copy()
        self._pre_revert = None
        self._just_reverted = False


class FontEdit:
    """Every glyph in the configuration, over one shared font array."""

    def __init__(self, font):
        self.font = np.array(font, dtype=np.uint8)     # own it; never alias the loader's
        self.load_baseline = self.font.copy()          # the on-open bytes, for round-trip
        self.glyphs = [GlyphEdit(i, self.font[i]) for i in range(len(self.font))]
        self.touched_at = {}                           # glyph -> unix time of last edit

    def __getitem__(self, i):
        return self.glyphs[i]

    def note_edit(self, i):
        self.touched_at[i] = time.time()

    def edited(self):
        return [g for g in self.glyphs if g.is_dirty()]

    def is_dirty(self):
        return any(g.is_dirty() for g in self.glyphs)

    def mark_all_saved(self):
        for g in self.glyphs:
            g.mark_saved()

    def unchanged_since_load(self):
        return np.array_equal(self.font, self.load_baseline)
