# Form B Report — C3 — inverse-video removal: consumer audit and memory-map costing

**Class:** recon. `wip`, pushed before reporting. **No 25.3 gate** — nothing visible changes.
**Nothing implemented.** No source edit, no `ORG` change, no font rebuild, no asset touched.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C3 received. HEAD at receipt `6332f51` (`wip`), tree clean. C2's head
`8735598` present and used as the input.

### 1 — Summary

**Three findings, each of which changes the dispatch's own framing.**

**1. The audit found four framebuffer-complement routines, not one.** The dispatch names
`ELEVATOR_INVERT` (`:2752`) as a known example and asks whether others exist. They do — including
**`REVERSE_MENU_OPTION`, the menu selection highlight**, which is precisely the "does the UI use
inverse for menu selection" question C2 §7 flag 6 left open. Also `EMP_FLASH` (whole-screen effect)
and `REVERSE_TILE` (map cursor). **None of them goes through `BITMAP_PLOTTER`, so neither Option A
nor Option B touches any of them**, and all four render orange-on-grey under the C2 palette.

**2. Option A is infeasible, not merely low-value.** The dispatch prices it at +32 glyphs from a
101-slot requirement, leaving 27 free. That accounting is tileset-only. Including the source-resident
sprite tables and the `GAMEOVER3` screen, and the glyphs text needs, removing inverse requires
**142 slots of the 128 available — 14 short.** There is no version of Option A that fits.

**3. Option B fits, but at 221 glyphs, not 256** — and only because `$0400-$09FF` is unusable by a
`LOADM`-able program (idioms §23). 256 glyphs overruns by 1,101 bytes and needs a bootloader.

| option | glyphs | free for variants | error | fit |
|---|---:|---:|---:|---|
| do nothing (inverse kept) | 128 | 11 | **100.85** | ships today |
| **A** — remove inverse, 128 slots | 128 | — | — | **INFEASIBLE, needs 142** |
| **B′** — 192 glyphs | 192 | 50 | **87.21** | fits, 947 B slack |
| **B** — 221 glyphs, `LOADM`-safe max | 221 | 79 | **83.28** | fits, **19 B slack** |
| B — 256 glyphs | 256 | 114 | 79.57 | needs a bootloader (over by 1,101 B) |
| — ceiling, every cell its own pattern | 2,303 | — | 25.31 | — |

**Removing inverse is worth 3.26 points on its own** (113.64 → 110.38 at one pattern per group).
Everything else in the table is the extra glyph slots, not the inverse removal.

### 2 — Files

**No file modified.** One added: this report. AC8 verified by hash in §5 — all four source files,
`PETSCII_COCO.asm`, `tileset.bin` and all ten level files identical to `HEAD`.

No prototype was built; every figure here is measurement over existing artifacts.

### 3 — Reasoning

**Why the audit had to look for two different signatures.** The inverse bit reaches the screen by two
independent mechanisms: a character code with bit 7 set going through `BITMAP_PLOTTER`'s
`NextRowInv`, and code complementing framebuffer bytes directly with `COMA`/`COMB`. Grepping
`INVERSE` finds only the first. The second is only visible as `COM*` against a `SCREEN`-derived
pointer, and there are four of those.

**Why the slot accounting had to include more than `tileset.bin`.** Character codes with bit 7 set
also live in source `.BYTE` tables — the weapon/item sprites and, much larger, `GAMEOVER3`. Any
glyph used *both* ways needs a second slot when inverse goes, wherever the two uses come from.

### 4 — Verification (AC-by-AC)

**AC1 — PASS. Search method, and why it is exhaustive.** Five orthogonal patterns over all four
source files (`PETROBOTS_6809.asm`, `BACKGROUND_TASKS_6809.ASM`, `graphics.asm`, `utils.asm`):

