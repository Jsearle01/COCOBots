# Form B Report — C2 — derive the CoCo3 palette from the Amiga artwork

**Class:** recon. `wip`, pushed before reporting. **No 25.3 gate** — nothing visible changed; the
render is surfaced for Jay, not gated, and a still does not raise findings on its own (§4).
**No shipped asset modified**, verified by hash.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C2 received. HEAD at receipt `23c23e0` (`wip`), tree clean. C1's
deliverable commit `73aadcd` present and used as the input.

### 1 — Summary

**Proposed palette, in slot order:**

```
$00 $07 $0A $3F $0E $22 $03 $30 $3C $23 $39 $1C $06 $01 $38 $00
```

15 distinct colours; `$00` deliberately occupies slots 0 **and** 15. Weighted mean error **2.093**,
complement demand satisfied 19.2%, normal survival **34.2%**, inverse survival **25.9%**, ordering
efficiency **75.6%**.

**Three findings matter more than the sixteen values, and two of them change what C3 should do.**

1. **The inverse bit in this tileset is a shape-doubling device, not a colour-inversion device.**
   19.3% of complement demand asks a colour to be its **own** complement — the art wants the *same*
   colours whether a glyph is drawn normally or inverted. Under a monochrome font, inverse video
   buys a second shape free; under a coloured font that same trick imposes a colour constraint.
   This is why `$00` is self-paired.

2. **AC5's central number is not scale-free.** A **1-colour palette scores 100%** inverse survival.
   Ranked by the raw fraction, the best design is the one that discards all colour. The meaningful
   figure is inverse survival **relative to normal survival at the same palette** — normal cells
   carry no complement constraint, so their rate is the ceiling every other loss imposes.

3. **Read that way, the ordering is not the dominant loss.** Normal cells survive at only 34.2%, so
   the ordering costs ~8 points and **§2M invariant 1 (one glyph, one colour) costs ~66**. That
   makes §2M's "optional second pass" — glyph splitting — **the main lever for C3**, and it is
   bounded: 3 variants per glyph consumes 122 of 128 slots and caps satisfaction near 65%.

AC9's `CLAUDE.md` edit was applied and committed separately, first.

### 2 — Files modified

Nothing modified. Added, tracked:

| file | what |
|---|---|
| `assets/palette.json` | 16 slots in order, per-slot provenance, complement pairing with evidence, 117 inverse-failure tiles |
| `docs/project/palette.md` | proposal, derivation, frontier, control, limits |
| `tools/palettederive.py` | reproduces all of it |

Separately, per AC9: `CLAUDE.md` — the dispatch self-containment rule, +12 lines, 0 removed.

Not committed (gitignored `build/`): `build/c2/palette-comparison.png`, the render for Jay.

### 3 — Reasoning

**Why the ordering reduces to a partition.** A glyph carries palette *indices*; normally a cell
shows `(pal[I], pal[P])`, inverted it shows `(pal[15−I], pal[15−P])`. So if the art wants colour *A*
where a glyph appears normally and *C* where it appears inverted, *A* and *C* must sit at
complementary indices. Two consequences: **which** index-pair a colour-pair occupies is irrelevant
(all pairs (*i*, 15−*i*) are equivalent, and swapping within a pair only relabels *I* and *P*), so
the whole problem is *partitioning 16 colours into 8 pairs* — solved exactly by DP matching over
subsets. And **only glyphs used both ways constrain anything**: 26 of 55.

**Colour choice and slot order are not separable**, so the frontier search re-solves the pairing
exactly at every colour swap rather than optimising one then the other.

### 4 — Verification (AC-by-AC)

**AC1 — PASS.** Sampling restricted to `live` ∧ `informative`, `$55`/`$66` excluded. **186 tiles,
1,417 cells, 55 glyph slots, 17 glyphs in exactly one tile**, and the contested list
`$4D` 100 / `$20` 92 / `$3A` 82 / `$5F` 68 / `$64` 49 / `$67` 28 — **every figure reconciles
exactly** with the dispatch's inventory. No discrepancy to explain.

**AC2 — PASS.** 16 entries, all valid `$FFBx` values from the GIME 64 (each chosen *after*
quantising the demand to the gamut, so every entry is reachable). Weighted mean error **2.093**
against the first cut's **6.5**.

