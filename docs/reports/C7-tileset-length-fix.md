# Form B Report — C7 — fix `assets/tileset.bin` to its full 2,816 bytes

**Class:** build (one-byte content change to a protected asset). `wip`, pushed before reporting.
**No 25.3 gate** — the change is invisible unless tile 255 is placed in a level, and nothing does.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C7 received. HEAD at receipt `d97bac1` (`wip`), tree clean.
`assets/tileset.bin` verified at the dispatch's stated BEFORE state before anything was written:
2,825 bytes, `sha256 1d2c02c7…`.

### 1 — Summary

**Done, and the result hashes to the value the dispatch predicted.**

```
before  2825 bytes  sha256 1d2c02c7bcd4168534296f0ec710a4e3a2fe27e500ac8876f06a86a22d87783c
after   2826 bytes  sha256 2b7090562412c79b91dc4acfe55bc20a497ae1fe3fee18f872aa446ce90dd4af
dispatch §2 AFTER   2b7090562412c79b91dc4acfe55bc20a497ae1fe3fee18f872aa446ce90dd4af   MATCH
```

One `$20` appended before the END block, header length `$0AFF` → `$0B00`. The first 2,815 data
bytes were compared against `git HEAD` byte for byte: **identical, first difference none.**

**All eight ACs met**, 14 direct checks plus the build. **Two consequences beyond the one byte**,
both real and both reported rather than absorbed — §6.

### 2 — Files modified

| path | change |
|---|---|
| `assets/tileset.bin` | **+1 byte** (`$20` at data offset 2815 = `$5CFF`), header len `$0AFF`→`$0B00` |
| `build.sh` | `EXPECT_SHA256` re-pinned `13b8b4c0…` → `c0254b09…`, with the reason recorded inline |
| `tools/glyph_tool/selftest.py` | three assertions that encoded the pre-C7 state, updated — §6 |
| `tools/glyph_tool/tileclass.py` | tile 255's storage warning now **derived from the file**, not hardcoded — §6 |
| `docs/project/protection-catalog.md` | AC7 — `tileset.bin` recorded as MODIFIED, with restore instructions |

**Not modified, verified against `HEAD`:** `src/graphics.asm`, `src/PETSCII_COCO.asm`,
`src/PETROBOTS_6809.asm`, `src/BACKGROUND_TASKS_6809.ASM`, `src/utils.asm`, all ten
`assets/levels/level_?.bin`, `assets/palette.json`, `assets/authored/`.

### 3 — Reasoning

**Byte-level splice, not a re-export** (§4 hard constraint, §5 hazard 1). The patch reads the file,
asserts the input hash, asserts the header, asserts the END block is exactly `FF 00 00 00 00`,
rebuilds the file as `type + newlen + load + <the 2,815 authored bytes verbatim> + $20 + <END block
verbatim>`, and **asserts the 2,815-byte prefix survived before writing anything**. No DECB writer
was involved, so there is nothing that could re-encode a field.

`$20` is the right filler because it is what every blank tile's nine cells already hold — the
missing cell renders empty rather than as arbitrary data.

**Why the END block matters** (§5 hazard 2): the `$FF` sitting at the end of the data region is the
END marker, not data. Inserting after it would have produced a file whose segment still claimed 2,816
bytes while the marker sat in the middle. The splice inserts *before* it and carries it through.

**Length field is big-endian** (§5 hazard 3): `$0B00` = `0B 00`, confirmed by re-parsing the written
file rather than by trusting the write.

### 4 — Verification (AC-by-AC)

14 checks, 0 failed, plus the build.

**AC1 — 2,826 bytes, sha256 `2b70905624…`.**
```
PASS  file is 2,826 bytes                 2826 bytes
PASS  sha256 matches the dispatch         2b7090562412c79b91dc4acfe55bc20a497ae1fe3fee18f872aa446ce90dd4af
```

**AC2 — header parses type `$00`, len 2816, load `$5200`; data `$5200`–`$5CFF`.**
```
PASS  header type/len/load                type $00  len 2816 ($0B00)  load $5200
PASS  parses as one segment $5200-$5CFF   $5200-$5CFF, 2816 bytes
PASS  END block intact                    ff 00 00 00 00
```

**AC3 — all nine `TILE_DATA` tables exactly 256 bytes.**
```
PASS  all 11 tables are 256 bytes         9 TILE_DATA + DESTRUCT_PATH + TILE_ATTRIB = 2816 bytes
PASS  TILE_DATA_BR is complete            was 255 before the fix
```

**AC4 — first 2,815 data bytes byte-identical to the previous file. LOAD-BEARING.**
Verified by comparison against `git show HEAD:assets/tileset.bin`, not by assertion:
```
PASS  first 2,815 data bytes identical to HEAD   compared 2815 bytes against git HEAD; first difference: none
PASS  exactly one byte added                     appended $20 at data offset 2815 ($5CFF)
```

