# Form B Report — C8 — build a CoCo3 tileset matching the C64

**Class:** build (emits a font + tile table; changes no shipped asset). `wip`, pushed before
reporting. **No 25.3 gate** — nothing visible changes in the game. **The renders are surfaced for
Jay, not interpreted** (§3), and a still is not a live gate (§4).

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-07, dispatch C8 received. HEAD at receipt `47c47dd` (`wip`), tree clean.

### 1 — Summary

**Built. Every one of the 2,304 cells keeps its exact PETSCII shape, and 98.22% of them get the
C64's exact colours.**

```
build/c8/font-c64.bin      6,144 B   sha256 9becdf9ea14fa9525a1ce799ef8bfc74a392e992343f7d2b15b5c105eb6b782f
build/c8/tileset-c64.bin   2,826 B   sha256 c655942ae7ba6164ded96eb113e1159080ae92da9efe7469e07c08e83343f083
                                     DECB, load $5200, 2,816 B payload
```

| | |
|---|---:|
| cells with data | **2,304** |
| distinct glyph codes | **69** |
| distinct (glyph, colour-pair) combos | **200** |
| tile slots used | **160** (69 primaries + 91 variants) |
| **cells exact** | **2,263 (98.22%)** |
| cells merged | **41**, touching **33 tiles** |
| **shape mismatches** | **0** |
| off-palette nibbles | **0** |

**Two findings that change the dispatch's numbers, both explained rather than adjusted:**

**(1) The 151-slot budget was an underestimate. 160 are actually free.** §2 puts 41 slots aside for
text/UI, which is the arithmetic complement of 151 rather than a measurement. Deriving the text set
from the 49 `.STR` literals in the sources gives **53 slots text addresses** — but **21 of those are
also tile glyphs**, and a combo placed at its base glyph's own index serves both. Only **32** are
text-only and need reserving. `192 − 69 primaries − 32 text-only = 91` variant slots, so **160 for
tiles**.

**(2) §1's 97.9% / 2,255-cell figure is not reachable under §5's shape constraint.** Ranking combos
by cell count and keeping the top 151 **orphans 17 glyphs** — `$0E $11 $15 $25 $31 $32 $33 $34 $5A
$5B $69 $6D $6E $72 $75 $7B $7C` — whose **21 cells would have to merge into a different shape**.
§5 forbids that, and **seven of the seventeen are text slots**. Guaranteeing every glyph its own
index costs 10 cells at 151 (2,245 rather than 2,255) and is the only allocation that satisfies AC3.

At the 160 slots actually available it does better than the dispatch's target anyway: **2,263 exact,
41 merged**.

### 2 — Files

| path | what |
|---|---|
| `tools/c64match.py` | **new**, 400 lines — derivation, allocation, merge, emit, renders |
| `tools/c64verify.py` | **new**, 130 lines — verifies the emitted files, sharing no code with the above |
| `build/c8/font-c64.bin` | 192 × 32 B (gitignored `build/`; hashes above) |
| `build/c8/tileset-c64.bin` | DECB `$5200`, 2,816 B payload |
| `build/c8/merge-queue.json` | AC8's hand-cleanup list |
| `build/c8/c8.json` | machine-readable summary |
| `docs/reports/C8-renders/` | **tracked** — source, result, captioned pair |

**Read, never written:** `assets/tileset.bin`, `assets/palette.json`, `art/image.png`,
`build/ROBOTSA.BIN`, the sources, the ten level files.

### 3 — Reasoning

**The extraction rule, and why the inverse bit needs no special case.** For each cell: `ink` =
dominant quantised sheet colour over pixels where the base glyph's nibble is non-zero, `paper` =
dominant over the rest. The output configuration removes inverse (bit 7 becomes part of the glyph
index, C6 §3), so each slot holds a complete pattern — and reading the sheet **at the pattern's own
pixel positions** reproduces what is there whether or not the cell currently draws inverted. The
colour pair absorbs the flip.

I tested the alternative. An "inverse-aware" rule that swaps ink/paper for bit-7 cells yields **181
combos, not 200**, and would only be correct if the emitted pattern were complemented too. **The
rule that matches §1's derivation is also the one that is right**, which is a useful coincidence but
was checked rather than assumed. §6 names this ambiguity as the single most likely defect.

