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