1. the `INVERSE` flag by name
2. every complement instruction — `COM`, `COMA`, `COMB`
3. every instruction that could *set* bit 7 on a value — `ORA`/`ORB`/`ADDA`/`ADDB` with an immediate ≥ `$80`
4. every instruction that could *strip* it — `ANDA`/`ANDB` with `#%01111111` or `#$7F`
5. every high-bit binary immediate `#%1xxxxxxx`

These cover the complete set of ways bit 7 can be set, cleared, or acted on: it is either already in
data, or put there by an OR/ADD, or removed by an AND, or the byte is complemented wholesale. **Plus
a data sweep** — every `.BYTE` line in the source scanned for values ≥ `$80`, and every segment of
the built binary counted for high-bit bytes, which is what surfaced `GAMEOVER3`.

**Results — 5 consumers, in 3 categories:**

| site | line | category | what it renders |
|---|---|---|---|
| `NextRowInv` | `:2340` | **tile data** | `BITMAP_PLOTTER`'s inverse path; all 852 inverse tile cells |
| `ELEVATOR_INVERT` | `:2748` | **direct FB** | floor-number highlight, 8 scanlines × 4 B |
| `REVERSE_MENU_OPTION` | `:3225` | **direct FB** | **menu selection highlight**, 8 lines × 40 B, one of 4 `MENU_CHART` lines |
| `EMP_FLASH` | `:3358` | **direct FB** | whole map area, 132 B × 168 lines, EMP flash |
| `REVERSE_TILE` | `:4005` | **direct FB** | 24×24 px map cursor highlight at `CURSOR_X/Y` |

Callers: `ELEVATOR_INVERT` ×5, `REVERSE_MENU_OPTION` ×5, `EMP_FLASH` ×1, `REVERSE_TILE` ×3.

**No code path sets bit 7 on a character code at runtime** — every immediate fed to
`BITMAP_PLOTTER` is < `$80` (46, 32, 58, `$31`, `$63`, `$4D`, `$41`, `$67`, `$53`). The bit arrives
only from data: `tileset.bin` (852 cells) and source tables (`WEAPON1B/C/D`, `EMP1B`, `MED1B/C/D`,
`GAMEOVER3` — 38 `.BYTE` lines, 21 distinct high-bit codes).

**Only one place strips it** — `ANDA #%01111111` at `:2332`. Confirmed sole occurrence.

**AC2 — PASS.** Mechanical derivation under the C2 palette
`$22 $31 $1C $06 $39 $0E $08 $07 $00 $0A $23 $30 $38 $03 $01 $3F`. Text is re-indexed to
black = slot 8 (`$00`), white = slot 15 (`$3F`). `COMA`/`COMB` maps slot *s* → 15−*s*:

```
black  slot  8 -> slot  7 = $07 rgb( 85, 85, 85)
white  slot 15 -> slot  0 = $22 rgb(170, 85,  0)
```

**All four direct-framebuffer consumers therefore render `$22` on `$07`** — orange on mid-grey.
`NextRowInv`'s tile cells are the exception: they are handled by pre-inverting the glyph, so there is
no visual change at all. **This report does not say whether that is acceptable** (§3); Jay has
already ruled on the text case.

**AC3 — PASS, and the answer is that Option A does not exist.**

```
drawing-data glyphs                97   (normal 85, inverse 50, used BOTH ways 38)
text glyphs (letters/digits/punct/space)  44
union committed today             104 of 128   -> 24 free
each both-ways glyph needs a 2nd slot      +38
slots required after removing inverse     142 of 128   -> SHORT BY 14
extra font bytes                        1,216
```

**Independent corroboration that this accounting is right:** the tile∩text overlap comes out at
**37**, which is exactly §2M invariant 2's "37 glyph slots serve both tiles and text/UI" — a figure
derived elsewhere, by someone else, from different reasoning.

So there are no regions to move, no `ORG`s to change and no fit question: **Option A is short 14
slots before any variant budget exists at all.** The dispatch's 27-free-slots figure comes from a
101-slot requirement counted over `tileset.bin` alone.

