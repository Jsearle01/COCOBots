# Proposed CoCo3 palette, derived from the Amiga artwork

**Status:** PROPOSAL, C2 re-derivation, **superseded C5 by the hue-covered variant**. Not applied;
`src/graphics.asm` is untouched.

> ## Adopted palette — hue-covered
>
> ```
> $00 $3F $0E $1C $15 $2A $22 $23 $06 $07 $38 $03 $35 $01 $0A $30
> ```
>
> **Jay, 2026-08-01, on the comparison render: *"that looks slightly better"*.**
>
> The palette below minimised frequency-weighted quantisation error, which held **five blue slots
> and zero green or magenta**. Jay saw the missing colours before the measurement did — mean chroma,
> the statistic used to claim parity with the art, is a magnitude average and cannot see hue
> variety. Reserving one slot per hue band the art uses above 0.2% of pixels costs **+0.06 error**
> (83.28 → 83.34 at 221 glyphs) and puts green and magenta on screen for the first time
> (0.74% and 0.15% of rendered pixels, from 0.00%).
>
> | band | before | after |
> |---|---:|---:|
> | grey | 4 | 4 |
> | blue | **5** | **3** |
> | green | **0** | **1** |
> | magenta | **0** | **1** |
> | orange | 1 | 2 |
> | yellow | 3 | 2 |
> | red / cyan | 1 / 2 | 1 / 2 |
>
> The ladder is undisturbed: 128 → 102.34, 192 → 87.27, 221 → 83.34, 256 → 79.64. Ordering and gaps
> preserved, so the C4 verdict (221 best, 256 no real improvement) stands.
>
> **At the target configuration slot ORDER is meaningless** — inverse is removed, `NextRowInv` is
> gone, and the complement pairing carries no rendering consequence. It matters only if inverse is
> retained.
>
> Machine-readable: [`assets/palette.json`](../../assets/palette.json), which now carries this
> variant. Reproduce with `python tools/repalette.py --glyphs 221 --hue-coverage`.
> Render: [`../reports/C5-renders/hue-coverage.png`](../reports/C5-renders/hue-coverage.png).

### Compared against the palette already in the code

`graphics.asm`'s `PALETTERGB` is hand-authored with named colours — black, white, green, blue, dark
grey, light grey, brown, light blue, tanish, orange, yellow, light green, light orange, red, and
black/white again. **It covers hues deliberately**, which is the thing the frequency-weighted
derivation failed to do. Rendered on the same conversion at 221 glyphs:

| | in-code `PALETTERGB` | adopted |
|---|---:|---:|
| error | **90.12** | **83.34** |
| distinct colours | 14 of 16 | 16 of 16 |
| green pixels rendered | **0.00%** | 0.74% |
| red pixels rendered | 0.24% | 2.19% |

**Two reasons it does worse on this artwork, neither of them a criticism of the palette:**

1. **Slots 0/14 are both `$00` and 1/15 both `$3F`.** That pairing exists so `COMA`/`COMB` inverts
   black↔white cleanly — the source comment at slot 15 says as much
   (*"SOMETHING TO DO WITH THE INVERSION PROCESS???"*, answered on the next line). It is exactly
   right for a monochrome font with inverse video. **With inverse removed it buys nothing and costs
   two of sixteen slots.**
2. **Its greens are PETSCII primaries, not Amiga greens.** Slot 2 is `$10` = (0,170,0) and slot 11
   is `$12` = (0,255,0) — fully saturated. The art's greens are `$14` (85,170,0) and `$15`
   (85,170,85), muted. Nothing in the artwork is near enough to select the saturated ones, so both
   green slots sit unused and green renders at 0.00%.

**The palette was built for the PETSCII original, and does that job** — CLAUDE.md §4 records the
monochrome font as a deliberate choice to match the PET during development. It is being measured
here against a different target.

Render: [`../reports/C5-renders/incode-palette.png`](../reports/C5-renders/incode-palette.png).

#### Reclaiming the two duplicate slots

**Jay, 2026-08-01:** *"there are also two whites and two black so i can get two more colors with my
palette"*. Correct — slots 14 and 15 duplicate 0 and 1, and once inverse is removed they are free.
Measured, keeping all fourteen of the named colours untouched and only filling the two freed slots:

| variant | the two freed slots become | error | cyan px | magenta px |
|---|---|---:|---:|---:|
| yours, as-is | — (duplicates) | 90.12 | 0.00% | 0.00% |
| **yours + error-optimal** | `$03` cyan, `$0E` blue | **85.48** | 13.73% | 0.00% |
| yours + hue coverage | `$03` cyan, `$2A` magenta | 87.31 | 14.50% | 0.93% |
| (fully derived, for reference) | — | 83.34 | — | — |

