# Form B Report — C6 — glyph editor

**Class:** build (tooling). **Includes DISPATCH C6-A1 (tile classification), folded in per its §8 —
no separate report.** `wip`, pushed before reporting. **No 25.3 gate** — this is a tool, not
game output. **Jay's acceptance is by using it, and that is the real verdict regardless of the ACs.**
**Nothing applied to the game. No shipped asset modified** (verified by hash, §4 AC9).

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C6 received. HEAD at receipt `3473bb5` (`wip`), tree clean. C4 (`8008a51`)
and C5 (`a003ee9`) present; `build/c4/font-192.bin`, `build/c4/tileset-192.bin` and
`docs/reports/C4-renders/ladder.json` all present and consumed.

**The dispatch's first instruction was to find Jay's reference implementation and match its
interaction model.** Three searches came back negative and I was about to ask for it; Jay's
redirection — *"no don't use that tool its been significantly improved. use the pop tool in its
directory"* — pointed at `POP3_port/harness/tools/sprite_tool/` with its launcher `sprite-tool.bat`
at the POP repo root. **That tool was read in full before a line of this one was written.** §3 lists
what was taken from it.

### 1 — Summary

**An interactive glyph editor exists and runs.** 2,455 lines across twelve modules, plus a
double-clickable `glyph-tool.bat` at the repo root matching POP's launcher convention.

**All nine ACs met, AC7 as amended by C6-A1.** `tools/glyph_tool/selftest.py` — **57 checks, 0
failed**, log at `docs/reports/C6-renders/selftest.log`.

**The load-bearing two:**

- **AC3 round-trip.** `build/c4/font-192.bin` → load → save with no edits →
  `assets/authored/font-a192.bin`, both `sha256 b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c`.
  Proven on the real save path, not on a mock, and an *edited* save is checked to differ so
  "identical" is not a vacuous claim.
- **AC6 affected-tile outlines.** All seven sharing figures the dispatch quotes reproduce exactly
  against `assets/tileset.bin` — `$4D` 122/210, `$20` 121/437, `$3A` 108/396, `$66` 88/268, `$5F`
  83/140, `$64` 60/176, `$67` 33/81 — as do the four summary statistics (69 distinct glyphs, 16
  single-tile, 23 over ten tiles, max 122 median 3). The outline set is additionally re-derived by an
  independent recount and compared.

**One discovery that changes how the tool must read its inputs.** The two configurations **disagree
about bit 7 of a cell code**, and the dispatch straddles them:

| | mapping | bit 7 | codes | distinct |
|---|---|---|---|---|
| **shipped** | `assets/tileset.bin` | **inverse video** (`COMA`/`COMB`, i → 15−i) | glyph = `code & $7F`, 0–127 | 69 |
| **a192** | `build/c4/tileset-192.bin` | **glyph-index bit 7** — inverse was removed | glyph = `code`, 0–**178** | **151** |

Reading the 192 mapping with the shipped rule would alias glyph `$B2` onto glyph `$32` and the error
would stay invisible until an edit landed in the wrong slot. The tool carries the semantics per
configuration and `selftest.py` asserts both (852 inverse cells in shipped; zero in a192, 554 codes
≥ `$80`).

**Two harness faults of mine were caught and fixed before delivery**, both by checks rather than by
inspection — §6.

### 2 — Files

