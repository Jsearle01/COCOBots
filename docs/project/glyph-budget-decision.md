# Decision — glyph budget: 221, and the glyphs get hand-edited

**Jay's ruling, 2026-08-01**, on the C4 render ladder:

> *"i think in anycase i am going to have to hand edit these glyphs. the 221 looks the best with 256
> not showing any real improvement"*

Recorded verbatim. This is the visual verdict the C4 dispatch existed to obtain, and it is the
authority (CLAUDE.md §3 — visual judgment is Jay's, never Clyde's).

---

## 1. What was decided

**Target configuration: 221 glyphs, inverse video removed.**

**256 glyphs is rejected** — no visible improvement over 221.

**The converter's output is a starting point, not the finished font.** Glyphs will be hand-edited.

---

## 2. What the measurement said, for the record

The verdict is consistent with the numbers rather than contradicting them, and the corroboration is
worth keeping because it tells us how much a 3.71-point gap is worth in practice:

| configuration | error | Jay's reading |
|---|---:|---|
| 128, inverse kept | 100.85 | *"much better but still not great"* (on C2's render) |
| 192, inverse removed | 87.21 | — |
| **221, inverse removed** | **83.28** | **best** |
| 256, inverse removed | 79.57 | *"not showing any real improvement"* over 221 |

**221 → 256 is 3.71 points and is not visible.** That is a useful calibration on the metric: a gap
of ~4 in this range does not read. It also means the last 35 glyph slots buy nothing anyone can see.

---

## 3. Consequences that follow immediately

### 3a. The bootloader leaves the art critical path

C3 established that **256 glyphs needs a bootloader** (it overruns the `LOADM`-safe window by 1,101
bytes), while **221 fits** with 19 bytes of slack. Since 256 is rejected, **no bootloader is
required for the art work.**

The case for a bootloader now rests entirely on **level loading** — see
[`loader-costing.md`](loader-costing.md). That case is independent and unaffected by this decision:
`MAP_LOAD_ROUTINE` and `TILE_LOAD_ROUTINE` do not exist, `CYCLE_MAP` never loads, and level select
and restart do not work. Those remain open on their own merits.

### 3b. The memory-map rework is still required

221 glyphs is **not** the do-nothing option. It needs:

- font grown from 4,096 to **7,072 bytes** (221 × 32)
- every region below `$8000` moved — font, code, tile tables, unit arrays, MAP
- `tileset.bin` **and all ten level files regenerated** for new DECB load addresses
- inverse video removed from `BITMAP_PLOTTER`, and **replacements designed for the four
  direct-framebuffer inverses** (C3 §7 flag 5) — the menu highlight, the elevator floor highlight,
  the map cursor and the EMP flash, none of which go through the plotter and all of which the C2
  palette already breaks

**19 bytes of slack is not an engineering margin.** C3 §7 flag 3 flags this: any growth in code,
tile tables or the unit arrays breaks the layout. 192 glyphs carries 947 bytes of slack and costs
3.93 points — worth re-checking against Jay's eye if the tightness bites.

### 3c. Hand-editing changes what the tooling should produce

**83.28 is a floor, not a target.** It is what k-means clustering plus a per-pixel argmin achieves
with no human judgment anywhere. A person editing a glyph can beat that on any glyph they touch,
because they can trade pixels the metric weights equally against each other in ways it cannot
express.

What hand-editing needs, and none of it exists yet:

1. **An editable form.** The converter currently emits `font-N.bin` and a `.asm` of `.BYTE` lines.
   Neither is editable by eye. A glyph sheet as a PNG — 221 glyphs laid out on a grid, at the real
   palette — is editable in any paint program.
2. **A round trip.** PNG sheet → font bytes, with the palette snapped back to indices, so an edited
   sheet rebuilds. **Without this the hand-editing has nowhere to go.**
3. **A re-verification path.** After an edit: does every pixel still land on a palette index, does
   the tileset still reference only allocated slots, does it still assemble. Cheap to check, easy to
   break by hand.
4. **An edit queue.** C4's `worst-tiles.png` and `ladder.json`'s `worst_tiles_221` list are the
   starting order. **Union it with C1's cleanup queue** — the two catch different failure modes
   (C1 measured correspondence confidence, C4 measures colour residual) and five of C4's worst
   eight are absent from C1's list.

---

## 3d. Can the palette be re-derived more colourfully now? Yes — but not for the reason asked

**Jay asked, 2026-08-01:** *"now that we have a non-inverse path can we re-derive a more colorful
palette."*

**Short answer: removing inverse buys nothing here — but the palette IS missing colours, and it can
be fixed almost for free.** Jay saw it before the measurement did: *"you told me the coco render is
as colorful as the amiga art. that isn't true i cn see colors missing."* He was right and the claim
was wrong. The three sections below are in the order they were established; **§3d-4 is the finding
that matters.**

**The palette was never constrained by inverse.** C2 chose the 16 by `--objective floor`: minimise
per-pixel quantisation error of the artwork, with no glyph model in the loop. The complement pairing
was solved *afterwards*, over those fixed 16. **Inverse constrained the slot ORDER, never the colour
CHOICE**, so removing it frees nothing on this axis.

**Re-deriving against the real configuration changes almost nothing.** `tools/repalette.py`
re-optimises the 16 against the actual 221-glyph, inverse-removed rendering error rather than
against the art alone:

| | |
|---|---|
| colours unchanged | **14 of 16** |
| swapped | `$39`→`$35`, `$04`→`$08` — exactly the two slots the render barely used (0.5% and 0.1%) |
| error | 83.28 → **83.13** |
| mean chroma | 85.0 → 85.0, unchanged |

0.15 of error is a twenty-fifth of the 3.71 gap Jay already judged invisible.

**Deliberately biasing toward chroma does not reach the screen.** Upweighting chromatic demand so
that getting a colourful pixel wrong costs more than getting a grey one wrong:

| bias | palette chroma | **rendered chroma** | error |
|---:|---:|---:|---:|
| baseline | 85.0 | 44.7 | 83.28 |
| 0 (re-derived) | 85.0 | 45.1 | 83.13 |
| ×2 | 100.9 | 45.8 | 83.23 |
| ×8 | **106.2** | **46.3** | 83.31 |
| — the Amiga art itself | — | **50.5** | — |

**Palette chroma rises 25%; rendered chroma rises 3.6%.** The render picks whichever entry is
nearest what the art asks for, and **the art asks for pure grey 58.2% of the time**. Extra chroma
lands in slots the art never selects.

**The ceiling is the artwork, not the palette.** At 221 glyphs the render is already at 88% of the
source's own colourfulness (44.7 of 50.5) and within 1.3 points on grey share (56.9% vs 58.2%). A
palette cannot put colour on screen that the source does not contain.

Visual: [`../reports/C5-renders/palette-variants.png`](../reports/C5-renders/palette-variants.png)
— source, baseline, re-derived and chroma×8, all at 221 glyphs, with each palette's swatch strip.

### 3d-4. The real defect: whole hues are absent, and mean chroma cannot see it

**Everything above measures colourfulness as MAGNITUDE — mean chroma. That is blind to hue
VARIETY.** A palette scoring well on it can contain two hues. Jay's objection was about *which*
colours, not how saturated they are, and the aggregate could not answer it. Measured properly:

| hue band | art pixels | baseline slots | |
|---|---:|---:|---|
| grey | 58.21% | 4 | |
| red | 3.65% | 1 | |
| orange | 5.85% | 1 | |
| yellow/olive | 5.31% | 3 | |
| **green** | **1.29%** | **0** | ← absent |
| cyan/teal | 6.39% | 2 | |
| blue | 18.86% | **5** | |
| **magenta** | **0.44%** | **0** | ← absent |

**Five slots on blue, none on green or magenta.** 30 of the art's 46 colours are displaced by more
than 60 RGB units, and the displacements cross hue boundaries: red → olive, green → olive, green →
yellow, magenta → blue. Those are the missing colours.

**This is a hazard C2's own dispatch named and I then ignored** — *"Frequency is not importance. A
colour at 1% that distinguishes two otherwise-identical tiles may matter more. Say how you handled
this."* Frequency-weighted squared error will always starve a 1.3% hue in favour of an 18.9% one,
because it cannot represent that a hue vanishing is more visible than a shade shifting.

**The fix costs almost nothing.** Reserve one slot per hue band the art uses above 0.2% of pixels,
then minimise error subject to that (`tools/repalette.py --hue-coverage`):

```
baseline  $22 $31 $1C $06 $39 $0E $08 $07 $00 $0A $23 $30 $38 $03 $01 $3F   err 83.28
covered   $00 $3F $0E $1C $15 $2A $22 $23 $06 $07 $38 $03 $35 $01 $0A $30   err 83.34
                          ^$15 green   ^$2A magenta
```

| | baseline | hue-covered |
|---|---:|---:|
| error | 83.28 | **83.34** (+0.06) |
| blue slots | 5 | 3 |
| green slots | **0** | **1** |
| magenta slots | **0** | **1** |
| green pixels rendered | **0.00%** | **0.74%** |
| magenta pixels rendered | **0.00%** | **0.15%** |

**+0.06 of error — a fiftieth of the 3.71 gap Jay judged invisible.** It buys green and magenta by
taking two slots off blue.

Visual: [`../reports/C5-renders/hue-coverage.png`](../reports/C5-renders/hue-coverage.png) — source,
baseline, hue-covered, all at 221 glyphs. **Not adopted; Jay's call.**

**And §3c still stands.** Hand-editing remains the one lever that can exceed the source, because a
person can choose colours the Amiga art never had. But the palette had a real, fixable defect, and
"the render is as colourful as the art" was a wrong claim built on the wrong statistic.

---

## 4. What is NOT decided here

- **Whether to do the memory-map rework at all.** 221 is the best-looking option; that is not the
  same as authorising the work to reach it.
- **The four direct-framebuffer inverse replacements.** Unavoidable under every option including
  do-nothing, since the C2 palette breaks them already. Undesigned and uncosted.
- **The bootloader / level-loading work.** Independent, and now clearly so.
- **Whether the palette itself should change.** C2's palette is fixed across the whole ladder by
  construction; a hand-editing pass might want different entries, and the complement pairing is what
  the direct-framebuffer inverses would need to exploit if they are fixed by palette rather than by
  code.

---

## 5. Provenance

- Ladder and verdict: [`../reports/C4-glyph-budget-ladder.md`](../reports/C4-glyph-budget-ladder.md),
  renders in [`../reports/C4-renders/`](../reports/C4-renders/)
- Slot and memory costing: [`../reports/C3-inverse-removal-recon.md`](../reports/C3-inverse-removal-recon.md)
- Palette: [`palette.md`](palette.md) — proposal, **not applied**
- Loader: [`loader-costing.md`](loader-costing.md)

**Nothing has been applied.** `graphics.asm`, the font, `tileset.bin` and the ten level files are
unmodified.
