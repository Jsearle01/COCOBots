# Proposed CoCo3 palette, derived from the Amiga artwork

**Status:** PROPOSAL, C2 recon, 2026-08-01. **Not applied.** `src/graphics.asm` is untouched; C3
applies this, after Jay has seen it.

**Machine-readable:** [`assets/palette.json`](../../assets/palette.json) — slot order, per-slot
provenance, the complement pairing with its evidence, and the inverse-failure list by tile.
Reproduced by `python tools/palettederive.py --sheet art/Amiga_Artwork.png --j 1`.

**Visual comparison for Jay:** `build/c2/palette-comparison.png` — the Amiga sheet, the same sheet
quantised to the proposed 16, and the slot-order swatch strip. Surfaced for inspection; this
document does not say what it shows.

---

## 1. The proposal

```
$00 $07 $0A $3F $0E $22 $03 $30 $3C $23 $39 $1C $06 $01 $38 $00
```

| slot | `$FFBx` | RGB | ↔ slot | ↔ colour | |
|---:|---|---|---:|---|---|
| 0 | `$00` | 0,0,0 | 15 | `$00` | **self-paired** |
| 1 | `$07` | 85,85,85 | 14 | `$38` | |
| 2 | `$0A` | 0,85,170 | 13 | `$01` | |
| 3 | `$3F` | 255,255,255 | 12 | `$06` | |
| 4 | `$0E` | 85,85,170 | 11 | `$1C` | |
| 5 | `$22` | 170,85,0 | 10 | `$39` | |
| 6 | `$03` | 0,85,85 | 9 | `$23` | |
| 7 | `$30` | 170,170,0 | 8 | `$3C` | |

15 distinct colours in 16 slots — `$00` occupies slots 0 and 15 deliberately (§4).

| metric | value |
|---|---|
| weighted mean error | **2.093** |
| complement demand satisfied | 19.2% |
| normal-cell survival | **34.2%** (256 / 748) |
| inverse-cell survival | **25.9%** (173 / 669) |
| ordering efficiency (inverse ÷ normal) | **75.6%** |

---

## 2. What was sampled

Rows of `assets/tile-correspondence.json` with `live` **and** `informative` true — filtering on
`informative` rather than `confidence`, per C1 §8, because a blank tile scores 1.000 against any
uniform art tile and carries no colour. Cells whose glyph is `$55` or `$66` are excluded; both are
corrupt and are the only two glyphs in the addressable font with nibbles outside {0,1}.

**186 tiles · 1,417 cells · 55 glyph slots**, reconciling exactly with the dispatch's inventory.
Of those cells, **748 render normally and 669 inverted**.

Each cell's two dominant colours (quantised to the GIME 64 first, so every candidate is reachable)
are split into ink and paper by majority vote **against the glyph's own ink mask** — the assignment
comes from the tileset side, not from guessing which art colour is foreground.

**Weighting: cell count in the tileset**, not tile appearance in the ten levels. Both are defensible
and they are not the same. Cell count was chosen because the palette must serve every *drawn cell*,
and a tile appearing 300 times in one level contributes the same nine cells' worth of colour demand
as one appearing 3 times — level frequency would let one common floor tile dominate the palette.
Reported so the choice is visible and reversible; §7 of the report records the comparison.

---

## 3. Why the ordering reduces to a pairing

A glyph carries palette **indices** in its nibbles — say index *I* for ink pixels, *P* for paper.
Rendered normally a cell shows `(pal[I], pal[P])`. `NextRowInv` complements all four bits, so
rendered inverted it shows `(pal[15−I], pal[15−P])`.

The same glyph is used in both kinds of cell. So if the art wants *A* where the glyph appears
normally and *C* where it appears inverted, **A and C must sit at complementary indices.**

Two consequences:

- **Which index-pair a colour-pair occupies does not matter.** Every pair (*i*, 15−*i*) is
  equivalent, and swapping within a pair only relabels *I* and *P*. The ordering problem is
  therefore *partitioning the 16 colours into 8 complement pairs* — a maximum-weight perfect
  matching, solved exactly here by DP over subsets.
- **Only glyphs used both ways constrain anything.** Of 55 sampled glyphs, **26** are used both
  normally and inverted; the other 29 are free.

---

## 4. The complement demand — and why no clean solution exists

Demand is built as a **soft outer product over cell pairs**, not a majority vote. Majority is
brittle here: the modal colour's dominance ranges from **22% to 99%** across glyphs, so a hard vote
would assert a constraint from a 22% plurality as confidently as one from a 95% consensus.

**Total demand spreads over 200 distinct pairs.** The heaviest is 9.7%.

| demanded pair | weight |
|---|---:|
| `$00` ↔ **itself** | 9.7% |
| `$00` ↔ `$07` | 8.7% |
| `$07` ↔ **itself** | 8.5% |
| `$07` ↔ `$38` | 6.6% |
| `$00` ↔ `$38` | 6.6% |
| `$00` ↔ `$0E` | 4.1% |
| `$07` ↔ `$1C` | 3.5% |
| `$06` ↔ `$07` | 2.6% |

**19.3% of demand asks a colour to be its own complement** — satisfiable only by placing the same
colour at both *i* and 15−*i*, spending two slots on one colour.