| path | lines | what |
|---|---:|---|
| `tools/glyph_tool/glyph_tool_app.py` | 733 | the Tk application |
| `tools/glyph_tool/selftest.py` | 401 | headless AC proof, 57 checks |
| `tools/glyph_tool/progress.py` | 154 | provenance sidecar + versioned save + autosave |
| `tools/glyph_tool/edit_model.py` | 145 | strokes, undo/redo, baseline, revert |
| `tools/glyph_tool/render.py` | 140 | glyph / composed tile / sheet / strip renders |
| `tools/glyph_tool/tilemap.py` | 129 | cell→glyph table, blast-radius index, classification |
| `tools/glyph_tool/tileclass.py` | 320 | **C6-A1** — derives available / referenced / no-static-reference |
| `tools/glyph_tool/sheet.py` | 119 | crop, quantise, sub-cell resolution, three reference views |
| `tools/glyph_tool/config.py` | 118 | the two configurations and their bit-7 rules |
| `tools/glyph_tool/glyphio.py` | 82 | 4bpp pack/unpack, atomic write, hashing |
| `tools/glyph_tool/queues.py` | 76 | work order; five queues, none drops a tile |
| `tools/glyph_tool/pixel_map.py` | 35 | 320×200 pixel aspect, derived not assumed |
| `glyph-tool.bat` | — | repo-root launcher, **CRLF** (idioms §14g) |
| `docs/project/protection-catalog.md` | — | new §2B-extending entry (AC8) |
| `assets/authored/font-a192.bin` + `.json` + `versions/` | — | the authored asset, **tracked** |
| `.gitignore` | +4 | `/assets/authored/autosave/` — crash buffer, not a record |

**Read, never written:** `assets/tileset.bin`, `build/c4/tileset-192.bin`, `art/*.png`,
`assets/palette.json`, `assets/tile-correspondence.json`, `docs/reports/C4-renders/ladder.json`,
`src/PETROBOTS_6809.asm`, `src/BACKGROUND_TASKS_6809.ASM`.

### 3 — Reasoning

**What was taken from POP's sprite tool, deliberately and without improvement.** Reading
`sprite_tool_app.py` (493 lines) and `edit_model.py` (184) settled every convention the dispatch told
me not to reinvent:

| convention | carried over |
|---|---|
| armed palette swatch, `#FFE400` highlight border | yes, on all 16 slots |
| **one undo step per STROKE** (`begin_stroke` on press) | yes |
| redo stack cleared by any new paint; undo capped at 200 | yes |
| coalesced redraw via `after_idle` during drag | yes — POP's note says the per-event re-render *was* the paint lag |
| prominent save banner only a save writes | yes, same colour vocabulary (`#1b7f1b` ok / `#b02020` stop / `#666` info) |
| fixed-width monospace readouts so text can't reflow the toolbar | yes — POP records the Play button silently vanishing from this |
| action buttons gray themselves when invalid (`refresh_buttons`) | yes |
| `Ctrl-Z`/`Ctrl-Y`/`Ctrl-S`, `+`/`-` zoom, wheel pan, Shift-wheel horizontal | yes |
| **Revert-to-baseline + one-shot Undo-Revert**, restored wholesale not replayed | yes |
| `int(canvas.canvasx())` — a float there silently kills painting | yes, and the same at sheet click, where it would break sub-cell resolution |
| pixel aspect **derived**, not assumed | yes — same derivation, 320×**200** gives 5:6, not POP's 4:5 |

**Two deliberate departures**, both because the unit of work is different:

1. **No unsaved-changes guard on switching glyphs.** POP guards every frame switch because a cel is a
   whole sprite. Here the job is to walk 151 glyphs, edits live in one shared font array, and they
   are all saved together — a modal on every switch would be intolerable and would protect nothing.
   Closing the window with unsaved work autosaves instead.
2. **No opacity layer.** POP's palette is colour+opacity because of its shadow feature. Here every
   nibble is an independent 4-bit palette index (C2), so a pixel is one value.

**Where the ratio the dispatch names becomes visible rather than a footnote.** §1 of the dispatch says
hand-editing changes *who decides which structure survives*, not the ~13:1 ratio. Three things make
that ratio impossible to ignore while drawing: the header count (`glyph $3A — 108 tiles, 396 cells`),
the cyan outlines on the sheet, and — inside one tile — the composed 24×24 outlining **every** cell
that uses the selected glyph in orange, so a single stroke visibly moves all of them at once.

