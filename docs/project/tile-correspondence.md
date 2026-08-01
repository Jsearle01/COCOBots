# Tile correspondence — `image.png` ↔ `tileset.bin`

**Status:** verified, C1 recon, 2026-08-01. **Verdict: identity holds**, with a characterised
residue of 104 tiles needing attention and 8 that cannot be resolved from the data.

**Machine-readable companions:** [`assets/tile-correspondence.json`](../../assets/tile-correspondence.json)
and [`assets/tile-correspondence.csv`](../../assets/tile-correspondence.csv) — 256 rows, one per
tile. **These are the artifacts C3 loads.** This document explains them; it is not the interface.

This file records a measurement. It changed no font, no tileset, and no source.

---

## 1. The verdict

**Sheet index *n* corresponds to tileset index *n*.** Adopt identity.

| evidence | value |
|---|---|
| mean identity agreement | **0.9315** (crude prior method: 0.830) |
| median | **0.9453** |
| mean over all 64,770 non-identity pairs | 0.7757 |
| separation | **+0.1557**, 1.73 sd of the non-identity distribution |
| identity is the best of 256 | 148 / 254 |
| identity ranks in the top 3 of 256 | 175 / 254 |
| median rank of identity | **1** |
| tiles scoring ≥ 0.90 | 185 / 254 |

**No consistent alternative mapping exists.** 41 tiles have some other index outscoring identity by
more than 0.05, but those 41 claim only **19 distinct indices** — index 154 is claimed 12 times,
index 0 six times, index 244 four times. A real remapping would be close to a bijection. This is a
handful of generic tiles acting as attractors for anything the measure cannot separate, which is a
property of the measure, not of the data.

**Independent structural corroboration.** 17 tileset tiles render entirely blank; 18 art tiles are
entirely uniform. The two sets agree on **15 members**, and the symmetric difference is
`[162, 214, 227, 236, 237]` — of which **214 and 227 are blank only because both are fully masked**
(every cell uses a corrupt glyph). This was not fitted; it falls out of the data.

---

## 2. Confidence

| label | rule | count | live |
|---|---|---:|---:|
| `high` | score ≥ 0.90 **and** identity ranks in the top 3 of 256 | **152** | 108 |
| `low` | score ≥ 0.75, failing one of the above | **96** | 75 |
| `unmatched` | score < 0.75, or no cells scoreable | **8** | 6 |

**Two axes, deliberately.** Absolute agreement alone is not enough: a tile can score 0.95 while
forty other indices score as well, which is agreement without discrimination. Rank alone is not
enough either: a tile can rank first at 0.70, which is the best of a bad field. `high` requires
both.

**Blank tiles are `high` and `informative: false`.** A blank tile scores 1.000 at rank 1 because
nothing beats it, and blank-matching-blank is genuinely true and needs no cleanup — but it is weak
evidence, being satisfied by any uniform art tile. **C3 must filter on `informative`, not on
`confidence`**, when deciding what carries colour information. 15 tiles are `informative: false`.

---

## 3. Fields

| field | meaning |
|---|---|
| `tile` | 0–255, index into `tileset.bin` |
| `art_index` | matching sheet index. Equals `tile` throughout — identity — or `null` when unscoreable |
| `score` | mean per-cell agreement over unmasked cells, free polarity per cell, 0.0–1.0 |
| `wscore` | the same, weighted by cell informativeness; `null` if every unmasked cell is constant |
| `confidence` | `high` / `low` / `unmatched`, per §2 |
| `cells_scored` | of 9, after masking |
| `live` | tile appears in at least one of the ten level maps |
| `informative` | at least one unmasked cell is non-constant |
| `rank` | identity's rank among all 256 art indices, 1 = best |
| `margin` | identity score minus the best non-identity score. Negative means something scored higher |
| `best_score_index` | the highest-scoring art index. Recorded for audit — **it is not a proposed remapping** |
| `notes` | free text |

---

## 4. Method

Reproducible by `tools/tilecorr.py --sheet art/image.png`. Geometry is **derived, not assumed**:
column and row edge-energy periodicity gives pitch **24**, phase **23** on both axes for all three
sheets, i.e. a 16×16 grid of 24×24 tiles at origin (0,0) with an 8 px residual band.

