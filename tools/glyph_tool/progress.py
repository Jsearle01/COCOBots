#!/usr/bin/env python3
"""
progress.py — the per-glyph provenance sidecar (C6 §5) and the save policy.

Two jobs the dispatch keeps separate and so does this module:

  PROVENANCE. Per glyph: untouched / edited / done, plus when. 151 glyphs is a
  long job and "which ones have I already done" is not something to hold in your
  head. Persisted, so it survives a session.

  PROTECTION. Hand-edited glyphs become the most valuable authored asset in the
  project and a converter re-run would erase them (C6 §5, CLAUDE.md §2B). So:

    - output is on a TRACKED path (assets/authored/), never under gitignored build/
    - every save also writes a VERSIONED copy; the current file is replaced
      atomically, but no previous save is ever destroyed
    - an autosave runs on a timer and after every stroke burst, to a separate
      file that a save never touches

STATES. `edited` is derived from the bytes (it is true iff the glyph differs
from the source font), so it cannot lie. `done` is a human judgement and is the
only field the operator sets by hand.
"""
import datetime
import json
import os

import glyphio

UNTOUCHED, EDITED, DONE = 'untouched', 'edited', 'done'


def _now():
    return datetime.datetime.now().replace(microsecond=0).isoformat()


def _stamp():
    return datetime.datetime.now().strftime('%Y%m%d-%H%M%S')


class Progress:
    """Per-glyph provenance, loaded/saved alongside the font."""

    def __init__(self, cfg, n_glyphs):
        self.cfg = cfg
        self.n = n_glyphs
        self.done = set()
        self.first_edit = {}
        self.last_edit = {}
        self.source_sha = None
        self.saves = 0
        # C6-A2 AC8: viewing state persists across sessions with the rest of the
        # progress. The reference view especially — Jay could not find the
        # quantised view at all, and having to re-select it every session would
        # be the same defect wearing a timer.
        self.ui = {}
        self.load()

    # ---- persistence --------------------------------------------------------
    def load(self):
        try:
            with open(self.cfg.out_sidecar, encoding='utf-8') as f:
                d = json.load(f)
        except (OSError, ValueError):
            return
        self.done = set(d.get('done', []))
        self.first_edit = {int(k): v for k, v in d.get('first_edit', {}).items()}
        self.last_edit = {int(k): v for k, v in d.get('last_edit', {}).items()}
        self.source_sha = d.get('source_sha256')
        self.saves = d.get('saves', 0)
        self.ui = d.get('ui', {}) or {}

    def to_dict(self, fontedit, source_path, source_sha, font_sha):
        edited = sorted(g.index for g in fontedit.edited())
        states = {}
        for i in range(self.n):
            if i in self.done:
                states[i] = DONE
            elif i in edited or i in self.last_edit:
                states[i] = EDITED
            else:
                states[i] = UNTOUCHED
        return {
            'tool': 'tools/glyph_tool',
            'config': self.cfg.name,
            'written': _now(),
            'saves': self.saves,
            'source_font': os.path.relpath(source_path, self.cfg.out_dir).replace('\\', '/'),
            'source_sha256': source_sha,
            'font_sha256': font_sha,
            'n_glyphs': self.n,
            'ui': self.ui,
            'counts': {
                'untouched': sum(1 for v in states.values() if v == UNTOUCHED),
                'edited': sum(1 for v in states.values() if v == EDITED),
                'done': len(self.done),
            },
            'state': {str(i): states[i] for i in range(self.n)},
            'done': sorted(self.done),
            'first_edit': {str(k): v for k, v in sorted(self.first_edit.items())},
            'last_edit': {str(k): v for k, v in sorted(self.last_edit.items())},
        }

    # ---- edits --------------------------------------------------------------
    def note_edit(self, glyph):
        self.first_edit.setdefault(glyph, _now())
        self.last_edit[glyph] = _now()

    def toggle_done(self, glyph):
        if glyph in self.done:
            self.done.discard(glyph)
        else:
            self.done.add(glyph)
        return glyph in self.done

    def state(self, glyph, fontedit):
        if glyph in self.done:
            return DONE
        if fontedit[glyph].is_dirty() or glyph in self.last_edit:
            return EDITED
        return UNTOUCHED

    def summary(self, fontedit, mapping):
        used = set(mapping.used_glyphs())
        d = len(self.done & used)
        e = sum(1 for g in used if self.state(g, fontedit) == EDITED)
        return d, e, len(used)


def save(cfg, fontedit, progress, source_path, source_sha):
    """Write the font + a versioned copy + the sidecar. Returns a dict for the
    save banner. NEVER overwrites a previous version (C6 §5)."""
    os.makedirs(cfg.versions_dir, exist_ok=True)
    raw = glyphio.pack(fontedit.font)
    font_sha = glyphio.sha256_bytes(raw)

    progress.saves += 1
    version = os.path.join(cfg.versions_dir,
                           'font-%s-%s-%04d.bin' % (cfg.name, _stamp(), progress.saves))
    with open(version, 'wb') as f:                 # versioned copy FIRST
        f.write(raw)
    glyphio.write_font(cfg.out_font, fontedit.font)      # then the current file, atomically

    doc = progress.to_dict(fontedit, source_path, source_sha, font_sha)
    tmp = cfg.out_sidecar + '.tmp'
    with open(tmp, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(doc, f, indent=1)
        f.write('\n')
    os.replace(tmp, cfg.out_sidecar)

    return {'font': cfg.out_font, 'version': version, 'sha256': font_sha,
            'identical_to_source': font_sha == source_sha,
            'counts': doc['counts']}


def autosave(cfg, fontedit):
    """A separate file on a separate path — a save never touches it, so a bad
    save cannot take the autosave with it."""
    os.makedirs(os.path.dirname(cfg.autosave), exist_ok=True)
    glyphio.write_font(cfg.autosave, fontedit.font)
    return cfg.autosave