**AC4 — N/A, superseded by AC3.** Option A's benefit cannot be measured because Option A has no
feasible configuration. The nearest meaningful figure: **removing inverse with one pattern per
(glyph, render-mode) group gives 110.38, against 113.64 with inverse** — a 3.26-point gain, and it
needs 142 slots to realise.

**AC5 — PASS. A layout exists, but only up to 221 glyphs.**

The binding constraint is not total space, it is that a `LOADM`-able program cannot occupy
`$0400-$09FF` — `$0600-$09FF` is DECB's `DBUF0`/`DBUF1`/FAT/FCBs, live *during* the load
(idioms §23), and `$0400-$05FF` is the text screen DECB writes `OK` into afterwards. The big regions
must live in **`$0A00-$7FFF` = 30,208 bytes**.

```
code + tile tables + units + MAP        23,117
font budget                              7,091   -> 221 glyphs
```

| font | glyphs | total | verdict |
|---|---:|---:|---|
| 4,096 | 128 | 27,213 | today, 2,995 B slack |
| 4,544 | 142 | 27,661 | Option A's requirement — fits in *space*, but exceeds the 128-slot **index** limit |
| 6,144 | 192 | 29,261 | fits, 947 B slack |
| **7,072** | **221** | **30,189** | **fits, 19 B slack — the ceiling** |
| 8,192 | 256 | 31,309 | **over by 1,101 B; needs a bootloader** |

**Candidate layout at 221 glyphs**, everything below `$8000`, `$0400-$09FF` avoided:

```
$0000-$00FF   direct page            256   fixed
$0100-$03D6   stack + unit timers + sprite table   727
$0400-$09FF   LEFT CLEAR for DECB              (1,536)
$0A00-$25FF   font, 221 glyphs      7,072
$2600-$5348   code                 11,597
$5349-$5E48   tile tables           2,816
$5E49-$7FE8   units + MAP           8,704
                                    19 bytes slack to $8000
```

**What moves:** the font, all code, the tile tables, the unit arrays and MAP — everything except the
direct page and the low fixtures. **Only three literal addresses appear in the source** (`$41F6`,
`$5200`, `$5D00`, one occurrence each — the `ORG` statements themselves); every other reference is
symbolic and `lwasm` recomputes it. **But `tileset.bin` and all ten level files carry fixed DECB
load addresses** (`$5200`, `$5D00`) and would all have to be regenerated — mechanical, but it
touches protected assets (§2B).

**AC6 — PASS. The marginal gain from 128 → 256 slots is 21.28 points, and most of it arrives
early.**

```
extra slots   total   error
        0      142   110.38
       11      153    96.05
       24      166    91.92
       50      192    87.21
       79      221    83.28   <- LOADM-safe ceiling
       80      222    83.16
      114      256    79.57
```

Today's shipped configuration is 100.85 at 128 slots. So:

- **128 → 221 (the reachable ceiling): 100.85 → 83.28, a gain of 17.57**
- **128 → 256 (needs a bootloader): 100.85 → 79.57, a gain of 21.28**
- the last 35 slots — the ones that cost a bootloader — are worth **3.71 of that 21.28**

**Do not read 256 slots as approaching the ceiling.** 2,303 cells against 256 patterns is still 9:1
compression, and 79.57 remains **3.1× above the 25.31 floor**. Measured, not extrapolated.

**AC7 — PASS.** §5. **No recommendation offered.**

**AC8 — PASS**, by hash — §5.

### 5 — Verdict-time evidence

**AC1's audit is load-bearing because it decides whether removal is safe.** The four
direct-framebuffer routines are the answer: **removing the plotter's inverse path does not remove
inverse video from the game.** It removes it from tile rendering only. The menu highlight, the
elevator floor highlight, the map cursor and the EMP flash all keep complementing the framebuffer
and all render `$22` on `$07` under the C2 palette. Each needs a designed replacement — a second
colour pair, a different highlight mechanism, or a palette laid out so that some pair *is* a sensible
inversion — and **that cost is additional to both options and is not costed here.**

