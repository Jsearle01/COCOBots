# Form B Report — C2 — derive the CoCo3 palette from the Amiga artwork

**Class:** recon. `wip`, pushed before reporting. **No 25.3 gate** — nothing visible changed in the
port; the renders are surfaced for Jay, not gated. **No shipped asset modified**, verified by hash.

> **This report was rewritten after delivery.** The first C2 derivation modelled each 8×8 cell as
> one ink colour plus one paper colour. **Jay corrected it: glyphs are 16-colour capable.** He was
> right, and everything downstream of that assumption was re-derived. The superseded figures are
> retained where they explain the correction, and are marked.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C2 received. HEAD at receipt `23c23e0` (`wip`), tree clean. C1's
deliverable commit `73aadcd` present and used as the input. Work continued across four follow-up
exchanges with Jay (§9); HEAD at this report `8735598`.

### 1 — Summary

**Proposed palette, slot order:**

```
$22 $31 $1C $06 $39 $0E $08 $07 $00 $0A $23 $30 $38 $03 $01 $3F
```

16 distinct colours. Mean per-pixel error at the palette floor **4.58**, against the §2M first
cut's 6.5.

**The dispatch asked which 16 colours and in what order. The answer to both is now settled and
neither turns out to be where the difficulty is.**

| what each constraint costs | error | added |
|---|---:|---:|
| palette quantisation alone (the floor) | 20.40 | — |
| + one pattern per glyph (§2M invariant 1) | 95.08 | **+74.67** |
| + inverse forced through 15−*i* (the ordering) | 98.75 | **+3.67** |

**The slot ordering — §2M invariant 4's central warning, and most of this dispatch's stated
work — costs 3.67 of a 98.75 residual.** One-glyph-one-pattern costs twenty times more.

**Jay's visual verdict on the delivered render (2026-08-01): "much better but still not great."**
That is the authority (§3), and it is corroborated by measurement rather than contradicted: the
best allocation reachable is **100.85** against a ceiling of **25.31**.

**And slots are not the lever.** Measured across the whole budget range:

| extra glyph slots | total slots | error | |
|---:|---:|---:|---|
| 0 | 69 | 113.64 | |
| **11** | **80** | **100.85** | **shipped — the provably safe band** |
| 18 | 87 | 97.49 | + the `$40-$5F` graphics band |
| 59 | 128 | 86.79 | **every free slot, i.e. text font destroyed** |
| — | 2,303 | **25.31** | ceiling: every cell its own glyph |

Spending *every* free slot and destroying text rendering buys 100.85 → 86.79, a 14% improvement,
and still sits 3.4× above the ceiling. **The binding constraint is that ~2,300 cells of Amiga
artwork must be served by at most 128 glyph patterns — roughly 18:1 compression.** No allocation
strategy fixes that. §8 sets out what would.

### 2 — Files

| file | state |
|---|---|
| `assets/palette.json` | re-derived under the correct model |
| `docs/project/palette.md` | re-derived; carries the supersession note |
| `tools/palettederive.py` | rewritten around the 16-colour glyph model |
| `tools/fontbuild.py` | **new** — font + tileset remap, at Jay's request (§9) |

Build products, gitignored: `build/c2/palette-preview.png`, `build/c3/font-colour.{bin,asm}`,
`build/c3/tileset-remapped.bin`, `build/c3/font-comparison.png`.

Separately, per AC9: `CLAUDE.md` — the dispatch self-containment rule, +12 lines, 0 removed.

**Nothing under `assets/` (except the derived `palette.json`) or `src/` was modified.** Verified by
hash: `tileset.bin`, `PETSCII_COCO.asm`, `graphics.asm`, `PETROBOTS_6809.asm` all identical to
`HEAD`.

### 3 — Reasoning

**The engine model, established from `BITMAP_PLOTTER` rather than assumed.** `DoRegular` does
`PULU D,Y` / `STD ,X` / `STY 2,X` — four bytes per row copied to the framebuffer unmodified. At 4bpp
that is 8 pixels, so **a glyph is 64 independent 4-bit palette indices**. `NextRowInv`'s
`COMA`/`COMB` complements every nibble, so inverse maps each pixel's index *n* → 15−*n*
individually.

