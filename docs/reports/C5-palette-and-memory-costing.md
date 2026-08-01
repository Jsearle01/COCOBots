# Form B Report — C5 — palette re-derivation and memory costing

**Class:** recon. `wip`, pushed. **No 25.3 gate** — renders are decision support, not a gate (§4).
**Nothing applied, nothing implemented**, no source or asset touched.

**Not a dispatch.** This report covers a conversational thread of eight questions from Jay following
C4. It exists because the work is substantial, four decisions came out of it, and CLAUDE.md §7's
delivery convention had produced project docs but no report.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, first question received after C4's report (`677b08c`). Tree clean throughout.
HEAD at this report `a003ee9` + the report commit.

### 1 — Summary

**Four decisions taken, and one finding that pushes back on a fifth.**

| # | question | outcome |
|---|---|---|
| 1 | can a non-inverse path give a more colourful palette? | **No** — inverse never constrained the colour *choice*, only the slot *order* |
| 2 | *"i can see colors missing"* | **Jay was right.** Green and magenta had **zero slots**. My "as colourful as the art" claim was wrong |
| 3 | render with the palette as it is in the code | in-code `PALETTERGB` scores 90.12; it covers hues deliberately, which my derivation failed to |
| 4 | *"two whites and two blacks — I can get two more colours"* | **Correct.** +`$03` cyan +`$0E` blue → **85.48**, recovering 4.6 of the 6.8 gap |
| 5 | **ADOPTED** | in-code palette with slots 14/15 reclaimed |
| 6 | how much memory in the proposed map? | **20 bytes.** |
| 7 | with a bootloader? | **1,597** |
| 8 | loader cost / sound cost | **438** measured-and-estimated / **~1,041** |

**The finding that matters most is the last line of §5:**

| configuration | free | after level loader | **after sound** |
|---|---:|---:|---:|
| 221 glyphs, no bootloader | **20** | — | does not fit |
| 221 glyphs + bootloader | 1,597 | 1,159 | **118** |
| **192 glyphs + bootloader** | 2,525 | 2,087 | **1,046** |

**192 is the first configuration in which the art, the level loader and sound all fit with room.**
Jay chose 221 on appearance in C4, against a ladder that showed no memory cost at all. 221 → 192
costs 3.81 of error — the same order as the 221 → 256 gap he judged invisible. **This is not a
recommendation; it is a cost the earlier decision was taken without.**

### 2 — Files

**No file modified outside `docs/`, `assets/palette.json` and `tools/`.** `graphics.asm`, the font,
`tileset.bin` and the ten level files are byte-identical to `HEAD` throughout (checked at every
commit).

| file | |
|---|---|
| `assets/palette.json` | **adopted palette replaced twice** — hue-covered, then the in-code+2 that Jay chose |
| `docs/project/palette.md` | adopted palette at the head; both superseded derivations retained below it |
| `docs/project/glyph-budget-decision.md` | §3d added — the colourfulness investigation |
| `docs/project/loader-costing.md` | estimates replaced with measurements |
| `docs/project/sound-costing.md` | **new** |
| `tools/repalette.py` | **new** — re-derivation, chroma bias, hue coverage |
| `docs/reports/C5-renders/` | four comparison renders, tracked per the C4 convention |

### 3 — Reasoning

**Why re-deriving the palette could not help.** C2 chose the 16 by `--objective floor` — quantisation
error of the artwork alone, no glyph model — and solved the complement pairing *afterwards* over
those fixed 16. Inverse therefore constrained the **order**, never the **choice**. Re-optimising
against the true 221-glyph configuration moved 2 of 16 colours and 0.15 of error.

**Why the clustering could be reused.** `kmeans_cells` groups cells by their demanded colour vectors
in RGB, which never touches the palette. So the cell→pattern assignment is computed once and any
candidate palette's exact error becomes a contraction of per-group histograms against the 64×64
distance matrix. That made a real 16-slot local search affordable, and later made a
1,225-combination exhaustive search instant.

### 4 — Verification

**Every adopted palette was checked against the C4 ladder before adoption**, because changing the
palette could in principle have reordered the configurations Jay judged:

```
                        prev adopted   chosen    delta
128 glyphs, inverse kept   102.34      105.83    +3.49
192 glyphs, inverse gone    87.27       89.29    +2.02
221 glyphs, inverse gone    83.34       85.48    +2.14
256 glyphs, inverse gone    79.64       82.00    +2.36
```

Ordering preserved in both adoptions, so **the C4 verdict (221 best, 256 no real improvement)
stands unchanged**.

**Consumers re-verified after each palette change** — `fontbuild.py`, `ladder.py` and `repalette.py`
all read `slots[].byte`; parsed clean, `applied: false` throughout.

