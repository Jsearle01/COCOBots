#!/usr/bin/env python3
"""
selftest.py — headless proof of the C6 acceptance criteria that are checkable
without a display.

  python tools/glyph_tool/selftest.py

Every hazard C6 §8 names gets a check that FAILS if it bites, not a note saying
it was considered:

  round-trip        load -> save unedited -> byte-identical, hashes printed (AC3)
  nibble order      high nibble is the LEFT pixel (§8)
  sub-cell click    every one of the 2,304 cell rectangles resolves to its own
                    (tile, cell) — the off-by-one §8 calls the first thing to
                    get wrong (AC1)
  crop not resize   the 384 grid is the source's first 384 px, unscaled (§8)
  affected tiles    $3A / $4D / a single-tile glyph, against tileset.bin (AC6)
  text/UI warnings  all 15 shared glyphs + the $66 health-bar case (AC6)
  classification    available 15 / referenced 214 / no-static-ref 27,
                    derived and reconciled against C6-A1 (AC7 amended)
  no data           tile 255 BR is None, never glyph $00 (§8)
  bit-7 semantics   the two configurations disagree and both are read correctly
  assets untouched  tileset.bin / levels / graphics.asm / PETSCII_COCO.asm
                    byte-identical to HEAD (AC9)
"""
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config as C          # noqa: E402
import glyphio              # noqa: E402
import progress as P        # noqa: E402
import render as R          # noqa: E402
import sheet as S           # noqa: E402
from edit_model import FontEdit    # noqa: E402
import queues                      # noqa: E402
from tilemap import Mapping, load_codes   # noqa: E402

FAILS = []
LINES = []


def check(name, ok, detail=''):
    LINES.append('%-4s %-38s %s' % ('PASS' if ok else 'FAIL', name, detail))
    if not ok:
        FAILS.append(name)
    return ok


# ---------------------------------------------------------------- AC3 -------
def t_roundtrip():
    for key in ('a192', 'shipped'):
        cfg = C.CONFIGS[key]
        if not os.path.exists(cfg.font):
            check('roundtrip:%s' % key, False, '%s missing' % cfg.font)
            continue
        font = glyphio.load_font(cfg.font, cfg.n_glyphs, cfg.font_addr)
        raw = glyphio.pack(font)
        src_sha = glyphio.sha256_bytes(raw)

        if cfg.font_addr is None:
            with open(cfg.font, 'rb') as f:
                on_disk = f.read()[:cfg.n_glyphs * 32]
            check('roundtrip:%s unpack/pack' % key, raw == on_disk,
                  'sha256 %s' % src_sha[:24])

        # the real save path, into a temp dir so the authored asset is untouched
        tmp = tempfile.mkdtemp(prefix='glyphtool-selftest-')
        try:
            cfg.out_dir = tmp
            fe = FontEdit(font)
            prog = P.Progress(cfg, cfg.n_glyphs)
            r = P.save(cfg, fe, prog, cfg.font, src_sha)
            out_sha = glyphio.sha256_file(cfg.out_font)
            check('roundtrip:%s save unedited' % key,
                  out_sha == src_sha and r['identical_to_source'],
                  'in %s -> out %s' % (src_sha[:16], out_sha[:16]))
            check('roundtrip:%s version written' % key,
                  os.path.exists(r['version'])
                  and glyphio.sha256_file(r['version']) == src_sha,
                  os.path.basename(r['version']))
            # and an EDITED save must differ, or "identical" would be vacuous
            fe.font[0][0, 0] ^= 0x0F
            r2 = P.save(cfg, fe, prog, cfg.font, src_sha)
            check('roundtrip:%s edited save differs' % key,
                  not r2['identical_to_source']
                  and glyphio.sha256_file(cfg.out_font) != src_sha,
                  r2['sha256'][:16])
            check('roundtrip:%s prior version survives' % key,
                  os.path.exists(r['version'])
                  and glyphio.sha256_file(r['version']) == src_sha,
                  'never overwritten in place')
        finally:
            cfg.out_dir = None
            shutil.rmtree(tmp, ignore_errors=True)


