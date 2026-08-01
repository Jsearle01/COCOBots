#!/usr/bin/env python3
"""
glyph_tool_app.py — hand-authoring glyph editor for the CoCo3 font (C6).

  python tools/glyph_tool/glyph_tool_app.py [--config a192|shipped] [--tile N]

LAYOUT (C6 §3, Jay's spec). Sheet on the RIGHT, position-indexed by tile, click
to load with sub-cell precision. Glyph under edit on the LEFT, enlarged, with
the composed 24x24 tile beside the Amiga source underneath it. Palette selector
along the BOTTOM. Zoom on both panels. Save, undo, redo.

INTERACTION MODEL is POP's sprite tool, deliberately: armed palette swatch with a
yellow highlight border, one undo step per stroke, coalesced redraw on drag, a
prominent save banner that only a save writes, a status line, action buttons that
gray themselves when their action is invalid, Ctrl-Z / Ctrl-Y / Ctrl-S, +/- zoom,
mouse-wheel pan. Nothing here reinvents a convention that tool already settled.

KEYS
  click sheet     load the tile+cell under the cursor (sub-cell)
  paint / drag    set the armed palette index
  right-click     eyedropper - arm the index under the cursor
  Ctrl-Z / Ctrl-Y undo / redo          Ctrl-S  save
  + / -           glyph zoom           [ / ]   sheet zoom
  , / .           previous / next palette index
  r               reference: raw Amiga -> quantised -> C64 oracle
  a               affected-tile strip (OFF by default - Jay: a strip
                  "would make the screen busy")
  d               mark the current glyph done / not done
  arrows          move the selected cell within the tile
  Shift-arrows    move to the next / previous tile on the sheet
  n / p           next / previous tile in the work queue
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config as C                    # noqa: E402
import glyphio                        # noqa: E402
import progress as P                  # noqa: E402
import queues                         # noqa: E402
import render as R                    # noqa: E402
import sheet as S                     # noqa: E402
from edit_model import FontEdit       # noqa: E402
from pixel_map import CELL_W, CELL_H, screen_to_glyph   # noqa: E402
from tilemap import Mapping, PLANES   # noqa: E402

ARM = '#FFE400'                       # armed-swatch highlight border (POP's convention)
OK, STOP, INFO, IDLE = '#1b7f1b', '#b02020', '#666666', '#444444'
STATE_BG = {P.UNTOUCHED: '#555555', P.EDITED: '#8a6d00', P.DONE: '#1b7f1b'}

AVAIL_MARK = '#00ff88'        # available — a free slot, marked invitingly
UNVERIFIED_MARK = '#ffaa00'   # no static reference — drawn normally
AFFECTED = '#00e0ff'
SELECTED = '#ffe400'

CLS_BG = {'available': '#0b6b3a', 'referenced': '#3a3a3a',
          'no-static-reference': '#8a5a00'}

# Fixed geometry, sized against a 1536x864 display. The two zooms the dispatch
# asks for (glyph, sheet) are live; the comparison pair is fixed at 3x because a
# third zoom control buys nothing and 3x is what makes 24x24 at 5:6 (360x432)
# sit beside the glyph canvas without either one clipping.
CMP_ZOOM = 3
STRIP_ZOOM = 1
STRIP_PER_ROW = 32          # 122 tiles -> 4 rows, not 8
STRIP_W = STRIP_PER_ROW * (24 * STRIP_ZOOM + 2)
STRIP_H_CAP = 140


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--config', default=C.DEFAULT, choices=sorted(C.CONFIGS))
    ap.add_argument('--tile', type=int, default=None)
    ap.add_argument('--font', default=None,
                    help='override the starting font (default: the authored '
                         'file if one exists, else the config source)')
    ap.add_argument('--cell', type=int, default=0, choices=range(9))
    ap.add_argument('--view', default=None, choices=S.Reference.VIEWS)
    ap.add_argument('--strip', action='store_true')
    ap.add_argument('--sheet-zoom', type=int, default=None)
    ap.add_argument('--screenshot', default=None,
                    help='build the UI, grab the window to this PNG, and exit '
                         '(evidence for the report; changes nothing)')
    args = ap.parse_args()

    cfg = C.CONFIGS[args.config]

    # Resume from the authored file when there is one — otherwise a session would
    # silently start from the converter output and the previous hand work would
    # look like it had vanished.
    src = args.font or (cfg.out_font if os.path.exists(cfg.out_font) else cfg.font)
    addr = cfg.font_addr if src == cfg.font else None
    if not os.path.exists(src):
        raise SystemExit(
            'glyph_tool: %s not found.\n'
            'Regenerate C4\'s artifacts first:  python tools/ladder.py' % src)
    font = glyphio.load_font(src, cfg.n_glyphs, addr)
    source_sha = glyphio.sha256_bytes(glyphio.pack(font))

    mapping = Mapping(cfg)
    pal_rgb, pal_bytes, pal_names = S.load_palette()
    ref = S.Reference(pal_rgb)
    qs = queues.build(mapping)
    fe = FontEdit(font)
    prog = P.Progress(cfg, cfg.n_glyphs)

    try:
        import tkinter as tk
        from PIL import ImageTk
    except Exception as e:                                    # noqa: BLE001
        print('GUI needs Tkinter + Pillow on a machine with a display: %s' % e)
        c = mapping.cls['counts']
        print('(headless: config %s, %d glyphs, %d used; tiles %d available / '
              '%d referenced / %d no-static-reference — the model loads; run on '
              'your desktop for the UI.)'
              % (cfg.name, cfg.n_glyphs, len(mapping.used_glyphs()),
                 c['available'], c['referenced'], c['unverified']))
        return

    root = tk.Tk()
    root.title('glyph tool — %s' % cfg.name)
    root.minsize(1200, 700)

    st = {'zoom': 8, 'sheet_zoom': 1, 'colour': 1, 'tile': 0, 'cell': 0,
          'view': 'amiga_raw', 'strip': False, 'painting': False,
          'queue': 'worst', 'qi': 0, 'imgs': {}, 'sheet_cache': (None, None)}

    def glyph():
        return mapping.glyphs[st['tile']][st['cell']]

    # ---------------------------------------------------------------- chrome --
    bar = tk.Frame(root)
    bar.pack(fill='x')
    selbar = tk.Frame(root)
    selbar.pack(fill='x')

    # FIXED width monospace so a changing readout never resizes the label and
    # shoves the button cluster off the right edge (POP's sprite tool bug).
    coord = tk.Label(bar, text='move over a pixel...', font=('Consolas', 10),
                     width=52, anchor='w')
    coord.pack(side='left', padx=6)

    save_btn = tk.Button(bar, text='SAVE', command=lambda: do_save())
    undo_btn = tk.Button(bar, text='undo', command=lambda: do_undo())
    redo_btn = tk.Button(bar, text='redo', command=lambda: do_redo())
    revert_btn = tk.Button(bar, text='Revert glyph', command=lambda: do_revert())
    undorevert_btn = tk.Button(bar, text='Undo Revert', command=lambda: do_undo_revert())
    for b in (undo_btn, redo_btn):
        b.pack(side='right')
    revert_btn.pack(side='right', padx=(8, 0))
    undorevert_btn.pack(side='right')
    save_btn.pack(side='right', padx=6)
    tk.Button(bar, text='+', command=lambda: zoom(+1)).pack(side='right')
    tk.Button(bar, text='-', command=lambda: zoom(-1)).pack(side='right')

    header = tk.Label(selbar, text='', font=('Consolas', 11, 'bold'), anchor='w')
    header.pack(side='left', padx=6)
    statechip = tk.Label(selbar, text='', font=('Consolas', 9, 'bold'),
                         fg='white', bg=STATE_BG[P.UNTOUCHED], padx=6)
    statechip.pack(side='left', padx=8)

    tk.Label(selbar, text='queue:').pack(side='left', padx=(12, 0))
    qvar = tk.StringVar(value=st['queue'])
    qmenu = tk.OptionMenu(selbar, qvar, *queues.ORDER,
                          command=lambda v: set_queue(v))
    qmenu.config(width=8, anchor='w')          # FIXED: label length can't reflow the row
    qmenu.pack(side='left')
    tk.Button(selbar, text='|<', width=3, command=lambda: step_queue(-1)).pack(side='left')
    tk.Button(selbar, text='>|', width=3, command=lambda: step_queue(+1)).pack(side='left')
    qlabel = tk.Label(selbar, text='', font=('Consolas', 9), width=44, anchor='w')
    qlabel.pack(side='left', padx=6)

    # The tile's classification, always visible and colour-coded. It carries the
    # tile-255 storage warning, which is the one case where a free slot is not
    # yet safe to spend (C6-A1 §2a).
    tilenote = tk.Label(root, text='', anchor='w', font=('Consolas', 9, 'bold'),
                        fg='white', bg=CLS_BG['referenced'], padx=8, pady=3,
                        justify='left', wraplength=1500)
    tilenote.pack(fill='x')

    body = tk.Frame(root)
    body.pack(fill='both', expand=True)

    # ---- LEFT: the glyph under edit, and the tile it lands in ----------------
    # The two canvases sit SIDE BY SIDE, not stacked. Stacked they came to about
    # 1,280 px of column against an 864 px screen, and Tk clamps the window to
    # the display rather than shrinking a fixed-size canvas — so the comparison
    # pair was simply off the bottom of the screen, invisible and silent.
    left = tk.Frame(body)
    left.pack(side='left', fill='y', padx=6, pady=4)
    lrow = tk.Frame(left)
    lrow.pack(anchor='w', fill='x')

    cola = tk.Frame(lrow)
    cola.pack(side='left', anchor='n')
    tk.Label(cola, text='GLYPH — paint here (yellow = changed)',
             fg='#ffe400', font=('Consolas', 10, 'bold')).pack(anchor='w')
    gcanvas = tk.Canvas(cola, width=8 * CELL_W * 8, height=8 * CELL_H * 8,
                        bg='#282828', highlightthickness=0)
    gcanvas.pack(anchor='w')

    colb = tk.Frame(lrow)
    colb.pack(side='left', anchor='n', padx=(14, 0))
    cmp_label = tk.Label(colb, text='', fg='#bbbbbb', font=('Consolas', 10, 'bold'),
                         anchor='w', justify='left')
    cmp_label.pack(anchor='w')
    ccanvas = tk.Canvas(colb, width=24 * CELL_W * CMP_ZOOM * 2 + 40,
                        height=24 * CELL_H * CMP_ZOOM,
                        bg='#282828', highlightthickness=0)
    ccanvas.pack(anchor='w')

    setlabel = tk.Label(left, text='', font=('Consolas', 9), anchor='w',
                        justify='left', wraplength=1040)
    setlabel.pack(anchor='w', pady=(6, 0))

    # ---- RIGHT: the sheet ----------------------------------------------------
    right = tk.Frame(body)
    right.pack(side='left', fill='both', expand=True, padx=6, pady=4)
    reflabel = tk.Label(right, text='', fg='#bbbbbb', font=('Consolas', 10, 'bold'),
                        anchor='w')
    reflabel.pack(anchor='w')
    sframe = tk.Frame(right)
    sframe.pack(fill='both', expand=True)
    vbar = tk.Scrollbar(sframe, orient='vertical')
    hbar = tk.Scrollbar(sframe, orient='horizontal')
    sheetc = tk.Canvas(sframe, bg='#282828', highlightthickness=0,
                       xscrollcommand=hbar.set, yscrollcommand=vbar.set)
    vbar.config(command=sheetc.yview)
    hbar.config(command=sheetc.xview)
    vbar.pack(side='right', fill='y')
    hbar.pack(side='bottom', fill='x')
    sheetc.pack(side='left', fill='both', expand=True)
    sheetc.bind('<MouseWheel>', lambda e: sheetc.yview_scroll(-e.delta // 120, 'units'))
    sheetc.bind('<Shift-MouseWheel>', lambda e: sheetc.xview_scroll(-e.delta // 120, 'units'))

    # ---- BOTTOM: strip (off by default), palette, save banner, status --------
    # The strip gets its own full-width row rather than a slot in the left
    # column, and is height-capped: it is the one panel that can be 122 tiles
    # long, and it must not be able to push anything else off a 864 px screen.
    striprow = tk.Frame(root)
    strip_label = tk.Label(striprow, text='', font=('Consolas', 9), anchor='w')
    strip_label.pack(anchor='w')
    scanvas = tk.Canvas(striprow, width=STRIP_W, height=0, bg='#282828',
                        highlightthickness=0)
    scanvas.pack(anchor='w')

    palbar = tk.Frame(root)
    savebar = tk.Label(root, text='ready — paint, then Save (Ctrl-S)', anchor='w',
                       font=('Consolas', 12, 'bold'), fg='white', bg=IDLE,
                       padx=10, pady=8, justify='left', wraplength=1240)
    status = tk.Label(root, text='', anchor='w', font=('Consolas', 9))
    # side='bottom' stacks FIRST-PACKED LOWEST, so this order reads upside down
    # on purpose: status ends up on the last line, strip just under the body.
    status.pack(side='bottom', fill='x')
    savebar.pack(side='bottom', fill='x')
    palbar.pack(side='bottom', fill='x')
    striprow.pack(side='bottom', fill='x')

    swatches = {}

    def arm(i):
        st['colour'] = i
        for n, fr in swatches.items():
            fr.config(bg=ARM if n == i else palbar.cget('bg'),
                      highlightbackground=ARM if n == i else palbar.cget('bg'))
        refresh_status()

    for i in range(16):
        r, g, b = (int(v) for v in pal_rgb[i])
        fr = tk.Frame(palbar, bg=palbar.cget('bg'), bd=0, padx=3, pady=4)
        fr.pack(side='left')
        fg = '#000000' if (r + g + b) > 330 else '#FFFFFF'
        tk.Button(fr, text='%X\n$%02X\n%s' % (i, pal_bytes[i], pal_names[i][:9]),
                  bg='#%02X%02X%02X' % (r, g, b), fg=fg,
                  activebackground='#%02X%02X%02X' % (r, g, b),
                  font=('Consolas', 8), width=9, height=3,
                  command=lambda n=i: arm(n)).pack()
        swatches[i] = fr

    # ------------------------------------------------------------- rendering --
    def sheet_photo():
        key = (st['view'], st['sheet_zoom'])
        if st['sheet_cache'][0] != key:
            img = R.sheet_image(ref.image(st['view']), st['sheet_zoom'])
            st['sheet_cache'] = (key, ImageTk.PhotoImage(img))
        return st['sheet_cache'][1]

    def redraw_sheet():
        z = st['sheet_zoom']
        p = sheet_photo()
        sheetc.delete('all')
        st['imgs']['sheet'] = p
        sheetc.create_image(0, 0, anchor='nw', image=p)
        sheetc.config(scrollregion=(0, 0, S.GRID * z, S.GRID * z))

        # C6-A1 classification. NOTHING here means "skip this".
        #   available  a green corner tick — an EMPTY, EDITABLE slot for new
        #              content. Jay: "it would provide a tile that I could use to
        #              create something new if needed." Deliberately an inviting
        #              mark, not the greyed-out cross an earlier build drew.
        #   unverified a small amber dot — real artwork reached by a computed
        #              offset. Drawn and edited exactly like any other tile.
        for t in mapping.available:
            x, y, w, h = S.tile_rect(t)
            sheetc.create_line(x * z, (y + 6) * z, x * z, y * z,
                               fill=AVAIL_MARK, width=2, tags='cls')
            sheetc.create_line(x * z, y * z, (x + 6) * z, y * z,
                               fill=AVAIL_MARK, width=2, tags='cls')
        for t in mapping.unverified:
            x, y, w, h = S.tile_rect(t)
            r = max(1, z)
            sheetc.create_oval((x + w - 4) * z - r, (y + h - 4) * z - r,
                               (x + w - 4) * z + r, (y + h - 4) * z + r,
                               fill=UNVERIFIED_MARK, outline='', tags='cls')

        # affected tiles — OUTLINES ON THE SHEET, not a strip (C6 §3)
        g = glyph()
        if g is not None:
            for t in sorted(mapping.tiles_of.get(g, ())):
                x, y, w, h = S.tile_rect(t)
                sheetc.create_rectangle(x * z, y * z, (x + w) * z - 1, (y + h) * z - 1,
                                        outline=AFFECTED, width=1, tags='aff')

        # the selection: tile box, then the cell box inside it
        x, y, w, h = S.tile_rect(st['tile'])
        sheetc.create_rectangle(x * z - 1, y * z - 1, (x + w) * z, (y + h) * z,
                                outline=SELECTED, width=2, tags='sel')
        cy, cx = divmod(st['cell'], 3)
        sheetc.create_rectangle((x + cx * 8) * z, (y + cy * 8) * z,
                                (x + cx * 8 + 8) * z - 1, (y + cy * 8 + 8) * z - 1,
                                outline='#ffffff', width=1, tags='sel')

    def redraw_glyph():
        g = glyph()
        z = st['zoom']
        gcanvas.config(width=8 * CELL_W * z, height=8 * CELL_H * z)
        if g is None:
            gcanvas.delete('all')
            gcanvas.create_text(8, 8, anchor='nw', fill='#ff66ff',
                                font=('Consolas', 11, 'bold'),
                                text='no data\n\ntile 255 bottom-right:\ntileset.bin is one byte\n'
                                     'short, so this cell has\nno glyph. Not $00.')
            return
        img = R.glyph_image(fe.font[g], pal_rgb, z, changed=fe[g].changed())
        st['imgs']['glyph'] = ImageTk.PhotoImage(img)
        gcanvas.delete('all')
        gcanvas.create_image(0, 0, anchor='nw', image=st['imgs']['glyph'])

    def redraw_compare():
        z = CMP_ZOOM
        g = glyph()
        gs = mapping.tile_glyph_set(st['tile'])
        sib = gs.get(g, []) if g is not None else []
        comp = R.tile_image(fe.font, mapping, st['tile'], pal_rgb, z,
                            cell=st['cell'], cells=sib)
        refimg = R.ref_tile_image(ref.tile(st['view'], st['tile']), z,
                                  cell=st['cell'], cells=sib)
        st['imgs']['comp'] = ImageTk.PhotoImage(comp)
        st['imgs']['ref'] = ImageTk.PhotoImage(refimg)
        ccanvas.config(width=comp.width + refimg.width + 40, height=comp.height)
        ccanvas.delete('all')
        ccanvas.create_image(0, 0, anchor='nw', image=st['imgs']['comp'])
        ccanvas.create_image(comp.width + 40, 0, anchor='nw', image=st['imgs']['ref'])
        cmp_label.config(text='COMPOSED tile $%02X (current font)      |      %s'
                              % (st['tile'], S.Reference.LABELS[st['view']]))

        # the tile's glyph SET, not nine independent things (C6 §3)
        parts = []
        for gg, cells in gs.items():
            tag = '$%02X[%s]' % (gg, ','.join(PLANES[c] for c in cells))
            parts.append('>' + tag + '<' if gg == g else tag)
        miss = [PLANES[k] for k in range(9) if mapping.glyphs[st['tile']][k] is None]
        txt = 'tile $%02X glyph set: %s' % (st['tile'], '  '.join(parts) or '(none)')
        if miss:
            txt += '    no data: ' + ','.join(miss)
        if len(sib) > 1:
            txt += '\nthis glyph fills %d cells of THIS tile — one edit moves all of them.' % len(sib)
        setlabel.config(text=txt)

    def redraw_strip():
        g = glyph()
        if not st['strip'] or g is None:
            scanvas.config(height=0)
            scanvas.delete('all')
            strip_label.config(text='')
            return
        img, shown, dropped = R.affected_strip(fe.font, mapping, g, pal_rgb,
                                               zoom=STRIP_ZOOM,
                                               per_row=STRIP_PER_ROW)
        if img is None:
            scanvas.config(height=0)
            strip_label.config(text='')
            return
        st['imgs']['strip'] = ImageTk.PhotoImage(img)
        scanvas.config(width=img.width, height=min(img.height, STRIP_H_CAP))
        scanvas.delete('all')
        scanvas.create_image(0, 0, anchor='nw', image=st['imgs']['strip'])
        strip_label.config(
            text='affected tiles composed: %d shown%s   [a] to hide'
                 % (shown, ', %d NOT shown (cap)' % dropped if dropped else ''))

    def refresh_status():
        g = glyph()
        d, e, used = prog.summary(fe, mapping)
        status.config(
            text='glyph zoom %dx (cell %dx%dpx, 5:6)  sheet %dx   armed $%X %s   '
                 'edited-now %d   progress %d done / %d edited of %d used   %s'
                 % (st['zoom'], CELL_W * st['zoom'], CELL_H * st['zoom'],
                    st['sheet_zoom'], st['colour'], pal_names[st['colour']],
                    len(fe.edited()), d, e, used, cfg.note))
        header.config(text=mapping.header(g))
        if g is None:
            statechip.config(text='NO DATA', bg='#800080')
        else:
            s = prog.state(g, fe)
            statechip.config(text=s.upper(), bg=STATE_BG[s])
        c = mapping.cls['counts']
        reflabel.config(text='SHEET — click a tile (sub-cell) to load.  %s   '
                             'cyan = tiles using this glyph   '
                             'green tick = available/free (%d)   '
                             'amber dot = no static reference (%d)   '
                             'referenced (%d)'
                             % (S.Reference.LABELS[st['view']], c['available'],
                                c['unverified'], c['referenced']))
        tilenote.config(text='tile $%02X  %s' % (st['tile'], mapping.tile_note(st['tile'])),
                        bg=CLS_BG[mapping.kind[st['tile']]])
        ql = qs[st['queue']]
        qlabel.config(text='%s: %d/%d  (%s)'
                           % (st['queue'], st['qi'] + 1 if ql else 0, len(ql),
                              queues.DESC[st['queue']]))
        refresh_buttons()

    def check_fits():
        """Say so when the layout does not fit the display.

        Tk clamps a window to the screen instead of shrinking a fixed-size
        canvas, so an over-tall layout does not look broken — the bottom panels
        are simply not there, and a screenshot of the result looks plausible.
        That is exactly how the stacked left column shipped past a first review,
        so the condition now reports itself in the save banner."""
        root.update_idletasks()
        rw, rh = root.winfo_reqwidth(), root.winfo_reqheight()
        sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
        if rw > sw or rh > sh - 40:
            savebar.config(
                text='LAYOUT: the window wants %dx%d on a %dx%d screen — the '
                     'bottom of the panel is clipped. Lower the glyph zoom (-) '
                     'or hide the strip (a).' % (rw, rh, sw, sh),
                fg='white', bg=STOP)
            return False
        return True

    def redraw(sheet_too=True):
        redraw_glyph()
        redraw_compare()
        redraw_strip()
        if sheet_too:
            redraw_sheet()
        refresh_status()
        check_fits()

    def refresh_buttons():
        g = glyph()
        ge = fe[g] if g is not None else None
        save_btn.config(state='normal' if fe.is_dirty() else 'disabled')
        undo_btn.config(state='normal' if ge is not None and ge.can_undo() else 'disabled')
        redo_btn.config(state='normal' if ge is not None and ge.can_redo() else 'disabled')
        revert_btn.config(state='normal' if ge is not None and ge.is_dirty() else 'disabled')
        undorevert_btn.config(state='normal' if ge is not None and ge.can_undo_revert()
                              else 'disabled')

    # ------------------------------------------------------------- selection --
    def select(tile, cell, sync_queue=True):
        st['tile'] = max(0, min(255, tile))
        st['cell'] = max(0, min(8, cell))
        if sync_queue:
            ql = qs[st['queue']]
            if st['tile'] in ql:
                st['qi'] = ql.index(st['tile'])
        redraw()

    def sheet_click(e):
        z = st['sheet_zoom']
        x = int(sheetc.canvasx(e.x)) // z          # canvasx returns a FLOAT; int() it or the
        y = int(sheetc.canvasy(e.y)) // z          # sub-cell division goes fractional
        t, k = S.cell_of_point(x, y)
        if t is None:
            return
        select(t, k)

    def sheet_motion(e):
        z = st['sheet_zoom']
        x = int(sheetc.canvasx(e.x)) // z
        y = int(sheetc.canvasy(e.y)) // z
        t, k = S.cell_of_point(x, y)
        if t is None:
            coord.config(text='(%d,%d) off the grid' % (x, y))
            return
        g = mapping.glyphs[t][k]
        coord.config(text='sheet (%3d,%3d)  tile $%02X %s  glyph %s%s'
                          % (x, y, t, PLANES[k],
                             'none' if g is None else '$%02X' % g,
                             '  ' + mapping.kind[t]))

    # ---------------------------------------------------------------- paint --
    def canvas_to_glyph(e):
        return screen_to_glyph(int(gcanvas.canvasx(e.x)), int(gcanvas.canvasy(e.y)),
                               st['zoom'])

    def on_press(e):
        g = glyph()
        if g is None:
            return
        fe[g].begin_stroke()
        st['painting'] = True
        on_drag(e)

    def _coalesced():
        if not st.get('pending'):
            st['pending'] = True

            def go():
                st['pending'] = False
                redraw_glyph()
                redraw_compare()
                refresh_status()
            root.after_idle(go)

    def on_drag(e):
        if not st['painting']:
            return
        g = glyph()
        x, y = canvas_to_glyph(e)
        if g is not None and fe[g].paint(x, y, st['colour']):
            fe.note_edit(g)
            prog.note_edit(g)
            _coalesced()

    def on_release(_e):
        if not st['painting']:
            return
        st['painting'] = False
        redraw(sheet_too=False)
        schedule_autosave()

    def on_glyph_motion(e):
        g = glyph()
        x, y = canvas_to_glyph(e)
        if g is None or not (0 <= x < 8 and 0 <= y < 8):
            return
        v = int(fe.font[g][y, x])
        coord.config(text='glyph $%02X (%d,%d) = $%X %s   %s nibble'
                          % (g, x, y, v, pal_names[v], 'high/LEFT' if x % 2 == 0 else 'low'))

    def eyedrop(e):
        g = glyph()
        x, y = canvas_to_glyph(e)
        if g is not None and 0 <= x < 8 and 0 <= y < 8:
            arm(int(fe.font[g][y, x]))

    # ----------------------------------------------------------- operations --
    def do_undo(_=None):
        g = glyph()
        if g is not None and fe[g].undo_stroke():
            redraw(sheet_too=False)

    def do_redo(_=None):
        g = glyph()
        if g is not None and fe[g].redo_stroke():
            redraw(sheet_too=False)

    def do_revert(_=None):
        g = glyph()
        if g is not None and fe[g].revert():
            redraw(sheet_too=False)

    def do_undo_revert(_=None):
        g = glyph()
        if g is not None and fe[g].undo_revert():
            redraw(sheet_too=False)

    def zoom(delta):
        st['zoom'] = max(2, min(20, st['zoom'] + delta))
        redraw(sheet_too=False)

    def sheet_zoom(delta):
        st['sheet_zoom'] = max(1, min(5, st['sheet_zoom'] + delta))
        st['sheet_cache'] = (None, None)
        redraw()

    def cycle_ref(_=None):
        v = S.Reference.VIEWS
        st['view'] = v[(v.index(st['view']) + 1) % len(v)]
        st['sheet_cache'] = (None, None)
        redraw()

    def toggle_strip(_=None):
        st['strip'] = not st['strip']
        redraw(sheet_too=False)

    def toggle_done(_=None):
        g = glyph()
        if g is None:
            return
        now = prog.toggle_done(g)
        savebar.config(text='glyph $%02X marked %s (saved with the next Ctrl-S)'
                            % (g, 'DONE' if now else 'not done'), fg='white', bg=INFO)
        refresh_status()

    def set_queue(name):
        st['queue'] = name
        st['qi'] = 0
        if qs[name]:
            select(qs[name][0], 0, sync_queue=False)
        else:
            refresh_status()

    def step_queue(delta):
        ql = qs[st['queue']]
        if not ql:
            return
        st['qi'] = max(0, min(len(ql) - 1, st['qi'] + delta))
        select(ql[st['qi']], 0, sync_queue=False)

    def move_cell(dx, dy):
        cy, cx = divmod(st['cell'], 3)
        select(st['tile'], max(0, min(2, cy + dy)) * 3 + max(0, min(2, cx + dx)))

    def move_tile(dx, dy):
        ty, tx = divmod(st['tile'], 16)
        select(max(0, min(15, ty + dy)) * 16 + max(0, min(15, tx + dx)), st['cell'])

    def do_save(_=None):
        if not fe.is_dirty() and not prog.done:
            savebar.config(text='nothing edited — nothing to save', fg='white', bg=INFO)
            return
        try:
            r = P.save(cfg, fe, prog, src, source_sha)
        except OSError as ex:
            savebar.config(text='SAVE FAILED — %s (nothing was overwritten)' % ex,
                           fg='white', bg=STOP)
            return
        fe.mark_all_saved()
        c = r['counts']
        savebar.config(
            text='Saved %s  sha256 %s%s  |  version %s  |  %d untouched / %d edited / %d done'
                 % (os.path.relpath(r['font'], C.REPO).replace('\\', '/'),
                    r['sha256'][:16],
                    '  (BYTE-IDENTICAL to the source font)' if r['identical_to_source'] else '',
                    os.path.basename(r['version']),
                    c['untouched'], c['edited'], c['done']),
            fg='white', bg=OK)
        refresh_status()

    def schedule_autosave():
        if st.get('autosave_id'):
            root.after_cancel(st['autosave_id'])
        st['autosave_id'] = root.after(4000, run_autosave)

    def run_autosave():
        st['autosave_id'] = None
        if not fe.is_dirty():
            return
        try:
            P.autosave(cfg, fe)
        except OSError:
            pass                       # an autosave failure must never interrupt drawing

    # ------------------------------------------------------------- bindings --
    sheetc.bind('<ButtonPress-1>', sheet_click)
    sheetc.bind('<B1-Motion>', sheet_click)
    sheetc.bind('<Motion>', sheet_motion)
    gcanvas.bind('<ButtonPress-1>', on_press)
    gcanvas.bind('<B1-Motion>', on_drag)
    gcanvas.bind('<ButtonRelease-1>', on_release)
    gcanvas.bind('<Motion>', on_glyph_motion)
    gcanvas.bind('<ButtonPress-3>', eyedrop)

    root.bind('<Control-z>', do_undo)
    root.bind('<Control-y>', do_redo)
    root.bind('<Control-s>', do_save)
    root.bind('+', lambda _e: zoom(+1))
    root.bind('-', lambda _e: zoom(-1))
    root.bind('[', lambda _e: sheet_zoom(-1))
    root.bind(']', lambda _e: sheet_zoom(+1))
    root.bind(',', lambda _e: arm((st['colour'] - 1) % 16))
    root.bind('.', lambda _e: arm((st['colour'] + 1) % 16))
    root.bind('r', cycle_ref)
    root.bind('a', toggle_strip)
    root.bind('d', toggle_done)
    root.bind('n', lambda _e: step_queue(+1))
    root.bind('p', lambda _e: step_queue(-1))
    root.bind('<Left>', lambda _e: move_cell(-1, 0))
    root.bind('<Right>', lambda _e: move_cell(+1, 0))
    root.bind('<Up>', lambda _e: move_cell(0, -1))
    root.bind('<Down>', lambda _e: move_cell(0, +1))
    root.bind('<Shift-Left>', lambda _e: move_tile(-1, 0))
    root.bind('<Shift-Right>', lambda _e: move_tile(+1, 0))
    root.bind('<Shift-Up>', lambda _e: move_tile(0, -1))
    root.bind('<Shift-Down>', lambda _e: move_tile(0, +1))

    def on_close():
        if fe.is_dirty():
            try:
                P.autosave(cfg, fe)
            except OSError:
                pass
        root.destroy()

    root.protocol('WM_DELETE_WINDOW', on_close)

    arm(st['colour'])
    if args.view:
        st['view'] = args.view
    if args.strip:
        st['strip'] = True
    if args.sheet_zoom:
        st['sheet_zoom'] = args.sheet_zoom
    if args.tile is not None:
        select(args.tile, args.cell)
    else:
        set_queue(st['queue'])
    savebar.config(text='loaded %s (%d glyphs, %d used by tiles) — sha256 %s'
                        % (os.path.relpath(src, C.REPO).replace('\\', '/'),
                           cfg.n_glyphs, len(mapping.used_glyphs()), source_sha[:16]),
                   fg='white', bg=IDLE)

    if args.screenshot:
        # Evidence mode: realise the window, let Windows actually PAINT it, grab
        # it, exit. Nothing is written except the PNG — a screenshot run must not
        # be able to touch the authored font.
        #
        # The grab has to happen from inside a running mainloop. update() alone
        # returns before the compositor has drawn anything, so ImageGrab (which
        # screen-scrapes) captured the desktop behind the window instead: two
        # different UI states produced BYTE-IDENTICAL PNGs, which is how the
        # fault was caught. A short after() delay inside mainloop fixes it, and
        # -topmost stops another window overlapping the grab rectangle.
        from PIL import ImageGrab
        root.attributes('-topmost', True)
        root.deiconify()
        root.lift()
        root.focus_force()

        def grab():
            root.update_idletasks()
            x, y = root.winfo_rootx(), root.winfo_rooty()
            box = (x, y, x + root.winfo_width(), y + root.winfo_height())
            os.makedirs(os.path.dirname(args.screenshot) or '.', exist_ok=True)
            ImageGrab.grab(box).save(args.screenshot)
            print('screenshot -> %s  (%dx%d)'
                  % (args.screenshot, box[2] - box[0], box[3] - box[1]))
            root.destroy()

        root.after(900, grab)
        root.mainloop()
        return

    root.mainloop()


if __name__ == '__main__':
    main()