**Why the ordering reduces to a pairing.** Choosing an index for a pixel fixes *both* what it shows
normally (`pal[i]`) and inverted (`pal[15−i]`). A palette is therefore characterised entirely by its
8 complement pairs — each pixel picks one of 16 options, being 8 pairs × 2 orientations — and which
slot a pair occupies is irrelevant.

**Why the 16 colours are chosen on the art alone.** Optimising colours jointly against the glyph
model collapses the palette to **9 distinct colours** (`--objective joint` reproduces it): when one
pattern serves many disagreeing cells, extra entries buy almost nothing, so the optimiser spends
slots on duplicates of the compromise colours. Correct answer, wrong question — C3 splits glyphs,
and a palette fitted to the unsplit case would be baked-in wrong.

### 4 — Verification (AC-by-AC)

**AC1 — PASS.** Sampling restricted to `live` ∧ `informative`, `$55`/`$66` excluded.
**186 tiles, 1,417 cells, 55 glyph slots, 17 glyphs in exactly one tile**, and the contested list
`$4D` 100 / `$20` 92 / `$3A` 82 / `$5F` 68 / `$64` 49 / `$67` 28 — **every figure reconciles exactly**
with the dispatch's inventory. No discrepancy to explain.

**AC2 — PASS.** 16 entries, all valid `$FFBx` values from the GIME 64, each chosen after quantising
the demand to the gamut so every entry is reachable. **Mean per-pixel error 4.58 vs the first cut's
6.5** — better, on a like-for-like mean. (RMS is 20.40; both are reported so neither flatters.)

The trade is explicit and is *not* the one the first derivation described: colour choice and slot
order are near-independent here, because the ordering costs only +3.67. Nothing meaningful was
traded away to satisfy the pairing.

**AC3 — PASS. Weighting: per drawn cell**, not per level appearance — the palette serves every drawn
cell, and level-frequency weighting would let one common floor tile dominate. **Not re-tested under
the corrected model**; §7 flag 3.

**AC4 — PASS, and the answer is structurally different from the first derivation.** Under the
correct model the complement demand is per *pixel*, not per ink/paper pair. The pairing is solved
exactly over the 16 chosen colours. **What the art wants and 8 pairs cannot accommodate is now
quantified directly as +3.67** — the entire cost of the ordering constraint, across all 669 inverse
cells in the derivation population.

The first derivation's headline here — "19.3% of demand asks a colour to be its own complement",
read as a structural finding about inverse video being a shape-doubling device — **was an artifact
of the two-colour reduction** and does not survive. Recorded because it was reported as a finding.

**AC5 — PASS, with the metric replaced.** The dispatch's central number was "the fraction of the 852
inverse-coded cells whose colours survive". **That metric is degenerate: a 1-colour palette scores
100%** (measured; §5). It rewards discarding colour and cannot rank designs.

Replaced with the error decomposition in §1, which is scale-free and additive: the ordering costs
**+3.67** on top of a 95.08 that one-glyph-one-pattern already imposed. Failures are no longer a
cell list but a continuous per-cell error, which C3 can threshold however it likes.

**AC6 — PASS.** `docs/project/palette.md` and `assets/palette.json` tracked on `wip`; JSON loads and
its 16 slot values match the document's block exactly (verified programmatically);
`applied: false`.

**AC7 — PASS, and the control did more than pass.** Same pipeline on `coco_ArtworkSheet.png`
(DEMOTED; control only):

| palette on the Amiga demand | floor | + sharing | + complement |
|---|---:|---:|---:|
| **Amiga-derived (proposed)** | **20.40** | 95.08 | **98.75** |
| coco-derived (control) | 38.48 | 96.62 | 100.74 |