**Two free slots recover 4.6 of the 6.8 gap** to the fully derived palette, without touching a
single one of your named colours. The art wants cyan badly — it goes straight to 13.7% of rendered
pixels from nothing.

**One thing not to do.** Letting the optimiser *also* retune the two saturated greens gives 84.50,
but it spends them on more blue and cyan — i.e. **it removes green from the palette entirely.** That
is the same frequency-over-importance trap that produced the original defect: green is 1.3% of art
pixels and squared error will always trade it away. The greens are worth keeping deliberately, and
retuning them to the art's muted `$14`/`$15` rather than dropping them is the version worth
rendering if this route is taken.

**Green still renders at 0.00% in all three**, because the saturated `$10`/`$12` remain unselectable
against the art's muted greens (see above). Fixing that is a separate change from reclaiming the
slots.

Render: [`../reports/C5-renders/incode-plus-two.png`](../reports/C5-renders/incode-plus-two.png)
— source, yours as-is, +cyan+blue, +cyan+magenta.

---

## The superseded derivation follows, retained as the record of how it was reached

**Machine-readable:** [`assets/palette.json`](../../assets/palette.json).
Reproduced by `python tools/palettederive.py --sheet art/Amiga_Artwork.png --objective floor`.

**Visual, for Jay:** `build/c2/palette-preview.png` — the Amiga sheet (left) beside **what the
engine would actually draw** under this palette (right): real glyph patterns, inverse cells through
15−*i*, **all 256 tiles**. Panels are labelled in the image. The strip beneath is the palette in
slot order, 0 to 15. Surfaced for inspection; this document does not say what it shows.

The render population is deliberately **wider than the derivation population**. The palette is
derived from live ∧ informative tiles only — the right filter for choosing colours that serve what
is drawn in-game. Applying that filter to the *preview* left 70 tiles black, including 15 of the
last row, which is almost entirely non-live sprite/UI tiles. The preview now draws every cell of all
256 tiles, with glyph patterns solved from the full-tileset demand so glyphs that appear only in
non-live tiles still have one.

Fifteen tiles still render flat black — `0, 1, 2, 3, 14, 23, 175, 183, 238, 239, 243, 247, 252,
253, 254`. That is correct output, not missing data: these are C1's blank tileset tiles, whose
glyphs are entirely one index, over uniform art. Verified drawn rather than skipped. Tile 255's
bottom-right cell is absent from `tileset.bin` (the file is one byte short) and is marked with a
grey check, being the only cell in the sheet that cannot be drawn at all.

> **Supersedes the first C2 derivation**, which modelled each 8×8 cell as one ink colour plus one
> paper colour. Jay corrected that: **glyphs are 16-colour capable.** `DoRegular` copies character
> bytes to the framebuffer unmodified (`PULU D,Y` / `STD ,X` / `STY 2,X`), so every one of a glyph's
> 64 pixels is an independent 4-bit palette index. Only 6.8% of art cells are describable with two
> colours; that reduction captured 69.4% of pixels and saw 26 of the 46 colours present. Everything
> below is re-derived under the correct model.

---

## 1. The proposal

```
$22 $31 $1C $06 $39 $0E $08 $07 $00 $0A $23 $30 $38 $03 $01 $3F
```

16 distinct colours, no duplicates.

| slot | `$FFBx` | RGB | ↔ slot | ↔ colour |
|---:|---|---|---:|---|
| 0 | `$22` | 170,85,0 | 15 | `$3F` |
| 1 | `$31` | 170,170,85 | 14 | `$01` |
| 2 | `$1C` | 85,170,170 | 13 | `$03` |
| 3 | `$06` | 85,85,0 | 12 | `$38` |
| 4 | `$39` | 170,170,255 | 11 | `$30` |
| 5 | `$0E` | 85,85,170 | 10 | `$23` |
| 6 | `$08` | 0,85,0 | 9 | `$0A` |
| 7 | `$07` | 85,85,85 | 8 | `$00` |

---

## 2. The engine model this is derived under

```
normal   cell shows  palette[I_p]        for each of the glyph's 64 pixels
inverse  cell shows  palette[15 - I_p]   NextRowInv COMA/COMB, per pixel
```

Choosing an index for a pixel therefore fixes **both** what it shows normally and what it shows
inverted. So a palette is characterised entirely by its **8 complement pairs** — each pixel picks
one of 16 options, being 8 pairs × 2 orientations — and *which slot a pair occupies is irrelevant*.