**Why primaries go at their base glyph's own index.** It is what keeps the 21 slots serving both
text and tiles readable: the shape at slot `$41` is still the `A` shape, only its two colours moved.
It also makes the "never a wrong shape" guarantee structural rather than incidental — every glyph is
guaranteed a slot before any variant competes.

**JPEG noise.** `art/image.png` is a JPEG, worst at cell edges where two colours meet. Taking the
**dominant** colour of each class — a mode over ~32 pixels, not a mean — is what absorbs it: ringing
perturbs a handful of edge pixels and cannot outvote the body of a flat region. No smoothing or
pre-filtering was applied, so nothing is invented to compensate.

### 4 — Verification (AC-by-AC)

**AC1 — derivation.** **200 combos, 69 glyph codes, 2,304 cells** — all three match §1 exactly.
Also matching: **28 of 69 glyphs need exactly one slot**. Two secondary figures differ:

| | §1 | measured |
|---|---:|---:|
| combos used more than once | 138 | **143** |
| combos used exactly once | 62 | **57** |
| `$66` colour pairs | 13 | **14** |

Both splits sum to 200, and every headline figure agrees, so the difference is in the tail —
plausibly a tie-break in the dominant-colour vote. **Reported, not adjusted.** `$7A` appears in §1's
top list but not mine; it does appear in the *inverse-aware* variant's top list, which suggests §1's
per-glyph figures were taken under that rule while its percentages were taken under this one.

**AC2 — allocation.** At the dispatch's **151 slots** the primaries-first allocator gives **2,245
exact (97.44%), 59 merged**. A pure top-151-by-count gives **2,255 (97.87%)** — matching §1 — but is
infeasible: it orphans 17 glyphs / 21 cells (§1 of this report). At the **160** slots actually
available: **2,263 exact (98.22%), 41 merged**. The emitted artifact is the 160 build.

**AC3 — shape exact for all 2,304 cells. LOAD-BEARING.** **0 wrong glyph, 0 mis-coloured.**
Verified twice, the second time by `c64verify.py` reading only the emitted binaries and comparing
against `assets/tileset.bin` + the shipped font:
```
PASS AC3 every cell is its ORIGINAL PETSCII mask, recoloured   2304 cells checked, 1158 flat, 0 bad
```
**My first version of this check failed 27 cells and the check was wrong, not the output.** It tested
whether the mask could be *read back* from the emitted glyph — but where the C64 cell is a single
flat colour, ink and paper coincide and the glyph is uniform, so the mask is unrecoverable by
inspection while still having driven every pixel. The correct test is that each glyph equals
`where(original_mask, ink, paper)`, which it does everywhere. **926 cells have ink == paper** because
the C64 cell is one colour.

**AC4 — text/UI reserved.** **32 text-only slots**, content untouched (still 0/1 → black on white):
```
$01 $02 $04 $05 $06 $07 $08 $09 $0A $0B $0C $0D $0F $10 $12 $13 $16 $17 $18 $19
$21 $26 $28 $29 $2C $2F $30 $36 $37 $38 $39 $45
```
The other **21 text slots are shared with tiles** (`$03 $0E $11 $14 $15 $20 $27 $2D $2E $31 $32 $33
$34 $35 $3A $41 $42 $49 $4C $56`) and keep their shapes via the primary-at-own-index rule; their
colours change from black/white to the C64's pair for that glyph. **Text stays legible but is no
longer monochrome** — flagged in §7.

**AC5 — file structure.** Verified independently:
```
PASS AC5 font is 6,144 B (192 x 32)              6144 B
PASS AC5 DECB: one segment, load $5200, 2,816 B  $5200-$5CFF, 2816 B, file 2826 B
PASS AC5 nine TILE_DATA tables of 256 B          {256}
PASS AC5 every cell has data                     2,304 cells (tile 255 BR present, post-C7)
```
C7's length fix is carried through — 2,816, not 2,815.

**AC6 — palette legality.** **0 nibbles outside 0–15**, checked on the packed bytes.