**AC5 — tile 255's cells read `70 40 6E 32 35 35 6D 40 20`.**
```
PASS  tile 255 reads 70 40 6E 32 35 35 6D 40 20   70 40 6E 32 35 35 6D 40 20
PASS  other eight cells untouched                 only BR was added
```

**AC6 — `build.sh` still produces a valid merged binary; overlap count 0.**
Full build, **exit 0**, all four steps including the disk image. Exactly one `lwasm` warning — the
expected benign `PETROBOTS_6809.asm:3146 Operand size larger than required` (CLAUDE.md §1).

```
#    load    end       length
0    $034D   $03D6        138   HAZARD: BASIC line-input buffer
1    $002E   $002F          2
2    $0035   $003D          9
3    $0043   $0064         34
4    $007A   $007C          3
5    $007E   $0080          3
6    $0E01   $14B9       1721
7    $14BB   $3B4D       9875
8    $41F6   $51F5       4096
9    $5200   $5CFF       2816   <- was $5200-$5CFE / 2815
10   $5D00   $7EFF       8704
exec $0E01     11 segments, 27401 bytes of payload     span $002E-$7EFF
```

**overlaps: none — count 0.** Segment table matches the dispatch's prediction exactly, including the
five-segment `$002E-$0080` group and the single changed row.

**AC7 — protection catalog updated.** `docs/project/protection-catalog.md` records
`assets/tileset.bin` as **MODIFIED 2026-08-01 (C7)**, superseding §2B's "CONVERTED, origin unknown"
row, with before/after hashes, the reason a re-export reintroduces the bug, and **how to restore the
byte** if one ever does.

**AC8 — no other file modified, verified by hash.** `git diff --stat HEAD` over `graphics.asm`,
`PETSCII_COCO.asm`, `PETROBOTS_6809.asm`, `BACKGROUND_TASKS_6809.ASM`, `utils.asm`, the ten level
files, `palette.json` and `assets/authored/`: **no diff.** The four files in §2 beyond
`tileset.bin` are consequences of the change, declared there and argued in §6 — none is game content.

### 5 — Verdict-time evidence

| | before | after |
|---|---|---|
| `assets/tileset.bin` | 2,825 B · `1d2c02c7bcd4168534296f0ec710a4e3a2fe27e500ac8876f06a86a22d87783c` | 2,826 B · `2b7090562412c79b91dc4acfe55bc20a497ae1fe3fee18f872aa446ce90dd4af` |
| data segment | `$5200`–`$5CFE`, 2,815 | `$5200`–`$5CFF`, **2,816** |
| `TILE_DATA_BR` | 255 bytes | **256** |
| `build/ROBOTSA.BIN` | 27,460 B · `13b8b4c078174abba8f059ebd35a1e9fb0b892b83a42ce8dd5fb34134b8f6c9a` | 27,461 B · `c0254b09aeb5498dc03956ebe8282dd574cf30edb3f231bbfed010d697f8e6c4` |

The merged binary grows by exactly one byte and no segment moves — `$5D00` (`UNIT_TYPE`) is
unchanged, so `2816` fits the region exactly as the dispatch says.

### 6 — Reactive deviations and ROUTE ACCOUNTING

The dispatch says *"Nothing else changes."* Two things did, both forced by the change itself. Both
are declared here rather than folded quietly into §2.

**Deviation 1 — `build.sh`'s pinned digest had to be re-pinned, and the `dist/` reference is now
permanently stale.** The tileset segment is one byte longer, so `ROBOTSA.BIN` changes and
`EXPECT_SHA256` fails. `build.sh`'s own comment sanctions exactly this: *"Update this ONLY alongside
a deliberate, authorized change to the sources or assets."* C7 is that change, so the pin is updated
to `c0254b09…` and both values are now recorded in the file with which dispatch set them.

**What I did NOT do, and why.** `dist/ROBOTSA.BIN` is the pre-verified copy that shipped with the
source package and is what A2 verified against; the build byte-compares against it when present.
After C7 the tree legitimately no longer reproduces it. **I did not refresh it from my own build** —
a reference regenerated from the thing it is supposed to check proves nothing, which is CLAUDE.md
§8's standing rule about tautological checkers. Instead the local copy is preserved as
`dist/ROBOTSA.BIN.pre-c7`, which puts the build on the clean-checkout path `build.sh` already
documents (*"the pinned digest is the primary gate"*). `dist/` is gitignored, so none of this is a
repo change. **Whether to retire or re-establish that reference is Jay's call** — flagged in §7.

**Deviation 2 — three C6 assertions encoded the pre-C7 state and had to be updated.** The glyph
editor's selftest went from 57/0 to 57/3 the moment the byte landed. All three failures were correct:

| assertion | why it failed | resolution |
|---|---|---|
| `$20` is 121 tiles / 437 cells | tile 255's BR cell is now a `$20`, so glyph `$20` gains one tile and one cell | expectation updated to **122 / 438**, with a new check that the total went 2,303 → **2,304 cells** |
| tile 255 BR is `None` in both configs | true only for the a192 artifact now | split: shipped asserts **no** missing cell; a192 asserts **one**, because `build/c4/tileset-192.bin` was generated pre-C7 |
| `assets untouched vs HEAD` | C7 deliberately changes it | self-resolved on commit; re-run after committing is clean |

**Every other figure C6 quotes is unchanged** — `$4D` 122/210, `$3A` 108/396, `$66` 88/268, `$5F`
83/140, `$64` 60/176, `$67` 33/81, 69 distinct glyphs. That six of seven are untouched is itself
evidence the append disturbed nothing else.

**Deviation 3 — tile 255's storage warning was hardcoded and would have lied.** C6-A1 made the
editor warn *"bottom-right cell has NO STORAGE until tileset.bin is 2,816 bytes — do not spend this
slot yet."* That sentence was a constant. C7 removes the condition, and the warning would have gone
on telling Jay not to use the slot indefinitely. It is now **derived by reading
`assets/tileset.bin`**, so it disappears when the file is right and returns if a converter ever
shortens it again. The selftest asserts the note tracks the file in **both** directions rather than
asserting either text.

**Route accounting:** append-only, load address untouched, END block untouched, tile 255's other
eight cells untouched, no level file touched, explicit-path staging throughout.

### 7 — Uncertainty flags

1. **`dist/ROBOTSA.BIN` no longer has a role, and I have not decided its fate.** It is A2's
   pre-verified reference and the tree cannot reproduce it any more, by authorization. Preserved
   locally as `dist/ROBOTSA.BIN.pre-c7`. **Options are: retire the byte-compare step entirely
   (leaving the pinned digest as the gate, which `build.sh` already calls primary), or re-establish
   a reference from an independently verified build.** Refreshing it from our own build is the one
   option I ruled out. **Jay's call.**
2. **`build/c4/tileset-192.bin` still has the short table.** It is a gitignored C4 artifact
   generated before the fix. Regenerating it (`python tools/ladder.py`) is out of C7's scope but
   **will change the glyph editor's a192 numbers when it happens** — glyph `$20` there will gain
   tile 255's cell exactly as the shipped mapping just did. The selftest pins both states so the
   difference is recorded rather than latent.
3. **Tile 255 still draws the "255" caption** in its other eight cells. C7 deliberately did not
   touch them (§4). The slot is now structurally usable; whether to redraw it is Jay's, in the
   editor.
4. **Nothing places tile 255 in any level**, so this fix changes no visible output today. It removes
   a trap rather than fixing an observed defect — there is no before/after to look at, which is why
   there is no 25.3 gate and why the hash is the evidence.
5. **The appended `$20` is a choice, not a derivation.** The dispatch specifies it and it matches
   every blank tile, but nothing in the original file records what that cell was meant to be.

### 8 — Follow-up candidates

- **Decide `dist/ROBOTSA.BIN`'s fate** (flag 1). It currently has no function.
- **Regenerate C4's artifacts** against the fixed tileset when the art work next needs them (flag 2).
- **Carried, unchanged:** the two C6 questions Jay has not yet ruled on — which palette (`ladder.json`'s
  C4-derived set vs `assets/palette.json`'s adopted one) and whether the allocator should reserve the
  15 text slots at 192 glyphs. Settle the 27 `no static reference` tiles by MAME trace (C6-A1 §5).
  Retune slots 2/11 toward the art's greens (C5). Per-frame CPU budget before committing to sound.
  CLAUDE.md §2L's claim that level-load routines exist. **`main` is fifteen dispatches behind at
  `a62809e`.**

### 9 — User interaction during task

None. The dispatch was self-contained and executable from its own text plus the repo (§7 of
CLAUDE.md) — the before and after hashes it quoted both verified exactly, which is what made the
whole thing checkable without a relay.

### 10 — Candidate(s) captured this task

One, to `seeds/cocobots/live/` — pool commit **`8593dd8`**, pushed.

- **`a-warning-about-a-condition-must-read-the-condition`** — a hardcoded caution outlives the
  problem it describes and becomes a lie that no test catches, because the test asserts the text.
  Derive the warning from the state, and assert that it tracks the state in *both* directions.

### 11 — Commit

| | |
|---|---|
| the fix (`tileset.bin`, `build.sh`, tool assertions, protection catalog) | **`edfd06fe7b37d556538eeaba1637a86eaa210752`** |
| this report | committed separately; SHA in the delivering message per §7 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`8593dd8`**, pushed |

Explicit-path staging; no `git add -A`. Nothing applied to the game beyond the authorized byte.