Only glyphs used **both** normally and inverted are constrained by the pairing; of 55 sampled
glyphs, 26 are.

---

## 3. What each constraint costs

Mean per-pixel RGB distance over all **90,688** sampled pixels (1,417 cells × 64):

| | error | added |
|---|---:|---:|
| **floor** — palette quantisation only, every cell free per pixel | **20.40** | — |
| **+ one pattern per glyph** (§2M invariant 1) | 95.08 | **+74.67** |
| **+ inverse forced through 15−*i*** (the ordering) | 98.75 | **+3.67** |

**One-glyph-one-pattern costs twenty times what the ordering costs.** The slot ordering — the thing
§2M invariant 4 warns hardest about, and the thing this dispatch was largely about — is worth 3.67
of a 98.75 residual. It is real and worth getting right, but it is not where the fidelity is.

At the floor the palette is good: **mean per-pixel error 4.58**, against the §2M first cut's 6.5.
(That 4.58 is the mean; 20.40 above is RMS, which weights the tail — both are reported so neither
flatters.)

---

## 4. Why the 16 colours are chosen on the art, not jointly

The palette is selected to minimise **floor** error — pure quantisation of the art's per-pixel
demand, weighted by how often each colour is drawn (§2M invariant 3). The pairing is then chosen to
minimise the complement cost given those 16.

**Optimising both jointly collapses the palette to 9 distinct colours** (`--objective joint`
reproduces it): when one pattern must serve many cells demanding different colours, extra palette
entries buy almost nothing, so the optimiser correctly spends slots on duplicates of the compromise
colours. That is a right answer to the wrong question — C3 will split glyphs, and a palette fitted
to the unsplit case would be baked-in wrong.

---

## 5. The lever: glyph splitting

The engine addresses 128 glyph slots; `tileset.bin` currently uses 69, and 55 carry sampled colour.
Allowing a glyph to split into K variants, cells clustered by their demanded colour vectors
(k-means in RGB, normal and inverse separated since they render through different transforms):

| variants/glyph | glyph slots | error | |
|---:|---:|---:|---|
| 1 | 55 | 98.75 | current plan |
| **2** | **95** | **93.85** | **fits the budget** |
| 3 | 131 | 83.20 | over by 3 |
| 4 | 165 | 79.02 | over |
| 6 | 228 | 72.79 | over |

**Two variants fits with 33 slots to spare; three misses by 3.** A non-uniform allocation — 3
variants for the most contested glyphs, 1 for the rest — fits inside 128 and lands between 93.85 and
83.20. That allocation is C3's to make; the machinery to evaluate it is in `tools/palettederive.py`.

**Splitting attacks the +74.67, which is where the error is.** Palette refinement attacks the 20.40.

---

## 6. Control — the derivation measures the art

Same pipeline on `coco_ArtworkSheet.png` (**DEMOTED** per §2M; a control only, no conclusion rests
on it), each palette then scored against the Amiga demand:

| palette | floor | + sharing | + complement |
|---|---:|---:|---:|
| **Amiga-derived (proposed)** | **20.40** | 95.08 | **98.75** |
| coco-derived (control) | 38.48 | 96.62 | 100.74 |

**At the floor the control is 89% worse** — the derivation is strongly art-specific. **At the actual
figure it is only 2% worse**, because sharing dominates the residual and swamps the difference.

That gap between 89% and 2% is itself the most useful number here: **at one variant per glyph the
palette choice barely shows.** It only starts to pay once splitting reduces the sharing cost — which
is a direct argument for C3 doing splitting first and palette refinement second.

---

## 7. Limits

- **Not applied, not gated.** A still is not a live gate (§4).
- **The art is a JPEG.** Every pixel is snapped to the GIME 64 before anything else. Re-runnable if
  lossless art appears.
- **`image.png` colours were not used anywhere** — structure oracle only (§2M, Jay's ruling).
  Colour derives solely from `Amiga_Artwork.png`. `ATTRIB_TO_MAP_TBL` was not consulted (§2K0).
- **Weighting is per drawn cell**, not per level appearance. Not re-tested under this model; still
  open from the first derivation.
- **The variant clustering is a lower bound on what C3 can do.** k-means on raw demand vectors with
  deterministic seeding; a smarter split, or one that also chooses *which* glyph to reuse, would do
  better. The numbers are a floor for the splitting benefit, not a ceiling.
- **17 non-informative and 8 unmatched tiles carry no sample.** Glyphs appearing only there have
  nothing to vote with and C3 must fall back.
- **Slot 0 is treated as having no special status.** If `$FF9A` (border) or anything else cares what
  sits at index 0, that is unmodelled.