def t_nibble_order():
    """High nibble is the LEFT pixel. Reversing it mirrors every glyph and looks
    almost plausible, so this is asserted on a byte with known halves."""
    raw = bytes([0xA3] + [0] * 31)
    g = glyphio.unpack(raw, 1)
    ok = g[0, 0, 0] == 0xA and g[0, 0, 1] == 0x3
    check('nibble order: high = LEFT', ok,
          '$A3 -> px0=$%X px1=$%X' % (g[0, 0, 0], g[0, 0, 1]))
    check('nibble order: pack inverts unpack', glyphio.pack(g) == raw)


# ---------------------------------------------------------------- AC1 -------
def t_subcell():
    """Every pixel of the 384 grid must map to the (tile, cell) whose rectangle
    contains it — checked exhaustively, not on samples."""
    xs, ys = np.meshgrid(np.arange(S.GRID), np.arange(S.GRID), indexing='xy')
    want_tile = (ys // 24) * 16 + (xs // 24)
    want_cell = ((ys % 24) // 8) * 3 + ((xs % 24) // 8)
    got_t = np.empty_like(want_tile)
    got_c = np.empty_like(want_cell)
    for y in range(S.GRID):
        for x in range(S.GRID):
            t, k = S.cell_of_point(x, y)
            got_t[y, x] = t
            got_c[y, x] = k
    check('sub-cell: all 147,456 px resolve',
          np.array_equal(got_t, want_tile) and np.array_equal(got_c, want_cell),
          '256 tiles x 9 cells, exhaustive')
    # the boundaries specifically — where an off-by-one lives
    corners = [((0, 0), (0, 0)), ((7, 7), (0, 0)), ((8, 0), (0, 1)),
               ((23, 23), (0, 8)), ((24, 0), (1, 0)), ((383, 383), (255, 8))]
    ok = all(S.cell_of_point(x, y) == exp for (x, y), exp in corners)
    check('sub-cell: cell boundaries', ok, '8/16/24 px edges')
    check('sub-cell: off-grid is None', S.cell_of_point(384, 0) == (None, None))


def t_crop():
    """CROP, DO NOT RESIZE (§8). If the sheet were resized 392->384 the corner
    pixels would no longer be the source's corner pixels."""
    raw = np.asarray(Image.open(C.SHEET_AMIGA).convert('RGB'))
    cropped = S.load_sheet(C.SHEET_AMIGA)
    ok = (cropped.shape == (384, 384, 3)
          and np.array_equal(cropped, raw[:384, :384]))
    check('sheet: cropped 392->384, not resized', ok,
          'source %dx%d' % (raw.shape[1], raw.shape[0]))


# ---------------------------------------------------------------- AC6 -------
def t_affected():
    cfg = C.CONFIGS['shipped']
    m = Mapping(cfg)
    # C7 completed tileset.bin to 2,816 bytes, so TILE_DATA_BR[255] now exists
    # and holds $20. Glyph $20 therefore gains exactly one tile and one cell
    # (121/437 -> 122/438) and the cell total goes 2,303 -> 2,304. Every other
    # figure the C6 dispatch quotes is unchanged — which is the check that the
    # one-byte append touched nothing else.
    expect = {0x4D: (122, 210), 0x20: (122, 438), 0x3A: (108, 396),
              0x66: (88, 268), 0x5F: (83, 140), 0x64: (60, 176), 0x67: (33, 81)}
    cells = sum(1 for t in range(256) for k in range(9) if m.codes[t][k] is not None)
    check('affected: 2,304 cells post-C7', cells == 2304 and 255 in m.tiles_of[0x20],
          'was 2,303; tile 255 BR is now $20')
    bad = [('$%02X' % g, m.n_tiles(g), m.n_cells(g))
           for g, (t, c) in expect.items()
           if (m.n_tiles(g), m.n_cells(g)) != (t, c)]
    check('affected: 7 quoted glyphs vs tileset.bin', not bad, str(bad) or
          '$3A=108/396  $4D=122/210  $20=121/437  +4 more')

    singles = [g for g in m.used_glyphs() if m.n_tiles(g) == 1]
    check('affected: single-tile glyphs', len(singles) == 16,
          '%d of %d used; e.g. $%02X -> tile %d'
          % (len(singles), len(m.used_glyphs()), singles[0],
             next(iter(m.tiles_of[singles[0]]))))
    check('affected: >10 tiles', sum(1 for g in m.used_glyphs()
                                     if m.n_tiles(g) > 10) == 23, '23')
    check('affected: distinct glyphs used', len(m.used_glyphs()) == 69, '69')

    # the outline set IS the tiles_of set — assert it against a recount
    for g in (0x3A, 0x4D, singles[0]):
        recount = {t for t in range(256)
                   for k in range(9)
                   if m.codes[t][k] is not None and (m.codes[t][k] & 0x7F) == g}
        check('affected: outline set $%02X' % g, recount == m.tiles_of[g],
              '%d tiles' % len(recount))


def t_warnings():
    m = Mapping(C.CONFIGS['shipped'])
    missing = [g for g in C.TEXT_GLYPHS if 'also used by text' not in m.warnings(g)]
    check('warnings: all 15 text glyphs', not missing and len(C.TEXT_GLYPHS) == 15,
          '$03 $0E $11 $14 $15 $1A $20 $27 $2D $2E $31 $32 $33 $34 $35')
    check('warnings: $66 health bar', 'health bar' in m.warnings(0x66),
          m.header(0x66))
    check('warnings: quiet glyph is quiet', m.warnings(0x3A) == [], m.header(0x3A))


# ------------------------------------------------------------ AC7 / §8 ------
def t_classification():
    """AC7 as amended by C6-A1. The classification is DERIVED; C6-A1 §2's lists
    are used only to reconcile, never to produce it."""
    import tileclass as TC
    cls = TC.classify()
    c = cls['counts']
    check('class: partitions all 256', sum(c.values()) == 256
          and not (set(cls['available']) & set(cls['referenced']))
          and not (set(cls['available']) & set(cls['unverified']))
          and not (set(cls['referenced']) & set(cls['unverified'])),
          'available %d + referenced %d + no-static-ref %d'
          % (c['available'], c['referenced'], c['unverified']))

    check('class: available matches C6-A1 (15)',
          set(cls['available']) == set(TC.A1_BLANK) | {255},
          '14 blanks + tile 255')

    # blankness MUST come from assets/tileset.bin — the a192 table remaps $20 to
    # $35 and testing it finds zero blanks, silently reclassifying all fourteen
    a192_codes = load_codes(C.CONFIGS['a192'].tileset)
    check('class: blankness ignores the remapped table',
          all(a192_codes[t][0] != 0x20 for t in TC.A1_BLANK)
          and set(TC.blank_tiles()) >= set(TC.A1_BLANK),
          'derived from assets/tileset.bin, not the a192 allocation')

    # a blank tile that IS placed is not free — tile 0 is the empty floor
    check('class: placed blank is not available',
          0 in cls['blanks'] and 0 not in cls['available']
          and 0 in cls['referenced'], 'tile 0 is all-$20 and in every level')

    # the units C6's "67 dead" would have thrown away
    units = [96, 97, 98, 100, 115, 140, 164, 165, 240, 241, 244, 245, 246, 248]
    missing = [t for t in units if t not in cls['code_refs']]
    check('class: code-placed units all found', not missing,
          'player, hoverbot, rollerbot, bullets, plasma, explosions')

    # the computed case a literal scan cannot see
    check('class: DEMATERIALIZE 160/161/162 found',
          all(t in cls['code_refs'] for t in (160, 161, 162)),
          'ADDB #160 at PETROBOTS_6809.asm:2986')

    # the two exclusive sentinels that must NOT become tiles
    check('class: run sentinels are not tiles',
          143 not in cls['code_refs'] and 252 not in cls['code_refs']
          and 252 in cls['available'],
          'CMPA #143 bounds 140-142; CMPA #252 bounds 246-251')
    check('class: sentinel runs are filled',
          all(t in cls['code_refs'] for t in (141, 142, 249, 250, 251)),
          '140-142 water droid, 246-251 explosion')

    # the false positive a naive backtrack produces
    check('class: timer reload is not a tile', 3 not in cls['code_refs']
          and 3 in cls['available'],
          'LDA #3 at BACKGROUND_TASKS:2264 sets UNIT_TIMER_B')

    # every code ref must cite a source line
    cited = {t for r in cls['evidence'] for t in r['tiles']}
    check('class: every code ref is cited', set(cls['code_refs']) <= cited,
          '%d evidence rows' % len(cls['evidence']))

    check('class: no-static-reference are drawn, not skipped',
          set(cls['unverified']).isdisjoint(cls['available']),
          '%d tiles marked unverified' % c['unverified'])

    m = Mapping(C.CONFIGS['a192'])
    qs = queues.build(m)
    check('class: no queue drops a tile',
          all(set(qs[n]) == set(range(256)) for n in ('worst', 'cleanup', 'all')),
          'worst/cleanup/all each reach all 256')
    # the warning must track the FILE, not a hardcoded sentence: present while
    # TILE_DATA_BR[255] is missing, gone once C7's byte is there
    has = TC.br255_has_storage()
    check('class: tile 255 note tracks the file',
          255 in cls['available']
          and ('NO STORAGE' in m.tile_note(255)) == (not has),
          'storage present: %s -> %s' % (has, m.tile_note(255)[-46:]))


def t_nodata():
    """C7 fixed assets/tileset.bin to its full 2,816 bytes, so the SHIPPED
    mapping has no missing cell any more. The a192 table still does: it is a C4
    artifact generated from the 2,815-byte file, and regenerating it is out of
    C7's scope. The no-data PATH still has to work for that reason, so it is
    asserted where it applies and asserted absent where it was fixed."""
    m = Mapping(C.CONFIGS['shipped'])
    missing = sum(1 for t in range(256) for k in range(9) if m.codes[t][k] is None)
    check('no data: shipped has none post-C7',
          missing == 0 and m.codes[255][8] == 0x20,
          'TILE_DATA_BR[255] = $%02X' % m.codes[255][8])

    a = Mapping(C.CONFIGS['a192'])
    others = sum(1 for t in range(256) for k in range(9) if a.codes[t][k] is None)
    check('no data: a192 still has tile 255 BR',
          a.codes[255][8] is None and a.glyphs[255][8] is None and others == 1,
          'C4 artifact, generated pre-C7 — regenerating it is out of scope')
    # and it must render as NODATA, not as glyph $00
    cfg = C.CONFIGS['a192']
    m = Mapping(cfg)
    font = glyphio.load_font(cfg.font, cfg.n_glyphs)
    _, nod = R.compose_tile(font, m, 255)
    check('no data: renders as no-data, not $00', nod[16:24, 16:24].all()
          and not nod[:16, :16].any(), 'bottom-right 8x8 masked')


def t_bit7():
    """The two configurations disagree about bit 7 and both must be read right."""
    a = Mapping(C.CONFIGS['a192'])
    s = Mapping(C.CONFIGS['shipped'])
    a_codes = [c for row in a.codes for c in row if c is not None]
    a_hi = [c for c in a_codes if c & 0x80]
    check('bit7: a192 treats it as index bit 7',
          max(a.glyphs[t][k] for t in range(256) for k in range(9)
              if a.glyphs[t][k] is not None) == max(a_hi),
          '%d codes >= $80, max $%02X, no inverse'
          % (len(a_hi), max(a_hi)))
    check('bit7: a192 has no inverse cells',
          not any(a.inverse[t][k] for t in range(256) for k in range(9)))
    n_inv = sum(1 for t in range(256) for k in range(9) if s.inverse[t][k])
    check('bit7: shipped treats it as inverse', n_inv == 852,
          '%d inverse cells, glyphs masked to $7F' % n_inv)
    check('bit7: shipped glyphs all < $80',
          max(g for row in s.glyphs for g in row if g is not None) < 0x80)


def t_paint():
    """AC2/AC3 through the real edit model: place all 16 indices, undo, redo,
    revert, undo-revert — and prove a shared glyph propagates to every tile."""
    cfg = C.CONFIGS['a192']
    m = Mapping(cfg)
    fe = FontEdit(glyphio.load_font(cfg.font, cfg.n_glyphs))

    # the most-shared glyph in this configuration is the interesting one
    g = max(m.used_glyphs(), key=m.n_tiles)
    ge = fe[g]
    before = fe.font[g].copy()

    ge.begin_stroke()
    for i in range(16):                       # every index placeable (AC2)
        ge.paint(i % 8, i // 8, i)
    placed = {int(fe.font[g][i // 8, i % 8]) for i in range(16)}
    check('paint: all 16 indices placeable', placed == set(range(16)),
          'glyph $%02X, %d tiles' % (g, m.n_tiles(g)))
    check('paint: changed set tracks the baseline', len(ge.changed()) == len(
        [i for i in range(16) if before[i // 8, i % 8] != i]))

    check('paint: rejects an out-of-range index',
          _raises(lambda: ge.paint(0, 0, 16), ValueError))

    # shared-glyph propagation — one edit, every tile using it moves (C6 §3)
    tiles = sorted(m.tiles_of[g])
    moved = sum(1 for t in tiles
                if not np.array_equal(R.compose_tile(fe.font, m, t)[0],
                                      R.compose_tile(
                                          _with(fe.font, g, before), m, t)[0]))
    check('paint: one edit moves every affected tile', moved == len(tiles),
          '%d/%d tiles composed differently' % (moved, len(tiles)))

    check('paint: undo restores', ge.undo_stroke()
          and np.array_equal(fe.font[g], before))
    check('paint: redo re-applies', ge.redo_stroke()
          and not np.array_equal(fe.font[g], before))
    check('paint: revert to baseline', ge.revert()
          and np.array_equal(fe.font[g], before) and not ge.is_dirty())
    check('paint: undo-revert is one-shot', ge.undo_revert()
          and ge.is_dirty() and not ge.can_undo_revert())
    ge.mark_saved()
    check('paint: save re-bases the baseline', not ge.is_dirty()
          and ge.changed() == set())


def _with(font, g, px):
    f = font.copy()
    f[g] = px
    return f


def _raises(fn, exc):
    try:
        fn()
    except exc:
        return True
    except Exception:                                          # noqa: BLE001
        return False
    return False


def t_palette():
    rgb, byts, names = S.load_palette()
    check('palette: 16 adopted slots from assets/palette.json',
          rgb.shape == (16, 3) and len(byts) == 16,
          ' '.join('$%02X' % b for b in byts))
    check('palette: every index placeable', len(set(range(16))) == 16
          and rgb.dtype == np.uint8)


# ---------------------------------------------------------------- AC9 -------
def t_assets_untouched():
    paths = ['assets/tileset.bin', 'src/graphics.asm', 'src/PETSCII_COCO.asm'] + \
            ['assets/levels/level_%s.bin' % c for c in 'abcdefghij']
    present = [p for p in paths if os.path.exists(os.path.join(C.REPO, p))]
    try:
        out = subprocess.run(['git', 'diff', '--stat', 'HEAD', '--'] + present,
                             cwd=C.REPO, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as ex:
        check('assets untouched vs HEAD', False, 'git unavailable: %s' % ex)
        return
    check('assets untouched vs HEAD', out.returncode == 0 and not out.stdout.strip(),
          '%d files: %s' % (len(present), out.stdout.strip() or 'no diff'))


def main():
    for fn in (t_roundtrip, t_nibble_order, t_subcell, t_crop, t_affected,
               t_warnings, t_classification, t_nodata, t_bit7, t_paint, t_palette,
               t_assets_untouched):
        try:
            fn()
        except Exception as ex:                                # noqa: BLE001
            check(fn.__name__, False, 'raised %s: %s' % (type(ex).__name__, ex))
    print('\n'.join(LINES))
    print('\n%d checks, %d failed' % (len(LINES), len(FAILS)))
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
