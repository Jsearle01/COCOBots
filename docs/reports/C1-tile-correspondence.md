# Form B Report — C1 — artwork ↔ tileset correspondence recon

**Class:** recon. `wip`, pushed before reporting. **No gate** — this dispatch produces measurements
and a table, nothing 25.3-able. **No data changed:** no font, no tileset, no level, no source.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C1 received. HEAD at receipt `fcb50f8` (`wip`), tree clean. A3 had
landed, so §2M and the §7 delivery convention were current when read.
HEAD at report `73aadcd` + this report's commit.

### 1 — Summary

**Verdict: identity holds.** Sheet index *n* corresponds to tileset index *n*.

| | |
|---|---|
| mean identity agreement | **0.9315** (crude prior method 0.830) |
| median | **0.9453** |
| null — all 64,770 non-identity pairs | 0.7757 |
| separation | **+0.1557**, 1.73 sd of the null |
| identity best of 256 / top-3 / median rank | 148 / 175 / **1** |

**No consistent alternative mapping exists.** 41 tiles have something outscoring identity by >0.05,
but those 41 claim only **19 distinct indices** — 154 twelve times, 0 six times, 244 four times.
A remapping would be near-bijective; these are attractors, a property of the measure.

**Independent structural corroboration, not fitted:** 17 blank tileset tiles vs 18 uniform art
tiles, agreeing on 15, with 2 of the 3 differences being the fully-masked tiles 214 and 227.

**The cleanup queue is the deliverable that matters:** 152 `high`, 96 `low`, 8 `unmatched`;
104 not-high of which **81 are live**.

Two things nearly went wrong and are the substance of §6: a tie-breaking artifact almost caused a
sound analysis to be reported as unsound, and the headline improvement was uninterpretable until
the controls were re-run.

### 2 — Files modified

Nothing modified — four files added, all new:

| file | what |
|---|---|
| `assets/tile-correspondence.json` | 256 rows, the artifact C3 loads |
| `assets/tile-correspondence.csv` | same data, flat |
| `docs/project/tile-correspondence.md` | verdict, method, confidence rules, cleanup queue |
| `tools/tilecorr.py` | reproduces all of it |

**AC8 verified by hash, not by `git status` alone** — `assets/tileset.bin`,
`assets/levels/level_a.bin`, `src/PETSCII_COCO.asm` and `src/PETROBOTS_6809.asm` all hash identical
to `HEAD`. §5.

### 3 — Reasoning

**Both output formats, not one.** The dispatch left JSON-or-CSV to me; I shipped both from a single
code path. The table is consumed by C3 (JSON, typed, with metadata: sheet, origin, pitch,
thresholds) and read by a human during hand-cleanup (CSV, sortable in anything). They cannot drift —
same rows, one writer.

**Geometry derived, not assumed** (CLAUDE.md §3: derive anchors fresh, never reuse recorded
coordinates). Column/row edge-energy periodicity gives pitch 24, phase 23 on both axes for all three
sheets independently — a 16×16 grid of 24×24 tiles at origin (0,0), 8 px residual band.

**Confidence needed two axes.** Absolute agreement alone passes a tile scoring 0.95 that forty other
indices also match — agreement without discrimination. Rank alone passes a tile ranking first at
0.70 — best of a bad field. `high` requires score ≥ 0.90 **and** rank ≤ 3.

### 4 — Verification (AC-by-AC)

**AC1 — PASS.** Both sides rendered per §3; the exact art-side reduction is stated in §5 and in
`docs/project/tile-correspondence.md` §4, and is reproducible by
`python tools/tilecorr.py --sheet art/image.png`.

**AC2 — PASS.** Identity scored for all 256 (254 scoreable; 214 and 227 fully masked).
Mean **0.9315**, median **0.9453**, min 0.500, max 1.000, sd 0.0730.

```
0.00-0.60 :   1        0.80-0.90 :  55
0.60-0.70 :   2        0.90-0.95 :  62
0.70-0.80 :  11        0.95-1.00 : 123
```

**Movement against the 0.830 baseline: +0.101.** Explained in §5 — the method sharpened, and the
controls prove it rather than assert it.

**AC3 — PASS, and the figures are reported with the correction that made them meaningful.**
Over all 256×256 pairs:

| figure | value |
|---|---|
| identity is at the maximum | **148 / 254** |
| identity is the *unique* maximum | 120 / 254 |
| some index beats identity by >0.05 | **41** |
| distinct indices claimed | **152 / 256** |