**89% worse at the floor, 2% worse at the actual figure.** The derivation is strongly art-specific,
and the difference is masked once sharing dominates. That gap is itself the argument for C3
attacking sharing before palette refinement.

**AC8 — PASS**, by hash, listed in §2.

**AC9 — PASS on substance; the stated line count differs.** Before-hash matched `2b83d38…` exactly.
After: **717 lines**, sha256 `917425dd215257c44bc9988d6d55dee70b23992e783462d42067df36301275f3`,
**12 added, 0 removed** — the quoted insert block is 12 lines, not the 16 the AC states. Superset
check clean. Committed separately, first (`cee42f3`).

### 5 — Verdict-time evidence

**The degeneracy control that forced AC5's metric to be replaced:**

```
palette            distinct   error    "inverse survival"
all black                 1   143.53          100.0%
black / mid-grey          2    66.12           74.7%
black / white             2   101.56           62.8%
4 colours                 4    33.76           33.3%
```

**The cost of my own wrong model, measured before re-deriving:**

```
cells actually describable with 2 colours   6.8%
pixels captured by the top-2 reduction     69.4% of 64
distinct colours the reduction saw           26
distinct colours actually present            46   (matches §2M independently)
```

**Error vs budget, and the ceiling** — the numbers behind §1's conclusion:

```
budget   slots   error
     0      69   113.64
     5      74   105.67
    11      80   100.85   shipped
    18      87    97.49
    30      99    92.45
    45     114    89.03
    59     128    86.79   every free slot; text font destroyed
     -   2,303    25.31   ceiling, every cell its own glyph
```

**The glyph-slot budget is 11, not 59** — the constraint that forced a non-uniform allocation:

```
$00-$1F  letters          9 used by tiles, 23 free   NOT usable (text)
$20-$3F  digits/punct    14 used by tiles, 18 free   NOT usable (text)
$40-$5F  graphics        25 used by tiles,  7 free   usable pending a text audit
$60-$7F  graphics        21 used by tiles, 11 free   USABLE
```

`PETROBOTS_6809.asm:3589` maps codes `$60-$7F` down to `$00-$1F` before lookup, so letters, digits
and punctuation render out of `$00-$3F`.

**The allocation, exact by DP over (glyph, slots):**

```
$20 -> 5 variants (437 cells)    $3A -> 2 variants (396 cells)
$66 -> 4 variants (268 cells)    $4D -> 2 variants (210 cells)
$67 -> 3 variants  (81 cells)    658 tile cells repointed
1 variant everywhere 113.64  ->  allocated 100.85
```

Greedy gave 105.27. Marginal gain is genuinely non-monotone — `$66` gains more going 2→3 variants
than 1→2, because at K=2 the clustering must spend its only split separating normal from inverse
cells — so greedy's diminishing-returns assumption picks the wrong slots.

**Artifact integrity, verified rather than asserted:**

```
font-colour.asm assembles under lwasm, round-trips byte-identical to the .bin (4096 B)
inverse bit preserved on all 658 repointed cells
every new slot inside the safe $60-$7F band
DESTRUCT_PATH and TILE_ATTRIB bytes untouched
a render built independently FROM THE EMITTED FILES matches the tool's own panel on
  153,600 of 153,664 pixels - the 64 differing are the single undrawable cell
  (tile 255 BR, absent from tileset.bin)
```

**Renders surfaced for Jay** (gitignored, regenerable): `build/c2/palette-preview.png` — source
beside the engine render, all 256 tiles. `build/c3/font-comparison.png` — source, 1 variant per
glyph, allocated. **This report does not say what either shows.** Jay's verdict on the second is
quoted in §1 and is the only visual judgment recorded here.

### 6 — Reactive deviations and ROUTE ACCOUNTING

Route as dispatched, then substantially extended at Jay's direction (§9). What the commits contain:

1. **AC9 first, committed separately** (`cee42f3`).