**Why the reference toggle has three states and not two.** The dispatch specifies raw ↔ quantised,
which answers *"is this flatness the palette or my drawing?"*. CLAUDE.md §2B and §2M are explicit
that `Amiga_Artwork.png` is **"COLOUR source only; NOT a shape/construction reference"** and that
`image.png` is the **ART ORACLE** for glyph use and tile construction. A tool whose entire purpose is
hand-authoring *shape* cannot show only the colour source. The same key cycles to the oracle — same
panel, same position, no extra screen space, which is the constraint the dispatch actually set.

**Work order.** `ladder.json`'s `worst_tiles_221` is the default queue (worst RMS first);
`tile-correspondence.json`'s non-`high` confidence rows form the cleanup queue, lowest score first —
those are the tiles where C1 was least certain the sheet tile and the tileset tile are the same
thing, and drawing them blind risks drawing the wrong tile well. Dead tiles are dropped from the
work queues and marked on the sheet, but remain reachable through the `all` queue so nothing is
unreachable.

### 4 — Verification (AC-by-AC)

Instrument: `python tools/glyph_tool/selftest.py` → **45 checks, 0 failed**, log tracked at
`docs/reports/C6-renders/selftest.log`. Screenshots at `docs/reports/C6-renders/C6-0*.png`, all
eight hash-distinct (checked — an earlier capture run produced byte-identical PNGs for different
states, §6).

**AC1 — runs; sheet right, glyph left, palette bottom, click-to-load with sub-cell precision.**
`C6-01-editor-a192-worst-tile.png`. Sub-cell resolution is proven **exhaustively, not by sampling**:
all 147,456 pixels of the 384×384 grid are mapped and compared against the independently computed
`(tile, cell)`, plus the 8/16/24-px boundary cases and off-grid rejection. This is the hazard §8
calls the first thing to get wrong.

**AC2 — pixel-accurate 4bpp; all 16 indices selectable and placeable; armed colour highlighted.**
All 16 placed through the real edit model and read back (`paint: all 16 indices placeable`, glyph
`$57`); an out-of-range index raises rather than silently truncating. The armed swatch carries POP's
`#FFE400` border. Nibble order is asserted directly — `$A3` unpacks to left `$A`, right `$3` — the
§8 hazard that mirrors every glyph and looks almost plausible.

**AC3 — undo/redo, save, round-trip proven, hashes reported.**

```
source   build/c4/font-192.bin          sha256 b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c
saved    assets/authored/font-a192.bin  sha256 b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c
                                        BYTE-IDENTICAL
```

Run through `progress.save()`, the same code path Ctrl-S uses, for **both** configurations. Three
further checks stop the result being vacuous: an *edited* save must differ (it does), the versioned
copy must match the source (it does), and the prior version must still be intact after the second
save (it is). Undo/redo/revert/undo-revert are exercised on a real glyph and each asserted.

**AC4 — left panel shows the 8×8 glyph AND the composed 24×24 tile beside the Amiga source.**
Three canvases: glyph under edit (zoomable), then the composed tile and the reference tile side by
side at matched aspect and zoom so the pair is comparable pixel for pixel. The tile's glyph **set**
is printed beneath — `tile $07 glyph set: $3A[TL,TM] >$20[TR,ML]<` — with the edited one bracketed,
and a line stating how many cells of *this* tile the glyph fills when it is more than one.

**AC5 — reference toggle; quantised view uses the adopted 16 from `assets/palette.json`.**
`C6-05-reference-quantised.png`, `C6-06-reference-c64-oracle.png`. Palette read from
`assets/palette.json` (`$00 $3F $10 $09 $07 $38 $22 $0B $30 $26 $37 $12 $34 $20 $03 $0E`), asserted
to be 16 slots. **The dispatch §2 quotes a different palette** — see §7 flag 1.

**AC6 — affected-tile outlines correct against `tileset.bin`; header counts and warnings.**