**AC7 — renders engine-faithful. LOAD-BEARING.** `c64verify.py` rebuilds the whole 384×384 render
from `font-c64.bin` and `tileset-c64.bin` alone — importing nothing from `c64match.py` — and
compares to the shipped PNG:
```
PASS AC7 render reproduced from the binaries alone   147456 of 147456 pixels match
```
All 256 tiles are present (the sheet *is* all 256), captions drawn in-image.

**AC8 — the merge queue.** 41 cells across 33 tiles, in `build/c8/merge-queue.json`, sorted by
descending colour distance. The head of the list:

| tile | cell | glyph | wanted | got | dist |
|---:|---|---|---|---|---:|
| 121 | ML | `$55` | ink `$3F` / paper `$3F` | ink `$00` / paper `$00` | **883.3** |
| 180 | MM | `$35` | ink `$00` / paper `$38` | ink `$3F` / paper `$00` | 736.1 |
| 255 | ML | `$32` | ink `$3F` / paper `$00` | ink `$00` / paper `$38` | 736.1 |
| 98 | MM | `$51` | ink `$3F` / paper `$3F` | ink `$3F` / paper `$00` | 441.7 |
| 143 | BM | `$3D` | ink `$00` / paper `$38` | ink `$07` / paper `$00` | 441.7 |

**AC9 — error, same metric as C2–C5.** **86.15** over 147,456 pixels.

**This number is measured against the C64 sheet. The Amiga ladder's 100.85 / 87.21 / 25.31 are
measured against the Amiga sheet. They are not comparable and putting them side by side would be
misleading** — a route can score well against an easy target and badly against a hard one. What *is*
comparable is the structural claim: the Amiga route merges ~1,962 appearances into 151 slots and
invents averaged shapes; this route merges 200 into 160 and invents none.

**AC10 — no shipped asset modified.** `git diff HEAD` over `assets/tileset.bin`,
`assets/palette.json`, `src/graphics.asm` and the ten level files: **empty**.

### 5 — Verdict-time evidence

Tracked under `docs/reports/C8-renders/`, surfaced for Jay's inspection per CLAUDE.md §3; **their
content is not analysed or judged here.**

| file | what |
|---|---|
| `c8-source-c64-quantised.png` | the C64 sheet quantised to the adopted 16 — the target |
| `c8-result.png` | the engine render from the emitted files |
| `c8-pair.png` | both, side by side, captioned in-image at 2× |

Reproduce with `python tools/c64match.py` then `python tools/c64verify.py`.

### 6 — Reactive deviations and ROUTE ACCOUNTING

**Deviation 1 — this uses `art/image.png`'s COLOURS, where §2M assigns it structure only.** Recorded
as the dispatch requires. §2M's reference hierarchy makes `image.png` the **ART ORACLE** for "glyph
use and tile construction" and gives colour to `Amiga_Artwork.png`. C8 deliberately inverts that for
this route: the whole premise is that the C64's colours are the target. **This does not overturn
§2M** — it is a second, parallel route, and §0 of the dispatch says so. If it is adopted, §2M's table
needs a line saying which route governs.

Also worth stating: §2M records `image.png`-is-the-C64 as a **working premise, evidenced not proven**
(palette distances crossed, 16.1 vs 26.8). **This whole dispatch inherits that premise.** If the
sheet turns out not to be C64, the artifact is still internally consistent — it matches *that sheet*
— but the name would be wrong.

**Deviation 2 — the allocator is not the one §3 specifies.** §3 says "rank by cell count; the top 151
get their own slot". That orphans 17 glyphs and violates §5. Every glyph is guaranteed its index
first. Both figures reported (§4 AC2).

**Deviation 3 — the emitted build uses 160 tile slots, not 151.** §2's 41-slot reservation is the
complement of 151; the measured text-only requirement is 32. Still within the 192 budget. The
151-slot variant was also built (`build/c8-151/`) purely to reconcile AC2.

**Deviation 4 — my own AC3 check was wrong before the output was right.** §4 AC3. Worth naming
because it failed 27 cells that were correct, and "fixing" the output to satisfy it would have made
things worse.

**Route accounting:** no shipped asset touched; palette read from the file and unchanged; no shape
invented or averaged — every emitted glyph is an existing PETSCII pattern recoloured, asserted for
all 2,304 cells by an independent checker; `ATTRIB_TO_MAP_TBL` not consulted; nothing applied to the
game; the editor untouched; explicit-path staging.

