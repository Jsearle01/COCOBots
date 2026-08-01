# Bootloader + resident level loader — costing

**Status:** costing only, 2026-08-01. **Nothing implemented, nothing authorised.** No source, asset
or memory map touched. Follows C3 (`docs/reports/C3-inverse-removal-recon.md`) and answers Jay's
question: *what would a bootloader cost, and does it close the level-load feature?*

Sizes are taken from **built artifacts of the sibling ports**, not estimated from source.

---

## 1. Answer in brief

| | |
|---|---|
| **boot stub** | **403 bytes**, runs from `$8000+` framebuffer space — **costs zero low RAM** |
| **disk primitive** | **~310 bytes** + a small variable block, from POP3_port |
| **resident level loader** | **~440 bytes of low RAM** (primitive + vars + wrapper + glue) |
| **fits?** | yes — the 256-glyph layout leaves **475 bytes** at `$7E25-$7FFF`. ~35 spare |
| **is the boot path proven?** | **yes, on karateka, end to end under MAME** — see §4 |
| **does it close level-load?** | **no.** The loader is necessary but not sufficient — see §5 |

**The headline: the boot stub is nearly free, the resident loader is not, and the level-load feature
needs code that does not exist yet.**

---

## 2. The boot stub — 403 bytes, zero low-RAM cost

`karateka_coco3/tests/scripted/bootloader.bin` is a **built 403-byte artifact**, and its source
`src/boot/bootloader.s` does `include "disk_read.s"` — so those 403 bytes are the stub logic *and*
the full disk primitive together.

It runs from `org $8000` — framebuffer space, which is boot-dead because the game has not drawn
anything yet. It masks IRQ/FIRQ, replicates the MMU setup, raw-reads whole tracks into low RAM, and
`jmp`s the game entry, never returning to BASIC. **It therefore consumes no memory the game needs.**

Entered by `LOADM"BOOT":EXEC`. At 403 bytes it is a single-granule file, so idioms §23's
second-granule failure cannot apply, and it loads at `$8000+`, clear of every DECB region.

**And because the stub raw-reads the game, the game image is not subject to DECB's constraints at
all** — which is the entire point. `$0400-$09FF` (1,536 bytes) and `$02DC-$03D5` (250 bytes) become
usable, and idioms §14e's "no `$0100` segment in a `LOADM`'d binary" stops applying to the game.

---

## 3. The disk primitive — 301 bytes, measured

**Assembled directly with `lwasm`** rather than inferred from POP3_port's linker map:

```
$ lwasm --format=raw --output=dr.bin disk_read.s
  301 bytes            code, $0000-$012C, last instruction rts at $012C
```

Its variables sit at a separate `DR_VARBASE` and are `equ` offsets, not part of those 301 bytes —
**7 bytes** in total: `dr_track`, `dr_sector`, `dr_dest` (2), `dr_status`, `dr_r_track`,
`dr_r_count`. (idioms §25: `-DDR_VARBASE` takes a C literal, so `$1F00` silently defines zero.)

**Primitive total: 308 bytes.** And since karateka's `bootloader.bin` is 403 bytes and `include`s
this file, **the boot-stub logic alone is 102 bytes** — which runs from framebuffer space and
therefore costs no low RAM at all.

It talks to the WD1773 directly (`$FF40`, `$FF48-$FF4B`), so it does not need DECB ROM mapped in.
It does need the **force-slow → do-I/O → restore-speed** wrapper (idioms §8), and `utils.asm`
already provides `slow`/`fast` and `romson`/`romsoff`.

---

## 4. Is the boot path actually proven? Yes

This is the part that would normally be the risk, and it is not. karateka's
`docs/project/decb-loadm-boot-gates.md` settles three gates **before** authoring — FAT/granule
reservation, the `LOADM`/`EXEC` transfer-address handoff, and `$0100-$01FF` during `LOADM` — and
records **all three PASS**. Its `build/logs/unit/decb_boot2.log` shows the whole path running under
MAME:

```
[f240] BASIC settled; typing LOADM"BOOT":EXEC
[f888] BL_RESULT=$A5 (bootloader loaded game). byte-exact 17955/17958, 3 mismatch (first@$010C)
[f888] JUMP reached game: PC=$1B04
```

The 3 mismatched bytes at `$010C` are DECB's live IRQ vector, exactly as idioms §5 documents — and
they are inert here because the loader never returns to BASIC.

**So this is copy-and-adapt from a working implementation on the same target** (§2G), not new
development against the FDC.

---

## 5. Does the level-load feature close? No — and this is the real cost

