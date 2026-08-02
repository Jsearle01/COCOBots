# Form B Report — C6-A4 — add the CoCo-palette sheet as a reference view

**Class:** build (small). `wip`, pushed before reporting. **No 25.3 gate** — tool, not game output.
**Jay's acceptance is by using it.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C6-A4 received. HEAD at receipt `116e13e` (`wip`), tree clean.

### 1 — Summary

**AC2 is the finding, and it splits in two — because there are two sheets, not one.** Both
regenerated at native 384×384, both palette-legal, and the count of distinct 8×8 cell appearances
classifies each without ambiguity:

| sheet | distinct 8×8 cells | classification | role |
|---|---:|---|---|
| `art/coco-quantised.png` | **1,799** | **per-pixel quantisation** | the **ceiling** — not reachable in 151 slots |
| `art/coco-engine.png` | **143** | **engine render** | **reachable** — what the machine shows |

**And the per-pixel one was already in the tool.** `coco-quantised.png` is **byte-identical** to the
editor's existing `amiga_quant` view — same computation, same adopted palette. So the CoCo-palette
sheet Jay is asking for has been on screen since C6; **its label said "Amiga quantised to the adopted
16", which reads as Amiga colours, and they are not Amiga colours.** That label was the defect.

**The genuinely new thing is the engine render**, and nothing on screen showed it before. It answers
a question the tool could not previously ask: *is this flatness the palette, or the glyph budget?*

**Consequently, per §3: the new sheet is an engine render, so it does NOT become the accept source.**
Accept stays on the per-pixel quantisation. Sourcing accept from the engine render would write a
glyph back its own current pixels — the merged k-means output that hand-editing exists to replace.

Four views now, all with labelled buttons. `uitest.py` **66 checks**, `selftest.py` **58 checks**,
both 0 failed.

### 2 — Files modified

| path | change |
|---|---|
| `tools/glyph_tool/cocosheet.py` | **new**, 145 lines — emits and *classifies* both sheets at 384×384 |
| `art/coco-quantised.png` | **new**, 384×384 · `sha256 0bec0a6ee73ae7585176aa4f0ac40ffb…` |
| `art/coco-engine.png` | **new**, 384×384 · `sha256 ff03e21d442d88902927f26692973491…` |
| `tools/glyph_tool/sheet.py` | fourth view, live engine render, relabelled the other three |
| `tools/glyph_tool/glyph_tool_app.py` | fourth button, live refresh, bounded label widths |
| `tools/glyph_tool/uitest.py` | +11 checks for the new paths |

**Read, never written:** `assets/tileset.bin`, `assets/palette.json`, `assets/authored/`, the font,
the levels, `graphics.asm`.

### 3 — Reasoning

**`repalette.py` has no render path** (§7 flag 1). It derives palettes and writes JSON; it emits no
PNG at all. C5's `incode-plus-two.png` was produced ad hoc in a conversational thread with no
dispatch, so there was no committed script to re-run. `cocosheet.py` is that script, written for
this dispatch and tracked.

**The composite could not have been reused anyway.** Measured: 4776×1302, three panels of 1592 wide.
Panel 0 holds 72,105 distinct colours (raw Amiga); panels 1 and 2 hold 166 and 169 — sixteen palette
colours plus antialiased label text and resampling. Rescaling 1592 → 384 would resample the colours
and produce off-palette pixels, which is exactly the hazard §6 names. **Regenerated from source at
1:1 instead.**

**Why the engine view is rendered live rather than loaded from the PNG.** A saved engine render is a
snapshot of the font at the moment it was written, and goes stale the instant Jay edits a glyph — a
reference that quietly stops matching the work is worse than none. `Reference.refresh_engine()`
re-renders when the font's bytes change, keyed on those bytes, so it cannot drift. The tracked PNG is
the same computation snapshotted at the current authored font, and the test asserts they agree.

**Why the quantised view stays.** §5 permits dropping it only if the new sheet supersedes it. It does
not — it *is* it. There is nothing to supersede and nothing to drop; the fix was the label.

### 4 — Verification (AC-by-AC)

`uitest.py` **66 checks, 0 failed** · `selftest.py` **58 checks, 0 failed**. Logs tracked.

**AC1 — 384×384, 1:1, from the palette file.**
```
palette from assets/palette.json: $00 $3F $10 $09 $07 $38 $22 $0B $30 $26 $37 $12 $34 $20 $03 $0E
coco-quantised  384x384  sha256 0bec0a6ee73ae7585176aa4f0ac40ffb…
coco-engine     384x384  sha256 ff03e21d442d88902927f26692973491…
```
The palette is asserted **against the file**, not against the dispatch's quote — the RGB triples the
tool holds are compared to `assets/palette.json`'s directly. It is the adopted `+$03 cyan, $0E blue`
set, unchanged.