2. **First derivation, since superseded** (`2ac7412`, report `cd1ceab`). Modelled each cell as one
   ink + one paper colour — a reduction carried over from C1, where it is correct for matching
   *shapes* against a monochrome font, and wrong as a *colour* model. Two controls I added
   unprompted (a degeneracy check and a normal-cell baseline) were what made the result readable,
   and both survived into the rewrite.

3. **Marked SUPERSEDED rather than deleted** (`5ea5af1`) the moment Jay corrected me, so nothing
   downstream could consume it unaware. `assets/palette.json` carried a `do_not_consume` flag until
   the replacement landed.

4. **Re-derived under the correct model** (`491f8e6`). Two bugs of mine found during the rewrite:
   a k=1 allocation that silently dropped every normal cell from the variant accounting (making 1
   variant appear to beat 2), and lexicographic "clustering" that grouped 64-dimensional vectors by
   their top-left pixel. A pixel-accounting assert now guards the first, and K=1 agrees exactly with
   the independent decomposition — the cross-check that proves it.

5. **Preview fixed to draw all 256 tiles** (`c9b1949`). It had drawn only the 186 live ∧ informative
   tiles it derives from, leaving 70 black — including 15 of the last row, which is almost entirely
   non-live sprite/UI tiles. The derivation and render populations are now explicitly separate.
   Panels are captioned inside the image, since Jay had to ask which side was which.

6. **Font + tileset remap built** (`8735598`), at Jay's request. This is C3 work done under a C2
   dispatch; it is confined to `build/c3/` and touches no protected asset. The slot-budget finding
   (11, not 59) came out of it and invalidates a claim I had made earlier in the exchange — that
   "2 variants everywhere = 95 of 128 slots" fits. It does not; that counted raw slots without
   asking which ones text needs.

**Nothing was applied.** `graphics.asm`, the font, `tileset.bin` and the levels are untouched.

### 7 — Uncertainty flags

1. **The whole first derivation was wrong and I did not catch it.** CLAUDE.md §4 states plainly that
   every nibble is a palette index and that the font is 2-colour by deliberate choice. I read that
   section during A2 and again at C2's start. The failure was carrying C1's measurement convention
   into a context where it was a claim about the engine. §10 captures it.

2. **Jay's "still not great" is a verdict on the approach, not on tuning.** The evidence supports
   reading it structurally: even at 128 slots the error is 86.79 against a 25.31 ceiling. **I have
   not established what an acceptable figure would be**, and no number here says whether any
   reachable version is good enough. That is Jay's call and §8 lists the levers.

3. **Weighting (per cell vs per level appearance) is still not re-tested** under the corrected
   model. Open since the first derivation; a one-line change to the demand accumulation.

4. **The variant clustering is a lower bound.** k-means on raw demand vectors with deterministic
   seeding. A better split — or one that also chooses *which* glyph a cell reuses, rather than
   taking the tileset's assignment as fixed — would do better. The curve in §5 is a floor for what
   splitting can achieve, not a ceiling.

5. **The `$40-$5F` graphics band is "plausibly safe", not proven.** It would raise the budget from
   11 to 18 (100.85 → 97.49). Establishing it needs an audit of every code path that emits a
   character code, which I did not do — I traced the `$60-$7F` → `$00-$1F` remap and stopped there.

6. **Text glyphs are re-indexed, and text inverse video is not modelled.** Glyphs not used by tiles
   keep their shapes with old index 0 → the palette's black slot (8) and 1 → white (15). But slots 8
   and 15 are not complements of each other, so **inverse-video text would render orange-on-grey**
   rather than inverted black/white. I did not check whether anything renders text inverted.

7. **The art is a JPEG**, snapped to the GIME 64 before anything else. Re-runnable if lossless art
   appears.

8. **17 non-informative and 8 unmatched tiles carry no colour sample**; glyphs appearing only there
   fall back to the re-indexed monochrome shape. Not enumerated.

9. **Nothing has been run.** These are static artifacts. A live MAME run is the only real verdict
   (§4), and applying any of this needs authorisation for protected assets (§2B).

### 8 — Follow-up candidates