| glyph | expected | measured | screenshot |
|---|---|---|---|
| `$3A` | 108 tiles / 396 cells | **108 / 396** | `C6-02-affected-3A-108-tiles.png` |
| `$4D` | 122 tiles / 210 cells | **122 / 210** | `C6-03-affected-4D-122-tiles.png` |
| `$0E` (single-tile) | 1 tile | **1** (tile 141) | `C6-04-affected-0E-single-tile.png` |
| `$20` | 121 / 437 | **121 / 437** | — |
| `$66` | 88 / 268 | **88 / 268** | — |
| `$5F` `$64` `$67` | 83/140, 60/176, 33/81 | **all three exact** | — |

The outline set drawn on the sheet is `tiles_of[g]`, and the test re-derives that set by an
independent scan of the raw codes and compares — so the check does not share the thing under test's
own index. All 15 text/UI glyphs produce `! also used by text`; `$66` additionally produces
`! health bar`; a glyph with no non-sheet consumer produces none.

**One thing worth Jay's attention:** in the 192 configuration **all 15 text slots are also tile
slots** — the allocator claimed every one of them. So at 192 glyphs, editing a tile glyph in any of
`$03 $0E $11 $14 $15 $1A $20 $27 $2D $2E $31 $32 $33 $34 $35` **will** change on-screen text. `$66`
is likewise both the health bar and 30 tiles. The warnings fire on all of them.

**AC7 (as amended by C6-A1) — tiles classified into three categories, nothing skippable; progress
persists; zoom on both panels.**

`tools/glyph_tool/tileclass.py` derives the classification from four sources — `assets/tileset.bin`
for blankness, the ten level files for map references, and both `.asm` sources for `UNIT_TILE`
stores. **The lists in C6-A1 §2 are used only to reconcile; nothing is hardcoded.**

| category | derived | C6-A1 | sheet mark |
|---|---:|---:|---|
| **available** | **15** | 15 | **exact match** — green corner tick, empty and editable |
| **referenced** | **214** | 205 | none (normal) |
| **no static reference** | **27** | 37 | amber dot — drawn and edited normally |

**Available reconciles exactly**: the same 14 blanks plus tile 255.

**The other two differ by 9 tiles, and in the direction C6-A1 invited** — my scan finds references
its list does not, so nine tiles move out of "no static reference" into "referenced":

| tiles | found by | evidence |
|---|---|---|
| 160, 161, 162 | computed | `ADDB #160` at `PETROBOTS_6809.asm:2986` — C6-A1 §2 predicted this one |
| 249, 250, 251 | run-to-sentinel | `CMPA #252 ; Did we finish all from 246-251?` at `BACKGROUND_TASKS:1478` |
| 141, 142 | run-to-sentinel | `CMPA #143` bounded by `LDA #140` at `BACKGROUND_TASKS:1211` |
| 99 | cmp+inc | `CMPA #98 / INCA` at `BACKGROUND_TASKS:2255` — hoverbot's second frame |
| 111, 131 | literal | dead-player tile; `LDD #6*256+131` cannister |

**Every code reference cites a file and line**, and the selftest asserts that no tile enters the set
without one — 32 evidence rows for 27 tiles.

**Three traps found by reading the sites rather than trusting the pattern**, each now a check that
fails if it returns:

1. **Blankness must come from `assets/tileset.bin`.** C4's allocator remaps cell codes, so the same
   blank tile reads as nine `$35`s in the 192-glyph table. My first run tested the a192 table, found
   **zero** blanks, and reclassified all fourteen free slots as artwork.
2. **`CMPA #252` and `CMPA #143` are exclusive sentinels, not tiles.** Taking them literally marked
   252 — a genuinely free blank — as referenced, and missed the runs they bound. They now emit
   `range(start, n)` and never `n`.