**AC2 — the finding. LOAD-BEARING.**
```
PASS A4-AC2 coco-quantised classified by measurement   1799 distinct 8x8 cells -> per-pixel quantisation
PASS A4-AC2 coco-engine    classified by measurement    143 distinct 8x8 cells -> engine render
```
The dispatch's thresholds were ~1,962 → per-pixel and ≤ ~200 → engine render. **1,799 and 143** sit
cleanly either side. (1,799 rather than 1,962 because some 8×8 regions of the art are genuinely
identical to each other once quantised; the classification is unaffected.)

**AC3 — palette-legal.** **Zero** off-palette pixels in both sheets, checked pixel by pixel against
the 16 RGB triples rather than by counting distinct colours.

**AC4 — four states, and the layout.** Buttons `raw` / `CoCo px` / `CoCo engine` / `C64`, the active
one highlighted, the full name of the current view spelled out in the sheet header. `check_fits()`
**passes**.

**It did not at first, and the cause is worth recording.** Adding the fourth view took the window's
requested width from 2,370 to **3,044 px** and clipped two rows — the reference row needed 330 px
against 226 available. The cause was not the button: it was the new view's **long name in an
unbounded `Label`**. A label with no `wraplength` demands its entire text width and drags the whole
window with it — the same class of fault as the fixed-width readouts C6-A2 fixed, in a place I had
not applied the rule. Bounding `reflabel` and `cmp_label` and shortening the names brought it to
**1,530 × 802**, and the row now needs 412 px against 412 available.

**AC5 — alignment, checked against landmarks.**
```
PASS A4-AC5 engine sheet agrees with compose_tile on all 256 tiles
PASS A4-AC5 single-glyph tiles repeat exactly 3x3 at their own index   14 such tiles, 0 misaligned
```
The first compares the sheet against the editor's own composed-tile path — an independent code path
over the same mapping. The second is the geometric one: a tile whose nine cells all use the same
glyph must render as that 8×8 tiled **exactly** 3×3, and a one-pixel offset in origin or pitch breaks
the repetition.

**My first attempt at the second landmark was wrong and failed**, which is how I noticed: I checked
that C6-A1's `available` tiles render as a flat colour, on the reasoning that they are blank. They
are blank in the **shipped** table — but a192's allocator remapped those cells onto a glyph whose
pixels come from k-means over the art and need not be uniform. Uniform in **glyph**, not in
**colour**. 4 of 8 passed, which is the shape of a wrong test rather than a broken sheet.

**AC6 — accept source stated and justified.** The new view is an **engine render**, so per §3 it must
**not** become the accept source. Accept remains on the per-pixel quantisation (`ref.qidx`), and
C6-A3 AC7 is re-verified across all four views:
```
PASS A4-AC6 accept is invariant across all four views   4 views -> e418fc086ebf32f2
PASS A4-AC6 accept source is per-pixel, not the engine render
            5 of 5 glyphs would actually change — an engine source would change 0
```
The second check is the one that would catch a silent switch: accepting from the engine render would
write each glyph its own current pixels, so **zero** glyphs would change. Five do.

**AC7 —** `uitest.py` **66 checks, 0 failed**; `selftest.py` **58 checks, 0 failed**.

**AC8 — no regression.** Round-trip still
`b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c`; `git diff HEAD` over the 13
shipped assets empty; the authored font byte-identical (`1f25ee24…`) before and after every run.

### 5 — Verdict-time evidence

Four screenshots and two sheets, **6 distinct hashes**, plus three logs, tracked under
`docs/reports/C6-A4-renders/`. Surfaced for Jay's inspection per CLAUDE.md §3; **their content is not
analysed or judged here.**

| file | state |
|---|---|
| `A4-01-view-raw.png` | Amiga raw — not reachable |
| `A4-02-view-coco-per-pixel.png` | CoCo palette per-pixel — the ceiling |
| `A4-03-view-coco-engine.png` | **CoCo engine, live — the new one** |
| `A4-04-view-c64-oracle.png` | C64 oracle |
| `coco-quantised.png`, `coco-engine.png` | the sheets themselves, 384×384 |

### 6 — Reactive deviations and ROUTE ACCOUNTING