**That self-pair demand is a real structural finding.** It means the inverse bit in this tileset is
being used as a **shape-doubling device, not a colour-inversion device**: the art wants the *same*
colours whether the glyph is drawn normally or inverted. Under a monochrome font, inverse video buys
a second shape for free. Under a coloured font, that same trick imposes a colour constraint.

**Eight slot-pairs cannot cover 200 demands.** Each slot-pair serves *either* one demanded
complement *or* colour coverage — never both. The frontier:

| pairs spent on demand | demand met | error | distinct | normal | inverse | efficiency |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 9.3% | 1.63 | 16 | 31.3% | 17.3% | 55.4% |
| **1** | **19.2%** | **2.09** | **15** | **34.2%** | **25.9%** | **75.6%** |
| 2 | 19.0% | 2.60 | 14 | 34.6% | 26.0% | 75.1% |
| 3 | 27.5% | 4.18 | 12 | 42.6% | 28.8% | 67.6% |
| 4 | 36.4% | 5.50 | 11 | 46.5% | 27.8% | 59.8% |
| 8 | 50.3% | 25.77 | 6 | 46.8% | 41.1% | 87.8% |

**j = 1 is the knee**, and is the proposal. One slot-pair on `$00` ↔ itself costs +0.46 error and
one distinct colour, and lifts inverse survival 17.3% → 25.9% and ordering efficiency 55.4% → 75.6%.
j = 2 buys nothing over j = 1 and costs another colour. Past j = 3 the palette collapses toward
monochrome.

---

## 5. Reading the survival numbers — the metric is not scale-free

**A 1-colour palette scores 100% inverse survival.** Measured:

| palette | distinct | error | inverse survival |
|---|---:|---:|---:|
| all black | 1 | 143.53 | **100.0%** |
| black / mid-grey | 2 | 66.12 | 74.7% |
| black / white | 2 | 101.56 | 62.8% |
| 4 colours | 4 | 33.76 | 33.3% |
| **proposed (j=1)** | **15** | **2.09** | **25.9%** |

So the raw fraction is **not** a quality measure — it is trivially maximised by throwing colour away.
The meaningful quantity is **inverse survival relative to normal survival at the same palette**:
normal cells face no complement constraint whatsoever, so their rate is the ceiling that
one-glyph-one-colour alone imposes, and the ratio isolates what the slot *order* costs.

**And that reframes the result.** Normal cells survive at only **34.2%**. The dominant loss is not
the ordering — it is **§2M invariant 1, one glyph one colour**. The ordering's marginal cost is the
gap: 34.2% → 25.9%, about 8 points.

---

## 6. The real lever for C3: glyph splitting

§2M lists a second pass splitting contested glyphs into variants as *optional*. **It is not
optional — it is the main lever**, and it is bounded.

319 distinct (glyph, ink, paper) demands exist across 1,417 cells. Against the engine's 128
addressable glyph slots:

| colour variants per glyph | cells satisfiable | glyph slots needed |
|---:|---:|---:|
| 1 (as now) | 36.3% | 55 |
| 2 | 55.0% | 93 |
| **3** | **65.2%** | **122** |
| 4 | 71.8% | 146 ✗ |
| 6 | 80.4% | 183 ✗ |

**Three variants per glyph is the practical ceiling** — 122 of 128 slots — and caps cell
satisfaction near **65%**. Reaching 90% would need 235 slots and is impossible on this engine.

Most colour-contested glyphs: `$4D` (46 distinct demands over 163 cells), `$20` (34 / 269),
`$5F` (27 / 116), `$3A` (15 / 276), `$67` (15 / 69), `$64` (13 / 140).

---

## 7. Control — the derivation measures the art, not itself

The same pipeline run on `coco_ArtworkSheet.png` (**DEMOTED** per §2M; used only as a control, no
conclusion rests on it), then each palette scored against each sheet's demand:

| palette | on Amiga | on coco sheet |
|---|---:|---:|
| **Amiga-derived** | **2.093** | 1.804 |
| coco-derived | 18.335 | 0.120 |

**The wrong-sheet palette is 8.8× worse on the Amiga art.** Zero of 16 slots coincide; 9 of 16
distinct colours are shared. The demand structures differ too — 200 pairs vs 91, heaviest
`$00`↔itself (9.7%) vs `$07`↔`$38` (15.5%).

---

## 8. Limits

- **Not applied, and not gated.** A still is not a live gate (§4). The render is for inspection.
- **The art is a JPEG.** Every pixel is snapped to the GIME 64 before anything else, which absorbs
  some quantisation noise, but 26 distinct colours were demanded where a lossless source might give
  fewer and cleaner. Re-runnable if lossless art appears — that is why the tool is a deliverable.
- **`image.png` colours were not used anywhere.** It is the structure oracle only (§2M, Jay's
  ruling). Colour derives solely from `Amiga_Artwork.png`.
- **`ATTRIB_TO_MAP_TBL` was not consulted** (§2K0).
- **17 non-informative and 8 unmatched tiles carry no sample.** C3 must fall back for any glyph
  appearing only in them.
- **Slot 0 has no special status here.** If the border register `$FF9A` or any other consumer cares
  which colour sits at index 0, that constraint is not modelled.