3. **`LDA #3` at `BACKGROUND_TASKS:2264` reloads the animate timer, not a tile.** A naive backtrack
   from `STA UNIT_TILE,X` walked straight past `LDA UNIT_TILE,X` and reported tile 3 — another free
   blank — as referenced. The backtrack now stops at anything that redefines the register it cannot
   resolve. A missed reference is safe (the tile falls to "no static reference" and is drawn anyway);
   a fabricated one hides a free slot.

**A blank tile that is placed is not free.** Tile 0 is all-`$20` and is the empty floor of every
level, so `available` is blank **and** unreached. C6-A1's 14-entry list is the same set.

**Nothing is presented as skippable.** The `available` tiles get an inviting green tick rather than
the greyed-out cross the pre-amendment build drew, and there is a dedicated `available` queue —
these are free slots for new content, not waste. No queue drops a tile (asserted). Tile 255 carries
its own warning: *available, but its bottom-right cell has no storage until `tileset.bin` is 2,816
bytes*, so the slot must not be spent yet.

**The two costs of using a free slot are stated in the UI** (C6-A1 §6): the note on an available tile
says it needs level placement to appear, and the glyph header shows the pool draw so new shapes
against the 192 budget are visible.

Progress is a tracked JSON sidecar keyed per glyph (`untouched` / `edited` / `done` with first- and
last-edit timestamps); `edited` is **derived from the bytes** so it cannot lie, `done` is the only
field set by hand. Zoom: glyph 2–20×, sheet 1–5×, independently.

**AC8 — protection catalog entry; edited font on a tracked path; autosave present.**
`docs/project/protection-catalog.md` added (§2D: it extends §2B rather than editing CLAUDE.md's
body, and flags the row for the Orchestrator to fold). Font at `assets/authored/`, **not** `build/`,
per C4 §7 flag 7. Every save also writes an immutable `versions/font-a192-<stamp>-<n>.bin`; the
current file is replaced atomically via `.tmp` + `os.replace`; autosave runs 4 s after a stroke burst
and on window close, to a separate path a save never touches.

**AC9 — no shipped asset modified, verified by hash.**
`git diff --stat HEAD` over `assets/tileset.bin`, `src/graphics.asm`, `src/PETSCII_COCO.asm` and all
ten `assets/levels/level_?.bin` — **13 files, no diff**. This runs as the last check in the selftest,
so it re-verifies on every future run rather than being a one-time claim.

### 5 — Verdict-time evidence

**No 25.3 gate — correctly, per the dispatch.** A tool produces no game output and a screenshot of a
tool is not a live gate. The eight PNGs under `docs/reports/C6-renders/` are surfaced for Jay's
inspection per CLAUDE.md §3 and **their content is not analysed or judged here.**

| file | state captured |
|---|---|
| `C6-01-editor-a192-worst-tile.png` | 192 config, worst-RMS queue at its head |
| `C6-02-affected-3A-108-tiles.png` | shipped, glyph `$3A` selected — 108 tiles outlined |
| `C6-03-affected-4D-122-tiles.png` | shipped, glyph `$4D` — 122 tiles outlined |
| `C6-04-affected-0E-single-tile.png` | shipped, glyph `$0E` — one tile outlined |
| `C6-05-reference-quantised.png` | reference toggled to the quantised ceiling |
| `C6-06-reference-c64-oracle.png` | reference toggled to the C64 oracle |
| `C6-07-affected-strip-optional.png` | the optional strip, on (off by default) |
| `C6-08-available-free-slot.png` | tile 175 — an **available** slot, green tick, editable |
| `C6-09-tile255-storage-warning.png` | tile 255 — available, with the no-storage warning |
| `C6-10-no-static-reference.png` | tile 150 — **no static reference**, drawn normally |

Plus two logs, both tracked: `selftest.log` (57 checks) and `tileclass.log` (the derivation and its
reconciliation against C6-A1 §2), and `tile-classification.json` (the full derived classification
with per-tile evidence).

**The real verdict is Jay using it.** `glyph-tool.bat` from the repo root.

### 6 — Reactive deviations and ROUTE ACCOUNTING

