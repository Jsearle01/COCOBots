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

NO CAPABILITY IS KEYBOARD-ONLY (C6-A2). Jay has no scroll wheel, and two-finger
gestures on his machine produce scroll/pan, never zoom — so a control reachable
only by wheel, gesture, or an unlabelled key does not exist for him. Both zooms,
the reference view, the strip, done-marking and queue stepping all have visible
on-screen buttons. Keys still work and are printed beside their buttons, but they
are never the only route to anything.

KEYS (all also available as on-screen controls)
  click sheet     load the tile+cell under the cursor (sub-cell)
  click tile      select that cell of the CURRENT tile - either the composed
                  24x24 or the reference beside it
  paint / drag    set the armed palette index
  right-click     eyedropper - arm the index under the cursor
  Ctrl-Z / Ctrl-Y undo / redo          Ctrl-S  save
  + / -           glyph zoom           [ / ]   sheet zoom (anchors on the
                                               SELECTED TILE, keeping it centred)
  Tab / Shift-Tab step the tile's nine cells TL->BR
  , / .           previous / next palette index
  r               reference, four states: raw Amiga -> CoCo per-pixel (the
                  ceiling) -> CoCo engine (reachable, live) -> C64 oracle
  a / Shift-A     accept the QUANTISED art for this cell / this tile's ticked
                  cells, as an authored edit (C6-A3)
  s               affected-tile strip (OFF by default - Jay: a strip
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

import accept as A                    # noqa: E402
import decor as D                     # noqa: E402
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
STATE_BG = {P.UNTOUCHED: '#555555', P.EDITED: '#8a6d00',
            P.ACCEPTED: '#00647a', P.DONE: '#1b7f1b'}

# Sheet decorations come from decor.py, which measures every one against the
# adopted palette (C6-A5). UNVERIFIED_MARK used to be #FFAA00 — exactly palette
# $34 — so it vanished on every light-orange tile.
AVAIL_MARK = D.AVAILABLE_MARK
UNVERIFIED_MARK = D.UNVERIFIED_MARK
AFFECTED = D.SIBLING_OUTLINE          # magenta: the one hue the palette has not got
MARK_LIGHT, MARK_DARK = D.MARK_LIGHT, D.MARK_DARK

CLS_BG = {'available': '#0b6b3a', 'referenced': '#3a3a3a',
          'no-static-reference': '#8a5a00'}

# Fixed geometry, sized against a 1536x864 display. The two zooms the dispatch
# asks for (glyph, sheet) are live; the comparison pair is fixed at 3x because a
# third zoom control buys nothing and 3x is what makes 24x24 at 5:6 (360x432)
# sit beside the glyph canvas without either one clipping.
CMP_ZOOM = 3
CMP_GAP = 40                 # gutter between the composed tile and the reference
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
    ap.add_argument('--queue', default=None, choices=queues.ORDER)
    ap.add_argument('--include', default=None,
                    help='cells to tick for accept, e.g. 0,1,2 (evidence only)')
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
    # C6-A2 AC8: the reference view persists across tile selection AND across
    # sessions, alongside the other progress state. Zooms ride along for the same
    # reason — they are viewing preferences, not per-tile facts.
    st.update({k: v for k, v in prog.ui.items() if k in st})

    def glyph():
        return mapping.glyphs[st['tile']][st['cell']]

    # ---------------------------------------------------------------- chrome --
    bar = tk.Frame(root)
    bar.pack(fill='x')
    selbar = tk.Frame(root)
    selbar.pack(fill='x')

    # FIXED width monospace so a changing readout never resizes the label and
    # shoves the button cluster off the right edge (POP's sprite tool bug).
    coord = tk.Label(bar, text='move over a pixel...   right-click = eyedropper',
                     font=('Consolas', 10), width=52, anchor='w')
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
    # (glyph and sheet zoom live in labelled clusters on their own panels — two
    # bare +/- buttons up here next to SAVE said nothing about WHAT they zoomed,
    # which is half of why the sheet zoom was never found.)

    # FIXED width, same reason as `coord`: this label's text grows with the
    # glyph's tile count and its warnings, and a variable-width label in a packed
    # row pushes whatever is to its right off the edge. C6 carried this
    # convention over from POP's sprite tool and then applied it to only one of
    # the two readouts — which is how two new buttons clipped the row.
    header = tk.Label(selbar, text='', font=('Consolas', 11, 'bold'),
                      width=58, anchor='w')
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
    # AC8b sweep: these two were reachable only by an unlabelled key, which is
    # exactly the failure that hid the sheet zoom and the quantised reference.
    done_btn = tk.Button(selbar, text='mark done (d)', font=('Consolas', 9),
                         command=lambda: toggle_done())
    done_btn.pack(side='left', padx=(10, 0))
    strip_btn = tk.Button(selbar, text='affected strip (s)', font=('Consolas', 9),
                          command=lambda: toggle_strip())
    strip_btn.pack(side='left', padx=(4, 0))
    qlabel = tk.Label(selbar, text='', font=('Consolas', 9), width=30, anchor='w')
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
    gctl = tk.Frame(cola)
    gctl.pack(anchor='w', pady=(0, 2))
    tk.Label(gctl, text='zoom', font=('Consolas', 9)).pack(side='left')
    tk.Button(gctl, text='−', width=2, font=('Consolas', 10, 'bold'),
              command=lambda: zoom(-1)).pack(side='left', padx=(4, 0))
    glyph_zoom_lbl = tk.Label(gctl, text='', font=('Consolas', 10, 'bold'),
                              width=6, relief='sunken', anchor='center')
    glyph_zoom_lbl.pack(side='left', padx=2)
    tk.Button(gctl, text='+', width=2, font=('Consolas', 10, 'bold'),
              command=lambda: zoom(+1)).pack(side='left')
    tk.Button(gctl, text='fit', width=4,
              command=lambda: glyph_zoom_fit()).pack(side='left', padx=(4, 0))
    tk.Label(gctl, text='+ -', font=('Consolas', 8), fg='#888').pack(side='left', padx=2)
    gcanvas = tk.Canvas(cola, width=8 * CELL_W * 8, height=8 * CELL_H * 8,
                        bg='#282828', highlightthickness=0)
    gcanvas.pack(anchor='w')

    colb = tk.Frame(lrow)
    colb.pack(side='left', anchor='n', padx=(14, 0))
    cmp_label = tk.Label(colb, text='', fg='#bbbbbb', font=('Consolas', 9, 'bold'),
                         anchor='w', justify='left', wraplength=760)
    cmp_label.pack(anchor='w')
    ccanvas = tk.Canvas(colb, width=24 * CELL_W * CMP_ZOOM * 2 + CMP_GAP,
                        height=24 * CELL_H * CMP_ZOOM,
                        bg='#282828', highlightthickness=0)
    ccanvas.pack(anchor='w')

    # ---- C6-A3: accept the quantised reference as an authored edit ----------
    # ONE full-width row above the strip, not a stack inside the left column.
    # Stacked (buttons / checkboxes / multi-line cost) it added 142 px and took
    # the window to 861 px against an 824 px budget — AC10 said verify rather
    # than assume there was room, and there was not. Side by side it costs ~40.
    acceptrow = tk.Frame(root)
    tk.Label(acceptrow, text='accept from QUANTISED art:',
             font=('Consolas', 9, 'bold'), fg='#00b8d4').pack(side='left', padx=(6, 4))
    accept_cell_btn = tk.Button(acceptrow, text='accept cell (a)', font=('Consolas', 9),
                                command=lambda: do_accept_cell())
    accept_cell_btn.pack(side='left', padx=2)
    accept_tile_btn = tk.Button(acceptrow, text='accept tile (9)  (Shift-A)',
                                font=('Consolas', 9), command=lambda: do_accept_tile())
    accept_tile_btn.pack(side='left', padx=2)

    # Per-cell opt-out: accept six, hand-draw three. The dispatch is explicit
    # that this must not be all-or-nothing.
    tk.Label(acceptrow, text=' include:', font=('Consolas', 8)).pack(side='left')
    cell_vars = []
    for k in range(9):
        v = tk.IntVar(value=1)
        tk.Checkbutton(acceptrow, text=PLANES[k], variable=v, font=('Consolas', 8),
                       padx=0, pady=0, command=lambda: refresh_cost()).pack(side='left')
        cell_vars.append(v)
    tk.Button(acceptrow, text='all', font=('Consolas', 8),
              command=lambda: (set_all_cells(1), refresh_cost())).pack(side='left', padx=(4, 0))
    tk.Button(acceptrow, text='none', font=('Consolas', 8),
              command=lambda: (set_all_cells(0), refresh_cost())).pack(side='left')

    # the cost, stated BEFORE the write — the numbers, not a reflex confirm box
    costlabel = tk.Label(acceptrow, text='', font=('Consolas', 8), anchor='w',
                         justify='left', fg='#ffcc66', wraplength=620)
    costlabel.pack(side='left', padx=(10, 0))

    setlabel = tk.Label(left, text='', font=('Consolas', 9), anchor='w',
                        justify='left', wraplength=1040)
    setlabel.pack(anchor='w', pady=(6, 0))

    # ---- RIGHT: the sheet ----------------------------------------------------
    right = tk.Frame(body)
    right.pack(side='left', fill='both', expand=True, padx=6, pady=4)
    reflabel = tk.Label(right, text='', fg='#bbbbbb', font=('Consolas', 9, 'bold'),
                        anchor='w', justify='left', wraplength=420)
    reflabel.pack(anchor='w')

    # ---- sheet controls. EVERY capability here has a visible, clickable
    # affordance. C6-A2: Jay has no scroll wheel and two-finger gestures produce
    # scroll, never zoom — so a control reachable only by wheel or by an
    # unlabelled key does not exist for this user. Keys still work; they are
    # never the only route, and each button carries its key in a tooltip-style
    # suffix so the shortcut is discoverable from the UI itself.
    sctl = tk.Frame(right)
    sctl.pack(anchor='w', fill='x', pady=(2, 2))
    tk.Label(sctl, text='sheet zoom', font=('Consolas', 9)).pack(side='left')
    tk.Button(sctl, text='−', width=2, font=('Consolas', 10, 'bold'),
              command=lambda: sheet_zoom(-1)).pack(side='left', padx=(4, 0))
    sheet_zoom_lbl = tk.Label(sctl, text='', font=('Consolas', 10, 'bold'),
                              width=6, relief='sunken', anchor='center')
    sheet_zoom_lbl.pack(side='left', padx=2)
    tk.Button(sctl, text='+', width=2, font=('Consolas', 10, 'bold'),
              command=lambda: sheet_zoom(+1)).pack(side='left')
    tk.Button(sctl, text='fit', width=4,
              command=lambda: sheet_zoom_fit()).pack(side='left', padx=(4, 0))
    tk.Label(sctl, text='[ ]', font=('Consolas', 8), fg='#888').pack(side='left', padx=(2, 12))

    # Reference-view selector: three labelled buttons, current one highlighted.
    # Jay could not find this at all when it was the unlabelled key `r` — the
    # quantised view is the CEILING and is the one that matters most while
    # drawing, so it cannot be hidden behind a keystroke.
    #
    # OWN ROW, and short labels. The left column takes ~1,100 px of a 1,540 px
    # window, so the sheet column has roughly 430 px to play with — one row
    # carrying both clusters needed ~725 and put these buttons off the right
    # edge, which would have reproduced the exact defect this dispatch fixes.
    # The full name of the current view is spelled out in `reflabel` below.
    rctl = tk.Frame(right)
    rctl.pack(anchor='w', fill='x', pady=(0, 2))
    tk.Label(rctl, text='reference:', font=('Consolas', 9)).pack(side='left')
    ref_btns = {}
    REF_LABEL = {'amiga_raw': 'raw', 'amiga_quant': 'CoCo px',
                 'coco_engine': 'CoCo engine', 'oracle': 'C64'}
    for v in S.Reference.VIEWS:
        b = tk.Button(rctl, text=REF_LABEL[v], font=('Consolas', 9),
                      command=lambda vv=v: set_ref(vv))
        b.pack(side='left', padx=2)
        ref_btns[v] = b
    tk.Label(rctl, text='(r)', font=('Consolas', 8), fg='#888').pack(side='left', padx=(2, 0))

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
    acceptrow.pack(side='bottom', fill='x')

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
        if st['view'] == 'coco_engine' and ref.refresh_engine(fe.font, mapping):
            st['sheet_cache'] = (None, None)     # live render moved; drop the cache
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

        # THE SELECTED TILE, distinguished from its siblings WITHOUT a hue
        # (C6-A5 §3). With a median of 88 tiles outlined magenta, the one you are
        # on has to stand out — and every neutral is close to one of the
        # palette's four greys, so the separation is structural: a dark line
        # immediately outside a light one. No single flat colour can hide both.
        x, y, w, h = S.tile_rect(st['tile'])
        sheetc.create_rectangle(x * z - 2, y * z - 2, (x + w) * z + 1, (y + h) * z + 1,
                                outline=MARK_DARK, width=2, tags='sel')
        sheetc.create_rectangle(x * z, y * z, (x + w) * z - 1, (y + h) * z - 1,
                                outline=MARK_LIGHT, width=2, tags='sel')
        cy, cx = divmod(st['cell'], 3)
        sheetc.create_rectangle((x + cx * 8) * z - 1, (y + cy * 8) * z - 1,
                                (x + cx * 8 + 8) * z, (y + cy * 8 + 8) * z,
                                outline=MARK_DARK, width=1, tags='sel')
        sheetc.create_rectangle((x + cx * 8) * z, (y + cy * 8) * z,
                                (x + cx * 8 + 8) * z - 1, (y + cy * 8 + 8) * z - 1,
                                outline=MARK_LIGHT, width=1, tags='sel')

    def redraw_glyph():
        g = glyph()
        z = st['zoom']
        gcanvas.config(width=8 * CELL_W * z, height=8 * CELL_H * z)
        if g is None:
            gcanvas.delete('all')
            gcanvas.create_text(8, 8, anchor='nw', fill=D.NODATA_FILL,
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
        ccanvas.config(width=comp.width + refimg.width + CMP_GAP, height=comp.height)
        ccanvas.delete('all')
        ccanvas.create_image(0, 0, anchor='nw', image=st['imgs']['comp'])
        ccanvas.create_image(comp.width + CMP_GAP, 0, anchor='nw', image=st['imgs']['ref'])
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
                             'MAGENTA = tiles using this glyph   '
                             'green tick = available/free (%d)   '
                             'cyan dot = no static reference (%d)   '
                             'referenced (%d)'
                             % (S.Reference.LABELS[st['view']], c['available'],
                                c['unverified'], c['referenced']))
        tilenote.config(text='tile $%02X  %s' % (st['tile'], mapping.tile_note(st['tile'])),
                        bg=CLS_BG[mapping.kind[st['tile']]])
        ql = qs[st['queue']]
        qlabel.config(text='%s: %d/%d  (%s)'
                           % (st['queue'], st['qi'] + 1 if ql else 0, len(ql),
                              queues.DESC[st['queue']]))
        strip_btn.config(relief='sunken' if st['strip'] else 'raised',
                         bg=ARM if st['strip'] else selbar.cget('bg'))
        glyph_zoom_lbl.config(text='%dx' % st['zoom'])
        sheet_zoom_lbl.config(text='%dx' % st['sheet_zoom'])
        for v, b in ref_btns.items():                 # highlight the active view
            b.config(relief='sunken' if v == st['view'] else 'raised',
                     bg=ARM if v == st['view'] else sctl.cget('bg'),
                     fg='black' if v == st['view'] else 'black')
        refresh_buttons()

    def check_fits():
        """Say so when something is ACTUALLY clipped.

        Tk clamps a window to the screen instead of shrinking a fixed-size
        canvas, so an over-tall layout does not look broken — the bottom panels
        are simply not there, and a screenshot of the result looks plausible.
        That is what the C6 version was written to catch.

        **The C6 version tested the wrong thing and had been failing since it
        was written** (C6-A2). It compared the window's REQUESTED width against
        the screen, and this layout legitimately requests ~2,370 px: several
        labels carry a `wraplength` and the sheet canvas is happy to expand. Tk
        satisfies all of them by shrinking the expandable widgets, and nothing is
        harmed. So the guard cried wolf on every redraw, and the one place it
        writes — the save banner — is overwritten by the load message at startup,
        which is why nobody saw it. A guard that always fires is a guard nobody
        reads.

        What actually matters is narrower and checkable directly:
          - HEIGHT: the panels stack and cannot shrink, so an over-tall window
            really does lose its bottom rows.
          - WIDTH: only for rows of fixed-size controls. If a control row was
            allocated less than it asked for, its right-hand buttons are off the
            edge and unreachable — which is precisely the C6-A2 defect class.
        """
        root.update_idletasks()
        bad = []
        for name, w in (('sheet controls', sctl), ('reference row', rctl),
                        ('glyph controls', gctl), ('toolbar', bar),
                        ('selector row', selbar), ('accept row', acceptrow)):
            have, want = w.winfo_width(), w.winfo_reqwidth()
            if have > 1 and want > have:
                bad.append('%s clipped (needs %dpx, has %d)' % (name, want, have))
        rh, sh = root.winfo_reqheight(), root.winfo_screenheight()
        if rh > sh - 40:
            bad.append('window wants %dpx of height on a %dpx screen' % (rh, sh))
        if bad:
            savebar.config(text='LAYOUT: ' + '; '.join(bad), fg='white', bg=STOP)
            return False
        return True

    def redraw(sheet_too=True):
        redraw_glyph()
        redraw_compare()
        redraw_strip()
        if sheet_too or st['view'] == 'coco_engine':
            redraw_sheet()
        refresh_cost()
        refresh_status()
        check_fits()

    def refresh_buttons():
        g = glyph()
        ge = fe[g] if g is not None else None
        save_btn.config(state='normal' if fe.is_dirty() else 'disabled')
        undo_btn.config(state='normal' if fe.can_undo() else 'disabled')
        redo_btn.config(state='normal' if fe.can_redo() else 'disabled')
        revert_btn.config(state='normal' if ge is not None and ge.is_dirty() else 'disabled')
        undorevert_btn.config(state='normal' if ge is not None and ge.can_undo_revert()
                              else 'disabled')

    # ------------------------------------------------------------- selection --
    def select(tile, cell, sync_queue=True):
        # C6-A2 AC3b. Zoom is a VIEWING preference and selection is a work item;
        # changing one must not clobber the other. Captured and re-asserted here
        # rather than relying on 'this function happens not to touch it'.
        z0, sz0, view0 = st['zoom'], st['sheet_zoom'], st['view']
        st['tile'] = max(0, min(255, tile))
        st['cell'] = max(0, min(8, cell))
        if sync_queue:
            ql = qs[st['queue']]
            if st['tile'] in ql:
                st['qi'] = ql.index(st['tile'])
        assert (st['zoom'], st['sheet_zoom'], st['view']) == (z0, sz0, view0),             'selection changed a viewing preference'
        redraw()

    # ---------------------------------------------- C6-A3: accept quantised --
    def set_all_cells(v):
        for var in cell_vars:
            var.set(v)

    def included_cells():
        return [k for k in range(9) if cell_vars[k].get()]

    def refresh_cost():
        """Update the before-the-write cost display for whatever is currently
        selected. Runs on every selection and checkbox change, so the numbers on
        screen are always the numbers the button would act on."""
        inc = included_cells()
        p_tile = A.plan(ref.qidx, mapping, st['tile'], inc) if inc else None
        p_cell = A.plan(ref.qidx, mapping, st['tile'], [st['cell']])
        txt = A.cost_line(p_cell, mapping, st['tile'], [st['cell']])
        if inc:
            txt += '\n' + A.cost_line(p_tile, mapping, st['tile'], inc)
        else:
            txt += '\nno cells ticked — accept tile would write nothing'
        costlabel.config(text=txt)
        accept_tile_btn.config(state='normal' if inc else 'disabled')
        g = glyph()
        accept_cell_btn.config(state='disabled' if g is None else 'normal')

    def _do_accept(cells, what):
        # `ref.qidx` is the PER-PIXEL quantisation, and stays the source whatever
        # view is displayed (C6-A3 AC7). C6-A4 deliberately did NOT move it to
        # the new engine view: that render is the glyph model's own output, so
        # accepting it would write back the merged art hand-editing exists to
        # replace (C6-A4 §3).
        p = A.plan(ref.qidx, mapping, st['tile'], cells)
        if not p['changes']:
            savebar.config(text=A.cost_line(p, mapping, st['tile'], cells),
                           fg='white', bg=INFO)
            return None
        written = fe.apply_txn(p['changes'])          # ONE history entry
        for g in written:
            fe.note_edit(g)
            prog.note_accept(g, st['tile'], PLANES[p['winners'][g]])
        redraw()
        savebar.config(text='%s — %s' % (what, A.outcome_line(p, mapping, st['tile'])),
                       fg='white', bg=OK if not p['dropped'] else '#8a5a00')
        schedule_autosave()
        return p

    def do_accept_cell(_=None):
        _do_accept([st['cell']], 'accept cell')

    def do_accept_tile(_=None):
        inc = included_cells()
        if not inc:
            savebar.config(text='no cells ticked — nothing to accept',
                           fg='white', bg=INFO)
            return
        _do_accept(inc, 'accept tile (%d cells)' % len(inc))

    def select_cell(k):
        """Select cell k of the CURRENT tile — the composed-tile route.

        Deliberately does not touch `fe` at all. Undo history and the stroke
        stacks live per GLYPH in FontEdit, so moving the cursor to another cell
        — including one that uses the very same glyph, which a tile may well do
        (C6 §3) — cannot disturb them. Re-selecting is a cursor move, never a
        reload. C6-A2 AC6 asserts this rather than trusting the sentence.
        """
        if not 0 <= k <= 8 or k == st['cell']:
            return False
        st['cell'] = k
        redraw()
        return True

    def compose_click(e):
        """Click either 24x24 in the left panel to select that cell's glyph.

        The composed tile and the reference sit side by side on one canvas, so
        the hit test resolves which of the two was clicked first, then does the
        same 8-px subdivision the sheet uses. int() on canvasx/canvasy for the
        reason C6 §3 records: a float there yields fractional cell indices and
        the resolution silently goes wrong (§ known hazards).
        """
        k = compose_hit(int(ccanvas.canvasx(e.x)), int(ccanvas.canvasy(e.y)))
        if k is not None:
            select_cell(k)

    def compose_hit(x, y):
        """Composed-tile pixel -> cell index, or None. Shared by click and hover
        so the readout can never disagree with what a click would do."""
        cw, ch = CELL_W * CMP_ZOOM, CELL_H * CMP_ZOOM
        tw, th = 24 * cw, 24 * ch
        if 0 <= x < tw:
            ox = x
        elif tw + CMP_GAP <= x < tw + CMP_GAP + tw:
            ox = x - (tw + CMP_GAP)
        else:
            return None
        if not 0 <= y < th:
            return None
        return (y // (8 * ch)) * 3 + (ox // (8 * cw))

    def compose_motion(e):
        k = compose_hit(int(ccanvas.canvasx(e.x)), int(ccanvas.canvasy(e.y)))
        if k is None:
            return
        g = mapping.glyphs[st['tile']][k]
        coord.config(text='tile $%02X %s  glyph %s%s  — click to edit'
                          % (st['tile'], PLANES[k],
                             'none' if g is None else '$%02X' % g,
                             '  (current)' if k == st['cell'] else ''))

    def step_cell(delta):
        """Traverse the tile's nine cells in TL->BR order, clamped at the ends so
        'I have seen every cell' is unambiguous."""
        select_cell(max(0, min(8, st['cell'] + delta)))

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
        st['stroke_glyph'] = g
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
        g = st.pop('stroke_glyph', None)
        # record only if the stroke actually changed pixels — a click that lands
        # on the colour already there must not leave a no-op undo entry
        if g is not None and fe[g].undo and not np.array_equal(fe[g].px, fe[g].undo[-1]):
            fe.record([g])          # same history as an accept, so undo is ordered
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
        # ONE history across all glyphs (C6-A3): undoing an accept that wrote
        # five glyphs puts all five back, in one step.
        gs = fe.undo()
        if gs:
            prog.forget_accept(gs)      # the sidecar must not outlive the pixels
            redraw()
            savebar.config(text='undo — %d glyph%s reverted (%s)'
                                % (len(gs), '' if len(gs) == 1 else 's',
                                   ' '.join('$%02X' % g for g in gs[:8])),
                           fg='white', bg=INFO)

    def do_redo(_=None):
        gs = fe.redo()
        if gs:
            redraw()

    def do_revert(_=None):
        g = glyph()
        if g is not None and fe[g].revert():
            redraw(sheet_too=False)

    def do_undo_revert(_=None):
        g = glyph()
        if g is not None and fe[g].undo_revert():
            redraw(sheet_too=False)

    GLYPH_ZOOM_MIN, GLYPH_ZOOM_MAX, GLYPH_ZOOM_DEF = 2, 24, 8
    SHEET_ZOOM_MIN, SHEET_ZOOM_MAX = 1, 8

    def zoom(delta):
        """Glyph zoom, SELF-LIMITING on the display.

        The glyph canvas is fixed-size and stacked, so every step up makes the
        window taller — and past a point Tk clamps the window to the screen and
        the bottom panels vanish (C6 §6 deviation 3, the whole reason
        check_fits() exists). Rather than hardcode a guess at the ceiling, take
        the step, ask whether it still fits, and step back if it does not. The
        limit then follows whatever display the tool is actually running on.
        """
        was = st['zoom']
        want = max(GLYPH_ZOOM_MIN, min(GLYPH_ZOOM_MAX, was + delta))
        if want == was:
            return
        st['zoom'] = want
        redraw(sheet_too=False)
        if delta > 0 and not check_fits():
            st['zoom'] = was
            redraw(sheet_too=False)
            savebar.config(
                text='glyph zoom held at %dx — %dx would push the layout off a '
                     '%d px screen. Hide the strip (a) for a little more room.'
                     % (was, want, root.winfo_screenheight()),
                fg='white', bg=INFO)

    def glyph_zoom_fit(_=None):
        """Back to the default. The glyph panel shows a single 8x8 with nothing
        around it, so there is no 'fit to content' distinct from a sane default —
        and it anchors on its own centre because it has no other anchor."""
        st['zoom'] = GLYPH_ZOOM_DEF
        redraw(sheet_too=False)

    def centre_on_selected():
        """Keep the tile being worked on in view, CENTRED.

        Button zoom has no pointer to anchor on, and the view centre is
        arbitrary — the selected tile is the thing under work, so the view
        follows it. At 5x on a 384x384 sheet an off-centre tile is one pan away
        from lost, which is why this centres rather than merely keeping it
        on-screen.
        """
        z = st['sheet_zoom']
        x, y, w, h = S.tile_rect(st['tile'])
        total = float(S.GRID * z)
        cx, cy = (x + w / 2.0) * z, (y + h / 2.0) * z
        vw = sheetc.winfo_width() or 384
        vh = sheetc.winfo_height() or 384
        if total > vw:
            sheetc.xview_moveto(max(0.0, min(1.0 - vw / total, (cx - vw / 2.0) / total)))
        else:
            sheetc.xview_moveto(0.0)
        if total > vh:
            sheetc.yview_moveto(max(0.0, min(1.0 - vh / total, (cy - vh / 2.0) / total)))
        else:
            sheetc.yview_moveto(0.0)

    def sheet_zoom(delta):
        z = max(SHEET_ZOOM_MIN, min(SHEET_ZOOM_MAX, st['sheet_zoom'] + delta))
        if z == st['sheet_zoom']:
            return
        st['sheet_zoom'] = z
        st['sheet_cache'] = (None, None)
        redraw()
        centre_on_selected()

    def sheet_zoom_fit(_=None):
        """Largest integer zoom at which the whole 384 sheet fits the viewport."""
        vw = sheetc.winfo_width() or 384
        vh = sheetc.winfo_height() or 384
        z = max(SHEET_ZOOM_MIN, min(SHEET_ZOOM_MAX,
                                    min(vw, vh) // S.GRID or SHEET_ZOOM_MIN))
        st['sheet_zoom'] = z
        st['sheet_cache'] = (None, None)
        redraw()
        centre_on_selected()

    def set_ref(v):
        st['view'] = v
        st['sheet_cache'] = (None, None)
        redraw()

    def cycle_ref(_=None):
        v = S.Reference.VIEWS
        set_ref(v[(v.index(st['view']) + 1) % len(v)])

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
            centre_on_selected()
        else:
            refresh_status()

    def step_queue(delta):
        ql = qs[st['queue']]
        if not ql:
            return
        st['qi'] = max(0, min(len(ql) - 1, st['qi'] + delta))
        select(ql[st['qi']], 0, sync_queue=False)
        centre_on_selected()      # the queue can jump anywhere; bring it into view

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
        prog.ui = {k: st[k] for k in ('view', 'zoom', 'sheet_zoom',
                                      'tile', 'cell', 'queue')}
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
    ccanvas.bind('<ButtonPress-1>', compose_click)
    ccanvas.bind('<Motion>', compose_motion)

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
    # Tab traverses the tile's nine cells TL->BR. 'break' stops Tk's own focus
    # traversal from stealing it — without that the key moves focus between
    # buttons and the cell never changes.
    root.bind('<Tab>', lambda _e: (step_cell(+1), 'break')[1])
    root.bind('<Shift-Tab>', lambda _e: (step_cell(-1), 'break')[1])
    root.bind('<ISO_Left_Tab>', lambda _e: (step_cell(-1), 'break')[1])
    root.bind('a', do_accept_cell)
    root.bind('A', do_accept_tile)
    root.bind('s', toggle_strip)
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
    if args.queue:
        qvar.set(args.queue)
        set_queue(args.queue)
    if args.tile is not None:
        select(args.tile, args.cell)
    elif not args.queue:
        set_queue(st['queue'])
    if args.include is not None:
        set_all_cells(0)
        for k in (int(x) for x in args.include.split(',') if x.strip() != ''):
            cell_vars[k].set(1)
        refresh_cost()
    root.update_idletasks()
    centre_on_selected()          # start looking at the tile we are working on
    savebar.config(text='loaded %s (%d glyphs, %d used by tiles) — sha256 %s'
                        % (os.path.relpath(src, C.REPO).replace('\\', '/'),
                           cfg.n_glyphs, len(mapping.used_glyphs()), source_sha[:16]),
                   fg='white', bg=IDLE)

    # TEST SEAM. selftest.py drives these through real Tk events — a click on the
    # composed tile, a keypress with focus parked on a Button — because C6-A2's
    # two defects were both "the code is fine, the user cannot reach it", and
    # only a driven event can tell those apart from a unit call.
    root.gt = dict(st=st, select=select, select_cell=select_cell,
                   accept_cell=do_accept_cell, accept_tile=do_accept_tile,
                   cell_vars=cell_vars, refresh_cost=refresh_cost,
                   included_cells=included_cells, set_all_cells=set_all_cells,
                   ref=ref, do_undo=do_undo, do_redo=do_redo, qs=qs,
                   compose_hit=compose_hit, step_cell=step_cell,
                   zoom=zoom, sheet_zoom=sheet_zoom, sheet_zoom_fit=sheet_zoom_fit,
                   glyph_zoom_fit=glyph_zoom_fit, centre_on_selected=centre_on_selected,
                   set_ref=set_ref, cycle_ref=cycle_ref, glyph=glyph,
                   fe=fe, mapping=mapping, prog=prog, cfg=cfg, sheetc=sheetc,
                   ccanvas=ccanvas, gcanvas=gcanvas, save_btn=save_btn,
                   check_fits=check_fits, redraw=redraw,
                   CMP_ZOOM=CMP_ZOOM, CMP_GAP=CMP_GAP,
                   SHEET_ZOOM_MAX=SHEET_ZOOM_MAX, GLYPH_ZOOM_MAX=GLYPH_ZOOM_MAX)

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
