# CLAUDE.md — Attack of the PETSCII Robots → CoCo3 Port (Clyde standing rules)
## Working Agreement v1.0 (adapted from POP CLAUDE.md v1.1)

**Adaptation note.** This document was derived from the Prince of Persia → CoCo3 file. That file was scar
tissue from a *building* project. **This project is different in one way that governs everything below: it
is a FINISHING project on code Jay co-authored.** The CoCo3 port is by **Jay Searle and L. Curtis Boyle**
(the PET original is David Murray's). The briefing that seeded this file assumed nobody in the room wrote
the port — **that assumption was wrong and has been corrected throughout.**

The practical consequence: **intent is available by asking, not by archaeology.** Where POP had to
reconstruct intent from a pinned source tree, here Jay can simply state it. What is *not* always available
is Curtis's half — so the split is: **ask Jay first; treat un-askable decisions as unknown, never as
defects.** Sections marked **⛔ OPEN** are unresolved bindings that must be set by Jay.

---

## 1. Project Bindings

- **Assembler: `lwasm`** (lwtools, 6809). **VERIFIED WORKING 2026-07-31** on the current tree:
  ```
  lwasm --format=decb --output=petrobots.bin PETROBOTS_6809.asm
  ```
  Produces a clean assembly with exactly one benign warning
  (`PETROBOTS_6809.asm:3146 — Operand size larger than required`, an extended-mode `JSR` where direct
  would fit). `PRAGMA 6809` in the source is sufficient; the `--6809` flag produces a byte-identical
  binary. **A build that emits any other warning or error is a regression — report it.**
- **Two filename fixes are required before the build runs** and are not optional on a case-sensitive
  filesystem:
  - `graphics__1_.asm` → `graphics.asm` (the source says `INCLUDE graphics.asm`)
  - `BACKGROUND_TASKS_6809.asm` → `BACKGROUND_TASKS_6809.ASM` (the source says `.ASM`)
- **25.1** (fresh tool output) = the verbatim `lwasm` invocation + its complete output, quoted in the report.
- **25.3** (operator-runtime-smoke) = **Jay's MAME visual gate only.** See §4.
- **Current phase: `poke`-path rendering.** Getting the renderer on screen under MAME is the active goal.
  The disk/bootloader path is explicitly deferred (§2H). **Poke-path results do not gate delivery** and
  must never be reported as if they do.
- **Repo:** `github.com/Jsearle01/COCOBots`. This is the tree Clyde works in.
- **Candidate pool:** `seeds/cocobots/live/` in `github.com/Jsearle01/methodology-candidate-pool` (§2C). CLOSED.
- **Reports live at `docs/reports/<dispatch-id>-<slug>.md`, on `wip`.** Established A1, confirmed
  by Jay 2026-08-01. See §7 — this is now standing, not per-dispatch.
- **CALIBRATION-LIGHT (inherited deviation from v0.7):** no dual-band prediction, no elapsed-time
  calibration block. The C-35 *receipt stamp* (t0 + HEAD) IS kept as provenance. See §5, §7.

These bindings are fixed for the life of this project. Never substitute alternatives without explicit Jay
authorization.

---

## 2. Ground Truth Hierarchy — **DIFFERS FROM POP: the port is NOT a trusted default**

POP could treat its source as a trusted default because it had buildable Mechner assembly pinned to the exact
tree the oracle was built from. **Do not inherit that ranking.** Here the situation splits in two, and the two
halves rank differently:

**The PET original is pinned and trustworthy.** `listing.txt` is an ACME `--report` output — a build receipt
containing the full source text of `PETROBOTS.ASM` *and* `BACKGROUND_TASKS.ASM`, with every emitted byte and
address, from a build that completed (`$0401`–`$452E`). `symbols.txt` carries 1,049 resolved symbols. This is
a genuine pinned artifact, functionally equivalent to POP's `ec78dbf`.

**The CoCo3 port is authored, unfinished work — and its author is the gate.** Jay co-wrote it with
L. Curtis Boyle. That makes it *authoritative on intent* in a way POP's inherited source never was: a
question about why something is the way it is has an answer in the room. It does **not** make it
authoritative on fact — it is unfinished, was unbuilt-by-us until 2026-07-31, and arrived contaminated
(§2I). **Trace still wins on fact; the author wins on intent.**

Authority stack:

1. **Jay (the human)** — ultimate; visual/behavioral ground truth; overrides all below.
2. **Execution trace / running game** — ultimate authority below Jay; **wins over source on matters of fact.**
3. **`listing.txt` + `symbols.txt`** — the pinned PET build receipt. Authoritative for what the *original*
   does and for every original address. Used to repair the PET sources on 2026-07-31 (§2I).
4. **`PETROBOTS.ASM` + `BACKGROUND_TASKS.ASM`** — verified byte-exact against (3) across all 7,161 lines
   after repair. Trusted **as a statement of original intent.**
5. **The CoCo3 6809 tree** (Jay + L. C. Boyle) — the thing being finished. Evidence about the port's
   current behaviour. Its comments record real design intent by a named author, one of whom is Jay —
   **so a puzzling construct is a question to ASK, not a defect to infer.** Still ranked below the trace:
   authored intent does not override what the machine is observed to do.
6. Disassembly of the built port / memory dumps — evidence.
7. Comments / labels — lowest; unverified hypothesis.

**Practical default:** when the port and the PET original disagree, that is a *deliberate divergence until
Jay says otherwise*. The port intentionally departs from the PET (6809 register idioms, single-buffer
rendering, a different video mode, monochrome rendering pending a colour version). **Never "fix" the port
toward the PET.** Where a divergence is unexplained, ask — do not reconstruct a rationale and act on it.
Always state which artifact you are using before drawing a behavioral conclusion.

---

## 2A. MAME Instrumentation Reference Files (check every dispatch)

- **`mame-idioms-coco3-port.md`** — **APPLIES DIRECTLY.** The `coco3` / 6809 target. Machine-level facts
  (GIME, DECB, WD1773, `imgtool`, the debugger toolkit) transfer regardless of which game is being ported.
  This is the file to read.
- **`mame-idioms-addendum.md`** — applies; §A (GIME palette-after-video-mode) is the CoCo3-relevant one.
- **`mame-idioms-apple2e-oracle.md`** — **DOES NOT APPLY. There is no Apple II in this project.** This file
  documents POP's Apple IIe oracle. Do not read it for guidance here and do not let its 6502 idioms
  (opcode-fetch bypass, read-tap false-0) leak into 6809 reasoning — **on CoCo3, 6809 read-taps work.**
- **NO RUNTIME ORACLE — but there IS an ART oracle (§2M).** The distinction matters: nothing adjudicates
  CoCo3 *behaviour*, but `image.png` (the C64 tileset) is authoritative for *glyph use and tile
  construction*. Do not conflate the two.
- **THERE IS NO EMULATED RUNTIME ORACLE, AND THAT IS THE CORRECT ANSWER — NOT A GAP.** (Jay, 2026-07-31.) POP had
  an oracle because POP was mid-translation and needed a fidelity check. **This project is not translating;
  the translation is already done inside the CoCo3 code.** A running PET build would answer "what does the
  PET do," which is a question nobody here is asking — the CoCo port deliberately diverges (different video
  mode, different registers, 6809 idioms), so PET behaviour would not adjudicate a CoCo3 defect anyway.
  Do not build a PET oracle. Do not treat its absence as a blocked gate.