**Deviation 1 — the reference tool was not where I looked.** Three searches (filename patterns for
`*sprite*edit*`/`*editor*`, the two ports' `harness/tools` directories, and a GUI-framework grep for
tkinter/pygame/Qt across `/c/Projects`) all came back negative, and I had one more candidate —
`appleiitococo3/AppleIIToCoCo3Gui.csproj` — when Jay redirected: *"no don't use that tool its been
significantly improved. use the pop tool in its directory."* The tool was at
`POP3_port/harness/tools/sprite_tool/`, with `sprite-tool.bat` sitting in plain sight at the POP repo
root. **My GUI grep should have found it** — it imports tkinter. It did not, because I ran the grep
against `/c/Projects` where the sheer volume of vcpkg and toolchain hits buried the result, instead
of against the two sibling repos the dispatch named. Cost: one redirection.

**Deviation 2 — my screenshot harness captured the desktop, not the window (found and fixed).**
The first capture run produced **byte-identical PNGs for different UI states** — `C6-03`/`C6-04` and
`C6-05`/`C6-06` hashed the same. `ImageGrab` screen-scrapes, and `root.update()` returns before the
compositor has painted, so it was grabbing whatever was behind the window. Fixed by grabbing from
inside a running `mainloop` after an `after(900, …)` delay, with `-topmost` set. **I caught this only
because I hash-checked the outputs for distinctness** rather than assuming eight runs produced eight
states — the same class of fault as A2's four harness faults, and the check is the reason it did not
reach Jay.

**Deviation 3 — the layout was clipped off the bottom of the screen (found and fixed).**
Stacked vertically, the left column requested ~1,280 px against an 864 px display. **Tk clamps a
window to the screen rather than shrinking a fixed-size canvas**, so the comparison pair and the
glyph-set line were simply not present — and a screenshot of that looks entirely plausible. Fixed by
putting the glyph canvas and the comparison pair side by side, giving the optional strip its own
height-capped full-width row, and defaulting the sheet to 1×. **A permanent guard was added**:
`check_fits()` compares the requested geometry against the screen on every redraw and reports the
condition in the save banner. This is deliberately a check that *fails visibly*, not a note in a
report — per the standing lesson that a hazard recorded as a flag is not a hazard handled.

**Deviation 5 — DISPATCH C6-A1 arrived after C6 had been committed and delivered.** It amends AC7,
so it was applied to the tool and folded into this report rather than reported separately, per its
§8. What it changed:

| before (C6) | after (C6-A1) |
|---|---|
| "67 dead tiles", from level maps only | three derived categories: **15 available / 214 referenced / 27 no static reference** |
| magenta crosses — read as "skip these" | green corner tick (available/free) and amber dot (unverified); **nothing marked skippable** |
| dead tiles dropped from the work queues | no queue drops a tile; dedicated `available` and `unverified` queues added |
| `Mapping.dead`, sourced from C1's `live` column | `tools/glyph_tool/tileclass.py`, deriving from four sources |
| tile 255 handled only as a no-data cell | classified `available` **and** carrying the no-storage warning |

**The amendment's premise checked out and then some.** C6's 67 would have written off the player's
own animation frames, both bullet types, both plasma types, the explosion sequence and the teleport
— and my own first pass at the corrected derivation reproduced two further versions of the same
mistake (testing blankness against the remapped table; taking exclusive sentinels as tiles). All
three are now checks that fail rather than notes that don't.

**Deviation 4 — bash heredoc ate a backslash again** (`'\\'` → `'\'`), producing a Python
`SyntaxError` for the third time across these dispatches. Routed around by writing the script to the
scratchpad with the Write tool and running the file. Noted in §8 as a standing tooling hazard.

