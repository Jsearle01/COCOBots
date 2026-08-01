#!/usr/bin/env python3
"""
tileclass.py — classify all 256 tiles by how (and whether) the game reaches them.

  python tools/glyph_tool/tileclass.py [--json out.json] [--reconcile]

WHY THIS EXISTS (C6-A1). C6 shipped with "67 dead tiles", taken from a single
measurement: distinct bytes in the ten level maps, subtracted from 256. That
measures only what a level DESIGNER placed, and is blind to two other ways a
tile reaches the screen:

  code-placed   units — player, robots, bullets, explosions — never appear in
                map data. Their tile numbers are written to UNIT_TILE in code.
  computed      some tiles are reached by arithmetic, so no literal exists to
                grep. DEMATERIALIZE does `ADDB #160` plus a conditional +1 and
                draws 160, 161 or 162; a literal scan misses all three.

Treating either as "dead" would have thrown away explosion frames, bullets, the
player's own animation and the teleport sequence.

FOUR SOURCES, three categories:

  1. tileset.bin          -> blankness (all nine cells $20)
  2. the ten level files  -> map references (payload offset $200, 8,192 bytes,
                             one byte per map position)
  3. the two .asm sources -> UNIT_TILE stores, literal and computed
  4. tile 255             -> an EDITOR ARTIFACT, classified explicitly (see below)

  available            empty and editable — FREE SLOTS FOR NEW CONTENT.
                       Jay, 2026-08-01: "it would provide a tile that I could
                       use to create something new if needed." NOT skippable,
                       NOT greyed out.
  referenced           reached by a map or by code. Normal.
  no static reference  real artwork with no literal reaching it. Every one sits
                       in a short run bounded on both sides by referenced tiles,
                       which is why they are DRAWN NORMALLY and merely marked
                       unverified.

NAMING. The 36 are labelled "no static reference", never "animation". Animation
is the likeliest explanation but door states, damage states and the trash
compactor look identical to static analysis, and calling them frames invites
reasoning about them as frames (C6-A1 §3).

TILE 255 is neither blank nor game art: its cells draw the string "255" in a box
— the tile-count caption from art/image.png, which was a tile-editor screenshot
rather than a clean export, baked into the tile data. Free for reuse, but it
cannot fall out of the blankness test, so it is classified explicitly.

  !! TRAP: tileset.bin is 2,815 data bytes where the layout needs 11 x 256 =
  2,816. The missing byte is exactly TILE_DATA_BR[255]. Anything drawn there and
  placed in a level makes DRAW_MAP_WINDOW read $5CFF — one byte past what is
  loaded — and draw whatever is in RAM. Eight cells of art plus one garbage
  cell, which reads as a drawing bug rather than a file-length bug. Fixing it is
  a separate authorised task (C6-A1 §7); until then tile 255 carries a warning.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import decbmerge                                              # noqa: E402

import config as C                                            # noqa: E402

AVAILABLE, REFERENCED, UNVERIFIED = 'available', 'referenced', 'no-static-reference'

BLANK_CELL = 0x20                    # space
MAP_OFFSET = 0x200                   # level payload: $200, then 8,192 map bytes
MAP_LEN = 8192
EDITOR_ARTIFACT = 255                # the "255" caption baked in from image.png

SOURCES = ('src/PETROBOTS_6809.asm', 'src/BACKGROUND_TASKS_6809.ASM')

# ---------------------------------------------------------------- sources ---
_STORE = re.compile(r'^\s*ST([AB])\s+UNIT_TILE\b', re.I)
_INC = re.compile(r'^\s*INC\s+UNIT_TILE\b', re.I)
_LD_IMM = re.compile(r'^\s*LD([AB])\s+#([^\s;]+)')
_ADD_IMM = re.compile(r'^\s*ADD([AB])\s+#([^\s;]+)')
_CMP_IMM = re.compile(r'^\s*CMP([AB])\s+#([^\s;]+)')
# LDD #12*256+244 — the 16-bit load. This is how every bullet, plasma and
# explosion tile is set: A gets the AI routine number, B gets the tile. A
# scanner that only understands LDA/LDB #n misses all of them, and they are
# exactly the units that must never be classified dead.
_LDD_IMM = re.compile(r'^\s*LDD\s+#([^\s;]+)')

BACKTRACK = 14                       # lines to walk back for the value being stored

_EXPR_OK = re.compile(r'^[0-9A-Fa-f$*+\-() ]+$')


def _num(tok):
    """A literal or a small constant expression (`12*256+244`, `$1F`).

    Restricted to digits, $hex, * + - and parentheses, and evaluated only after
    the whole token matches that character set — so a symbol name never reaches
    eval and a typo yields None rather than an accidental value."""
    tok = tok.strip()
    if not tok or not _EXPR_OK.match(tok):
        return None
    py = re.sub(r'\$([0-9A-Fa-f]+)', lambda m: str(int(m.group(1), 16)), tok)
    try:
        v = eval(py, {'__builtins__': {}}, {})       # noqa: S307 — charset-gated above
    except (SyntaxError, ValueError, TypeError, NameError, ZeroDivisionError):
        return None
    return v if isinstance(v, int) else None


_INCREG = re.compile(r'^\s*INC([AB])\b', re.I)
_REDEF = re.compile(r'^\s*(LD|CLR|DEC|TFR|EXG|PUL|ABX|NEG|LSR|ASL|ROL|ROR|COM)', re.I)


def scan_sources(repo=None):
    """-> (set of tile numbers, list of evidence rows).

    Four rules, each recorded with file and line so every tile in the result is
    auditable back to a source line rather than appearing as a bare number:

      literal       LDA/LDB #n            ... ST UNIT_TILE
      literal-LDD   LDD #12*256+244       ... ST UNIT_TILE   (B is the tile)
      computed      ADDB #160             ... ST UNIT_TILE   -> 160, 161, 162
      cmp+inc       CMPA #98 / INCA       ... ST UNIT_TILE   -> 99
      run-sentinel  INC UNIT_TILE,X / CMPA #n                -> n is EXCLUSIVE

    TWO OFF-BY-ONE TRAPS, both found by reading the sites rather than trusting
    the pattern:

    `CMPA #252  ; Did we finish all from 246-251?` — the compare value is the
    sentinel that ENDS the run, not a frame. Adding it makes tile 252 look
    referenced when it is actually a free blank. Same for `CMPA #143`, which is
    bounded by `LDA #140`. So a sentinel emits `range(start, n)` where start is
    the nearest literal below it, and never n itself.

    The backtrack also STOPS at anything that redefines the register it cannot
    resolve. Without that, the walk from `STA UNIT_TILE,X` in HOVERBOT_ANIMATE
    strolled past `LDA UNIT_TILE,X` and reached `LDA #3` — the animate-timer
    reload — and reported tile 3, which is a blank the level designer never
    placed. A missed reference is safe (the tile falls to "no static reference"
    and is drawn anyway); a fabricated one is not (it would hide a free slot).
    """
    repo = repo or C.REPO
    tiles, rows, literals, sentinels = set(), [], set(), []

    def add(vals, kind, rel, line, text):
        vals = [v for v in vals if 0 <= v <= 255]
        tiles.update(vals)
        rows.append(dict(tiles=vals, kind=kind, file=rel, line=line, text=text))
        return vals

    for rel in SOURCES:
        path = os.path.join(repo, rel)
        if not os.path.exists(path):
            continue
        with open(path, 'r', encoding='latin-1') as f:
            # bare CRs are line terminators to lwasm (CLAUDE.md §10) — split on
            # all three so a 12-bare-CR file does not read as one giant line
            lines = re.split(r'\r\n|\r|\n', f.read())

        for i, line in enumerate(lines):
            code = line.split(';')[0]

            m = _STORE.search(code)
            if m:
                reg = m.group(1).upper()
                pending_inc = 0
                for j in range(i - 1, max(-1, i - BACKTRACK) - 1, -1):
                    prev = lines[j].split(';')[0]
                    if not prev.strip():
                        continue

                    a = _ADD_IMM.match(prev)
                    if a and a.group(1).upper() == reg:
                        v = _num(a.group(2))
                        if v is not None:
                            # ADDB #160 + a conditional +1 -> 160, 161 or 162
                            literals.update(add([v, v + 1, v + 2], 'computed',
                                                rel, j + 1, prev.strip()))
                        break

                    d = _LD_IMM.match(prev)
                    if d and d.group(1).upper() == reg:
                        v = _num(d.group(2))
                        if v is not None:
                            literals.update(add([v + pending_inc], 'literal',
                                                rel, j + 1, prev.strip()))
                        break

                    dd = _LDD_IMM.match(prev)
                    if dd:
                        v = _num(dd.group(1))
                        if v is not None and 0 <= v <= 0xFFFF:
                            half = (v >> 8) if reg == 'A' else (v & 0xFF)
                            literals.update(add([half + pending_inc], 'literal-LDD',
                                                rel, j + 1, prev.strip()))
                        break

                    inc = _INCREG.match(prev)
                    if inc and inc.group(1).upper() == reg:
                        pending_inc += 1          # CMPA #98 / INCA -> 99
                        continue

                    c = _CMP_IMM.match(prev)
                    if c and c.group(1).upper() == reg and pending_inc:
                        v = _num(c.group(2))
                        if v is not None:
                            literals.update(add([v + pending_inc], 'cmp+inc',
                                                rel, j + 1, prev.strip()))
                        break

                    if _REDEF.match(prev):
                        break                     # register clobbered — give up

            if _INC.search(code):
                for j in range(i + 1, min(len(lines), i + BACKTRACK)):
                    nxt = lines[j].split(';')[0]
                    c = _CMP_IMM.match(nxt)
                    if c:
                        v = _num(c.group(2))
                        if v is not None and 0 <= v <= 255:
                            sentinels.append((v, rel, j + 1, nxt.strip()))
                        break

    # post-pass: a sentinel bounds a run that starts at the nearest literal below
    for v, rel, ln, text in sentinels:
        below = [x for x in literals if x < v]
        if not below:
            continue
        add(list(range(max(below), v)), 'run-to-sentinel', rel, ln,
            '%s   -> %d..%d' % (text, max(below), v - 1))
    return tiles, rows


# ----------------------------------------------------------------- levels ---
def scan_levels(repo=None):
    repo = repo or C.REPO
    seen, files = set(), []
    for ch in 'abcdefghij':
        p = os.path.join(repo, 'assets', 'levels', 'level_%s.bin' % ch)
        if not os.path.exists(p):
            continue
        segs, _ = decbmerge.read_decb(p)
        (_, blob), = segs
        seen.update(blob[MAP_OFFSET:MAP_OFFSET + MAP_LEN])
        files.append(os.path.basename(p))
    return seen, files


# ---------------------------------------------------------------- tileset ---
def blank_tiles(codes=None, repo=None):
    """Tiles whose every present cell is $20.

    ALWAYS measured against `assets/tileset.bin`, never against a remapped
    allocation. C4's allocator reassigns cell codes, so the same blank tile
    reads as nine `$35`s in the 192-glyph table — testing that table for `$20`
    finds zero blanks and silently reclassifies all fourteen. C6-A1 §4 says
    "compute from assets/tileset.bin (blankness)" and it means it.

    Tile 255 is excluded here: it has content and is classified explicitly
    (§2a), not by this test."""
    from tilemap import load_codes
    codes = load_codes(os.path.join(repo or C.REPO, 'assets', 'tileset.bin'))
    out = set()
    for t in range(256):
        cells = [c for c in codes[t] if c is not None]
        if cells and all(c == BLANK_CELL for c in cells):
            out.add(t)
    return out - {EDITOR_ARTIFACT}


# ------------------------------------------------------------- classify -----
def classify(codes=None, repo=None):
    blanks = blank_tiles(repo=repo)
    map_refs, level_files = scan_levels(repo)
    code_refs, evidence = scan_sources(repo)

    # A blank tile that IS placed is not free — tile 0 is all-$20 and is the
    # empty floor of every level. "Available" means blank AND unreached.
    reached = map_refs | code_refs
    available = (blanks - reached) | {EDITOR_ARTIFACT}
    referenced = reached - available
    unverified = set(range(256)) - referenced - available

    kind = {}
    for t in range(256):
        kind[t] = (AVAILABLE if t in available else
                   REFERENCED if t in referenced else UNVERIFIED)

    return {
        'kind': kind,
        'available': sorted(available),
        'referenced': sorted(referenced),
        'unverified': sorted(unverified),
        'blanks': sorted(blanks),
        'editor_artifact': EDITOR_ARTIFACT,
        'map_refs': sorted(map_refs),
        'code_refs': sorted(code_refs),
        'evidence': evidence,
        'level_files': level_files,
        'counts': {'available': len(available), 'referenced': len(referenced),
                   'unverified': len(unverified)},
    }


def note(t, cls):
    """The one-line explanation the editor shows for a tile."""
    k = cls['kind'][t]
    if t == EDITOR_ARTIFACT:
        return ('AVAILABLE - editor artifact: draws "255", the tile-count caption '
                'baked in from image.png. !! bottom-right cell has NO STORAGE '
                'until tileset.bin is 2,816 bytes - do not spend this slot yet')
    if k == AVAILABLE:
        return 'AVAILABLE - empty slot, free for new content (needs level placement to appear)'
    if k == UNVERIFIED:
        return 'no static reference - drawn normally; reached by a computed offset, unverified'
    where = []
    if t in cls['map_refs']:
        where.append('placed in a level')
    if t in cls['code_refs']:
        where.append('written to UNIT_TILE in code')
    return 'referenced - ' + ' and '.join(where)


# --------------------------------------------------------------- reconcile --
# C6-A1 §2's lists, kept ONLY for reconciliation. The classification above is
# derived; these are never used to produce it.
A1_BLANK = [1, 2, 3, 14, 23, 175, 183, 238, 239, 243, 247, 252, 253, 254]
A1_UNVERIFIED = [30, 69, 70, 73, 74, 77, 78, 84, 85, 86, 88, 89, 99, 101, 102, 103,
                 141, 142, 146, 147, 150, 151, 152, 153, 156, 157, 160, 161, 162,
                 172, 173, 181, 182, 249, 250, 251, 255]
A1_CODE = [96, 97, 98, 100, 115, 130, 134, 140, 160, 161, 162, 164, 165,
           240, 241, 244, 245, 246, 248]


def reconcile(cls):
    lines = []

    def cmp(name, got, want):
        got, want = set(got), set(want)
        lines.append('%-22s derived %3d   C6-A1 %3d   %s'
                     % (name, len(got), len(want),
                        'exact match' if got == want else
                        'only-derived %s | only-A1 %s'
                        % (sorted(got - want), sorted(want - got))))

    # A1's "blank" list is blank-AND-UNPLACED. Tile 0 is all-$20 and is the
    # empty floor of every level, so it is blank but not free; compare like
    # for like rather than reporting a phantom disagreement.
    reached = set(cls['map_refs']) | set(cls['code_refs'])
    cmp('blank (unplaced)', set(cls['blanks']) - reached, A1_BLANK)
    cmp('blank (all)', cls['blanks'], A1_BLANK + [0])
    cmp('available', cls['available'], A1_BLANK + [255])
    cmp('no-static-reference', cls['unverified'], A1_UNVERIFIED)
    lines.append('%-22s derived %3d   (A1 quotes 205)' % ('referenced', cls['counts']['referenced']))
    lines.append('%-22s derived %3d   map-only %d, code-only %d, both %d'
                 % ('  of which', cls['counts']['referenced'],
                    len(set(cls['map_refs']) - set(cls['code_refs'])),
                    len(set(cls['code_refs']) - set(cls['map_refs'])),
                    len(set(cls['map_refs']) & set(cls['code_refs']))))
    extra = sorted(set(cls['code_refs']) - set(A1_CODE))
    missed = sorted(set(A1_CODE) - set(cls['code_refs']))
    lines.append('%-22s derived %3d   A1 lists %d   extra-found %s | not-found %s'
                 % ('code refs', len(cls['code_refs']), len(A1_CODE), extra, missed))
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', default=None)
    ap.add_argument('--reconcile', action='store_true')
    ap.add_argument('--config', default='a192', choices=sorted(C.CONFIGS))
    args = ap.parse_args()

    from tilemap import load_codes
    codes = load_codes(C.CONFIGS[args.config].tileset)
    cls = classify(codes)

    c = cls['counts']
    print('available %d   referenced %d   no-static-reference %d   (total %d)'
          % (c['available'], c['referenced'], c['unverified'], sum(c.values())))
    print('blanks           :', cls['blanks'])
    print('available        :', cls['available'])
    print('no static ref    :', cls['unverified'])
    print('code refs (%d)   :' % len(cls['code_refs']), cls['code_refs'])
    if args.reconcile:
        print()
        print('\n'.join(reconcile(cls)))
    if args.json:
        with open(args.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump({k: v for k, v in cls.items() if k != 'kind'}, f, indent=1)
            f.write('\n')
        print('\n-> %s' % args.json)
    return 0


if __name__ == '__main__':
    sys.exit(main())