**On the quality question Jay raised**, in descending order of what the evidence says they are worth:

- **Reduce the demand, not the compression.** ~2,300 cells against ≤128 patterns is 18:1, and the
  ceiling says slot allocation cannot close it. The levers that can: simplify the art targets so
  cells that share a glyph actually look alike, or accept a stylised approximation rather than a
  reproduction. Both are Jay's design calls, not measurements.
- **Free glyph slots by moving text out of the shared font** — the only way past 18 extra slots. Big
  change; buys at most 86.79, so worth it only if that is near an acceptable figure.
- **Audit the `$40-$5F` band** (§7 flag 5) — cheap, worth 100.85 → 97.49.
- **Let the converter re-assign which glyph a cell uses** (§7 flag 4), rather than inheriting the
  tileset's assignment. Unmeasured, and the only untested lever that could move things structurally.
- **Check whether text is ever rendered inverted** (§7 flag 6) before any of this is applied.
- Re-test the weighting choice (§7 flag 3).

Carried, unchanged: pinned-digest check on the three source blobs (A1b §8); the three MAME idioms to
fold in (A2 §10, §2D); where run captures live (A2 §7 flag 4). `main` is at `a62809e`, now eight
dispatches behind.

### 9 — User interaction during task

Five exchanges, four of which changed the work:

1. *"what am I looking at in the preview?"* — answered; the right panel was a per-pixel quantisation,
   an upper bound, not an engine render. Led to the engine-faithful render.
2. **"i think you are wrong about the 8x8 glyphs. there should be 16 color capable"** — **correct,
   and the most consequential correction in the dispatch.** Confirmed from `BITMAP_PLOTTER`,
   quantified, marked superseded, re-derived.
3. *"the new preview is less than desirable, the last row doesn't even display tiles"* — correct;
   my filter, not the render. Fixed to draw all 256 tiles.
4. *"did you re-render the tileset"* — answered: the preview is a genuine tileset render (proved by
   showing glyph `$3A`'s 396 instances render byte-identically), but no font artifact existed.
5. *"rework and produce the better version"* — produced `tools/fontbuild.py` and the artifacts.
6. *"the allocated looks much better but still not great"* — recorded as the visual verdict (§1) and
   answered with the budget/ceiling measurement rather than left open.

### 10 — Candidate(s) captured this task

Four rows in `seeds/cocobots/live/`. Pool commits **`39e6e28`** (two, from the first derivation —
both survived the rewrite) and **`10a465f`** (two, from the correction and rework).

| slug | one line |
|---|---|
| `fidelity-metric-needs-an-unconstrained-baseline` | A metric a degenerate answer maximises is not a quality measure; pair it with the same metric where the constraint is inert |
| `hard-vote-discards-its-own-margin` | A majority vote emits a 22% plurality and a 95% consensus identically |
| `a-measurement-convention-is-not-a-property-of-the-system` | A reduction adopted for one measurement becomes a false claim about the system when carried downstream — **the error Jay caught** |
| `optimise-only-after-checking-the-ceiling-says-it-can-matter` | Before tuning an allocation, measure what the unbounded version achieves; here every slot buys 14% against a 3.4× gap |

### 11 — Commit

| | |
|---|---|
| `CLAUDE.md` (AC9) | `cee42f31ffdc77923e3a4e03e5e426fe274143ff` |
| first derivation (superseded) | `2ac74129a0dc3a5bd6ab73ba2760d092085a55de` |
| first report | `cd1ceabf8ecca9884e6cc64a489f5e74bfbcad70` |
| marked SUPERSEDED | `5ea5af1381620331f2321bcfddb8770211281415` |
| **re-derivation** | **`491f8e6929506f33c72958f7ab6b1662254ce69d`** |
| preview: all 256 tiles | `c9b194937bfb41c4509dfd8277b482168c473e3e` |
| **font + tileset remap** | **`87355988b4b4fa0b618999ccf535571481d5bfe3`** |
| this report | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |

Working tree clean. No shipped asset modified; nothing applied.