**Route accounting:** no dispatch requirement was skipped or narrowed. Everything in §3 ("The smaller
ones — all in scope") is built. Nothing in §4's out-of-scope list was touched: no cell→glyph
reassignment, no palette editing, nothing applied to the game.

### 7 — Uncertainty flags

1. **The dispatch's §2 palette is not the adopted palette.** §2 quotes
   `$22 $31 $1C $06 $39 $0E $08 $07 $00 $0A $23 $30 $38 $03 $01 $3F` — that is
   `ladder.json`'s **C4-derived** palette. `assets/palette.json`, which C5 adopted on Jay's *"+cyan
   and +blue is best"*, holds `$00 $3F $10 $09 $07 $38 $22 $0B $30 $26 $37 $12 $34 $20 $03 $0E`.
   **AC5 names `assets/palette.json` as the authority and I followed the file, not §2.** If §2 was
   the intended palette, the quantised reference view and every swatch are wrong and it is a
   one-line change.
2. **Which sheet is "the Amiga art" is not settled.** The dispatch names `art/Amiga_Artwork.png`;
   C1's `tile-correspondence.json` records `art/image.png` as the sheet it measured. Both are
   392×392 JPEGs and their pixels differ. I follow the dispatch for the colour views and expose
   `image.png` as the third toggle state per §2B's role split — but **the identity correspondence
   C1 verified was measured on `image.png`**, so strictly the tile↔tile guarantee is strongest for
   the oracle view.
3. **The comparison pair has a fixed 3× zoom, not a live one.** The dispatch says "zoom on both
   panels"; I read "both panels" as the glyph and the sheet, which are the two it names in §3. A
   third zoom control bought nothing and 3× is what lets 24×24 at 5:6 sit beside the glyph canvas
   without either clipping on an 864 px screen. Easy to make live if Jay wants it.
4. **The sheet is drawn with square pixels; everything judged as output is drawn at 5:6.** The sheet
   is a navigation surface — stretching 384×384 to 1920×2304 makes tiles harder to recognise, not
   easier. The composed-tile/reference pair and the glyph canvas are aspect-correct. This is a
   judgment call and it is reversible.
5. **The `--strip` cap is 128 tiles.** Nothing currently hits it (`$4D` is the largest at 122), and
   when it does the count of dropped tiles is displayed rather than silently truncated. But it is a
   cap and it is mine.
6. **Progress `done` is unverified by anything.** `edited` is derived from bytes and cannot lie;
   `done` is pure human judgement with no check behind it. That is intentional, but it means the
   `done` count is a self-report.
7. **Undo is per glyph and does not span glyphs.** Ctrl-Z on glyph B will not undo the last stroke
   on glyph A. This matches how the work is actually done (walk to a glyph, draw it, move on) but it
   differs from a global undo history and may surprise.
8. **I have not judged the tool's output appearance** and this report contains no such judgement
   (dispatch §7). Whether hand-editing through this interface actually reproduces the structure Jay
   found missing is exactly what his use of it will decide.
9. **My classification disagrees with C6-A1 §2 on 9 tiles, and I use mine** — as §4 of the
   amendment directs (*"If your scan finds references the lists above miss, that is a better result,
   not a discrepancy"*). `available` matches exactly at 15; `referenced` is 214 not 205 and
   `no static reference` is 27 not 37, because 160/161/162, 249/250/251, 141/142 and 99 are all
   reachable and each cites a source line (§4 AC7). **160-162 is the case C6-A1 itself predicted a
   scan would miss** — mine catches it, which is some evidence the scan is working rather than that
   it is over-reaching. Against that: **the extra nine come from three inference rules of mine**
   (run-to-sentinel, cmp+inc, LDD low-byte), and a rule that infers is a rule that can over-infer.
   The three sites I read by hand all confirmed, but I did not read all 32.
10. **The `unverified` label is deliberately not "animation"** (C6-A1 §3). Door states, damage states
    and the trash-compactor cycle would look identical to static analysis, and calling them frames
    invites reasoning about them as frames.
11. **A MAME trace would settle the 27 definitively** and is explicitly out of scope (C6-A1 §5) —
    27 tiles of drawing is cheaper than the trace. Carried as a follow-up.
12. **`build/c4/font-192.bin` lives under gitignored `build/`.** The tool seeds
   `assets/authored/font-a192.bin` from it, so a clean checkout has the tracked starting point — but
   regenerating the *source* still requires `python tools/ladder.py`. The app says so when the file
   is absent.

### 8 — Follow-up candidates

- **Fix `assets/tileset.bin` to 2,816 bytes** (C6-A1 §7). One byte — `TILE_DATA_BR[255]`, value
  `$20`. `$5D00` is `UNIT_TYPE`, so 2,816 fits exactly with no memory-map consequence. It is a
  content change to a protected asset (§2B) and needs its own authorised task. **Until it lands,
  tile 255's free slot cannot be spent**, and the editor says so.
- **Settle the 27 `no static reference` tiles by MAME trace** — watch writes to `UNIT_TILE` and into
  the map. C6-A1 §5 defers this deliberately (drawing them is cheaper), but it is the only thing
  that converts them from inference to fact.
- **Carried from C5, still open:** retune slots 2/11 (`$10`/`$12`, PETSCII-saturated) toward the
  art's `$14`/`$15`; green currently renders 0.00%. **This tool is where that would now be judged**,
  and it is free in slots.
- **The 15 text slots are all shared with tiles at 192 glyphs** (§4 AC6). Whether that is acceptable
  or whether the allocator should reserve them is a budget decision nobody has taken.
- A "next unfinished glyph" jump keyed off the progress sidecar — the queues navigate by *tile*, and
  after a few sessions "which glyph have I not done" is the more useful question.
- Bash heredoc backslash mangling has now cost three Python `SyntaxError`s across dispatches. The
  reliable route is Write-to-scratchpad-then-run; worth an idiom entry.
- **Carried, unchanged:** replacements for the four direct-framebuffer inverses (C3 §7 flag 5);
  per-frame CPU budget measurement before committing to sound (C5); CLAUDE.md §2L's claim that
  level-load routines exist; the level file-location scheme; folding the render-location convention
  into §7; the pinned-digest check on three source blobs (A1b §8); three MAME idioms (A2 §10).
  **`main` is thirteen dispatches behind at `a62809e`.**

### 9 — User interaction during task

Two. **DISPATCH C6-A1** arrived after C6 was committed, amending AC7 — applied to the tool and folded
into §4/§6/§7 above rather than reported separately.

And one exchange. Jay: *"no don't use that tool its been significantly improved. use the pop tool in its
directory."* — redirecting me off `appleiitococo3` and onto
`POP3_port/harness/tools/sprite_tool/`. Acted on immediately; the POP tool was read in full before
any code was written, and §3 records what was taken from it. No other interaction.

### 10 — Candidate(s) captured this task

Two, to `seeds/cocobots/live/` — see §11 for the pool SHA.

- **`a-fixed-size-canvas-does-not-shrink-it-vanishes`** — a layout that exceeds the display is
  clamped by the window manager, not reflowed, so the overflowing panels are absent rather than
  squashed; a screenshot of the result looks correct. The distinguishing check is comparing
  *requested* geometry against screen size, and it belongs in the code as a visible failure rather
  than in a review.
- **`hash-your-own-evidence-for-distinctness`** — when generating N artifacts to evidence N different
  states, compare them to each other before shipping. Two identical hashes proved the capture
  harness was reading the desktop instead of the window; nothing about the files' size, count or
  filenames gave it away, and the report would have cited eight screenshots of one state.

### 11 — Commit

| | |
|---|---|
| tool + launcher + protection catalog + authored font | **`755ed0486b81c7d4245c799ee6580389ce9c5f90`** |
| this report + `C6-renders/` | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`1798a1f`**, pushed |

Explicit-path staging throughout; no `git add -A`. Working tree clean. Nothing applied; no shipped
asset modified.