152 is far short of 256, so **no remapping is proposed** — per the dispatch's own instruction. The
reason it is short is measured, not guessed: the median tie count at the maximum is 1 but the mean
is 3.1, and the ties are concentrated in the low-information tiles. §6 item 1.

**AC4 — PASS.** All eight blank anchors score **1.0000 at rank 1**, and all eight are `high`:

```
tile   0  1.0000  rank 1  high      tile 238  1.0000  rank 1  high
tile   1  1.0000  rank 1  high      tile 239  1.0000  rank 1  high
tile  14  1.0000  rank 1  high      tile 253  1.0000  rank 1  high
tile 175  1.0000  rank 1  high      tile 254  1.0000  rank 1  high
```

Checked for genuineness rather than accepted: all eight **art** tiles are entirely uniform (1
distinct quantised colour in every cell) and all eight **tileset** tiles render entirely blank. And
checked for degeneracy: a blank tileset tile scores 1.000 against exactly **18 of 256** art indices —
the uniform ones — not against everything. The anchor check is therefore weak-but-real, and is
flagged as such (§7 flag 2).

**AC5 — PASS.** Both files exist, tracked, on `wip`. JSON loads; 256 rows; tile indices exactly
0–255; every §2 field populated. Thresholds (`high` 0.90, `low` 0.75) stated in the file's metadata
block and justified in `docs/project/tile-correspondence.md` §2.

**AC6 — PASS. Verdict: identity holds**, in the dispatch's first form, with the residue
characterised. Exceptions: 8 `unmatched` — `[24, 169, 205, 214, 223, 227, 246, 250]` — of which 214
and 227 are unscoreable by construction. Evidence in §5.

**AC7 — PASS.** Cleanup queue ordered ascending by confidence, live first, then worst score. 104
not-high, 81 live. Head of queue and the full ordering rule are in
`docs/project/tile-correspondence.md` §6; the JSON supports the sort directly.

**AC8 — PASS.** §5.

### 5 — Verdict-time evidence

**The art-side reduction, exactly** (AC1 — a future dispatch must reproduce this). Per **8×8 cell**,
independently: quantise every pixel to the GIME gamut (2 bits per channel → {0,85,170,255}); take
the two most frequent quantised colours by pixel count; assign each pixel to whichever of the two it
is nearer in RGB. Per-cell, not per-tile, because the engine's inverse bit is per character. Tileset
side is exact: glyph `code & $7F` from the 128-glyph font at `$41F6`, inverse when the high bit is
set, reducing to an 8×8 boolean. Cells whose glyph is `$55` or `$66` are masked.

**Masking figures reproduce the dispatch exactly** — and identify *why* those two glyphs:

```
mask by code & 0x7F  -> 290 cells masked, across 101 tiles; fully-masked: [214, 227]
mask by raw code     -> 268 cells masked, across  91 tiles; fully-masked: [214, 227]
```

The dispatch's 290 / 101 / [214,227] matches the 7-bit form. **$55 and $66 are, verified, the only
two glyphs in the entire font holding nibbles outside {0,1}** ($55 has values {0,1,4,9} over 34 px;
$66 has {0,3,4,5,7} over 43 px), used in 22 and 268 cells. So after masking, every scored cell is
strict binary — the reduction loses nothing.

**AC3 — the load-bearing numbers, and the correction behind them:**

```
                              identity-at-max   distinct claims   beats identity >0.05
naive argmax (tie-blind)         125 / 254          132 / 256              41
tie-aware (at the maximum)       148 / 254          152 / 256              41
median #tied at max: 1   mean: 3.1
```

**Why 152 rather than ~256, measured:** for high-ink (informative) tiles the measure is sharp — only
**1 to 4 of 256** indices score at or above identity. For blank tiles it is not: they tie at 1.000
with all 18 uniform art tiles. Two populations with opposite behaviour; the aggregate averages them.

**Structure test on the 41 — this is what rules out a remapping:**

```
41 tiles claim 19 distinct indices; a bijection would claim 41
attractors: 154 (x12), 0 (x6), 244 (x4), 5 (x3), 203 (x2)
offset (best - tile) histogram: no mode above 2 occurrences — no constant offset
```

**Null comparison — identity is not an arbitrary pairing:**

