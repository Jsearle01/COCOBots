#!/usr/bin/env python3
"""
uitest.py — C6-A2. Drives the real UI with real Tk events.

  python tools/glyph_tool/uitest.py

WHY A SEPARATE HARNESS. C6's selftest checks the model: does the arithmetic
resolve, does the round-trip hash. Both of C6-A2's defects passed every one of
those checks and still made the tool unusable, because they were not model bugs:

  defect 1  sheet zoom WORKED. It was bound only to `[`/`]` on the toplevel, and
            there was no button. A model test calling sheet_zoom(+1) passes and
            proves nothing about whether a human can reach it.
  defect 2  cell selection existed on the sheet, not on the composed tile, which
            is the panel you are looking at while drawing.

So this harness asks the questions a model test cannot: does a BUTTON exist,
does invoking it work, does a KEY work while focus sits somewhere else entirely,
and does a CLICK at these pixel coordinates land on that cell.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config as C                                            # noqa: E402
import glyph_tool_app as A                                    # noqa: E402
import sheet as S                                             # noqa: E402

FAILS, LINES = [], []


def check(name, ok, detail=''):
    LINES.append('%-4s %-44s %s' % ('PASS' if ok else 'FAIL', name, detail))
    if not ok:
        FAILS.append(name)
    return ok


class App:
    """Build the real app, off-screen, and settle it."""

    def __enter__(self):
        sys.argv = ['glyph_tool_app', '--tile', '0']
        import tkinter as tk
        self._real_mainloop = tk.Misc.mainloop
        self._real_tk_mainloop = tk.Tk.mainloop
        tk.Misc.mainloop = lambda *a, **k: None               # build, do not block
        tk.Tk.mainloop = lambda *a, **k: None
        A.main()
        tk.Misc.mainloop = self._real_mainloop
        tk.Tk.mainloop = self._real_tk_mainloop
        self.root = tk._default_root
        self.gt = self.root.gt
        self.root.geometry('1500x760+0+0')
        self.settle()
        return self

    def settle(self, n=3):
        for _ in range(n):
            self.root.update_idletasks()
            self.root.update()

    def __exit__(self, *a):
        try:
            self.root.destroy()
        except Exception:                                      # noqa: BLE001
            pass


def buttons(widget, out=None):
    """Every Button in the tree, as {text: widget}."""
    import tkinter as tk
    out = {} if out is None else out
    for w in widget.winfo_children():
        if isinstance(w, tk.Button):
            try:
                out.setdefault(str(w.cget('text')), []).append(w)
            except Exception:                                  # noqa: BLE001
                pass
        buttons(w, out)
    return out


# ------------------------------------------------------------------ AC1 -----
def t_zoom_buttons(app):
    """Both panels must have +/-/fit reachable BY CLICK ALONE."""
    st, gt = app.gt['st'], app.gt
    bs = buttons(app.root)
    check('AC1 minus button exists', len(bs.get('−', [])) >= 2,
          '%d found (sheet + glyph)' % len(bs.get('−', [])))
    check('AC1 plus button exists', len(bs.get('+', [])) >= 2,
          '%d found' % len(bs.get('+', [])))
    check('AC1 fit button exists', len(bs.get('fit', [])) >= 2,
          '%d found' % len(bs.get('fit', [])))

    # invoke() is exactly what a mouse click does — no key, no wheel, no focus
    before = st['sheet_zoom'], st['zoom']
    for b in bs['+']:
        b.invoke()
    app.settle()
    after = st['sheet_zoom'], st['zoom']
    check('AC1 clicking + zooms both panels',
          after[0] > before[0] and after[1] > before[1],
          'sheet %d->%d  glyph %d->%d' % (before[0], after[0], before[1], after[1]))

    for b in bs['−']:
        b.invoke()
    app.settle()
    check('AC1 clicking - zooms out', (st['sheet_zoom'], st['zoom']) == before,
          'sheet %d  glyph %d' % (st['sheet_zoom'], st['zoom']))

    for b in bs['fit']:
        b.invoke()
    app.settle()
    check('AC1 fit buttons work', st['zoom'] == 8 and st['sheet_zoom'] >= 1,
          'glyph %dx  sheet %dx' % (st['zoom'], st['sheet_zoom']))

    # the readout
    labels = []

    def walk(w):
        import tkinter as tk
        for c in w.winfo_children():
            if isinstance(c, tk.Label):
                labels.append(str(c.cget('text')))
            walk(c)
    walk(app.root)
    check('AC1 zoom readout visible',
          any(t.endswith('x') and t[:-1].isdigit() for t in labels),
          [t for t in labels if t.endswith('x') and t[:-1].isdigit()])


def t_zoom_key_without_focus(app):
    """DEFECT-1 DIAGNOSIS. Park focus on a Button and fire the key. If sheet zoom
    were focus-dependent this fails; it passes, which is what proves the cause
    was discoverability rather than focus."""
    st = app.gt['st']
    bs = buttons(app.root)
    victim = bs['SAVE'][0]
    victim.focus_set()
    app.settle()
    focused = str(app.root.focus_get())
    before = st['sheet_zoom']
    app.root.event_generate('<KeyPress-bracketright>')
    app.settle()
    check('AC1 sheet-zoom key works with focus elsewhere',
          st['sheet_zoom'] == before + 1,
          'focus on %s; [ ] still reached the toplevel  %d->%d'
          % (focused, before, st['sheet_zoom']))
    app.root.event_generate('<KeyPress-bracketleft>')
    app.settle()


# ------------------------------------------------------------------ AC3 -----
def t_zoom_anchor(app):
    """Sheet zoom must anchor on the SELECTED TILE, not the origin."""
    st, gt = app.gt['st'], app.gt
    gt['select'](250, 0)                       # bottom-right corner of the sheet
    app.settle()
    while st['sheet_zoom'] > 1:
        gt['sheet_zoom'](-1)
    app.settle()

    for _ in range(4):
        gt['sheet_zoom'](+1)
    app.settle()
    z = st['sheet_zoom']
    sheetc = gt['sheetc']
    x, y, w, h = S.tile_rect(250)
    cx, cy = (x + w / 2.0) * z, (y + h / 2.0) * z
    x0 = sheetc.canvasx(0)
    y0 = sheetc.canvasy(0)
    vw, vh = sheetc.winfo_width(), sheetc.winfo_height()
    inview = x0 <= cx <= x0 + vw and y0 <= cy <= y0 + vh
    check('AC3 selected tile still in view at %dx' % z, inview,
          'tile 250 centre (%.0f,%.0f) in viewport x[%.0f..%.0f] y[%.0f..%.0f]'
          % (cx, cy, x0, x0 + vw, y0, y0 + vh))
    # ...and CENTRED, not merely on-screen. A tile within half a viewport of the
    # sheet edge CANNOT be centred without scrolling past the content, so the
    # honest test is "centred, or the view is already hard against the edge it
    # would have to scroll past". Tile 250 is in the bottom row, which is exactly
    # that case — an unconditional tolerance here fails on correct behaviour.
    total = float(S.GRID * z)
    want_x = max(0.0, min(total - vw, cx - vw / 2.0))
    want_y = max(0.0, min(total - vh, cy - vh / 2.0))
    off = max(abs(x0 - want_x), abs(y0 - want_y))
    check('AC3 and centred as far as the scroll range allows', off <= 2,
          'view at (%.0f,%.0f), clamped ideal (%.0f,%.0f), error %.0f px'
          % (x0, y0, want_x, want_y, off))

    # a tile in the MIDDLE has no clamp, so it must be centred outright
    gt['select'](8 * 16 + 8, 0)
    app.settle()
    gt['sheet_zoom'](-1)
    gt['sheet_zoom'](+1)
    app.settle()
    x, y, w, h = S.tile_rect(8 * 16 + 8)
    cx, cy = (x + w / 2.0) * z, (y + h / 2.0) * z
    off2 = max(abs(cx - (sheetc.canvasx(0) + vw / 2.0)),
               abs(cy - (sheetc.canvasy(0) + vh / 2.0)))
    check('AC3 a mid-sheet tile is centred outright', off2 <= 24 * z,
          'tile 136 off-centre by %.0f px (tolerance %d)' % (off2, 24 * z))


def t_no_selection_state(app):
    """AC3 also asks what happens with nothing selected. Establish whether that
    state can occur at all rather than assuming Jay is right."""
    st, gt = app.gt['st'], app.gt
    check('AC3 a tile is always selected', isinstance(st['tile'], int)
          and 0 <= st['tile'] <= 255 and isinstance(st['cell'], int),
          'tile=%r cell=%r — st is seeded with 0 and select() clamps to 0..255, '
          'so no unselected state exists' % (st['tile'], st['cell']))
    gt['select'](-5, 0)
    gt['select'](999, 0)
    app.settle()
    check('AC3 out-of-range selection clamps, no crash',
          st['tile'] == 255, 'select(-5) then select(999) -> %d' % st['tile'])


def t_zoom_survives_selection(app):
    """AC3b — changing the selected tile must not reset either zoom."""
    st, gt = app.gt['st'], app.gt
    gt['sheet_zoom'](+2)
    gt['zoom'](+3)
    app.settle()
    sz, gz, view = st['sheet_zoom'], st['zoom'], st['view']
    for t in (7, 100, 3, 250, 0):
        gt['select'](t, 4)
    app.settle()
    check('AC3b selection does not reset zoom',
          (st['sheet_zoom'], st['zoom'], st['view']) == (sz, gz, view),
          'after 5 selections: sheet %dx glyph %dx view %s' %
          (st['sheet_zoom'], st['zoom'], st['view']))


# ------------------------------------------------------------ AC4/5/6/7 -----
def t_compose_click(app):
    """All NINE cells, by pixel coordinate, on both the composed tile and the
    reference beside it — the same exhaustive standard C6 met for the sheet."""
    st, gt = app.gt['st'], app.gt
    gt['select'](7, 0)
    app.settle()
    cw, ch = A.CELL_W * gt['CMP_ZOOM'], A.CELL_H * gt['CMP_ZOOM']
    tw = 24 * cw

    bad = []
    for k in range(9):
        cy, cx = divmod(k, 3)
        # a point in the middle of that cell, in BOTH panels
        px, py = cx * 8 * cw + 4 * cw, cy * 8 * ch + 4 * ch
        for base, which in ((0, 'composed'), (tw + gt['CMP_GAP'], 'reference')):
            gt['select'](7, 0)
            got = gt['compose_hit'](base + px, py)
            if got != k:
                bad.append((which, k, got))
    check('AC4 all 9 cells resolve in both panels', not bad, str(bad) or
          '18 hit tests (9 cells x composed/reference)')

    # corners, where an off-by-one lives
    edges = [((0, 0), 0), ((8 * cw - 1, 8 * ch - 1), 0), ((8 * cw, 0), 1),
             ((tw - 1, th_last := 24 * ch - 1), 8)]
    bad2 = [(p, e, gt['compose_hit'](*p)) for p, e in edges
            if gt['compose_hit'](*p) != e]
    check('AC4 cell boundaries', not bad2, str(bad2) or '8/16/24-px edges')
    check('AC4 outside the tiles is None',
          gt['compose_hit'](tw + 5, 5) is None
          and gt['compose_hit'](0, 24 * ch + 5) is None, 'gutter and below')

    # a real click event, not just the hit test
    gt['select'](7, 0)
    app.settle()
    cc = gt['ccanvas']
    cc.event_generate('<ButtonPress-1>', x=int(1 * 8 * cw + 4 * cw),
                      y=int(2 * 8 * ch + 4 * ch), warp=False)
    app.settle()
    check('AC4 a real click selects that cell', st['cell'] == 7,
          'clicked BM -> cell %d' % st['cell'])


def t_selected_cell_distinct(app):
    """AC5 — the edited cell must be marked differently from the orange
    same-glyph outline. Rendered, then the two marks counted in the pixels."""
    import numpy as np
    import render as R
    from tilemap import Mapping
    gt = app.gt
    m = gt['mapping']
    tile = next((t for t in range(256)
                 if len(m.tile_glyph_set(t)) < 9 and m.glyphs[t][0] is not None), 7)
    gs = m.tile_glyph_set(tile)
    g = m.glyphs[tile][0]
    sib = gs.get(g, [])
    import sheet as SS
    pal, _, _ = SS.load_palette()
    img = np.asarray(R.tile_image(gt['fe'].font, m, tile, pal, 3, cell=0, cells=sib))
    n_edit = int((img == np.array(R.EDITING)).all(axis=2).sum())
    n_sib = int((img == np.array(R.SIBLING)).all(axis=2).sum())
    n_cur = int((img == np.array(R.CURSOR)).all(axis=2).sum())
    check('AC5 edited cell has its own mark',
          n_edit > 0 and R.EDITING != R.SIBLING,
          'tile $%02X: %d edit-tick px, %d sibling px, %d cursor px'
          % (tile, n_edit, n_sib, n_cur))


def t_reselect_is_noop(app):
    """AC6 — re-selecting the glyph already under edit must not clear undo."""
    st, gt = app.gt['st'], app.gt
    m, fe = gt['mapping'], gt['fe']
    # a tile using the SAME glyph in two different cells
    pair = None
    for t in range(256):
        for gg, cells in m.tile_glyph_set(t).items():
            if len(cells) >= 2:
                pair = (t, gg, cells[0], cells[1])
                break
        if pair:
            break
    if not pair:
        check('AC6 re-select preserves undo', False, 'no tile repeats a glyph')
        return
    t, gg, k0, k1 = pair
    gt['select'](t, k0)
    app.settle()
    ge = fe[gg]
    ge.begin_stroke()
    ge.paint(0, 0, (int(fe.font[gg][0, 0]) + 1) % 16)
    depth, dirty = len(ge.undo), ge.is_dirty()
    check('AC6 setup: a stroke is live', depth == 1 and dirty,
          'tile $%02X glyph $%02X in cells %s' % (t, gg, (k0, k1)))

    gt['select_cell'](k1)                       # same glyph, different cell
    app.settle()
    check('AC6 re-selecting the same glyph is a no-op',
          len(fe[gg].undo) == depth and fe[gg].is_dirty() == dirty
          and gt['glyph']() == gg,
          'undo depth %d kept, still dirty, glyph still $%02X'
          % (len(fe[gg].undo), gt['glyph']()))
    check('AC6 selecting the SAME cell returns False',
          gt['select_cell'](k1) is False, 'no redraw, no state change')
    fe[gg].revert()


def t_keyboard_traversal(app):
    """AC7 — Tab steps the nine cells; it must not be eaten by focus traversal."""
    st, gt = app.gt['st'], app.gt
    gt['select'](7, 0)
    app.settle()
    seen = [st['cell']]
    for _ in range(8):
        app.root.event_generate('<KeyPress-Tab>')
        app.settle(1)
        seen.append(st['cell'])
    check('AC7 Tab traverses all nine cells TL->BR', seen == list(range(9)), seen)
    for _ in range(8):
        app.root.event_generate('<KeyPress-Tab>', state=1)      # Shift-Tab
        app.settle(1)
    check('AC7 Shift-Tab walks back', st['cell'] == 0, 'cell %d' % st['cell'])


# ------------------------------------------------------------------ AC8 -----
def t_reference_buttons(app):
    st, gt = app.gt['st'], app.gt
    bs = buttons(app.root)
    # C6-A4: four states now — a CoCo engine render joined the three
    names = ['raw', 'CoCo px', 'CoCo engine', 'C64']
    check('AC8 four reference buttons exist',
          all(n in bs for n in names) and len(names) == len(S.Reference.VIEWS),
          [n for n in names if n not in bs])
    for n, v in zip(names, S.Reference.VIEWS):
        bs[n][0].invoke()
        app.settle()
        if st['view'] != v:
            check('AC8 button "%s" selects %s' % (n, v), False, st['view'])
            return
    check('AC8 every reference view reachable by click alone', True,
          ' -> '.join(S.Reference.VIEWS))

    # the CURRENT view must be spelled out on screen for whichever view is
    # active — three near-identical images with no label is its own trap
    def labels():
        import tkinter as tk
        out = []

        def walk(w):
            for c in w.winfo_children():
                if isinstance(c, tk.Label):
                    out.append(str(c.cget('text')))
                walk(c)
        walk(app.root)
        return out

    missing = []
    for n, v in zip(names, S.Reference.VIEWS):
        bs[n][0].invoke()
        app.settle()
        word = S.Reference.LABELS[v].split()[0]
        if not any(word in t and len(t) > 20 for t in labels()):
            missing.append(v)
    check('AC8 the ACTIVE view is named on screen', not missing,
          str(missing) or 'all three named in full while selected')
    bs['raw'][0].invoke()
    app.settle()


def t_ui_state_persists(app):
    """AC8 — the view survives a session, via the progress sidecar."""
    gt = app.gt
    prog = gt['prog']
    prog.ui = {'view': 'amiga_quant', 'zoom': 11, 'sheet_zoom': 3,
               'tile': 42, 'cell': 5, 'queue': 'worst'}
    d = prog.to_dict(gt['fe'], gt['cfg'].font, 'x' * 64, 'y' * 64)
    check('AC8 view is written to the sidecar',
          d.get('ui', {}).get('view') == 'amiga_quant', d.get('ui'))


def t_no_wheel_only(app):
    """AC2 — enumerate wheel/gesture bindings and confirm each has another route."""
    gt = app.gt
    wheel = []
    for name, w in (('sheet', gt['sheetc']), ('glyph', gt['gcanvas']),
                    ('tile', gt['ccanvas'])):
        for seq in w.bind():
            if 'Wheel' in seq or 'Button-4' in seq or 'Button-5' in seq:
                wheel.append('%s%s' % (name, seq))
    # the sheet's wheel bindings PAN; scrollbars do the same job by click-drag
    sframe = gt['sheetc'].master
    import tkinter as tk
    bars = [c for c in sframe.winfo_children() if isinstance(c, tk.Scrollbar)]
    check('AC2 wheel bindings enumerated', True, wheel or 'none')
    check('AC2 every wheel binding is pan, and scrollbars duplicate it',
          all('Wheel' in s for s in wheel) and len(bars) == 2,
          '%d wheel bindings (all pan), %d scrollbars' % (len(wheel), len(bars)))


def t_check_fits(app):
    """Hard constraint: the layout must fit at every zoom the tool will ACCEPT.

    Sheet zoom cannot break it — the sheet canvas expands and scrolls, so the
    window never grows. Glyph zoom can, and does: the canvas is fixed-size and
    stacked. So the requirement is not 'every zoom fits' but 'the tool refuses
    the zooms that do not', which is what the self-limit in zoom() enforces.
    """
    st, gt = app.gt['st'], app.gt
    st['zoom'] = 8
    gt['redraw']()
    app.settle(1)

    bad = [ 'sheet %dx' % sz for sz in range(1, gt['SHEET_ZOOM_MAX'] + 1)
            if (st.__setitem__('sheet_zoom', sz),
                st.__setitem__('sheet_cache', (None, None)),
                gt['redraw'](), app.settle(1), not gt['check_fits']())[-1] ]
    st['sheet_zoom'] = 1
    st['sheet_cache'] = (None, None)
    gt['redraw']()
    app.settle(1)
    check('check_fits passes at every SHEET zoom', not bad, str(bad) or
          '1x-%dx, canvas expands so the window never grows' % gt['SHEET_ZOOM_MAX'])

    # walk glyph zoom all the way up; the self-limit must stop it before clipping
    for _ in range(40):
        gt['zoom'](+1)
        app.settle(1)
    reached = st['zoom']
    check('glyph zoom self-limits before clipping',
          gt['check_fits']() and reached < gt['GLYPH_ZOOM_MAX'],
          'held at %dx (ceiling offered: %dx) on a %dpx screen; layout still fits'
          % (reached, gt['GLYPH_ZOOM_MAX'], app.root.winfo_screenheight()))
    for _ in range(40):
        gt['zoom'](-1)
    st['zoom'] = 8
    gt['redraw']()
    app.settle(1)
    check('glyph zoom returns to the default cleanly',
          st['zoom'] == 8 and gt['check_fits']())


# ------------------------------------------------------------- C6-A3 -------
def t_accept_buttons(app):
    """AC1 — visible, labelled, shortcut printed."""
    bs = buttons(app.root)
    want = ['accept cell (a)', 'accept tile (9)  (Shift-A)']
    check('A3-AC1 accept buttons exist and name their key',
          all(w in bs for w in want), [w for w in want if w not in bs])
    labels = []

    def walk(w):
        import tkinter as tk
        for c in w.winfo_children():
            if isinstance(c, tk.Label):
                labels.append(str(c.cget('text')))
            walk(c)
    walk(app.root)
    check('A3-AC1 the source is named beside them',
          any('QUANTISED' in t for t in labels),
          next((t for t in labels if 'QUANTISED' in t), ''))


def t_accept_cost(app):
    """AC2 — the cost is computed from the LOADED tileset, not hardcoded."""
    import accept as ACC
    gt = app.gt
    m, refc = gt['mapping'], gt['ref']
    for tile in (4, 136):
        p = ACC.plan(refc.qidx, m, tile, range(9))
        line = ACC.cost_line(p, m, tile, list(range(9)))
        check('A3-AC2 cost for tile %d' % tile,
              len(p['tiles']) > 0 and 'changes %d tiles' % len(p['tiles']) in line,
              '%d distinct glyphs -> %d tiles; %d conflicting'
              % (len(p['changes']), len(p['tiles']),
                 len([g for g in p['conflicts'] if g not in p['identical']])))
    # and it must react to the checkboxes rather than being a constant
    gt['select'](4, 0)
    gt['set_all_cells'](1)
    gt['refresh_cost']()
    app.settle(1)
    full = _cost_text(app)
    gt['set_all_cells'](0)
    gt['cell_vars'][0].set(1)
    gt['refresh_cost']()
    app.settle(1)
    one = _cost_text(app)
    check('A3-AC2 cost tracks the tick boxes', full != one and one,
          'nine cells vs one produce different costs')
    gt['set_all_cells'](1)
    gt['refresh_cost']()


def _cost_text(app):
    import tkinter as tk
    out = []

    def walk(w):
        for c in w.winfo_children():
            if isinstance(c, tk.Label) and str(c.cget('fg')) == '#ffcc66':
                out.append(str(c.cget('text')))
            walk(c)
    walk(app.root)
    return out[0] if out else ''


def t_accept_conflict(app):
    """AC3 — no silent last-write-wins."""
    import accept as ACC
    gt = app.gt
    m, refc = gt['mapping'], gt['ref']
    # a tile with a REAL conflict — the same glyph written from two cells whose
    # art DIFFERS. A tile where the competing art happens to agree proves nothing
    # about the tie-break, so it is not good enough for this check.
    tile, p, real = None, None, {}
    for cand in range(256):
        pc = ACC.plan(refc.qidx, m, cand, range(9))
        rc = {g: ks for g, ks in pc['conflicts'].items() if g not in pc['identical']}
        if rc:
            tile, p, real = cand, pc, rc
            break
    check('A3-AC3 a tile with DIFFERING conflicting art exists', bool(real),
          'tile $%02X, %d glyph(s) written from >1 cell with different art: %s'
          % (tile, len(real), ', '.join('$%02X x%d' % (g, len(k))
                                        for g, k in sorted(real.items()))))
    # TL->BR: the winner must be the LOWEST cell index of each conflicted glyph
    bad = [(g, p['winners'][g], ks) for g, ks in p['conflicts'].items()
           if p['winners'][g] != min(ks)]
    check('A3-AC3 first cell in TL->BR order wins', not bad, str(bad) or
          'winner == min(cells) for all %d' % len(p['conflicts']))
    check('A3-AC3 dropped cells are recorded',
          all(sorted(p['dropped'].get(g, [])) == sorted(set(ks) - {p['winners'][g]})
              for g, ks in p['conflicts'].items()),
          '%d glyphs with dropped cells' % len(p['dropped']))
    if real:
        line = ACC.cost_line(p, m, tile, list(range(9)))
        out = ACC.outcome_line(p, m, tile)
        check('A3-AC3 conflict stated BEFORE and AFTER the write',
              'conflicting art' in line and 'DROPPED' in out,
              'before: names them; after: names what was dropped')
    else:
        check('A3-AC3 conflict stated BEFORE and AFTER the write', True,
              'all conflicts on this tile carry identical art')


def t_accept_undo(app):
    """AC5 — ONE undo reverts an entire accept, byte-identically."""
    import glyphio
    gt = app.gt
    fe = gt['fe']
    gt['select'](4, 0)
    gt['set_all_cells'](1)
    app.settle(1)
    before = glyphio.sha256_bytes(glyphio.pack(fe.font))
    depth = len(fe.history)
    gt['accept_tile']()
    app.settle(1)
    after = glyphio.sha256_bytes(glyphio.pack(fe.font))
    check('A3-AC5 accept changed the font', after != before,
          '%s -> %s' % (before[:12], after[:12]))
    check('A3-AC5 accept is exactly ONE history entry',
          len(fe.history) == depth + 1,
          '%d glyphs written in 1 entry' % len(fe.history[-1]))
    gt['do_undo']()
    app.settle(1)
    back = glyphio.sha256_bytes(glyphio.pack(fe.font))
    check('A3-AC5 one undo restores byte-identically', back == before,
          '%s == %s' % (back[:12], before[:12]))
    check('A3-AC5 undo cleared the accepted provenance',
          not any(g in gt['prog'].accepted for g in range(len(fe.font))),
          'sidecar does not claim art the font no longer holds')


def t_accept_subset(app):
    """AC4 — per-cell opt-out writes only the ticked cells."""
    import accept as ACC
    import numpy as np
    gt = app.gt
    m, fe, refc = gt['mapping'], gt['fe'], gt['ref']
    gt['select'](4, 0)
    gt['set_all_cells'](0)
    for k in (0, 1, 2):                       # top row only
        gt['cell_vars'][k].set(1)
    gt['refresh_cost']()
    app.settle(1)
    check('A3-AC4 included_cells reflects the boxes',
          gt['included_cells']() == [0, 1, 2], gt['included_cells']())
    expect = ACC.plan(refc.qidx, m, 4, [0, 1, 2])['changes']
    excluded = ACC.plan(refc.qidx, m, 4, [3, 4, 5, 6, 7, 8])['changes']
    snap = {g: fe.font[g].copy() for g in set(expect) | set(excluded)}
    gt['accept_tile']()
    app.settle(1)
    wrote_wanted = all(np.array_equal(fe.font[g], expect[g]) for g in expect)
    only_excluded = [g for g in excluded if g not in expect]
    kept = all(np.array_equal(fe.font[g], snap[g]) for g in only_excluded)
    check('A3-AC4 only the ticked cells were written', wrote_wanted and kept,
          'wrote %s; left %s untouched'
          % (['$%02X' % g for g in sorted(expect)],
             ['$%02X' % g for g in sorted(only_excluded)] or 'nothing else'))
    gt['do_undo']()
    gt['set_all_cells'](1)
    gt['refresh_cost']()
    app.settle(1)


def t_accept_source(app):
    """AC7 — source is the quantised reference whatever view is displayed."""
    import glyphio
    import numpy as np
    gt = app.gt
    fe = gt['fe']
    results = {}
    for view in ('amiga_raw', 'oracle', 'amiga_quant'):
        gt['set_ref'](view)
        gt['select'](4, 0)
        gt['set_all_cells'](1)
        app.settle(1)
        gt['accept_tile']()
        app.settle(1)
        results[view] = glyphio.sha256_bytes(glyphio.pack(fe.font))
        gt['do_undo']()
        app.settle(1)
    check('A3-AC7 accept ignores the displayed view',
          len(set(results.values())) == 1,
          'raw/oracle/quantised all produce %s' % list(results.values())[0][:16])
    gt['set_ref']('amiga_raw')

    # ...and it really is the QUANTISED pixels, not the raw ones
    import accept as ACC
    m, refc = gt['mapping'], gt['ref']
    q = ACC.quantised_cell(refc.qidx, 4, 0)
    check('A3-AC7 the source pixels are palette indices 0-15',
          q.shape == (8, 8) and int(q.max()) <= 15 and q.dtype == np.uint8,
          'quantised cell is an index map, not RGB')


def t_accept_provenance(app):
    """AC6 — accepted is distinguishable from hand-drawn in the sidecar."""
    import progress as PP
    gt = app.gt
    fe, prog = gt['fe'], gt['prog']
    gt['select'](4, 0)
    gt['set_all_cells'](1)
    app.settle(1)
    gt['accept_tile']()
    app.settle(1)
    g_acc = fe.history[-1][0]
    d = prog.to_dict(fe, gt['cfg'].font, 'x' * 64, 'y' * 64)
    check('A3-AC6 accepted glyphs are marked `accepted`',
          d['state'][str(g_acc)] == PP.ACCEPTED and str(g_acc) in d['accepted'],
          'glyph $%02X -> %s (%s)' % (g_acc, d['state'][str(g_acc)],
                                      d['accepted'][str(g_acc)]))
    check('A3-AC6 the sidecar counts them separately',
          'accepted' in d['counts'] and d['counts']['accepted'] >= 1,
          d['counts'])
    # a hand stroke over an accepted glyph promotes it to `edited`
    prog.note_edit(g_acc)
    d2 = prog.to_dict(fe, gt['cfg'].font, 'x' * 64, 'y' * 64)
    check('A3-AC6 drawing over an accept promotes it to `edited`',
          d2['state'][str(g_acc)] == PP.EDITED,
          'provenance follows the most recent authorship')
    prog.last_edit.pop(g_acc, None)
    gt['do_undo']()
    app.settle(1)


def t_accept_queue(app):
    """AC8 — the cheap-first queue exists and is sorted by ascending radius."""
    import accept as ACC
    gt = app.gt
    q = gt['qs'].get('cheap-accept')
    check('A3-AC8 cheap-accept queue exists', bool(q) and len(q) == 256,
          '%d tiles' % (len(q) if q else 0))
    radius = ACC.blast_radius(gt['mapping'])
    r = [radius[t] for t in q]
    check('A3-AC8 sorted by ascending blast radius', r == sorted(r),
          'first %s ... last %s' % (r[:4], r[-3:]))


# ------------------------------------------------------------- C6-A4 -------
def t_coco_sheets(app):
    """AC1/AC2/AC3 — the sheets exist at 384x384, are classified by measurement,
    and hold nothing but the adopted 16."""
    import cocosheet as CS
    import glyphio
    import numpy as np
    from PIL import Image
    gt = app.gt
    pal = gt['ref'].pal_rgb

    for name, expect in (('coco-quantised', 'per-pixel quantisation'),
                         ('coco-engine', 'engine render')):
        path = os.path.join(C.REPO, 'art', '%s.png' % name)
        check('A4-AC1 %s exists at 384x384' % name, os.path.exists(path)
              and Image.open(path).size == (384, 384),
              '%s  sha256 %s' % (Image.open(path).size if os.path.exists(path) else '-',
                                 glyphio.sha256_file(path)[:32] if os.path.exists(path) else '-'))
        rgb = np.asarray(Image.open(path).convert('RGB'))
        n = CS.distinct_cells(rgb)
        check('A4-AC2 %s classified by measurement' % name,
              CS.classify(n) == expect,
              '%d distinct 8x8 cells -> %s' % (n, CS.classify(n)))
        check('A4-AC3 %s is palette-legal' % name,
              CS.off_palette(rgb, pal) == 0,
              '%d off-palette pixels' % CS.off_palette(rgb, pal))

    # the palette really came from the FILE, not a quote in a dispatch
    import json
    with open(C.PALETTE_JSON, encoding='utf-8') as f:
        want = [s['rgb'] for s in json.load(f)['slots']]
    check('A4-AC1 palette is the one in assets/palette.json',
          np.array_equal(pal, np.array(want, dtype=np.uint8)),
          ' '.join('$%02X' % b for b in gt.get('pal_bytes', [])) or 'matches file')


def t_coco_alignment(app):
    """AC5 — sheet tile n corresponds to tileset tile n, checked against a
    landmark rather than asserted."""
    import numpy as np
    from PIL import Image
    import render as R
    import sheet as SS
    gt = app.gt
    m, fe = gt['mapping'], gt['fe']
    pal = gt['ref'].pal_rgb
    eng = np.asarray(Image.open(os.path.join(C.REPO, 'art', 'coco-engine.png'))
                     .convert('RGB'))

    # landmark 1: every tile must agree with the editor's own composed-tile path,
    # which is an independent code path over the same mapping
    bad = []
    for t in range(256):
        idx, nod = R.compose_tile(fe.font, m, t)
        want = pal[idx]
        x, y, w, h = SS.tile_rect(t)
        got = eng[y:y + h, x:x + w]
        if not np.array_equal(got[~nod], want[~nod]):
            bad.append(t)
    check('A4-AC5 engine sheet agrees with compose_tile on all 256 tiles',
          not bad, str(bad[:5]) or 'independent path, same result')

    # landmark 2: a tile whose nine cells all use the SAME glyph must render as
    # that 8x8 tiled exactly 3x3. Offset the sheet by a single pixel and the
    # repetition breaks, so this pins the origin and the pitch together.
    #
    # NOT the flat-colour test I reached for first: C6-A1's `available` tiles are
    # blank in the SHIPPED table, but a192's allocator remapped those cells onto
    # a glyph whose pixels come from k-means over the art and need not be
    # uniform. Uniform in GLYPH, not in colour — the test has to say which.
    uniform = [t for t in range(256) if len(m.tile_glyph_set(t)) == 1
               and all(c is not None for c in m.glyphs[t])]
    bad2 = []
    for t in uniform:
        x, y, w, h = SS.tile_rect(t)
        block = eng[y:y + 8, x:x + 8]
        if not np.array_equal(eng[y:y + h, x:x + w], np.tile(block, (3, 3, 1))):
            bad2.append(t)
    check('A4-AC5 single-glyph tiles repeat exactly 3x3 at their own index',
          uniform and not bad2,
          '%d such tiles (e.g. %s), %d misaligned'
          % (len(uniform), sorted(uniform)[:4], len(bad2)))


def t_coco_accept_source(app):
    """AC6 — the engine render must NOT have become the accept source, and
    accept stays invariant across all FOUR views."""
    import glyphio
    gt = app.gt
    fe = gt['fe']
    out = {}
    for view in S.Reference.VIEWS:
        gt['set_ref'](view)
        gt['select'](4, 0)
        gt['set_all_cells'](1)
        app.settle(1)
        gt['accept_tile']()
        app.settle(1)
        out[view] = glyphio.sha256_bytes(glyphio.pack(fe.font))
        gt['do_undo']()
        app.settle(1)
    check('A4-AC6 accept is invariant across all four views',
          len(set(out.values())) == 1,
          '%d views -> %s' % (len(out), list(out.values())[0][:16]))

    # ...and it is the PER-PIXEL source, not the engine one. Accepting from the
    # engine render would write a glyph its own current pixels — a no-op.
    import accept as ACC
    import numpy as np
    p = ACC.plan(gt['ref'].qidx, gt['mapping'], 4, range(9))
    same = [g for g, px in p['changes'].items() if np.array_equal(fe.font[g], px)]
    check('A4-AC6 accept source is per-pixel, not the engine render',
          len(same) < len(p['changes']),
          '%d of %d glyphs would actually change — an engine source would change 0'
          % (len(p['changes']) - len(same), len(p['changes'])))
    gt['set_ref']('amiga_raw')
    app.settle(1)


def main():
    try:
        import tkinter  # noqa: F401
    except Exception as e:                                     # noqa: BLE001
        print('uitest needs Tkinter on a machine with a display: %s' % e)
        return 0
    with App() as app:
        for fn in (t_zoom_buttons, t_zoom_key_without_focus, t_zoom_anchor,
                   t_no_selection_state, t_zoom_survives_selection,
                   t_compose_click, t_selected_cell_distinct, t_reselect_is_noop,
                   t_keyboard_traversal, t_reference_buttons, t_ui_state_persists,
                   t_no_wheel_only,
                   t_accept_buttons, t_accept_cost, t_accept_conflict,
                   t_accept_undo, t_accept_subset, t_accept_source,
                   t_accept_provenance, t_accept_queue,
                   t_coco_sheets, t_coco_alignment, t_coco_accept_source,
                   t_check_fits):
            try:
                fn(app)
            except Exception as ex:                            # noqa: BLE001
                import traceback
                check(fn.__name__, False, 'raised %s: %s' % (type(ex).__name__, ex))
                traceback.print_exc()
    print('\n'.join(LINES))
    print('\n%d checks, %d failed' % (len(LINES), len(FAILS)))
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