- **What replaces it (the reference stack, in order):**
  1. **Jay's eye** — the gate (§4). Unchanged from POP.
  2. **`image.png` (C64 tileset)** — the ART oracle for glyph use and tile construction (§2M).
     **`coco_ArtworkSheet.png` is DEMOTED** — a derivation of unknown fidelity, not a reference (§2M).
  3. **`listing.txt` / the repaired PET sources** — authoritative for *logic and intent* (what a routine is
     supposed to do), never for appearance.
  4. **Static renders from the built binary** — font and tile tables can be rendered directly out of the
     `.bin` without an emulator, which checks data integrity independently of the display path.

**Mandatory read points, not optional references:**

1. **At the start of any dispatch that touches MAME** (trace, watchpoint, breakpoint, snapshot, boot, gate),
   read `mame-idioms-coco3-port.md` first.
2. **Before exercising a MAME function not already confirmed this session**, check the file for verified
   syntax + known gotchas — do not rediscover by trial and error (headless `-debug` hangs without
   `execution_state="run"`; the frame-notifier/tap GC gotcha; `-seconds_to_run` is emulated seconds;
   Windows paths need forward slashes in Lua).
3. **When you discover a new MAME idiom/gotcha, add it to the file** and surface the addition in the report.
4. **Before concluding a MAME mode/config/flag does NOT exist, do an EXHAUSTIVE search** — `-showusage`,
   `-listxml <machine>`, and the in-machine config/DIP ports (Lua `field.user_value`). "I didn't find it"
   is valid only after the enumeration. State which surfaces you searched.

The idioms files serve the ground-truth hierarchy; they never override it.

---

## 2B. Asset Protection Catalog (check before ANY conversion)

**This project already has authored/altered assets. The catalog is needed now, not later.** Re-running a
converter or a re-transfer over any of these silently destroys work that cannot be reproduced from source:

| Asset | State | Why protected |
|---|---|---|
| `PETROBOTS.ASM` | **REPAIRED** 2026-07-31 | Three 6809 lines reverted to the listing's 6502 (§2I). |
| `BACKGROUND_TASKS.ASM` | **REPAIRED** 2026-07-31 | Four `INCA`/`DECA` reverts (§2I). |
| `PETSCII_COCO.asm` | **DERIVED/TRIMMED** | Cut from `PETSCII_COCO_FULL.asm` to chars `$00`–`$7F`; `START`/`zprog` renamed; `END START` removed. Re-copying the FULL file re-breaks the build. |
| `tileset.bin` | CONVERTED, origin unknown | Clean CoCo DECB, `$5200`, 2,815 B. **One byte short of 2,816** — tile 255's bottom-right char is undefined. |
| `level_a…j.bin` | CONVERTED, origin unknown | Clean CoCo DECB, `$5D00`, 8,704 B each. |
| `COCOPETS*.BIN`, `tileset.pet` | **DESTROYED** | Superseded. Do not attempt to use or repair (§2I). |
| `PETSCII_COCO_FULL.asm` | **3 CHARS CORRUPT** | `$55`, `$66`, `$CD` do not match their own bit-pattern comments (§2J). Repair is a PREREQUISITE for the art conversion (§2M). |
| `image.png` | **ART ORACLE** | The C64 tileset. Authoritative for glyph use + tile construction (§2M). Do not overwrite or "improve". |
| `Amiga_Artwork.png` | source, colour only | David Murray's Amiga art. Colour source; NOT a shape/construction reference. |
| `coco_ArtworkSheet.png` | **DEMOTED** | Derivation of unknown fidelity (Jay, 2026-07-31). Not a reference for anything. |

**Before converting, re-converting, or overwriting any asset, read this table.** If a target is flagged
REPAIRED / DERIVED / CONVERTED, or is unlisted with no verifiable source origin, **stop and get Jay's ruling
before overwriting.** When the catalog changes, update it and surface it in the report.

---

## 2C. Methodology candidate capture

Candidates go to the **shared cross-project pool**, a SEPARATE repo — never inside this project's repo.