**The loader figure is now measured, not estimated.** `disk_read.s` assembled with `lwasm`:
**301 bytes** of code (`$0000`–`$012C`, last instruction `rts`), with 7 bytes of variables at a
separate `DR_VARBASE` — **308 total**. And since karateka's `bootloader.bin` is 403 bytes and
`include`s that file, **the boot-stub logic alone is 102 bytes**, framebuffer-resident and therefore
free.

**The sound ISR figures are measured too.** POP's per-instruction table re-summed: 3-voice mixer
**85 cycles / ~44 bytes**, 1-voice PCM **51 cycles / ~21 bytes** — both cycle totals matching POP's
own headlines exactly, which is what makes the byte counts trustworthy.

**The PET sound engine measured from the pinned build receipt** (`reference/pet/symbols.txt`,
CLAUDE.md §2 rank 3): one contiguous block `$2503`–`$2623` = **289 bytes**, plus 97 bytes of
callers and 566 bytes across the four used music tables.

### 5 — Verdict-time evidence

**The hue defect — what Jay saw, measured:**

```
hue band        art pixels    baseline slots
grey              58.21%           4
red                3.65%           1
orange             5.85%           1
yellow/olive       5.31%           3
green              1.29%           0   <- absent
cyan/teal          6.39%           2
blue              18.86%           5
magenta            0.44%           0   <- absent
```

Five slots on blue, none on green or magenta. **30 of the art's 46 colours displaced by more than
60 RGB units**, with displacements crossing hue boundaries — red→olive, green→olive, green→yellow,
magenta→blue.

**Why my statistic could not see it.** I measured colourfulness as **mean chroma**, a magnitude
average. It reported the render at 44.7 against the art's 50.5 and I called that parity. A palette
scoring well on mean chroma can contain two hues. **The question was about which colours, and the
statistic was structurally incapable of answering it.**

**The adopted palette, and what the two reclaimed slots buy:**

```
$00 $3F $10 $09 $07 $38 $22 $0B $30 $26 $37 $12 $34 $20 $03 $0E
                                                    cyan  blue

                            error    cyan rendered
yours as-is (2 duplicates)  90.12        0.00%
+ $03 cyan, $0E blue        85.48       13.73%
+ $03 cyan, $2A magenta     87.31       14.50%
fully derived (rejected)    83.34            -
```

**The memory position, which is the load-bearing part of this report:**

```
proposed 221-glyph map, no bootloader
  $0000-$00FF    256   direct page                fixed
  $0100-$01FF    256   stack
  $0200-$03D6    471   unit timers + sprite table
  $03D7-$09FF   1577   UNUSABLE - DECB line buffer, text screen, DBUF/FAT/FCB
  $0A00-$259F   7072   font, 221 glyphs
  $25A0-$52EB  11596   code
  $52EC-$5DEB   2816   tile tables
  $5DEC-$7FEB   8704   unit arrays + MAP
  $7FEC-$7FFF     20   FREE
```

With a bootloader all three DECB holes vanish and usable becomes `$0100-$7FFF`:

```
glyphs   font B   free   after loader (438)   after sound (~1041)
  256     8192     477            37                 does not fit
  221     7072    1597          1159                        118
  192     6144    2525          2087                      1,046
```

**Renders surfaced for Jay, not interpreted** — `docs/reports/C5-renders/`:
`palette-variants.png`, `hue-coverage.png`, `incode-palette.png`, `incode-plus-two.png`.

### 6 — Reactive deviations and ROUTE ACCOUNTING

No dispatch, so no route. What was done, and why each step followed:

1. **Measured before answering** whether inverse removal frees the palette — it does not, and
   asserting either way without checking would have been a guess.
2. **Accepted Jay's correction immediately and measured it** rather than defending the claim. The
   hue-band analysis is what turned "I can see colours missing" into a specific, fixable defect.
3. **Adopted the hue-covered palette, then replaced it** when Jay compared against his own and chose
   differently. Both adoptions checked against the ladder first.
4. **Assembled the reference loader** rather than continue quoting ~440.
5. **Followed Jay's redirection on where the sound research lived.** I looked in code, found stubs,
   and reported that neither sibling port has a player — true, but not the answer. Jay: *"you're not
   going to find in code it should be a document"*. It was:
   `POP3_port/reports/20260725-220315-pa-12-sound-feasibility.md`.

**Two arithmetic slips of mine, both caught and corrected in-thread:**

- The LOADM-safe ceiling was first stated as 237 glyphs; `$8000 − $0A00` is 30,208, not the 30,720
  I used in that sentence. The computed table was right and the prose was not. Correct: **221**.