```
identity      n=   254  mean 0.9315  median 0.9453
non-identity  n=64,770  mean 0.7757  median 0.7781
separation +0.1557 = 1.73 sd of the non-identity distribution
identity rank <=1: 148  <=3: 175  <=5: 184  <=10: 192  <=50: 232   median rank 1
```

**AC2's movement, with controls** (§6 item 2 — the same sharpened method over all three sheets):

| sheet | crude | sharpened | movement | ≥0.90 | rank 1 |
|---|---:|---:|---:|---:|---:|
| **`image.png`** | 0.830 | **0.9315** | **+0.101** | 185/254 | 148 |
| `coco_ArtworkSheet.png` | 0.726 | 0.7380 | +0.012 | 22/254 | 26 |
| `Amiga_Artwork.png` | 0.730 | 0.7335 | +0.004 | 18/254 | 25 |

**Only the hypothesis moved.** A merely-looser measure lifts all three. The §2M gap of 10 points
widens to 19.

**Structural corroboration, not fitted:**

```
uniform art tiles   (18): [0,1,2,3,14,23,162,175,183,236,237,238,239,243,247,252,253,254]
blank tileset tiles (17): [0,1,2,3,14,23,175,183,214,227,238,239,243,247,252,253,254]
symmetric difference:     [162, 214, 227, 236, 237]
```

15 of 17 agree; 214 and 227 are blank only because they are fully masked.

**AC8 — nothing touched:**

```
$ git status --short
?? assets/tile-correspondence.csv
?? assets/tile-correspondence.json
?? docs/project/tile-correspondence.md
?? tools/tilecorr.py

unchanged  assets/tileset.bin
unchanged  assets/levels/level_a.bin
unchanged  src/PETSCII_COCO.asm
unchanged  src/PETROBOTS_6809.asm
```

Additional corroborations that the tileset side is being read correctly: 189 of 256 tiles are live
(§2M says 67 never appear — exact match); 101 distinct character codes, 69 glyph slots after the
7-bit mask, 43 inverse codes (§2K's table — exact match); the only cell absent from `tileset.bin`
is tile 255's BR (§2B's "one byte short").

### 6 — Reactive deviations and ROUTE ACCOUNTING

Route as dispatched: render both sides, score identity, then test alternatives, then table and
verdict. Two mid-run method changes, both material:

1. **The best-match statistic was changed from `argmax` to at-the-maximum, mid-run.**
   The first run reported *identity is best for 125/254, 132 distinct claims* — which is the
   dispatch's documented signature of a measure too weak to discriminate, and grounds to report the
   analysis as unsound rather than report a mapping. **The cause was `numpy.argmax` breaking exact
   ties by lowest index.** 17 blank tiles tie at exactly 1.000 against all 18 uniform art tiles, so
   each "claimed" whichever index sorted first, collapsing the count. Recounting as *is identity at
   the maximum, and how many are tied there* gave 148/254 and 152/256 and exposed two populations
   with opposite behaviour. **The canary was firing on the counting rule, not on the measure.**
   Both figures are reported in §5 so the correction is auditable.

2. **The two rejected sheets were re-scored through the sharpened method** — not asked for. Without
   them, +0.101 on the hypothesis is uninterpretable: a looser measure raises everything. The
   controls moved +0.012 and +0.004, which is what makes the improvement mean discrimination rather
   than inflation. `coco_ArtworkSheet.png` is DEMOTED (§2M) and was used **only** as a control; no
   conclusion rests on it.

3. **Confidence became two-axis (score **and** rank)** after the single-axis version labelled all
   eight AC4 anchors `low`. That was a defect in my rule, not in the data: the anchors score 1.000
   and nothing beats them, so they rank 1. A rank-aware rule labels them `high` and keeps 15
   genuinely blank tiles out of the cleanup queue, with `informative: false` recording that the
   agreement is unconstrained.

4. **An `informative` field was added** beyond the dispatch's field list, because `confidence` alone
   would mislead C3 into sampling colour from tiles that carry none.

**No asset was modified and the font was not repaired** — §2M prerequisite 1 is dropped per the
dispatch, masking replaces it.

### 7 — Uncertainty flags

Every judgment call, as §7 requires:

1. **Thresholds `high` ≥ 0.90 & rank ≤ 3, `low` ≥ 0.75 — chosen, not derived.** 0.90 sits above the
   null mean (0.7757) by nearly two sd and below the identity median (0.9453); 0.75 is just below
   the null median, so anything under it is worse than an average random pairing. Rank ≤ 3 rather
   than = 1 because JPEG noise reorders near-ties. **They are conventions, and moving them moves the
   queue length, not the verdict** — the verdict rests on the null separation and the structure
   test.

2. **The eight blank anchors are a weak check** and AC4 cannot fail hard on them. A blank tileset
   tile scores 1.000 against any of the 18 uniform art tiles, so the anchors confirm the method is
   not *broken* (blank does map to blank) without confirming it discriminates. The discrimination
   evidence is the null separation and the 1-to-4 selectivity on high-ink tiles, not the anchors.

3. **Ties broken by lowest index in `best_score_index`.** After §6 item 1 this only affects that
   audit field, not any verdict; `rank` and `margin` carry the tie information.

4. **The art-side two-colour reduction is the largest modelling choice.** Two dominant *quantised*
   colours per cell, nearest-in-RGB assignment. Alternatives — k-means, luminance median, dominant
   after dithering-aware filtering — would give different numbers. Chosen because it is what the
   engine does (one ink, one paper per character cell) and because it is deterministic and cheap to
   re-run. Not tuned against the result.

5. **Free polarity per cell may over-fit slightly.** It is correct for the engine (the inverse bit
   is per character) but it means a cell can never score below 0.50, which compresses the bottom of
   the range and lifts the null mean to 0.7757. The separation figure accounts for this by comparing
   like with like; the absolute scores should not be read as "93% of pixels agree".

6. **Sheet geometry has an 8 px residual band** (392 = 16×24 + 8) which is assumed to be margin and
   is excluded. The phase evidence (23 on both axes) is consistent with the grid starting at (0,0),
   but I did not verify what occupies the residual band — doing so would be interpreting picture
   content, which §5 forbids.

7. **`image.png` being C64 remains a WORKING PREMISE** (§2M). Nothing measured contradicts it and
   nothing here proves it. Its 0.9315 against a monochrome render is consistent with a
   different-palette source sharing glyph structure, which is what the premise predicts.

8. **JPEG quantisation is present and uncorrected.** It is part of why agreement is 0.93 and not
   higher, and it is the most likely cause of the near-tie reordering behind flag 1.

### 8 — Follow-up candidates

- **C2 (palette derivation) and C3 (converter) can proceed on identity.** Load
  `assets/tile-correspondence.json`; filter on `informative`, not `confidence`.
- **Re-run after C3's font rewrite.** Tiles 214 and 227 become scoreable once `$55`/`$66` are no
  longer corrupt, and the 290 masked cells rejoin the measurement. `tools/tilecorr.py` is unchanged
  by that — just re-run it.
- **The 81 live not-high tiles are the hand-cleanup queue**, ordered. Worth confirming the ordering
  is what the cleanup pass actually wants before C3 consumes it.
- Carried, unchanged: the pinned-digest check on the three source blobs (A1b §8); the three MAME
  idioms to fold in (A2 §10, §2D); where run captures live (A2 §7 flag 4).
- `main` is still at `a62809e`, now five dispatches behind.

### 9 — User interaction during task

None. No blocking ambiguity: the dispatch specified the method, the hazards and the thresholds-are-
yours latitude, and every judgment call is recorded in §7 rather than raised.

### 10 — Candidate(s) captured this task

Two new rows in `seeds/cocobots/live/`, pool commit **`5af8c2a`**, pushed. **New rows only — no
existing entry read or edited.**

| slug | one line |
|---|---|
| `argmax-over-a-tied-field-fabricates-a-collapsed-mapping` | `argmax` breaks exact ties by position, so independent best-match queries collapse onto the first few indices and read as a too-weak measure; count *at the maximum* plus the tie count |
| `apply-the-sharpened-method-to-the-controls-not-only-the-hypothesis` | A refined method's headline number measures the method and the data jointly; re-running the rejected candidates is what factors them apart |

Both are measurement-integrity findings, and both are `initiator: executor`. The first is the
stronger: it nearly caused a sound analysis to be reported as unsound, and the dispatch's own canary
fired correctly on a symptom whose cause lay in the counting rule rather than the measure it names.

### 11 — Commit

| | |
|---|---|
| deliverables | **`73aadcd504f228d1a7be9f8dbe2c84212d5569ce`** |
| this report | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`5af8c2a`**, pushed |

Working tree clean. No data file modified.
