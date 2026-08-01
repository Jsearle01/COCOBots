#!/usr/bin/env python3
"""
queues.py — work order (C6 §3, "Prioritise from ladder.json's worst-tile list
and tile-correspondence.json's cleanup queue").

151 glyphs is long enough that the order matters more than the speed. Four
orders, each answering a different question:

  worst      ladder.json `worst_tiles_221`, worst RMS first — where the current
             automated output is furthest from the art. Biggest visible win per
             hour.
  cleanup    tile-correspondence.json rows whose confidence is not `high`,
             lowest score first — where C1 was least sure the sheet tile and the
             tileset tile are even the same thing. Drawing these blind risks
             drawing the wrong tile well.
  live       every tile that appears in a level, index order.
  all        all 256, index order.

Dead tiles (67 of 256) are dropped from `worst`/`cleanup`/`live` by default —
C6 §3 wants effort steered off them — but `all` keeps them so nothing is
unreachable.
"""
import json

import config as C


def _load(path):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def build(mapping):
    """-> {name: [tile, ...]} in priority order."""
    dead = mapping.dead
    live = [t for t in range(256) if t not in dead]

    q = {}

    ladder = _load(C.LADDER_JSON) or {}
    worst = [r['tile'] for r in ladder.get('worst_tiles_221', [])]
    q['worst'] = [t for t in worst if t not in dead] or list(live)

    corr = _load(C.CORRESPONDENCE) or {}
    rows = corr.get('rows', [])
    cleanup = sorted((r for r in rows
                      if r.get('confidence') != 'high' and r['tile'] not in dead),
                     key=lambda r: (r.get('score') if r.get('score') is not None else 1.0))
    q['cleanup'] = [r['tile'] for r in cleanup]

    q['live'] = live
    q['all'] = list(range(256))
    return q


ORDER = ('worst', 'cleanup', 'live', 'all')

DESC = {
    'worst': 'worst RMS first (ladder.json worst_tiles_221)',
    'cleanup': 'lowest-confidence correspondence first (C1)',
    'live': 'tiles used by a level, index order',
    'all': 'all 256 including the 67 dead',
}