- An intermediate palette search divided by the cost-matrix row count instead of the true pixel
  count, inflating every figure ~3.58× (305/312/322 instead of 85/87/90). Rankings were unaffected;
  recomputed against 147,392.

### 7 — Uncertainty flags

1. **Green renders at 0.00% under the adopted palette**, and reclaiming the slots did not fix it.
   Slots 2 and 11 hold `$10` (0,170,0) and `$12` (0,255,0) — PETSCII-saturated — while the art uses
   `$14` (85,170,0) and `$15` (85,170,85). Nothing in the artwork is near enough to select them, so
   both green slots sit unused. **Retuning them would put green on screen at no cost in slots.**
   Raised once, not adopted; recorded rather than re-argued.

2. **The C4 ladder showed no memory cost.** Jay chose 221 on appearance alone. The 20-byte result
   was not known at decision time, and 221 → 192 costs 3.81 — the same order as the gap he called
   invisible. Flagged, not pressed.

3. **The sound engine's CPU load on *this* game is unmeasured.** POP's 36.96% is against *POP's*
   frame budget. PETSCII Robots is much lighter, but its VSYNC handler already drives the game clock
   and unit timers. **This is the biggest uncosted risk in the sound estimate and a MAME frame count
   would settle it cheaply.**

4. **Sound is 435 code + 606 data, of which only ~65 bytes are measured** (the two ISR variants).
   The rest is estimated from the PET's own sizes, which is a good basis for transliteration and a
   poor one for a re-architected FIRQ player.

5. **The 566 bytes of music data are reusable only if the note/tempo format survives** the move to a
   DAC player. Not verified.

6. **Sound and the level loader are coupled** — audio must be masked across disk sector transfers
   because the FDC halts the CPU. Doing the loader first is the cleaner order.

7. **`repalette.py`'s hue bands are my boundaries**, not a perceptual standard. Different cuts would
   move which bands count as "used" and therefore which get a reserved slot.

### 8 — Follow-up candidates

- **Re-examine 221 vs 192 with the memory cost visible** (§7 flag 2). Three separate pressures — art,
  loader, sound — now point at 192.
- **Retune the two saturated greens** (§7 flag 1). Free in slots, puts green on screen.
- **Measure this port's per-frame CPU budget** (§7 flag 3) before committing to a sound design.
- Carried: the four direct-framebuffer inverse replacements (C3 §7 flag 5, unavoidable under every
  option); correct CLAUDE.md §2L (C3 §7 flag 9); the level file-location scheme; fold the
  render-location convention into CLAUDE.md §7 (C4 §8); the pinned-digest check (A1b §8); the three
  MAME idioms (A2 §10). `main` is at `a62809e`, **twelve dispatches behind**.

### 9 — User interaction during task

The whole report is user interaction — eight questions, four of which changed a decision:

1. *"i don't see a huge difference between them"* — consistent with the measurement (rendered chroma
   44.7 → 46.3).
2. **"you told me the coco render is as colorful as the amiga art. that isn't true i cn see colors
   missing"** — **correct, and the most consequential correction here.**
3. *"that looks slightly better"* — adopted the hue-covered palette.
4. *"can you render the tile map with the 16c palette as it is in the code?"* → *"i meant tileset"*.
5. **"there are also two whites and two black so i can get two more colors with my palette"** —
   correct, and worth 4.6 of the 6.8 gap.
6. *"+cyan and +blue is best"* — adopted.
7. *"how much memory is available in the new proposed map"* → 20 bytes → *"what is the number if we
   use a bootloader?"* → 1,597 → *"what is the memory cost of the proposed level loader code"* → 438.
8. *"what would the sound engine cost"* + **"you're not going to find in code it should be a
   document"** — the redirection that found PA.12.

### 10 — Candidate(s) captured this task

Two new rows in `seeds/cocobots/live/`, pool commit **`6a1d6ef`**. **New rows only.**

| slug | one line |
|---|---|
| `a-hazard-recorded-as-a-flag-is-not-a-hazard-handled` | The dispatch warned "frequency is not importance"; I recorded it as a flag and then optimised frequency-weighted error anyway, producing exactly the defect it named |
| `prior-research-may-live-in-a-report-not-in-the-code` | Searching the sibling repo's *code* found stubs and concluded no research existed; the research was a report, and the operator had to redirect |

### 11 — Commit

| | |
|---|---|
| palette re-derivation | `3460d9a`, `fcd1b93`, `618a9a4` |
| in-code palette + reclaimed slots | `69a60af`, `9c96164`, **`900682e`** (adopted) |
| loader measured | **`7e330cd`** |
| sound costed | **`a003ee9`** |
| this report | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`6a1d6ef`**, pushed |

Working tree clean. Nothing applied; no shipped asset modified.