The first cut's figure is not directly comparable — it was computed over all Amiga pixels; mine is
over the sampled cell demand, and the error-minimal 16 on that demand is 1.627. **The trade I made
is explicit:** 1.627 → 2.093 (+0.466) buys inverse survival 17.3% → 25.9% and ordering efficiency
55.4% → 75.6%, by spending one slot-pair on the heaviest demanded complement. I traded 0.47 of
colour error for 8.6 points of inverse survival.

**AC3 — PASS. Weighting: cell count in the tileset**, not tile appearance in the levels. Justified
in `docs/project/palette.md` §2 — the palette serves every *drawn cell*, and level-frequency
weighting would let one common floor tile dominate. §7 flag 1 records the comparison.

**AC4 — PASS.** Full analysis in `palette.md` §4. Demand spreads over **200 distinct pairs**, the
heaviest at 9.7%:

| demanded pair | weight |
|---|---:|
| `$00` ↔ itself | 9.7% |
| `$00` ↔ `$07` | 8.7% |
| `$07` ↔ itself | 8.5% |
| `$07` ↔ `$38` | 6.6% |
| `$00` ↔ `$38` | 6.6% |

Placed at complementary indices: `$00`↔`$00` (rank 1) and `$07`↔`$38` (rank 4). **What the art wants
and 8 pairs cannot accommodate: 200 demands compete for 8 slots.** Each slot-pair serves *either*
one demanded complement *or* colour coverage. The residue is 80.8% of demand weight.

**AC5 — PASS, with the correction that makes it readable.** Of 669 inverse-coded cells in the
sampled population, **173 survive (25.9%)**; ink alone 62.6%, paper alone 50.2%. Method: assign each
glyph the (ink, paper) indices C3 would most plausibly vote for — inverse cells voting through the
complement — then check the **colour** rendered after complementing equals the colour the art wants.
Compared as colours, not slot indices, because duplicate colours otherwise fail spuriously.

**The raw fraction must not be read alone** (finding 2). Failures are listed by tile in
`assets/palette.json` → `inverse_failures_by_tile`, **117 tiles**, ready for the cleanup queue.

The 669 reconciles against the 852 in §2M: 852 counts all 256 tiles including corrupt-glyph cells;
830 excluding those; **669** within live ∧ informative — the only population with art to compare
against. All three reported so the denominator is unambiguous.

**AC6 — PASS.** All three deliverables tracked on `wip`. JSON loads; its 16 slot values match
`palette.md`'s block exactly (verified programmatically); complement pairs internally consistent;
`applied: false`.

**AC7 — PASS.** Crossed control:

| palette | on Amiga | on coco sheet |
|---|---:|---:|
| **Amiga-derived** | **2.093** | 1.804 |
| coco-derived | 18.335 | 0.120 |

**The wrong-sheet palette is 8.8× worse on the Amiga art.** Zero of 16 slots coincide. The demand
*structures* differ too: 200 pairs vs 91, heaviest `$00`↔itself (9.7%) vs `$07`↔`$38` (15.5%).
The derivation measures the art. `coco_ArtworkSheet.png` remains DEMOTED; nothing rests on it.

**AC8 — PASS**, by hash. `src/graphics.asm`, `src/PETSCII_COCO.asm`, `src/PETROBOTS_6809.asm`,
`src/BACKGROUND_TASKS_6809.ASM`, `src/utils.asm`, `assets/tileset.bin`, both art files and all ten
level files hash identical to `HEAD`.

**AC9 — PASS on substance; the stated line count differs.** Before-hash matched
`2b83d38…` exactly. After: **717 lines**, sha256
`917425dd215257c44bc9988d6d55dee70b23992e783462d42067df36301275f3`. **12 lines added, 0 removed** —
the quoted insert block is 12 lines, not the 16 the AC states, so 717 not 721. Superset check clean:
**zero** old lines absent. Committed separately, first (`cee42f3`).

### 5 — Verdict-time evidence

**AC5 — and the degeneracy control that reframes it.**