**AC6's marginal gain is load-bearing because it decides whether the larger option is worth it:**

```
option                         glyphs   free    error     fit
do nothing (inverse kept)      128      11      100.85    ships today
A: remove inverse, 128 slots   128      n/a     n/a       INFEASIBLE: needs 142 slots
B' 192 glyphs                  192      50       87.21    fits, slack 947 B
B max LOADM-safe 221           221      79       83.28    fits, slack 19 B
B full 256                     256      114      79.57    needs bootloader (over 1101 B)
ceiling                                          25.31
```

**Verification of the dispatch's own quoted figures**, reproduced independently from
`assets/tileset.bin`:

```
total tile cells 2,304 (2,303 present; tile 255 BR absent)   dispatch 2,304
cells NORMAL 1,451                                           dispatch 1,452  (the absent cell)
cells INVERSE 852                                            dispatch 852     exact
glyphs normal 58 / inverted 43 / both 32                     dispatch 58/43/32 exact
slots today 69 / without inverse 101 (+32)                   dispatch exact
```

All reproduce. **The tileset-only accounting is correct; it is the scope that is too narrow** —
adding the source tables and text gives 90 → 126 for drawing data alone, and 104 → 142 including
text.

**Memory map, derived from the source `ORG`/`RMB` block plus the built binary segments:**

```
$0000-$001A     27   $01FF-$03D6    472   $14BB-$3B4D  9,875
$002E-$0080     51   $0E01-$14B9  1,721   $41F6-$51F5  4,096 (font)
$5200-$7EFF 11,520
allocated 27,762, free 5,006 of 32,768; largest contiguous gap $03D7-$0E00 = 2,602
```

The dispatch quotes 28,324 / 4,444 / `$0457-$0E00` = 2,474. Mine differ by ~560 bytes; the direction
does not change any conclusion (the font needs 8,192 contiguous and the largest gap is ~2.5 KB
either way), but the figures are measured, not adopted. §7 flag 2.

**AC8:**

```
unchanged  src/PETROBOTS_6809.asm      unchanged  src/PETSCII_COCO.asm
unchanged  src/BACKGROUND_TASKS_6809.ASM  unchanged  assets/tileset.bin
unchanged  src/graphics.asm            (all ten level files unchanged)
unchanged  src/utils.asm
```

### 6 — Reactive deviations and ROUTE ACCOUNTING

Route as dispatched — C3a audit, C3b Option A costing, C3c Option B costing — with three places
where the measurement contradicted the dispatch's premise and I followed the measurement:

1. **AC4 could not be performed as written.** It asks for Option A's benefit at 27 free slots.
   Option A has no feasible configuration, so there is no allocation to run. Reported as N/A with the
   nearest meaningful figure rather than answering a different question.

2. **The audit was widened to source data tables**, which the dispatch's slot arithmetic did not
   cover. That is what found `GAMEOVER3` and moved the requirement from 101 to 142 — the finding that
   makes Option A infeasible.