**The two routines the author sketched do not exist.** `MAP_LOAD_ROUTINE`, `TILE_LOAD_ROUTINE` and
`DISPLAY_LOAD_MESSAGE1/2` appear in `PETROBOTS_6809.asm` **only inside commented-out `JSR` lines**
(lines 276-277, 294-295). There is no code behind them. L. Curtis Boyle's note on line 295 —
*"Until this is working, restarting the game will not work right"* — is a note about work not yet
started, not work switched off.

**`CYCLE_MAP` does not load anything.** In full, it increments `SELECTED_MAP`, wraps at 10, and
branches to `DISPLAY_MAP_NAME`. The menu lets you cycle the map *name on screen*; the map *data* is
whatever shipped in the binary. A2's live run confirmed the menu path reaches it.

**So closing the feature needs, beyond the loader itself:**

| item | bytes | basis |
|---|---:|---|
| disk primitive, code | **301** | **measured** — assembled with `lwasm` |
| disk primitive, variables | **7** | **measured** — `equ` offsets from `DR_VARBASE` |
| force-slow / restore wrapper | ~25 | estimated; `utils.asm` already has `slow`/`fast`, `romson`/`romsoff` |
| `TILE_LOAD_ROUTINE` | ~25 | estimated; set track/dest/count, call, check `dr_status` |
| `MAP_LOAD_ROUTINE` | ~25 | estimated; same shape |
| `DISPLAY_LOAD_MESSAGE1/2` | ~40 | estimated; text already renders through `BITMAP_PLOTTER` |
| **file location** — fixed raw tracks | ~15 | estimated; karateka's route |
| **file location** — DECB directory walk | ~200 | estimated; read dir, match name, follow granule chain |

**Totals, resident in low RAM:**

| | bytes | against 1,597 free at 221 + bootloader |
|---|---:|---:|
| **with fixed raw tracks** | **438** | 1,159 left |
| with a DECB directory walk | 623 | 974 left |

**308 of that is measured; the rest is estimated**, and the file-location choice moves it by 185.

The boot stub is separate and free: 102 bytes of stub logic plus the 301-byte primitive, running from
`$8000+` framebuffer space which is dead until the game draws.

---

## 6. Where it lives

The resident loader **cannot** live in framebuffer space the way the boot stub does: once the game
is drawing, `$8000+` is pixels. It needs real low RAM.

CLAUDE.md §2H nominates `$7F00-$7FFF` (256 bytes). **That is not enough** — the primitive alone is
~310. The 256-glyph layout from C3 leaves 475 bytes at `$7E25-$7FFF`, which is close but tight.

**Three ways to buy room, in order of cheapness:**

1. **Drop to 221 glyphs** and put the loader in the space that frees. Costs 3.71 points of colour
   error (83.28 vs 79.57) and gains ~1.1 KB of slack.
2. **Put the loader in the reclaimed `$0400-$09FF`** and shift the font up. The boot stub frees
   1,536 bytes there; the C3 layout spends them on the font, but that is a choice, not a
   requirement.
3. **Trim the font below 256.** Each glyph dropped returns 32 bytes.

Option 2 is the one that costs nothing in fidelity and only needs the layout re-solved.

---

## 7. Open questions — not costed here

- **File location scheme.** Reading a *named* file means walking the DECB directory on track 17 and
  following the granule chain; reading **fixed raw tracks** is far less code but means the levels
  are not DECB files and the disk must be built to place them. karateka took the raw-track route.
  **This choice moves the ~40 B estimate in §5 by a lot in one direction.**
- **Does the resident loader need ROM mapped in?** The primitive is raw FDC, so probably not — but
  karateka's stub comments note `MC3=1` is required for the disk NMI handler in the constant page,
  and the game runs ROMs-out. Needs settling against `sys.s` before anyone builds it.
- **Regenerating `tileset.bin` and ten level files.** Every layout in C3 moves their load addresses
  (`$5200`, `$5D00`), so all eleven files must be rewritten. Mechanical, but they are protected
  assets (§2B).
- **The 3 clobbered bytes at `$010C`.** Inert for karateka because its loader never returns to
  BASIC. Same should hold here; not verified for this port.
- **All estimates in §5 except the two artifact sizes are mine**, from reading the reference and the
  call shapes. The 403 B and ~310 B are measured; the rest are engineering judgement and could be
  30% out either way.

---

## 8. What this changes about the C3 comparison

C3 costed the bootloader purely as the price of 256 glyphs, worth **3.71 points** — the worst-value
step on the whole error curve. That framing stands and is unchanged.

**What it understated is the other side.** The boot stub is 403 bytes of proven, copy-and-adapt code
that costs no low RAM, and the same disk primitive is the thing that unblocks level select and
restart — a feature the menu already advertises and which has never worked. Judged as an art-fidelity
purchase the bootloader is poor value. Judged as the level-loading work, the 256-glyph headroom is a
by-product that arrives for free.

**No recommendation.** The numbers are above; the call is Jay's.