```
palette                     distinct   error    inverse survival
all black                          1   143.53          100.0%
black / mid-grey                   2    66.12           74.7%
black / white                      2   101.56           62.8%
4 colours                          4    33.76           33.3%
PROPOSED (j=1)                    15     2.09           25.9%
```

**A 1-colour palette scores 100%.** The metric runs backwards across most of its range and selects
for discarding colour. The scale-free reading uses the unconstrained population:

```
                        normal cells    inverse cells    ordering efficiency
                        (no constraint) (constrained)    (inverse / normal)
error-first  (j=0)         31.3%           17.3%              55.4%
PROPOSED     (j=1)         34.2%           25.9%              75.6%
demand-first (j=8)         46.8%           41.1%              87.8%
current graphics.asm       34.9%           25.7%              73.6%
```

**Normal cells face no complement constraint at all**, so 34.2% is the ceiling imposed by everything
else. The ordering costs ~8 points; the other ~66 are one-glyph-one-colour.

**The frontier — each slot-pair serves demand OR coverage, never both:**

```
j  demand%   err     distinct  normal%  inverse%  efficiency
0     9.3    1.63       16      31.3     17.3       55.4%
1    19.2    2.09       15      34.2     25.9       75.6%   <- proposed, the knee
2    19.0    2.60       14      34.6     26.0       75.1%   <- costs a colour, buys nothing
3    27.5    4.18       12      42.6     28.8       67.6%
8    50.3   25.77        6      46.8     41.1       87.8%   <- near-monochrome
```

**AC7 control** — quoted in §4. **AC1 reconciliation** — 186 / 1,417 / 55 / 17 and the contested
list, all exact.

**The glyph-splitting headroom, which is the actionable output for C3:**

```
319 distinct (glyph, ink, paper) demands across 1,417 cells; engine budget 128 glyph slots

variants/glyph   cells satisfiable   slots needed
      1               36.3%              55
      2               55.0%              93
      3               65.2%             122   <- practical ceiling
      4               71.8%             146   exceeds budget
      6               80.4%             183   exceeds budget

90% of each glyph's own cells would need 235 slots — impossible on this engine.
```

**The render for Jay** — `build/c2/palette-comparison.png`, 1584×848: the Amiga sheet, the same
sheet quantised to the proposed 16, and the slot-order swatch strip. Surfaced for inspection.
**This report does not say what it shows.** It is gitignored (`build/`) and regenerable by
`python tools/palettederive.py --sheet art/Amiga_Artwork.png --j 1 --render <path>`.

### 6 — Reactive deviations and ROUTE ACCOUNTING

Route as dispatched: sample → weight → choose 16 from the GIME 64 → solve the ordering → test the
inverse cells → control → deliverables. AC9 done first and committed separately.

Deviations, all in method rather than scope:

1. **The complement demand is a soft outer product, not a majority vote.** A hard vote was built
   first; printing the dominance distributions showed the modal colour ranging from **22% to 99%**,
   so a 22% plurality would have been asserted as confidently as a 95% consensus. The soft form
   changed the picture materially — the top demand fell from an apparent near-certainty to 9.7% of
   weight spread over **200** pairs rather than a clean handful. Optimising against the hard version
   would have fitted a sparse fiction and looked like a clean solve.

2. **A bug of mine in the inverse test, found and fixed mid-run.** It compared slot *indices*, which
   fails spuriously when a colour occupies more than one slot — and the proposal deliberately
   duplicates `$00`. Comparing rendered *colours* moved the demand-first variant from 29.1% to
   41.1%. Both figures are in the history; the corrected form is what §4 reports.

3. **The degeneracy control (finding 2) was not asked for.** Without it the dispatch's central
   number would have selected the near-monochrome design, which is the opposite of the point.

4. **The normal-cell baseline was not asked for either**, and it is what overturned the framing.
   It is the same discipline as C1's control sheets, applied to a metric rather than a source.

5. **The frontier is reported rather than a single answer.** j=1 is recommended and j=2 is shown to
   be dominated by it; the whole curve is in `palette.md` §4 so a different trade can be taken
   without re-deriving.

6. **Nothing was applied.** `graphics.asm` untouched.

### 7 — Uncertainty flags

