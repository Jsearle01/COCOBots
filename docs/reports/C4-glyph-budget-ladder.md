# Form B Report — C4 — render the glyph-budget ladder for visual comparison

**Class:** recon (renders only). `wip`, pushed before reporting. **No 25.3 gate** — these are stills,
and a static capture is not a live gate and raises no findings on its own (§4). They are decision
support surfaced for Jay. **Nothing applied, nothing implemented, no asset touched.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C4 received. HEAD at receipt `b701c18` (`wip`), tree clean. C2's
`fontbuild.py` (`8735598`) and C3's costing both present and consumed.

### 1 — Summary

Four renders produced at 128 / 192 / 221 / 256 glyphs. **Every achieved error reproduces C3's figure
exactly** — 100.85 / 87.21 / 83.28 / 79.57 — and **all four panels draw 2,303 of 2,304 cells**, the
one absentee being tile 255's bottom-right, which is not in `tileset.bin` (the file is one byte
short) and is marked with a grey check.

Engine-faithfulness is verified the way C2 verified it: each panel was re-rendered **independently
from the emitted font and tileset files**, and matches the tool's own output on **151,704 of 151,704
body pixels — exact, for all four**.

| panel | glyphs | inverse | tile slots used | error | cells |
|---|---:|---|---:|---:|---:|
| baseline | 128 | **kept** | 80 | **100.85** | 2,303 |
| | 192 | removed | 151 | **87.21** | 2,303 |
| | **221** | removed | 180 | **83.28** | 2,303 |
| | 256 | removed | 215 | **79.57** | 2,303 |