**Tileset side — exact.** Nine character codes per tile from `TILE_DATA_TL..BR`
(`$5200` + 512 + *k*·256). Each code indexes the 128-glyph font at `$41F6`, 8×8 at 4bpp.
`BITMAP_PLOTTER` masks with `$7F`; a set high bit is inverse video, and since the font's live
nibbles are 0 and 1 with palette 0=`$00` 1=`$3F` 14=`$00` 15=`$3F`, inverse is exactly an ink/paper
swap. Every cell reduces to an 8×8 boolean with no loss.

**Art side — lossy, and this is where the old 83% floor came from.** Per **8×8 cell**, independently:
quantise every pixel to the GIME gamut (2 bits per channel), take the two most frequent quantised
colours, assign each pixel to whichever it is nearer in RGB. Per-cell rather than per-tile because
the engine's inverse bit is per character. The prior method thresholded a whole 24×24 tile on
luminance, which cannot represent that.

**Masking.** Cells whose glyph `code & $7F` is `$55` or `$66` are excluded — both are corrupt
(CLAUDE.md §2J) and are, verified, the **only two glyphs in the font holding nibbles outside
{0,1}**. 290 of 2,304 cells across 101 tiles. Tiles 214 and 227 are fully masked. The font was not
repaired: C3 overwrites all 128 glyphs, so a repair would have a one-dispatch lifetime.

**Scoring.** Per cell, `max(m, 64−m)/64` where *m* is the agreeing-pixel count — free polarity per
cell. Tile score is the mean over unmasked cells.

---

## 5. That the method discriminates

The same sharpened method applied to all three sheets, against the same tileset render:

| sheet | mean now | §2M crude | movement | ≥0.90 | rank 1 |
|---|---:|---:|---:|---:|---:|
| **`image.png`** | **0.9315** | 0.830 | **+0.101** | 185/254 | 148 |
| `coco_ArtworkSheet.png` | 0.7380 | 0.726 | +0.012 | 22/254 | 26 |
| `Amiga_Artwork.png` | 0.7335 | 0.730 | +0.004 | 18/254 | 25 |

**Only `image.png` moved.** A method that merely inflated agreement would have lifted all three.
The 10-point gap in §2M widens to 19 points. `coco_ArtworkSheet.png` is **DEMOTED** (§2M) and is
scored here only as a control — no conclusion rests on it.

---

## 6. The cleanup queue

104 tiles are not `high`; **81 of those are live** and are the ones that matter. Ordered worst-first,
live first. Full ordering is derivable from the JSON — sort by `confidence`, then `live`, then
`score`.

**Unmatched — 8 tiles**

| tile | live | score | why |
|---|---|---|---|
| 214 | yes | — | all 9 cells masked; unscoreable by construction, **not a failure** |
| 227 | yes | — | all 9 cells masked; same |
| 169 | yes | 0.500 | ranks 254 of 256; index 148 scores 0.31 higher |
| 205 | yes | 0.672 | ranks 232; index 0 scores 0.189 higher |
| 24 | yes | 0.703 | ranks 15; 7 of 9 cells scored |
| 223 | yes | 0.729 | ranks 112 |
| 246 | no | 0.672 | ranks 75 |
| 250 | no | 0.705 | ranks 49 |

**Low — 96 tiles, 75 live.** Head of the queue: 138, 219, 200, 199, 204, 54, 62, 170, 206, 215, 51,
166, 211, 139. Two of these (206, 215) rank **1** and are low only on absolute score — they are the
cheapest to confirm.

**Tiles 214 and 227 are a special case worth stating plainly.** They are unresolvable *from this
data* because every cell uses a glyph the font corrupts. They are not evidence against identity and
should not be treated as defects. If C3's font rewrite makes them scoreable, re-run.

---

## 7. Limits

- **`image.png` being a C64 tileset remains a WORKING PREMISE** (§2M), evidenced by crossed palette
  distances, not proven. Nothing measured here contradicts it; nothing here proves it either.
- **The sheets are JPEGs with `.png` extensions.** Quantisation noise is present and is part of why
  agreement is 0.93 rather than higher. It is not corrected for.
- **`best_score_index` is not a remapping proposal.** It is recorded so a later dispatch can audit
  without re-running the 256×256 search. §1 gives the reason it must not be read as a mapping.
- **This says nothing about colour.** It establishes *which art tile corresponds to which tileset
  tile*. Colour derives from `Amiga_Artwork.png` (§2M), and `ATTRIB_TO_MAP_TBL` is not a colour
  authority (§2K0).
- **Dead tiles carry rows but did not drive the verdict.** 67 of 256 never appear in a level.