1. **Weighting: cell count, not level frequency.** Chosen, not derived. Level-frequency weighting
   would let a common floor tile dominate the palette; cell count treats every drawn cell equally.
   The dispatch asked for both if they disagree materially — I did not compute the level-weighted
   palette in full, so **whether it disagrees materially is unmeasured**. It is a one-line change to
   `colour_weights()` and worth doing before C3 commits to this.

2. **The `j=1` recommendation rests on a knee, which is a judgment.** j=0 is more accurate in
   colour; j=8 survives inversion better; j=1 is where the marginal return is highest. A different
   weighting of "colour fidelity" against "inverse fidelity" picks differently, and the whole
   frontier is published so that choice is Jay's rather than buried.

3. **`assign_glyph_indices` is a stand-in for C3's vote.** C3 will colour glyphs by its own method;
   mine is a plausible majority used only to make the ordering testable. **A better C3 vote would
   raise all the survival numbers** — so 25.9% is a floor for this palette, not a prediction.

4. **The ink/paper split within a cell** comes from majority agreement against the glyph's own ink
   mask. Where a cell's two art colours are close, that assignment is noisy, and JPEG artefacts make
   it noisier.

5. **Slot 0 is treated as having no special status.** If `$FF9A` (border) or anything else cares
   which colour sits at index 0, that is unmodelled — and index 0 currently holds `$00`, which is
   the most likely choice anyway.

6. **The 8.8× control ratio is favourable but partly structural.** `coco_ArtworkSheet.png` is
   already drawn in CoCo colours, so a palette derived from it fits it almost perfectly (0.120) —
   which inflates the contrast. The load-bearing half is that the coco-derived palette is **18.335**
   on the Amiga art versus 2.093, and that direction is not structurally advantaged.

7. **AC9's stated line count (721 / 16 added) does not match the quoted insert block** (12 lines →
   717). Same class as A3's 6-vs-5 and 44-vs-43. Zero lines removed, so the §2D gate holds; flagged
   because the figure would otherwise be restated in a later dispatch.

8. **17 non-informative and 8 unmatched tiles carry no colour sample.** Glyphs appearing *only*
   there have nothing to vote with and C3 must fall back. I did not enumerate which glyphs those
   are — a short follow-up.

### 8 — Follow-up candidates

- **Compute the level-frequency-weighted palette** and compare (§7 flag 1). Cheap; closes the one
  AC3 sub-question I left open.
- **Enumerate glyphs with no sample** (§7 flag 8) so C3's fallback set is known in advance.
- **Glyph splitting is C3's main lever, not an optional second pass** — and it is capped at ~65% by
  the 128-slot budget. §2M describes it as optional; that framing understates it.
- **`$00` self-paired at slots 0/15 is a load-bearing choice.** If C3 finds it costly, the frontier
  table gives the alternative directly.
- Carried, unchanged: pinned-digest check on the three source blobs (A1b §8); the three MAME idioms
  to fold in (A2 §10, §2D); where run captures live (A2 §7 flag 4).
- `main` is at `a62809e`, now seven dispatches behind.

### 9 — User interaction during task

None. The dispatch was self-contained — which it now requires of itself, via the rule AC9 installs.
Every judgment call is recorded in §7 rather than raised.

### 10 — Candidate(s) captured this task

Two new rows in `seeds/cocobots/live/`, pool commit **`39e6e28`**, pushed. **New rows only — no
existing entry read or edited.**

| slug | one line |
|---|---|
| `fidelity-metric-needs-an-unconstrained-baseline` | A metric a degenerate answer maximises is not a quality measure; pair it with the same metric where the constraint is inert and report the ratio |
| `hard-vote-discards-its-own-margin` | A majority vote emits a 22% plurality and a 95% consensus identically; check the dominance distribution before letting one stand |

The first is the stronger: its control overturned the dispatch's own framing, showing the constraint
under test costs ~8 points while an unmeasured one costs ~66.

### 11 — Commit

| | |
|---|---|
| `CLAUDE.md` (AC9) | **`cee42f31ffdc77923e3a4e03e5e426fe274143ff`** |
| deliverables | **`2ac74129a0dc3a5bd6ab73ba2760d092085a55de`** |
| this report | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`39e6e28`**, pushed |

Working tree clean. No shipped asset modified; the palette is **not applied**.