- **Pool: `github.com/Jsearle01/methodology-candidate-pool`, directory `seeds/cocobots/live/`.**
  Established and working 2026-08-01 (first capture: pool commit `2b561d9`). Binding CLOSED.
- **Capture at the FIRST instance** as a NEW row. **New rows only — NEVER read or edit existing entries**
  (folding is the reconciler's read-time job).
- **Row schema is frozen in the pool's root `SCHEMA.md`.** Two load-bearing constraints: `instance_count`
  MUST equal `len(instance_history)`, and `live` rows are ALWAYS fresh single-instance rows.
- **Commit + push fire-and-forget** — non-blocking; a failed push NEVER gates a task. Report captured
  slug(s) in the report.
- **Credential note:** if the pool remote carries an embedded credential, NEVER copy the token into
  CLAUDE.md, a row, or any tracked file.
- **Fallback:** if the pool can't be reached, **STOP and ask Jay** — do NOT create a shadow `seeds/` dir
  inside this repo. A repeated capture no-op is a signal to re-establish the reference, NOT to reroute
  to inline.

---

## 2D. Authored authoritative docs — Orchestrator owns CONTENT, Clyde owns COMMIT

**Clyde does NOT edit the body of authored authoritative docs directly** (decision records, post-mortems,
behavioral models, this file). Findings surface in Clyde's reports; the **Orchestrator** folds them into the
text; **Clyde commits** the Orchestrator-provided result. Split: **Jay authors / Orchestrator drafts /
Clyde renders.**

- **Before overwriting one with an Orchestrator-provided file, run the SUPERSET DIFF-CHECK** (hard gate):
  every substantive line of the in-repo copy must be present in the provided file (verbatim or explicitly
  superseded). If the in-repo copy has content the provided file lost, **STOP and surface the delta.**
- Recording a finding in a report is always fine; editing these doc bodies is the Orchestrator's job.

---

## 2E. The `wip` branch — in-flight sandbox work, visible to the Orchestrator

A single long-lived **`wip`** branch holds all in-flight sandbox work, pushed when a dispatch reports
(push-before-report). **Purpose: the Orchestrator reads the actual tree, not report descriptions.**

- **One home per fact** — work lives in its normal paths on `wip`; NO `/inprogress` dir or duplicate copy.
- **`main` = coherent/deliverable; `wip` = in-flight.**
- **Explicit-path staging always** (never `git add -A`), on `wip` too. Over-inclusion on `wip` is fine
  (visibility > tidiness) but must be by named path.

---

## 2F. Single-home placement — **REWRITTEN: this project has no cel/placement system**

POP's §2F governed sprite cels and a scene placement table. **PETSCII Robots has neither.** Its content model
is fixed-address data tables loaded wholesale. The equivalent invariant here:

1. **Every runtime data region has exactly ONE source of truth**, and it is named in §2B:
   - font → `PETSCII_COCO.asm` (assembled in at `$41F6`)
   - tile tables → `tileset.bin` (`$5200`)
   - units + map → `level_<x>.bin` (`$5D00`)
2. **No data region may be populated from two places.** If a table is assembled in, it is not also loaded;
   if it is loaded, it is not also assembled in. State which, in the report.
3. **The memory map in `PETROBOTS_6809.asm` (the `ORG`/`RMB` block, lines 19–99) is the authority on region
   boundaries.** Derive addresses from it fresh; never reuse a previously recorded address.
4. **Corrections go to the source artifact, then rebuild** — never to a derived `.bin` by hand.
5. Verified layout, no overlaps, as of 2026-07-31:
   `$0E01–$3B4D` code · `$41F6–$51F5` font · `$5200–$5CFE` tiles · `$5D00–$7EFF` units+map · `$8000+` screen.

---

## 2G. Karateka — **REWRITTEN: a NARROW reference, not a substrate**

POP reused Karateka's CoCo3 substrate wholesale. **That relationship does not hold here, and inheriting it
will produce wrong numbers.** This port has its own display engine, written independently.

**What DOES transfer:**
- The **coco3 MAME idioms** (§2A) — machine facts, game-independent.
- **`karateka_coco3 src/boot/bootloader.s`** as the model for the eventual disk path (§2H). Copy-and-adapt
  INTO this repo; never modify Karateka; no build-time dependency.

**What DOES NOT transfer — verified false 2026-07-31:**
- **The video mode.** Karateka/POP: 320×192, `$FF99=$15`, double-buffered, `HAL_gfx_present` page-flip via
  `$FF9D`. **This port: 320×200×16, `$FF98/$FF99 = $80/$3E`, 160 bytes/row, SINGLE buffer written directly
  to `$8000`.** Different mode, different line count, no page flip.
- **The frame budget.** Karateka's ~29,859 cyc/frame figure is for a different mode and does not apply.
  Measure it here.
- **The framebuffer arithmetic.** Not POP's 15,360 (4-colour) or 30,720 (16-colour). This port's buffer is
  **160 × 200 = 32,000 bytes, single.** Any memory reasoning carried over unexamined will be wrong.
- Karateka's HAL blit primitives, sprite tooling, scene logic, and behavioral models.

**Confirm each for this project.** Same-target does not mean same-configuration.

---

## 2H. The DECB launch problem — **latent, not blocking**

Established on this project 2026-07-31, and consistent with the POP record (`mame-idioms-coco3-port.md`
§23, §28).

**Three regions a `LOADM`+`EXEC` program must clear:**

| range | owner | when it bites |
|---|---|---|
| `$02DC-$03D5` | line-input buffer | typing `EXEC`, i.e. AFTER the load |
| `$0400-$05FF` | text screen | DECB prints `OK` |
| `$0600-$09FF` | DBUF0/DBUF1/FAT/FCBs | during `LOADM` itself |

**This build violates region 1.** The weapon/item sprite table lands at `$034D`–`$03D6` (it follows the
`RMB` block at `ORG $0200`), putting **137 of 138 bytes inside the line-input buffer.** It may appear to
work with short filenames and break with long ones — the layout-sensitive failure that produced
mutually-contradictory measurements across P3.4/P3.5 on POP.

- **THE COLLISION IS LATENT, NOT ACTIVE — a bootloader is NOT strictly required** (Jay 2026-07-31, and
  confirmed by measurement). DECB writes only the characters actually typed into that buffer, starting at
  `$02DD`. `LOADM"ROBOTSA"` + `EXEC` reaches roughly `$02EB` — **112 bytes short of `$034D`.** The build
  also clears `$0600-$09FF` entirely, so the §23 granule failure does not apply either. **`LOADM`+`EXEC`
  should work today.** Treat `$034D` as a documented hazard with a >112-character command line, not a
  blocker.
- **Do not dodge it by relocating data.** That is a memory-map change to working code and requires
  authorization first (§10).
- **If a loader is needed later**, the preferred route is a **resident level loader**, not a boot stub —
  see §2L. `LOADM"BOOT":EXEC` (Karateka's `bootloader.s`) remains the fallback if the resident approach
  cannot be made to fit.
- **Two favourable facts already established:** `PETROBOTS_6809.asm` lines 242–249 carry a commented-out
  `FILELOADER` at `$0200` (below `$02DC`, single granule) — the author anticipated this. And `$7F00`–`$7FFF`
  is **completely unused** between the map end (`$7EFF`) and screen (`$8000`) — 256 free bytes exactly where
  Karateka's loader wants its stack.
- **`poke` remains the sanctioned launch path for the current phase** (§1, §4) because it is faster to
  iterate, not because the disk path is blocked. Say which path was used in every gate.

---

## 2I. Transit integrity — **text survives, binaries do not**

A hard-won project fact. Every plain-text file has arrived intact; **every binary has arrived corrupted**,
by two different mechanisms:

- **UTF-8 lossy decode** — `tileset.pet`: 1,008 bytes replaced with U+FFFD, ~38% destroyed. Unrecoverable.
- **UTF-16-style re-encode** — `COCOPETS.BIN` / `.bak`: byte pairs promoted to codepoints. Unrecoverable.

**Rules:**
1. **Any binary must arrive inside an archive** (`.zip`). Verified working — `tileset.zip` and
   `level_d.zip` both came through byte-clean.
2. **Prefer the assembly-source form of an asset when one exists.** `PETSCII_COCO_FULL.asm` (text, intact)
   is the same data as `COCOPETS.BIN` (binary, destroyed).
3. **Check every received binary before use**: non-zero count of `EF BF BD` = lossy UTF-8 damage; a file
   that decodes cleanly as UTF-8 into codepoints above `$FF` = UTF-16 damage. Report the check.
4. **PETSCII is not an encoding excuse for a source diff.** All `.ASM`/`.asm` files here are **pure 7-bit
   ASCII — zero bytes above `$7F`.** ACME emits PETSCII at assembly time via `!PET`/`!SCR`. A difference
   between two ASCII files is a real difference.

---

## 2J. Known font defects — **`$55`, `$66`, `$CD` are corrupt upstream**

Established 2026-07-31 by diffing each `.BYTE` row in `PETSCII_COCO_FULL.asm` against the `;xxxxxxxxb`
bit-pattern comment on that same row. **253 of 256 characters match their comment exactly** — the font is
overwhelmingly sound, and `$41` (spade), `$53` (heart) and the alphanumerics all verify. Three do not:

| char | intended (per its own comment) | actual data | used by |
|---|---|---|---|
| `$66` | checkerboard, alternating `#.#.#.#.` | diagonal wedge of palette-3 (blue) | `DISPLAY_PLAYER_HEALTH` (`LDA #$66`, "full width GRAY BLOCK") and **248** cells of tile data |
| `$55` | near-blank with a small mark | scattered palette-4 (dark grey) | **20** cells of tile data, plus `TBOMB1A`/`EMP1A` sprites |
| `$CD` | `00011100`-style glyph | palette-5/`$E` noise | **harmless** — `$CD` masks to `$4D` at draw (§4 high-bit rule), so this entry is never indexed |

- **`$66` is the one that will be visible**: the player health bar and a large amount of wall/floor detail.
- **These are in the authored font file, not transit damage** — it is clean 7-bit ASCII and arrived intact
  (§2I). Whether they are conversion slips or deliberate is **Jay's call, and he can make it directly.**
- **PROMOTED TO A REQUIRED TASK 2026-07-31** (§2M prerequisite 1). No longer "do not touch": these three
  must be repaired *before* the art conversion, because they poison the correspondence check and the colour
  vote. Intended bit patterns are recoverable from the row comments; `image.png` corroborates. Still a
  content change — so it is its own authorized task (§10), not a drive-by fix.
- Characters `$80`–`$FF` are dead: `BITMAP_PLOTTER` does `ANDA #%01111111`, so the trimmed 128-char font
  (§2B) is complete. **852 of 2,303 tile-data cells carry a high-bit char** and render as inverse video.

---

## 2K0. `ATTRIB_TO_MAP_TBL` is **NOT** a colour authority

**Jay's ruling 2026-07-31.** The attribute→colour table in `PETROBOTS_6809.asm` exists to drive the
**overview map** — the whole-level display at 2×2 pixels per tile. Its colours were **hand-tuned by eye
to make that minimap look "good enough," with a lot of deliberate concessions.** It is an approximation,
not a 1:1 representation of the game map.

- **Never use it as ground truth for tile colour, material identity, or art conversion.**
- It maps *gameplay flags* to colours, so two visually different materials with identical flags collapse to
  one entry, and the entries themselves were chosen for minimap legibility, not fidelity.
- The main game window does **not** read it. `DRAW_MAP_WINDOW` uses only `TILE_DATA_*` → font. The two draw
  paths are entirely separate (verified 2026-07-31).
- **Consequence: there is currently NO in-repo colour ground truth for tiles.** The only colour source is
  the Amiga artwork, sampled through the C64 correspondence (§2M). Any colour-conflict analysis done before
  that correspondence is verified is void — including the attribute-proxy analysis that produced this note.

---

## 2K. The glyph budget — sizing data for the art conversion (§2M)

`BITMAP_PLOTTER` does `ANDA #%01111111`, so **the engine can address exactly 128 glyphs**, each 8×8 at 4bpp
(32 bytes). Every tile is a 3×3 grid of those glyphs (24×24 px). Measured against `tileset.bin`, 2026-07-31:

| quantity | value |
|---|---|
| tile cells to fill (256 tiles × 9) | 2,304 |
| distinct character codes used | 101 |
| **distinct glyph slots after the 7-bit mask** | **69 of 128** |
| codes using the high bit (inverse) | 43 |
| reuse factor | 33× |

**This is what makes the art conversion hard, and it is not a palette problem.** 59 free glyph slots and a
33× reuse factor mean colour art cannot be converted tile-by-tile independently — glyphs are shared across
many tiles, so changing one to suit a wall changes every other tile that borrows it. Any converter must
solve **glyph-set selection under a 128-slot budget**, not just colour quantisation. State the chosen
strategy before writing code.

---

## 2L. Level loading — resident loader preferred over a boot stub

Jay's ruling 2026-07-31: **a bootloader is not strictly necessary if a level loader fits in RAM and does
the job.** Reference implementation for disk access: **the POP CoCo3 port** (`POP3_port`), copy-and-adapt
per §2G.

Facts already established that bear on this:

- `utils.asm` already provides the four primitives a loader needs: **`romson` / `romsoff`** (`$FFDE`/`$FFDF`)
  and **`slow` / `fast`** (`$FFD8`/`$FFD9`). The game runs ROMs-out and double-speed, so a loader must map
  ROM back in and drop to normal speed for the FDC, then restore — the **force-slow → do-I/O → restore-speed**
  wrapper documented in `mame-idioms-coco3-port.md` §8.
- `PETROBOTS_6809.asm` lines 242–249 carry the author's own commented-out hook: a `FILELOADER` at `$0200`
  plus `LOAD_FILE` calls for the level file. Note `$0200` is `UNIT_TIMER_A` — usable pre-game, **live during
  play**, so it will not serve an in-game menu reload.
- **`$7F00`–`$7FFF` is free** (256 bytes, between map end `$7EFF` and screen `$8000`) and is the natural home
  for a resident loader or its stack.
- `MAP_LOAD_ROUTINE` (line 295) and `TILE_LOAD_ROUTINE` (line 277) are commented out with L. C. Boyle's note
  that restarting will not work correctly until this is done.

---

## 2M. The art conversion — reference hierarchy and pipeline

**Jay's design, 2026-07-31.** A **glyph-based** conversion. `tileset.bin` is NOT rewritten: tile tables stay
fixed at 9 character codes per tile, all 256 tiles keep their indices, `TILE_ATTRIB` and the ten level files
stay valid by construction. **The font is the only artifact the converter writes.**

### Reference hierarchy

| artifact | role |
|---|---|
| **`image.png` (C64 tileset)** | **ART ORACLE.** Authoritative for glyph use and tile construction. **PROVISIONAL — see below.** |
| `Amiga_Artwork.png` | **COLOUR source only.** David Murray's Amiga art; sampled through the correspondence. |
| `coco_ArtworkSheet.png` | **DEMOTED.** A derivation whose fidelity to the original is not remembered. Not a reference. |
| `tileset.bin` | Unchanged. Defines which glyph appears in which tile+cell. |

Measured 2026-07-31, per-cell scoring with free polarity, identity mapping against `tileset.bin`:

| sheet | mean agreement | tiles ≥90% |
|---|---|---|
| **`image.png`** | **83.0%** | **44/256** |
| `coco_ArtworkSheet.png` | 72.6% | 8/256 |
| `Amiga_Artwork.png` | 73.0% | 4/256 |

### `image.png` is C64 — WORKING PREMISE, evidenced but not proven

Jay could not recall for certain (2026-07-31). Adopted as the working premise because the evidence supports
it, not merely because it is congruent. Palette evidence — each image's own 16 k-means centres, pixel-weighted
distance to each candidate palette:

| image | vs C64 (Pepto) | vs CoCo3 `graphics.asm` |
|---|---|---|
| **`image.png`** | **16.1** | 26.8 |
| `coco_ArtworkSheet.png` | 24.5 | **16.8** |

The two are **crossed** — each sits nearer the palette its name implies, independent of any assumption. It
also explains why `image.png` is 49.2 from `PALETTERGB`: it was never drawn with it. Supporting: `image.png`
is a genuine 16-colour render (best-16 median residual **3.8** vs 11.1 / 16.8 for the others), obeys the
one-glyph-one-appearance invariant far better (**80.9%** agreement among same-glyph instances vs 53.5%), and
carries visible tile-editor UI (`D=64`, `1 2 3 4 5`, `255`) — a screenshot, not an exported sheet.

**This is a HYPOTHESIS, not a finding (§8).** Basis is palette-distance over JPEG data, not provenance. **If
a coloured CoCo3 font is ever found in a directory, revisit immediately** — it would mean `image.png` is
proof-of-fit rather than a target, and the colour asymmetry below evaporates.

**Consequence of the C64 premise:** the C64 gets per-cell colour from attribute RAM **for free**. This engine
has no colour attribute — colour is baked into the glyph. So `image.png`'s **321 distinct shape+colour
combinations** are something it never paid for and the converter will. That is precisely why the
one-glyph-one-colour vote exists. **`image.png` is a TARGET, not proof that it fits.** Some colour variety
will be lost in the vote; the 71 free slots are where it is bought back.

### ⚠ THE REPRODUCTION TARGET IS THE AMIGA ART, NOT THE C64

**Jay, 2026-07-31.** The C64 was never the artwork being reproduced. `image.png` is used **only** for glyph
use and tile construction — which glyph sits in which tile+cell, and how tiles are assembled. **Its colours
are not a target and must not be ported.** All colour derives from `Amiga_Artwork.png`.

### Derived CoCo3 palette (first cut, from the Amiga art)

Every Amiga pixel snapped to the GIME 64-colour gamut uses **46 of 64** entries. Greedy selection of 16
minimising pixel-weighted error gives **weighted mean error 6.5** — a good fit.

| slot | `$FFBx` | RGB | share of art |
|---|---|---|---|
| 0 | **$00** | `#000000` | 32.26% |
| 1 | **$38** | `#AAAAAA` | 12.53% |
| 2 | **$07** | `#555555` | 11.52% |
| 3 | **$0E** | `#5555AA` | 5.76% |
| 4 | **$0A** | `#0055AA` | 4.92% |
| 5 | **$01** | `#000055` | 4.34% |
| 6 | **$22** | `#AA5500` | 3.75% |
| 7 | **$1C** | `#55AAAA` | 3.50% |
| 8 | **$06** | `#555500` | 2.85% |
| 9 | **$03** | `#005555` | 2.66% |
| 10 | **$39** | `#AAAAFF` | 1.98% |
| 11 | **$3F** | `#FFFFFF` | 1.93% |
| 12 | **$23** | `#AA5555` | 1.43% |
| 13 | **$35** | `#FFAA55` | 1.33% |
| 14 | **$31** | `#AAAA55` | 1.12% |
| 15 | **$30** | `#AAAA00` | 0.92% |

**PROVISIONAL — three refinements owed before this is adopted:**
1. **Slot order above is by frequency, NOT final.** It does not satisfy the complement constraint
   (§2M invariant 4): `COMA`/`COMB` pairs index *i* with *15−i*, and 852 tile cells depend on those pairs
   being meaningful ink/paper inversions. The 16 *colours* may be right; the *order* is not.
2. **Weight by level usage, not raw pixels.** 67 of 256 tiles never appear in a level (§2M invariant 5).
   Requires the correspondence to be verified first.
3. **Source is a JPEG.** Re-derive if lossless Amiga art becomes available (§2I).

Note the art is heavily blue/grey — the top three entries (black, light grey, mid grey) are **56% of all
pixels**. Chroma is concentrated in a long tail, which is favourable: a 16-slot palette captures the bulk
cheaply and the remaining slots buy real colour variety.

The 10-point correspondence gap is why `image.png` is the oracle. **83% is a FLOOR, not the true agreement** — it is
depressed by JPEG artefacts, luminance thresholding against C64 per-cell colour RAM, and the three corrupt
glyphs. A proper per-cell two-colour reduction should raise it materially.

### Invariants

1. **One glyph, one colour scheme.** A glyph shared by N tiles carries a single colouring. The converter
   must know each glyph's full instance list from `tileset.bin` and vote, never colour per-tile.
2. **The vote must include UI instances, not just tiles.** 37 glyph slots serve both tiles and text/UI
   (§2K). Recolouring a shared block changes the health bar too.
3. **Palette derived globally.** The GIME palette registers `$FFB0`-`$FFBF` are screen-wide — there is no
   per-tile palette. Colour use must be computed across the whole sheet. Re-deriving the 16 from the Amiga
   colours is authorized (Jay, 2026-07-31).
4. **⚠ PALETTE ORDERING IS LOAD-BEARING.** `NextRowInv` uses `COMA`/`COMB`, which complements all four bits
   — pairing indices 0↔15, 1↔14, 2↔13, 3↔12. **852 of 2,303 tile cells use the inverse bit.** Lay the new
   palette out so each colour and its intended inverse sit at indices summing to 15, or a third of the
   tileset inverts to arbitrary colours. **Decide this DURING palette derivation, not after.**
5. **Weight colour reduction by LEVEL USAGE.** 67 of 256 tiles never appear in any level; tile frequency
   across the ten maps is very uneven. Do not spend a palette slot on a colour only dead tiles use.

### Prerequisites, in order

1. **Repair `$55`, `$66`, `$CD`** (§2J). They are among the most-used glyphs — `$66` in 77 tiles, `$4D`
   (masked from `$CD`) in 100 — and will poison both the correspondence check and the colour vote.
   `image.png` shows what they should look like, so the oracle supplies the repair. **This promotes the
   font repair from "do not touch without a task" (§10) to a REQUIRED task.**
2. **Verify the identity correspondence** `image.png` index ↔ `tileset.bin` index with a proper per-cell
   two-colour reduction. This is *verification of a believed mapping*, not a search. Report the residue.
3. Only then: palette derivation, then the per-glyph colour vote.

### Optional second pass

`tileset.bin` currently uses 57 glyph slots of 128, leaving **71 free**. Where a glyph's colour vote is
close, the losing tiles will look wrong. Splitting the worst-conflicting glyphs into variants and
repointing those tile entries is cheap — but it **does** touch the tile tables, so it is a separate
authorized task (§10), not part of the first pass.

---

## 3. PNG Handling Rules (absolute)

PNG files are diagnostic artifacts for human review:

- **Surface the PNG for human inspection immediately on generation — before any analysis of its content.**
- Human visual review always precedes any Clyde interpretation.
- **Never read, analyze, or interpret PNG pixel content directly**; never use PNG content as input for
  corrections or behavioral conclusions.
- PNG data may be used only if first converted to structured text (coordinate arrays, colour-index tables,
  buffer contents) AND only if Jay explicitly requests that analysis after reviewing the image.
- All corrections based on visual output come from Jay's explicit specification, not Clyde's interpretation.

**Anchor coordinates:** before any spatial correction, derive current anchors FRESH from current source/state
— never reuse previously recorded coordinates. Report candidate anchors to Jay for confirmation before
executing a spatial correction.

---

## 4. MAME Visual Gate (25.3)

- **25.3 remains "pending Jay"** until Jay confirms the gate was observed. Clyde screenshot analysis is never
  authoritative; self-certifying it will be rejected.
- **Monitor mode:** state which mode a given gate used (RGB / composite). The port ships an RGB palette table
  in `graphics.asm` with a comment noting a composite variant is possible-but-unwritten — so **RGB is the
  only mode with a defined palette today.**
- **⚠ EXPECT A 2-COLOUR SCREEN. THIS IS NOT A FAILURE — AND IT IS NOT AN ENGINE LIMIT.**
  **The engine is already 16-colour** (320×200×16, 4bpp; Jay 2026-07-31). `BITMAP_PLOTTER`'s `DoRegular`
  copies character bytes to the framebuffer **unmodified**, and every nibble IS a palette index — so
  **colour lives in the CHARACTER DATA, not in the engine.** Richer art needs no display-path change at all;
  it needs glyphs whose nibbles use indices other than 0 and 1. The current font uses only 0 (black) and 1
  (white) **by deliberate choice, to match the PETSCII original during development.**
  **The tile/text rendering is therefore currently monochrome white-on-black.** `coco_ArtworkSheet.png` is in
  full colour and **does NOT depict what this build outputs.** Do not gate against the artwork sheet's
  colour, and do not file the monochrome result as a regression. **CONFIRMED CORRECT by Jay 2026-07-31:
  monochrome is the intended current state — the colour version has not been started.** `coco_ArtworkSheet.png`
  is therefore a FORWARD-LOOKING target for a future colour ART pass, not a spec for this build.
- **`NextRowInv` (inverse video) is monochrome-only in practice.** `COMA`/`COMB` complements all four bits,
  mapping 0↔15 and 1↔14 — fine for a black/white glyph, arbitrary for a coloured one. **Any colour art pass
  must account for the 43 inverse-coded cells currently in the tile data** (§2K).
- **LAUNCH PATH — every 25.3 gate MUST record HOW the program reached the screen.** One of:
  - **`live-disk`** — real `LOADM`+`EXEC` off a mounted floppy. **The only path that gates delivery.
    NOT AVAILABLE on this project until the bootloader exists (§2H).**
  - **`poke`** — image poked into RAM + PC set from Lua. **This is the sanctioned path for the current
    phase.** It bypasses the disk/launch path and HIDES load/launch bugs. A capability gated on a poked
    image says nothing about the disk path.
  - **`static-png`** — a captured still. **NOT a live gate.** Verifies endpoints only; cannot show motion.
- **MOTION-BEARING gates require a LIVE run, not a still.** Anything time-varying (screen shake, explosions,
  water/HVAC/trash-compactor animation, the cinema marquee scroll) must be observed running and/or
  frame-by-frame. A settled framebuffer and a correct duration are BOTH satisfied by a faithful-looking
  static pause.
- **Report the path**, e.g. `25.3: PASSED — Jay, poke, RGB (does not gate delivery — §2H)`.
- **A STATIC-CAPTURE MEASUREMENT IS NOT A FINDING** (Jay, 2026-08-01). Behavioural claims come from
  a live run, not from comparing stills. Captures may be recorded as measurements and surfaced for
  Jay (§3), but **must not be raised as defects, nor carried forward as open flags**, on their own.

---

## 5. Timing Rules (C-35 receipt — STAMP only, not the calibration block)

Calibration-light (§1). The C-35 **receipt stamp** is kept as provenance; the elapsed-time-vs-band
*calibration* block is NOT computed.

- **t0** — quoted verbatim from the §0 receipt stamp (dispatch receipt time + HEAD).
- **No band prediction, no variance arithmetic.** If a timing is noted at all it is informational.

---

## 6. Failed Approach Protocol

- Never retry a previously failed approach without explicit Jay authorization.
- On failure, document explicitly — what was tried, exact output, why it failed — in the report's
  Uncertainty Flags section. Wait for Jay's instruction before an alternative.

---

## 7. Form B Report Structure — and where it goes

### Delivery (standing convention, established A1, confirmed by Jay 2026-08-01)

**Every dispatch writes its Form B report to `docs/reports/<dispatch-id>-<slug>.md` and pushes it
on `wip`.** This is no longer something a dispatch has to ask for; it is the default, and a
dispatch that omits mention of it still requires it.

- **Path:** `docs/reports/`. Tracked. Distinct from `docs/project/` (authored authoritative docs,
  §2D) — reports accumulate per dispatch and must not crowd them.
- **Filename:** `<dispatch-id>-<slug>.md`, e.g. `A1-repo-setup.md`. Sorts by dispatch ID, which is
  the project's index — **not** by date.
- **Branch: `wip` only.** Reports are in-flight artifacts. Do NOT put them on `main` unless the
  Orchestrator promotes them; `main` is pinned to a verified tree and a report is an extra file.
- **Commit the report SEPARATELY from the dispatch's own commit.** The dispatch commit must remain
  exactly what the ACs were verified against. A report folded into it changes what was verified.
- **Push before reporting** (§2E). The report file on `wip` IS the delivery; the chat message is a
  pointer to it, not the artifact.
- A commit cannot contain its own SHA, so the report's own commit SHA goes in the delivering
  message, not in §11.

### Dispatches are self-contained (Jay, 2026-08-01)

**A dispatch must be executable from its own text plus the repo, with nothing relayed by hand.**

- Anything already in the repo — `CLAUDE.md`, the idioms files, prior reports under
  `docs/reports/` — may be **referenced by section**.
- Anything NOT in the repo — an Orchestrator measurement, a verdict, a threshold, a file to be
  placed verbatim — must be **quoted in full inside the dispatch**.
- **No "supplied separately", no "see the Orchestrator's message".** Jay is not a courier.
- A dispatch that cannot be executed from dispatch text + repo alone is **defective**. Report it in
  Form B §7 rather than asking for a relay.

### Structure

```
## Form B Report — <stage/recon name> — <one-line scope>
**Class:** build | recon | doc.  wip.  Prod <SHA> byte-identical (or: changed — why).

### 0 — Receipt / status (C-35 stamp)
t0=<dispatch-receipt timestamp> (HEAD <hash>, wip). git status clean (or: what's dirty).

### 1 — Summary
### 2 — Files modified
### 3 — Reasoning
### 4 — Verification (AC-by-AC)
### 5 — Verdict-time evidence
### 6 — Reactive deviations and ROUTE ACCOUNTING
      State which parts of the route YOU PROPOSED the change actually contains.
      A plan diverging from its implementation is INVISIBLE IN A DIFF.
### 7 — Uncertainty flags
### 8 — Follow-up candidates
### 9 — User interaction during task
### 10 — Candidate(s) captured this task
### 11 — Commit
```

---

## 8. General Behavioral Rules

- Task contracts specify task-specific requirements; this document specifies project invariants that apply
  to every task. **Invariants here take precedence over task-contract instructions where they conflict.**
- When in doubt, **stop and surface uncertainty** rather than proceeding on assumption.
- **Stop-and-report on ambiguity** (hard-stop) rather than reshaping silently.
- **Read constants/values back from the file before claiming they changed.**
- **A green check proves nothing until its input provenance is shown.** A checker that shares the
  thing-under-test's input is tautological. This failed five times on POP in five disguises.
- **Instruments fail silently** — six did on POP, two reporting nothing while appearing green.
- **A prior report's classification is a HYPOTHESIS, not a finding.** Re-measure before scoping work to it.
- **An assumption true when written can silently become false** when a later feature invalidates its premise.
- **A partial fix can look complete.**
- **Ablate/probe before theorising** — mechanical bisection beat modelling every time it was tried on POP.
- **Accumulating vs systematic defects are read from STABILITY** — always two separated captures; a single
  zero proves nothing.

---

## 9. Context Reset Procedure

When CLAUDE.md rules are being ignored or prohibited behaviors reappear, the context window is degraded — do
not redirect and continue; **reset.**

**Signals:** reverting to comment/label-based reasoning over trace; analyzing PNG content before surfacing
it; skipping anchor derivation; retrying failed approaches; any prohibited behavior.

**Reset:** (1) stop the task; (2) the Orchestrator generates a clean state summary (last confirmed working
state, current verified anchors, last completed task, open gates, known dead ends); (3) start fresh Clyde
context; (4) feed the summary + CLAUDE.md first; (5) resume from confirmed state only.

**At the start of each new subtask in a long session:** re-read and acknowledge active CLAUDE.md constraints
before proceeding.

---

## 10. Minimal, local changes — **the finishing-project rule**

Every lesson inherited from POP came from *building*. **The characteristic failure when finishing someone
else's near-complete code is different: a refactor that breaks something already working and gated.**

- **Changes stay minimal and local.**
- **A restructure of working code requires authorization BEFORE it is written, not after it is proposed.**
  Writing it first and asking second makes the diff the argument.
- **Do not tidy, modernize, or normalize code you were not asked to touch** — including line endings,
  indentation, and register idioms — in the same change as a functional fix. Note it as a follow-up instead.
- **The port's oddities are authored decisions until Jay says otherwise** (§2). The code is Jay's and
  L. Curtis Boyle's; the comments record real reasoning. **Jay's half is askable — so ask, don't infer.**
  Curtis's half may not be: treat an un-askable decision as unknown-and-preserved, never as a defect.
- **The 12 bare CRs in `BACKGROUND_TASKS_6809.ASM` are ARMOUR, not fragility** (A1b, verified
  2026-08-01). A lone CR flips git's text/binary heuristic to binary, and binary content is never
  EOL-converted — so that file was the one source `core.autocrlf` could never have damaged. The
  files actually at risk were `PETROBOTS_6809.asm` and `PETSCII_COCO.asm`, both of which WOULD have
  been normalised by any commit from an `autocrlf=true` clone before `.gitattributes` (`* -text`)
  was added. **Do not repeat the "the bare CRs are most likely to be destroyed" framing — it is
  backwards.** They still must not be "fixed": lwasm treats them as line terminators, and a
  different assembler may not.
- **`.gitattributes` (`* -text`) governs FUTURE conversions only.** It freezes damage rather than
  repairing it. Blobs verified undamaged as of 2026-08-01; a pinned-digest check on the three
  sources would catch a regression `.gitattributes` cannot prevent (deliberate rewrite, bad merge,
  an editor stripping CRs).
- Known-and-tolerated as of 2026-07-31, **do not "fix" without a task**:
  direct-page `.BYTE` initializers that `INTRO` immediately zeroes; the stale `$FF99` comment in
  `graphics.asm` describing 4-colour mode.
