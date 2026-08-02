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
  unverified real artwork with no static reference (C6-A1) — the 27 tiles that
             need drawing but that nothing in the map or a literal reaches.
  available  the free slots. Not a chore list — this is where NEW content goes.
  all        all 256, index order.

**NOTHING IS EXCLUDED FROM ANY QUEUE** (C6-A1 §4). The earlier build dropped
"dead" tiles from the work queues, which was wrong twice over: the 67 it called
dead included explosion frames, bullets, the player's own animation and the
teleport sequence, and the genuinely empty ones are free slots rather than
waste. Jay, 2026-08-01: *"it would provide a tile that I could use to create
something new if needed."*

The ORDER still steers effort — `worst` first, `available` last — but every
tile is reachable from every ordering.
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
    """-> {name: [tile, ...]} in priority order. Every queue reaches every tile
    it is about; none of them silently drops one."""
    q = {}

    # worst RMS first, then everything else in index order — so the ordering
    # steers effort without the tail becoming unreachable.
    ladder = _load(C.LADDER_JSON) or {}
    worst = [r['tile'] for r in ladder.get('worst_tiles_221', [])]
    q['worst'] = worst + [t for t in range(256) if t not in set(worst)]

    corr = _load(C.CORRESPONDENCE) or {}
    rows = corr.get('rows', [])
    low = sorted((r for r in rows if r.get('confidence') != 'high'),
                 key=lambda r: (r.get('score') if r.get('score') is not None else 1.0))
    cleanup = [r['tile'] for r in low]
    q['cleanup'] = cleanup + [t for t in range(256) if t not in set(cleanup)]

    q['unverified'] = sorted(mapping.unverified)
    q['available'] = sorted(mapping.available)

    # C6-A3: ascending blast radius. Accepting the quantised art for a tile whose
    # glyphs are barely shared is nearly free; for one at the top of this list it
    # rewrites most of the sheet. Working it from the front converts the cheap
    # wins before touching anything contested.
    import accept as A
    radius = A.blast_radius(mapping)
    q['cheap-accept'] = sorted(range(256), key=lambda t: (radius[t], t))

    q['all'] = list(range(256))
    return q


ORDER = ('worst', 'cheap-accept', 'cleanup', 'unverified', 'available', 'all')

DESC = {
    'worst': 'worst RMS first (ladder.json worst_tiles_221), then the rest',
    'cheap-accept': 'smallest blast radius first - accept is cheapest here (C6-A3)',
    'cleanup': 'lowest-confidence correspondence first (C1), then the rest',
    'unverified': 'real art, no static reference - draw normally (C6-A1)',
    'available': 'FREE SLOTS for new content - empty and editable',
    'all': 'all 256 in index order',
}