**The 128 panel is bit-for-bit the configuration Jay already judged** ("much better but still not
great"), so the ladder is anchored to a verdict on record.

**This report does not say what any render shows.** That is the entire point of the dispatch and it
is Jay's (§3).

### 2 — Files

Added, tracked: `tools/ladder.py`, and this report.

**No file modified.** `PETROBOTS_6809.asm`, `graphics.asm`, `PETSCII_COCO.asm`, `tileset.bin`,
`palette.json` and all ten level files hash identical to `HEAD` (§5).

Under `build/c4/` — gitignored, regenerable by `python tools/ladder.py --out build/c4`:

| artifact | |
|---|---|
| `ladder.png` | source + all four budgets, one row, captioned — **the primary artifact** |
| `render-128/192/221/256.png` | full resolution, ×3, one per budget |
| `worst-tiles.png` | the 16 worst tiles at 221, each above its Amiga source |
| `font-*.bin`, `tileset-*.bin` | the emitted artifacts each render was verified against |
| `ladder.json` | machine-readable: per-config figures and the worst-32 tile list |

### 3 — Reasoning

**Why a new tool rather than a flag on `fontbuild.py`.** The dispatch permits extending the tool but
not changing what it does, and the four configurations are not one parameter apart: the 128 panel
groups cells **by glyph** with the two render modes coupled through `COMA`/`COMB`, while the other
three group **by (glyph, render-mode)** with no coupling at all. Bolting a mode switch into
`fontbuild.py` would have changed the code path that produced C2's shipped artifacts. `ladder.py`
**imports** `fontbuild.allocate`, `fontbuild.tile_used_slots` and `fontbuild.SAFE_BAND`, and
`palettederive.kmeans_cells`, `sample_all`, `quantise_sheet` and `D2` — so the allocation, clustering
and sampling are literally the same code, and C2's own outputs are unchanged (§5).

**Why the 128 panel must use exactly 11 variants.** Naively there are 52 slots free of tiles at 128,
but text renders out of `$00-$3F` (C3), so C2 shipped with variants drawn only from the
provably-safe `$60-$7F` band — 11 slots. Reproducing 100.85 depends on that being 11 and not 52.

### 4 — Verification (AC-by-AC)

**AC1 — PASS.** Four renders at 128 / 192 / 221 / 256, one palette (C2's, unchanged and not
re-derived), one allocation algorithm, inverse kept at 128 and removed at the other three.

**AC2 — PASS. Every figure reconciles exactly, no discrepancy to explain:**

| budget | achieved | C3 | |
|---:|---:|---:|---|
| 128, inverse kept | 100.85 | 100.85 | ✅ C2's shipped configuration |
| 192 | 87.21 | 87.21 | ✅ |
| 221 | 83.28 | 83.28 | ✅ |
| 256 | 79.57 | 79.57 | ✅ |

Slot arithmetic also reconciles: the no-inverse configurations use 151 / 180 / 215 tile slots, being
C3's 101 base (glyph, mode) groups plus 50 / 79 / 114 variants, which is `total − 142` in each case.

**AC3 — PASS. 2,303 cells drawn in every panel**, of 2,304. The single undrawn cell is tile 255's
BR, absent from `tileset.bin`, and is filled with a grey check so it reads as "no data" rather than
as a black tile. **No panel is below 256 tiles** — the failure C2 §6 item 5 hit is not present, and
the render population is deliberately all 256 tiles rather than the 186 the palette derivation
samples from.

**AC4 — PASS, and this is the load-bearing check.** Each configuration emits a real font
(`font-N.bin`, 4,096 / 6,144 / 7,072 / 8,192 bytes) and a real remapped tileset
(`tileset-N.bin`, DECB `$5200`). Each was then **re-rendered by a separate script that reads only
those two files** — no shared state with `ladder.py` beyond the palette — and compared to the
tool's own PNG:

```
128 glyphs: 151704/151704 body pixels identical  EXACT
192 glyphs: 151704/151704 body pixels identical  EXACT
221 glyphs: 151704/151704 body pixels identical  EXACT
256 glyphs: 151704/151704 body pixels identical  EXACT
```

**"Body" excludes the top 5 rows, which carry the in-image caption** — the first pass reported
117-140 differing pixels and they were all in rows 2-4, columns 2-88, i.e. the text I draw on the
render. Below the caption band the difference is zero everywhere. §7 flag 2.

This is a stronger result than C2's equivalent (153,600 of 153,664): there, one cell genuinely
differed by construction; here the emitted files reproduce the panels exactly.

**AC5 — PASS.** `ladder.png` and `worst-tiles.png` exist, both captioned inside the image — the
ladder labels the source panel and each budget with its error, and names the palette strip;
`worst-tiles.png` states the pairing convention and labels every tile with its index and residual.

**AC6 — PASS.** Worst 16 tiles at 221 glyphs, by per-tile RMS against the GIME-quantised Amiga
source, over that tile's own cells only:

```
246 (129)   250 (127)   212 (126)   132 (121)
223 (120)   251 (117)   114 (117)   156 (115)
```

The full worst-32 list is in `build/c4/ladder.json` under `worst_tiles_221`, keyed by tile index so
it cross-references directly against `assets/tile-correspondence.json`.

**Cross-referenced against C1's cleanup queue** — of the eight above, **246, 250 and 223 are already
`unmatched` in C1**, and 246 and 250 are among the five C1 flagged as not `live`. So three of the
eight worst were already known-bad from a completely independent measurement, and two of those never
appear in a level at all. **114, 132, 156, 212 and 251 are new** — not on C1's queue.

**AC7 — PASS**, by hash. §5.

### 5 — Verdict-time evidence

**AC4, the engine-faithfulness check** — quoted in full above. Method: a standalone script decodes
`font-N.bin` back to 64 nibble-indices per glyph, reads the cell codes out of `tileset-N.bin`'s
`TILE_DATA` planes, and composes each cell as `BITMAP_PLOTTER` does — masking with `$7F` and
complementing through 15−*i* **only** in the inverse-kept configuration, and indexing the full 8-bit
code directly in the other three. Nothing in that path consults the artwork, so a per-pixel
quantisation could not have passed it.

**AC2, the error reconciliation:**

```
128 glyphs, inverse kept           err 100.85  slots  80  cells 2303
192 glyphs, inverse removed        err  87.21  slots 151  cells 2303
221 glyphs, inverse removed        err  83.28  slots 180  cells 2303
256 glyphs, inverse removed        err  79.57  slots 215  cells 2303
```

**AC7:**

```
unchanged  src/PETROBOTS_6809.asm     unchanged  assets/tileset.bin
unchanged  src/graphics.asm           unchanged  assets/palette.json
unchanged  src/PETSCII_COCO.asm       (ten level files unchanged)
```

**Renders surfaced for Jay**, and not interpreted anywhere in this report:

- `build/c4/ladder.png` — the primary artifact
- `build/c4/render-128.png` / `-192` / `-221` / `-256` — full resolution
- `build/c4/worst-tiles.png` — the 16 worst at 221, each above its source

### 6 — Reactive deviations and ROUTE ACCOUNTING

Route as dispatched: sweep four budgets over the existing tooling, render, reconcile, report.
**One variable moved** — the glyph budget, plus the inverse premise that is part of each
configuration's definition. Palette fixed, algorithm fixed, sampling fixed.

Deviations:

1. **A new module rather than a flag on `fontbuild.py`** (§3). It imports the allocation, clustering
   and sampling rather than reimplementing them, and leaves C2's artifacts byte-identical.

2. **Two slot-model bugs of mine, found and fixed during the sweep.** Both surfaced as a pool
   exhaustion rather than a wrong picture, which is the good failure mode:
   - I first reserved all 59 non-tile slots as "text", when C3 established text needs 44. The pool
     was 15 slots short before any variant was placed.
   - Then, in the inverse-kept configuration, glyph *primaries* were drawing from the 11-slot
     variant pool, so the variants had nowhere to go. Primaries keep their own glyph index; the pool
     exists only for what a configuration *adds*.

   Neither could have produced a plausible-but-wrong render — both crashed. Recorded because the
   second one is the exact off-by-model the dispatch's §7 hazard warns about.

3. **`worst-tiles.png` uses per-tile RMS against the GIME-quantised source**, restricted to each
   tile's own cells. The dispatch did not specify the metric; §7 flag 3.

**Nothing applied**, per §6 of the dispatch. No memory-map change, no `ORG` edit, no asset
regeneration.

### 7 — Uncertainty flags

1. **The slot *numbering* in the no-inverse configurations is nominal.** The budget constrains how
   many distinct patterns exist, which is what the render depends on; which physical index each one
   occupies is a font-layout decision C3 costed but nobody has taken. Text-only glyphs keep their
   indices and tile groups take the rest. **A real layout would also have to satisfy the memory map**,
   and this does not attempt that.

2. **The AC4 check excludes the caption band** (top 5 rows of the downsampled comparison). That is
   where the in-image labels are drawn, and they are not part of the render. Stated rather than
   silently cropped: the honest claim is "identical below the caption", not "identical".

3. **The worst-tile metric is mine.** Per-tile RMS against the quantised source, over that tile's
   own cells. A different weighting — by level frequency, by cell count, by perceptual distance —
   would reorder the list. The dispatch asked for "highest residual error" without fixing the
   measure.

4. **All four errors inherit C2's clustering lower bound** (C2 §7 flag 4) — k-means on raw demand
   vectors, deterministic seeding. Applied identically across all four, so the *comparison* is sound
   even though each absolute figure is a floor.

5. **The renders are stills.** They cannot show anything time-varying, and per §4 a static capture
   raises no findings on its own. The live verdict would need the font actually applied and run
   under MAME — which needs authorisation for protected assets and a memory-map decision.

6. **`worst-tiles.png` shows 24×24 tiles at ×4.** Large enough to compare shapes; whether it is
   large enough to judge is Jay's call, and the full-resolution panels are there for closer looking.

### 8 — Follow-up candidates

- **The decision this dispatch exists to support**: 128 / 192 / 221 / 256, and whether the
  memory-map rework and (at 256) the bootloader are worth what the renders show.
- **Five tiles are worst-at-221 but absent from C1's cleanup queue** — 114, 132, 156, 212, 251. Worth
  adding, since C1's queue was built from correspondence confidence and this is colour residual;
  they are different failure modes and the union is the real queue.
- Carried, unchanged: replacements for the four direct-framebuffer inverses (C3 §7 flag 5, unavoidable
  under every option); correct CLAUDE.md §2L (C3 §7 flag 9); the level file-location scheme; the
  pinned-digest check (A1b §8); the three MAME idioms (A2 §10). `main` is at `a62809e`, **eleven
  dispatches behind**.

### 9 — User interaction during task

None. The dispatch was self-contained. Every judgment call is in §7.

### 10 — Candidate(s) captured this task

One new row in `seeds/cocobots/live/`, pool commit **`5287420`**. **New rows only.**

| slug | one line |
|---|---|
| `a-scalar-quality-metric-cannot-answer-a-question-about-appearance` | An aggregate error figure weights all error equally and is blind to where it lands; when the decision turns on appearance, render the ladder and let the eye that owns the verdict compare |

Only one, deliberately. The two slot-model bugs (§6 item 2) both crashed rather than producing a
wrong picture, and "off-by-one in a resource pool" does not generalise beyond itself.

### 11 — Commit

| | |
|---|---|
| `tools/ladder.py` | **`8008a5186fbff70ff2a3399ee44ac828b4e7edc0`** |
| this report | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`5287420`**, pushed |

Working tree clean. Nothing applied; no shipped asset modified.