### 7 — Uncertainty flags

1. **The 21 shared text/tile slots now carry C64 colours instead of black-on-white.** Their *shapes*
   are unchanged so text remains legible, but a message using `$3A` will draw in whatever pair that
   glyph took. **Nobody has looked at a message rendered this way.** If it reads badly the fix is to
   move those 21 to reserved and spend 21 variant slots — the budget has room at 160.
2. **`$66` needs 14 colour pairs, 9% of the budget for one glyph**, and it is corrupt in the current
   font (§2J) *and* draws the health bar. Several of its pairs are near-duplicates —
   `($00,$07)`/`($00,$00)`, `($38,$38)`/`($03,$38)`, `($0E,$0E)`/`($03,$0E)` — so **merging three
   pairs frees three slots at almost no visible cost**. Not done, because it is a judgement about
   appearance and that is Jay's.
3. **The merge metric is summed RGB Euclidean distance over the two colours**, unweighted by how many
   pixels each covers. A glyph that is 90% paper weights its ink error equally, which is wrong in
   principle. It affects only the *ordering* of the 41-item queue, not which cells merge.
4. **The worst merge is genuinely bad**: tile 121 ML wants flat white and gets flat black, distance
   883. It survives because the merge rule may only choose a pair of the *same glyph*, and `$55` — a
   corrupt glyph — has no closer surviving pair. **Widening the rule would break the shape
   guarantee**, so the queue is the right place to fix it, by hand.
5. **Allocation ranks variants by raw cell count, not by cost-if-merged.** A cost-ranked allocation
   would spend slots where merging hurts most and would likely improve the queue's head. Not done:
   §3 specifies count-ranking, and AC8's queue is designed as the cleanup path.
6. **926 of 2,304 cells are flat** (ink == paper). That is the C64 being flat, not a loss — but it
   means 40% of the sheet carries no shape information, so the "shapes are exact" guarantee is doing
   less work than it sounds.
7. **Nothing has been rendered on hardware or in MAME.** The claim is that the files are internally
   consistent and the render reproduces from them; whether the GIME shows this is unverified.
8. **I have not judged the result's appearance** and this report contains no such judgement.

### 8 — Follow-up candidates

- **Decide between the two art routes** — this one and the Amiga ladder. They are not comparable by
  error figure (§4 AC9); the comparison Jay can make is visual, from `c8-pair.png` against
  `C4-renders/pair-192.png`.
- **Merge `$66`'s near-duplicate pairs** to free ~3 slots (flag 2).
- **Look at a text message rendered with the shared slots recoloured** (flag 1).
- **Cost-ranked allocation** instead of count-ranked (flag 5).
- **Carried, unchanged:** whether the allocator should reserve the 15 text slots at 192 glyphs;
  `dist/ROBOTSA.BIN`'s fate (C7 §7); ghosted accept preview and the per-glyph conflict winner
  (C6-A3 §7); scrollable glyph canvas (C6-A2 §7); settle the 27 no-static-reference tiles by MAME
  trace; retune slots 2/11 toward the art's greens; per-frame CPU budget before sound.
  **`main` is twenty dispatches behind at `a62809e`.**

### 9 — User interaction during task

None. The dispatch was self-contained, and its §1 measurements were quoted precisely enough to
reconcile against — which is what surfaced both findings in §1 of this report.

### 10 — Candidate(s) captured this task

One, to `seeds/cocobots/live/` — pool commit **`196bbb7`**, pushed.

- **`a-target-figure-can-be-unreachable-under-the-same-briefs-constraints`** — a brief can quote an
  achievable-looking number and, elsewhere in the same document, forbid the only allocation that
  reaches it. Reconciling both is how you find it; hitting the number is how you ship a violation.

### 11 — Commit

| | |
|---|---|
| the tools + renders | **`02aac806e4aa5fef9ea489cc2ec9c9b79f4b439b`** |
| this report | committed separately; SHA in the delivering message |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`196bbb7`**, pushed |

Explicit-path staging; no `git add -A`. No shipped asset modified.