**Deviation 1 — the sheet had to be written, not regenerated.** §3 says "produce the sheet … from
`repalette.py`". That module has no render path; C5's PNGs came from an undispatched thread. Wrote
`cocosheet.py` and said so, rather than bolting a renderer into a palette-derivation tool.

**Deviation 2 — two sheets, not one.** §2 frames it as "one of the palette-legal panels is the sheet
Jay means" and asks which. The honest answer is that the two are different artifacts answering
different questions, both are cheap, and the classification is only meaningful with both present. So
both are emitted and both are labelled.

**Deviation 3 — the fourth view is rendered live, not loaded.** §3 asks for "a stable location the
tool loads from", and the tracked PNG is that. But an engine render loaded from disk is stale after
the first edit, so the tool re-renders it from the live font. The file remains the artifact; the
view remains true.

**Deviation 4 — two labels were given `wraplength`.** Not asked for, forced by AC4 (§4). Minimal and
local: two attributes.

**Route accounting:** palette untouched and read from the file; `assets/tileset.bin` opened
read-only; the quantised view kept; the engine render **not** made the accept source; explicit-path
staging.

### 7 — Uncertainty flags

1. **`repalette.py` could not emit at 384×384 without change, because it cannot emit at all** — it is
   a palette-derivation tool that writes JSON. Nothing in it was changed; a new file was added. If
   the Orchestrator intended a specific C5 panel to be lifted, **that panel is `coco-quantised`, and
   it is what the tool already displayed.**
2. **`art/` now holds two derived files** alongside the three source sheets. `art/` was previously
   source-only, and CLAUDE.md §2B's table describes it that way. These are regenerable from
   `cocosheet.py` in one command, so they are not authored assets — but they are not source either,
   and the Orchestrator may prefer them elsewhere.
3. **The engine render depends on the font being edited**, so `art/coco-engine.png` is a snapshot
   that will drift from the live view as Jay works. The test asserts they agree *at the current
   authored font*; it will need re-emitting after a drawing session if the file is to stay useful.
   **The in-tool view is always correct; only the file goes stale.**
4. **1,799 distinct cells, not the ~1,962 the dispatch predicted.** The difference is real 8×8
   repetition in the art after quantisation, not a measurement disagreement. It does not affect the
   classification, but the figure should be 1,799 wherever it is quoted next.
5. **Four references now differ subtly**, which §6 names as a hazard. The active view is named in
   full in the sheet header and its button is highlighted — but `CoCo px` and `CoCo engine` are one
   word apart on the button, and that is the pair most easily confused. **Say if the button labels
   need to be more distinct.**
6. **I did not change which sheet the composed-tile comparison shows.** The left panel still pairs
   the composed tile against whichever reference view is active, so selecting `CoCo engine` there
   compares the composed tile against… the engine render, which is the same thing. Harmless, and
   arguably a useful null check, but it is not informative.
7. **I have not judged the tool's output appearance** and this report contains no such judgement.

### 8 — Follow-up candidates

- **Re-emit `art/coco-engine.png` after drawing sessions**, or drop the file and keep only the live
  view (flag 3).
- **Decide where derived sheets live** if `art/` should stay source-only (flag 2).
- **Carried, unchanged:** which palette variant, and whether the allocator should reserve the 15 text
  slots at 192 glyphs. `dist/ROBOTSA.BIN`'s fate (C7 §7). Ghosted accept preview and the per-glyph
  conflict winner (C6-A3 §7). Scrollable glyph canvas (C6-A2 §7). Settle the 27 no-static-reference
  tiles by MAME trace. Retune slots 2/11 toward the art's greens. Per-frame CPU budget before sound.
  **`main` is eighteen dispatches behind at `a62809e`.**

### 9 — User interaction during task

None. The dispatch was self-contained. Its §2 was the useful part: it named the distinction, named
the prior occasion it was got wrong, and specified the test — which is why the finding took a
measurement rather than an argument.

### 10 — Candidate(s) captured this task

One, to `seeds/cocobots/live/` — pool commit **`95e3d93`**, pushed.

- **`the-thing-they-are-asking-for-may-already-be-there-under-a-wrong-name`** — a request to add a
  capability can be a report that an existing one is unrecognisable. Check whether the artifact
  already exists before building a second one, or you ship two things that differ only in label.

### 11 — Commit

| | |
|---|---|
| the feature + sheets | **`284decf51ffe8581438530bb3b7dcfd66f35a596`** |
| this report + `C6-A4-renders/` | committed separately; SHA in the delivering message |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`95e3d93`**, pushed |

Explicit-path staging; no `git add -A`. No shipped asset modified.