3. **The DECB-safe window was applied to Option B's layout.** The dispatch's framing ("348 bytes
   slack") treats the whole of `$0000-$7FFF` as available. Idioms §23 rules out `$0400-$09FF` for a
   `LOADM`-able program, which is what caps Option B at 221 glyphs rather than 256 and turns the
   full option into a bootloader dependency.

**An arithmetic slip of mine, caught and corrected mid-run:** I first stated the LOADM-safe ceiling
as 237 glyphs. `$8000 − $0A00` is 30,208, not the 30,720 I used in that sentence; the computed table
was right and the prose was not. The corrected ceiling is **221**. Both figures appear in the working
history; 221 is correct.

**Nothing was implemented**, per §5 of the dispatch.

### 7 — Uncertainty flags

1. **The exhaustiveness claim in AC1 is a claim about mechanisms, not a proof of completeness.** The
   five patterns cover every way bit 7 can be set, cleared or acted upon, and the data sweep covers
   every `.BYTE` line and every loaded segment. What it cannot catch: a complement performed by
   arithmetic rather than `COM` (e.g. `NEGA` plus an offset, or `LDA #$FF` / `SUBA`), or a computed
   character code that acquires bit 7 through arithmetic on a value I did not trace. I searched for
   the first and found nothing; **I did not exhaustively trace every arithmetic path to a character
   code.** Confidence is high, not total.

2. **My memory map differs from the dispatch's by ~560 bytes.** Mine is derived from the `ORG`/`RMB`
   block plus binary segments; I did not reconcile against theirs. Neither figure changes a
   conclusion, but if the exact slack matters — and at 221 glyphs it is **19 bytes** — it needs
   settling before anyone builds to it.

3. **19 bytes of slack at 221 glyphs is not an engineering margin.** Any growth in code, tile tables
   or the unit arrays breaks it. 192 glyphs with 947 bytes slack is the version with room to move.

4. **The error figures inherit C2's clustering lower bound** (C2 §7 flag 4) — k-means on raw demand
   vectors with deterministic seeding. All numbers here are floors for what a better converter could
   achieve, not ceilings.

5. **The four direct-framebuffer consumers are costed at zero.** I have identified them and derived
   what they render, but designing replacements — and what *that* costs in bytes and slots — is not
   in this dispatch and is not in the comparison table. **It is additional to whichever option is
   chosen**, including do-nothing.

6. **Regenerating `tileset.bin` and ten level files** for Option B is mechanical but touches
   protected assets (§2B) and is not costed in bytes-of-effort here.

7. **`GAMEOVER3`'s 31 lines were treated as character data.** I read them as a screen drawn through
   the plotter based on their code range and neighbours; I did not trace the routine that renders
   them. If they are something else, the +38 both-ways figure moves.

8. **Text glyph set is derived, not enumerated from the code.** I took letters `$01-$1A`, space,
   digits `$30-$39` and six punctuation marks. The 37-overlap match with §2M is strong corroboration,
   but a routine emitting a code outside that set would shift the accounting.

### 8 — Follow-up candidates

- **Decide what replaces the four direct-framebuffer inverses** (§7 flag 5). This is unavoidable
  under every option including do-nothing, because the C2 palette already breaks them. It may also
  be the cheapest thing on this list: a palette laid out so one pair is a deliberate
  highlight/normal inversion could fix all four without touching the engine.
- **Settle the memory map discrepancy** (§7 flag 2) before anyone builds to a 19-byte slack.
- **Trace `GAMEOVER3`'s renderer** (§7 flag 7) to confirm the accounting.
- Carried, unchanged: pinned-digest check on the three source blobs (A1b §8); the three MAME idioms
  to fold in (A2 §10, §2D); where run captures live (A2 §7 flag 4). `main` is at `a62809e`, nine
  dispatches behind.

### 9 — User interaction during task

None. The dispatch was self-contained. Every judgment call is recorded in §7.

### 10 — Candidate(s) captured this task

Two new rows in `seeds/cocobots/live/`, pool commit **`a2ef644`**. **New rows only.**

| slug | one line |
|---|---|
| `a-second-implementation-of-the-same-feature-hides-from-the-obvious-search` | The feature's name finds one implementation; the others are only visible by their *mechanism*, and removing the named one leaves the feature working |
| `scope-the-inventory-to-every-producer-not-the-largest-one` | A budget counted over the biggest data source understated the requirement by 41 slots and turned a feasible option into an infeasible one |

### 11 — Commit

| | |
|---|---|
| this report | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`a2ef644`**, pushed |

Working tree clean. Nothing implemented; no shipped asset modified.
