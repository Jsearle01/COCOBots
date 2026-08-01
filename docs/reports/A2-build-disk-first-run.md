# Form B Report — A2 — reproducible build, disk image, first MAME visual gate

**Class:** build. `wip`, pushed before reporting. No prod binary changed — this dispatch *created*
the first reproducible one. **No source file was modified.**

```
25.3: PENDING JAY — live-disk, RGB
```

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch A2 received. HEAD at receipt `28eaba5` (`wip`), tree clean.
HEAD at report `1c99f20` (`wip`), tree clean.

### 1 — Summary

All three parts delivered. The build reproduces the pre-verified binary **byte-for-byte from a
clean checkout**, the disk image builds and its file reads back byte-identical, and the port runs
**on the live-disk path — not poke.**

Measured, first ever execution of this port:

- `LOADM` completes and DECB returns `OK`; all eleven segments verified present in guest RAM
- `EXEC` transfers control — PC leaves ROM into the game's code region
- the port sets its own video mode, `$FF98 <- $80` / `$FF99 <- $3E`, exactly as documented, and
  writes its own 16-entry palette
- the VSYNC keyboard scanner responds; the menu navigates
- selecting **START GAME** leaves the menu loop and runs the main loop

Eight MAME screenshots and six framebuffer-decoded PNGs captured for Jay. **25.3 is not
self-certified and is not claimed.**

The dispatch's central prediction held: **the `$034D` line-buffer collision is latent, not active.**
Measured directly — after typing `EXEC`, the sprite table at `$034D` was byte-intact.

Four harness faults were found and corrected along the way, three of which had produced confident
false readings about working code. They are in §6 and §7 and are the bulk of §10.

### 2 — Files modified

Created and tracked:

| file | what |
|---|---|
| `build.sh` | build entry point (POSIX) |
| `build.bat` | build entry point (Windows), **CRLF-pinned** per idioms §14g |
| `tools/decbmerge.py` | DECB segment parse / report / merge / compare / sha256 |
| `tools/fb2png.py` | GIME framebuffer → native 1:1 PNG |
| `tools/a2c_liverun.lua` | MAME live-disk harness |

Modified: `.gitignore` — added `/cfg/`, `/snap/`, `__pycache__/`. MAME writes `cfg/` and `snap/`
into the working directory unless redirected, and they appeared as untracked noise.

**No file under `src/`, `assets/` or `art/` was touched.** Verified: `git status` shows no
modification to any of them.

Build products (all gitignored, none committed): `build/petrobots.bin`, `build/build.lst`,
`build/ROBOTSA.BIN`, `build/robots.dsk`, `build/run_a2c.dsk`, `build/a2c/*`.

### 3 — Reasoning

**Merge approach.** A DECB file is segments (`$00 len addr data`) plus one end block
(`$FF $0000 exec`). Merging is therefore concatenation of segments with a single new end block —
no address arithmetic and nothing to get subtly wrong. `tools/decbmerge.py` also refuses to write
a file whose segments overlap, and flags any segment landing in the four regions DECB uses during
or just after a `LOADM` (idioms §23, §28, §14e). It correctly flags `$034D` as a hazard, which is
the known-and-documented latent one.

**Why `-video none` was abandoned.** The first run used it for speed; MAME's snapshot then produces
nothing. Runs are ~700% speed windowed anyway, so the visual path stays enabled.

**Why both a MAME snapshot and a framebuffer decode.** The MAME snapshot is the authentic render
through the emulator's video path with Monitor Type = RGB. The framebuffer decode is native 1:1
square pixels per idioms §11b and is independent of MAME's display path. They corroborate each
other and neither depends on the other being right.

### 4 — Verification (AC-by-AC)

**AC1 — PASS.** Build runs from a clean checkout, one known warning, segment table matches,
15,931 bytes.

Verified by cloning `wip` to a fresh directory and running `./build.sh` there. Complete `lwasm`
output, verbatim — this is the 25.1 evidence:

```
Warning (src/PETROBOTS_6809.asm:3146): Operand size larger than required
```

That is the entire output. Exit code 0. `build/petrobots.bin` = **15,931 bytes**.

Segment table against the dispatch's expected values:

| expected | measured | |
|---|---|---|
| `$034D` / 138 | `$034D`–`$03D6`, **138** | ✅ |
| `$002E`–`$0080`, 51 total in 5 segments | `$002E`/2, `$0035`/9, `$0043`/34, `$007A`/3, `$007E`/3 = **51 in 5** | ✅ |
| `$0E01` / 1,721 | `$0E01`–`$14B9`, **1,721** | ✅ |
| `$14BB` / 9,875, ends `$3B4D` | `$14BB`–`$3B4D`, **9,875** | ✅ |
| `$41F6` / 4,096, ends `$51F5` | `$41F6`–`$51F5`, **4,096** | ✅ |
| exec `$0E01` | **`$0E01`** | ✅ |

**AC2 — PASS.** `build/ROBOTSA.BIN` is byte-identical to `dist/ROBOTSA.BIN`.

```
IDENTICAL: build/ROBOTSA.BIN == dist/ROBOTSA.BIN (27460 bytes)
sha256  13b8b4c078174abba8f059ebd35a1e9fb0b892b83a42ce8dd5fb34134b8f6c9a   (both)
```

**27,460 bytes**, span `$002E`–`$7EFF`, **overlaps: none**. Segment count is **11, not the 10 the
dispatch states** — see §7 flag 1. The reference copy has 11 as well, and byte-identity is the
real gate.

**AC3 — PASS.** `build/` gitignored, scripts tracked:

```
IGNORED  build/ROBOTSA.BIN   <- .gitignore:12:/build/
IGNORED  build/robots.dsk    <- .gitignore:12:/build/
IGNORED  build/run_a2c.dsk   <- .gitignore:12:/build/
tracked  build.sh
tracked  build.bat
tracked  tools/decbmerge.py
```

**AC4 — PASS.** `.dsk` builds and lists the file at the expected size:

```
Contents of build/robots.dsk:
ROBOTSA.BIN                       27460             2 B
       1 File(s)           27460 bytes            129024 bytes free
```

Image is 161,280 bytes = 35 tracks × 18 sectors × 256 B. Going beyond "listed", the file was
**read back off the disk and byte-compared** — `imgtool get` → `IDENTICAL … (27460 bytes)`, and its
segment table re-parsed clean from the extracted copy. The dispatch asked for listed *and*
readable; this is the readable half.

**AC5 — PASS.** The program loads and executes.

| question | answer | evidence |
|---|---|---|
| does `LOADM` complete? | **yes** | `OK` printed below the command on the text screen; 1,004 frames after typing |
| are all segments present? | **yes** | `$0E01`=`10 CE 01 FF`, `$41F6`=`00 01`, `$5200`=`AA AA`, `$5D00`=`01 03`, `$7EFF`=`D3` |
| does `EXEC` transfer control? | **yes** | PC leaves ROM; sits in `ISLOOP` (`$1F75`), the intro menu key-wait |
| does the screen change from DECB text mode? | **yes** | `$FF90<-$08`, `$FF98<-$80`, `$FF99<-$3E`, `$FF9D<-$F0`, plus all 16 palette registers |
| does the keyboard respond? | **yes** | `MENUY` `$00`→`$01` on move-down, back to `$00` on move-up |
| does the game start? | **yes** | after SPACE at menu 0, PC ranges across `$1321`–`$26E1` |

**AC6 — PASS.** 14 PNGs captured — 8 MAME snapshots + 6 framebuffer decodes. Paths and the exact
invocation in §5.

**AC7 — PASS.** Gate line is `25.3: PENDING JAY — live-disk, RGB`. Not self-certified. No claim is
made anywhere in this report about what the screenshots depict.

### 5 — Verdict-time evidence

**25.1 — the complete `lwasm` invocation and output:**

```
$ lwasm --format=decb --output=build/petrobots.bin --list=build/build.lst src/PETROBOTS_6809.asm
Warning (src/PETROBOTS_6809.asm:3146): Operand size larger than required
$ echo $?
0
```

**`imgtool` listing:**

```
$ imgtool create coco_jvc_rsdos build/robots.dsk --heads=1 --tracks=35 --sectors=18 --sectorlength=256
$ imgtool put coco_jvc_rsdos build/robots.dsk build/ROBOTSA.BIN ROBOTSA.BIN --ftype=binary --ascii=binary
Putting file 'build/ROBOTSA.BIN'...
$ imgtool dir coco_jvc_rsdos build/robots.dsk
Contents of build/robots.dsk:
ROBOTSA.BIN                       27460             2 B
       1 File(s)           27460 bytes            129024 bytes free
```

**The MAME invocation, verbatim:**

```
mame coco3 -rompath C:/mame/roms -ext fdc -flop1 build/run_a2c.dsk
     -autoboot_script tools/a2c_liverun.lua
     -snapshot_directory build/a2c -cfg_directory build/a2c/cfg
     -nothrottle -sound none -seconds_to_run 130 -window -nomaximize -skip_gameinfo
```

`-ext fdc` per idioms §14a. `build/run_a2c.dsk` is a **copy** of `build/robots.dsk` per idioms §24
— MAME opens floppies read-write and the built artifact is never mounted. Monitor Type is set to
**RGB** from Lua (`:screen_config`, `field.user_value = 1`) per idioms §11l, since it is a machine
config and not a CLI flag, and MAME's default is Composite.

`mame coco3 -verifyroms` reports `bad`. Per idioms §14a this is benign: every missing file is an
*alternate* DOS ROM (`disk10`, `ados*`, `rgbdos_mess`, `hdbdw3bck`, `hdbdw3bc3`). `disk11.rom`,
the one that matters, is present inside `coco3.zip` — confirmed by listing the archive.

**Guest-side trace of the launch:**

```
boot settled           frame=300    PC=$A7D5
|DISK EXTENDED COLOR BASIC 2.1|
|OK|
posted LOADM at frame 301
LOADM keystrokes drained at frame 451 (150 frames)
LOAD COMPLETE at frame 1455 (1004 frames after typing)
  $0E01..$0E08 = 10 CE 01 FF 4F 1F 8B 1A  (entry)
  $41F6 = 00 01 (font)   $5200 = AA AA (tileset)   $5D00 = 01 03 (level)
  $7EFF = D3 (last byte of the last segment)
|LOADM"ROBOTSA"|
|OK|
posted EXEC at frame 1576
EXEC keystrokes drained at frame 1636
|EXEC|
```

**GIME writes after `EXEC` — the video mode change (write tap; these registers cannot be read):**

```
f=1626 $FF90 <- $08
f=1626 $FF98 <- $80
f=1626 $FF99 <- $3E
f=1626 $FF9D <- $F0
f=1626 $FF9E <- $00
```

`$FF98/$FF99 = $80/$3E` is exactly what CLAUDE.md §2G specifies for this port. The port also wrote
all sixteen palette registers at the same moment:

```
$FFB0-$FFBF = $00 $3F $10 $09 $07 $38 $22 $0B $30 $26 $37 $12 $34 $20 $00 $3F
```

**The `$034D` collision — measured, and latent as predicted (CLAUDE.md §2H):**

```
line buffer $02DD..$02E4    = 00 00 00 43 00 4F 54 53
$034D..$0354 sprite table   = 2C 20 20 20 20 2C E2 F9      <- byte-intact
```

Those eight bytes are exactly the first eight of the `$034D` segment in the file. Typing `EXEC`
did not reach it.

**Keyboard, measured at `CURRENT_KEY` (`$0034`) by write tap:**

```
f=1879 key=$01      f=1882 key=$53 ('S', move down)  -> MENUY $00 -> $01
f=2059 key=$01      f=2062 key=$57 ('W', move up)    -> MENUY $01 -> $00
f=2299 key=$20 (SPACE, select)                       -> START GAME
```

**PC before and after selecting START GAME — the execution evidence:**

```
watch +480   PC=$1F78  S=$01FD     <- ISLOOP, menu key-wait
watch +600   PC=$1F77  S=$01FD
   ... SPACE ...
watch +720   PC=$1E4C  S=$01FB
watch +840   PC=$1B9A  S=$01F5
watch +960   PC=$1321  S=$01FD
watch +1080  PC=$26E1  S=$01FB
watch +1200  PC=$1B96  S=$01F5
watch +1800  PC=$13E4  S=$01FC
```

Pinned in a two-instruction loop before, ranging across the whole code region after.

**Stack behaviour**, bearing on dispatch §8's third suspect: S stayed within **`$01F5`–`$01FD`**
across every sample — about 10 bytes deep, never approaching DECB's `$010C` IRQ vector. The
`LDS #$01FF` suspect is not implicated on this evidence.

**Screenshots — surfaced for Jay, not interpreted (CLAUDE.md §3).**

All under `build/a2c/`, which is **gitignored and therefore local-only** — they are not on the
remote (§7 flag 4).

MAME snapshots, RGB monitor, authentic render path:

| file | point in the run |
|---|---|
| `shot-00-decb-prompt.png` | DECB prompt, before anything |
| `shot-01-after-loadm.png` | after `LOADM` returned `OK` |
| `shot-02-exec+60.png` | 60 frames after `EXEC` |
| `shot-03-menu.png` | intro menu, selection at entry 0 |
| `shot-04-menu-start.png` | menu, selection returned to START GAME |
| `shot-05-ingame.png` | after selecting START GAME |
| `shot-06-ingame2.png` | +360 frames later |
| `shot-07-final.png` | +960 frames later |

Framebuffer decodes, native 320×200 at ×3 integer scale (idioms §11b): `screen-menu.png`,
`screen-after-key.png`, `screen-menu-start.png`, `screen-ingame-1/2/3.png`.

**One mechanical observation offered without interpretation.** The three in-game framebuffer
captures — 840, 1200 and 1800 frames after `EXEC`, spanning ~16 emulated seconds — are
**byte-identical to one another** (SHA-256 `cfba03856671…`), while the PC continues to range across
the code region. The menu captures do differ from each other when the selection changes, so the
capture path does detect change. Whether anything in this game is expected to animate without
player input is **Jay's call, not mine** — recorded as a measurement, not a defect.

### 6 — Reactive deviations and ROUTE ACCOUNTING

**The route was as dispatched: A2a → A2b → A2c, live-disk, no fallback to poke.** The gate line
says `live-disk` because that is what ran. Nothing was poked at any point.

Deviations and additions, with what the commits actually contain:

1. **`tools/decbmerge.py` and `tools/fb2png.py` are more than the dispatch asked for.** It asked
   for a build script; the merge needs real DECB parsing, and putting it in a tested tool with a
   `report` mode is what made the segment table checkable at all. `fb2png.py` exists because MAME's
   Lua snapshot appeared to be producing nothing (§7 flag 3) and idioms §11b prefers a direct
   framebuffer decode for this target regardless.

2. **The build gates on a pinned SHA-256, not only on `dist/ROBOTSA.BIN`.** `/dist/` is gitignored,
   so **a clean checkout has no reference copy** and the dispatch's specified byte-compare
   physically cannot run there — which would have made AC1's "runs from a clean checkout" and AC2's
   byte-compare mutually unsatisfiable. The digest is pinned in both scripts and checked always;
   the byte-compare still runs additionally when `dist/` is present. Both paths were exercised.

3. **`.gitignore` gained `/cfg/`, `/snap/`, `__pycache__/`.** MAME and Python wrote these into the
   repo root. Not requested; flagged here rather than done silently.

4. **Four harness faults found and fixed mid-dispatch.** All four were mine, none were in the port,
   and three produced confident wrong readings:

   - **Read-back of write-only registers.** v1 logged GIME state by reading `$FF90`–`$FF9F`. All
     five registers returned the *same* byte every sample — the floating bus. Replaced with a write
     tap, which is what produced the `$80/$3E` evidence above.
   - **Polled for the first segment, not the last.** v1 treated the entry point landing as "loaded"
     and typed `EXEC` into a DECB still streaming 25 KB off the floppy. DECB does not poll the
     keyboard during disk I/O, the keystrokes were dropped, and **v1's honest conclusion was that
     `EXEC` did not transfer control** — a false negative on the dispatch's milestone. Fixed by
     gating on the last segment *and* the prompt returning. Apparent load time went from 162 frames
     to an actual 1,004.
   - **Snapshot verification checked the wrong path.** MAME resolves a snapshot filename relative
     to `-snapshot_directory`; the harness passed a path and then looked for the file at that
     literal path. Five real PNGs existed at `snap/build/a2c/…` while the log reported `0 bytes`.
   - **Read tap contaminated by loader traffic.** Taps on the code region and on the game-start
     entry fired at frames 24 and 618 — before the program was even loaded (load completed at
     1455). The one-shot latch then reported "IN GAME since frame 618" forever. Discarded in favour
     of PC sampling.

5. **A probe that manufactured a fault.** To prove the keyboard worked, the harness pressed
   move-down and watched the menu variable change. That moved the selection **off** START GAME onto
   "cycle maps", whose handler deliberately branches back to the menu loop. The subsequent SPACE
   therefore cycled a map, and the run looked exactly like *"select key delivered, game refuses to
   advance"* — a reportable fault under dispatch §6, with two independent instruments agreeing.
   Caught by reading the handler for the entry actually selected. The harness now restores the
   selection and asserts it before selecting. **Nothing was wrong with the port.**

6. **No fix of any kind was attempted on the port**, and none was needed.

### 7 — Uncertainty flags

1. **Segment count is 11, the dispatch says 10.** `build/ROBOTSA.BIN` has 9 game segments + tileset
   + level. The reference `dist/ROBOTSA.BIN` also has 11, so the two agree and byte-identity holds;
   I read the dispatch's "10" as a miscount. Flagged rather than reconciled silently.

2. **The framebuffer decode assumes CPU `$8000` is the displayed region.** CLAUDE.md §2G states the
   port writes a single buffer at `$8000`, and `$FF9D/$FF9E = $F0/$00` gives a GIME start of
   `$78000`, which masks to the same physical block that CPU `$8000` maps to on this machine — so
   they agree *by derivation*. I did not verify the MMU mapping directly. **The MAME snapshots do
   not depend on this** and are the safer artifact of the two.

3. **`screen:snapshot()` behaviour cost three runs.** It silently produces nothing under
   `-video none`, and with video enabled it resolves filenames relative to `-snapshot_directory`.
   Recorded here and in §10 since idioms has no note on either.

4. **The screenshots are in `build/`, which is gitignored — they are local-only.** The Orchestrator
   reading `wip` will not see them, and they are absent after a context reset. This is the same
   invisible-artifact problem A1 solved with tracked manifests. **Not resolved here**, because the
   dispatch is explicit that `build/` must not be committed. If these captures should survive, they
   need a decision on where — `docs/reports/` alongside this file would work.

5. **`.gitattributes` still does not exist, and A2 has raised the stakes.** A1 flagged this; idioms
   §14g now makes it directly load-bearing — `build.bat` **must** stay CRLF or `cmd.exe` cannot
   parse it, and §14g says to pin it in `.gitattributes` rather than rely on any developer's
   `core.autocrlf`. Verified the committed blob holds 57 CRLF line endings and is byte-identical to
   disk, so it is correct *today* on this machine. A contributor with `core.autocrlf=input` could
   still normalise it. Recommend `*.bat text eol=crlf` plus `* -text` before anyone else clones.

6. **Python is now a build dependency.** The dispatch did not name an implementation language for
   the merge step. Python 3.13 was present; the tools use only the standard library. If the build
   must be Python-free, the merge is ~40 lines of anything.

7. **The in-game framebuffer does not change across ~16 emulated seconds** (§5). Stated as a
   measurement. I do not know whether this game animates without input, and I have not looked —
   determining that would mean interpreting behaviour I was told to capture and report.

8. **MAME `-verifyroms` reports `bad`.** Benign per idioms §14a — but §14a lists three missing
   alternate ROMs and this MAME (0.281) lists nine. Same class, larger list.

### 8 — Follow-up candidates

- **A `.gitattributes`** — §7 flag 5. Now load-bearing for `build.bat`, not just tidiness.
- **Decide where run captures live** — §7 flag 4. `build/` is correct for throwaway artifacts and
  wrong for the evidence behind a gate.
- **Add the three new MAME idioms to `mame-idioms-coco3-port.md`** — §10. Idioms §2A rule 3 says a
  discovered idiom goes in the file, but §2D reserves authored-doc bodies to the Orchestrator, so
  they are surfaced here rather than written in.
- **`imgtool`'s createopts need `=`** (`--tracks=35`, not `--tracks 35`), which fails with a bare
  usage message and exit 255. Minor, undocumented, cost a cycle.
- **The `-seconds_to_run` budget is tight**: the full sequence needs ~3,450 frames ≈ 58 emulated
  seconds; 130 was used with margin.

### 9 — User interaction during task

None. No questions raised, no clarification requested. The dispatch, CLAUDE.md and the idioms file
between them covered everything, and the two things they did not cover (the clean-checkout `dist/`
problem, and the Python dependency) were routine judgment calls recorded in §6 and §7.

### 10 — Candidates captured this task

Four new rows in `seeds/cocobots/live/`, pool commit **`8c58471`**, pushed. **New rows only — no
existing entry was read or edited.** All four are instrument failures from the first run of code
nobody had ever executed, which is the environment dispatch §10 predicted would generate them.

| slug | one line |
|---|---|
| `read-back-of-a-write-only-register-is-the-floating-bus` | Check the observed thing is *readable* before building an instrument on reading it; five registers returning one value is the tell |
| `poll-for-the-last-artifact-not-the-first` | A completion signal must be the last artifact a producer emits; the first-produced one arrives while it is still working |
| `probe-that-moves-state-manufactures-the-defect` | A probe that mutates state owes a restore *and* an assertion — otherwise every downstream instrument faithfully measures the system you disturbed |
| `read-tap-as-execution-detector-is-contaminated` | A tap says an address was *accessed*, not that code *executed*; loaders and memory clears touch it too |

Three MAME idioms discovered that belong in `mame-idioms-coco3-port.md` (§2D — Orchestrator's to
fold in):

- `screen:snapshot()` **silently writes nothing under `-video none`**, and returns success.
- With video enabled, a snapshot filename resolves **relative to `-snapshot_directory`** — passing
  a path puts files somewhere unexpected and a naive existence check then reports failure.
- **`imgtool` createopts require `=`** — `--tracks 35` fails with a bare usage message and exit 255;
  `--tracks=35` works.

### 11 — Commit

| | |
|---|---|
| `9cda36c` | A2: reproducible build, boot disk, and first live-disk run |
| `1c99f20` | A2: gate the build on a pinned digest, not just `dist/ROBOTSA.BIN` |
| branch | `wip`, pushed — `origin/wip` at `1c99f20` |
| `main` | untouched at `a62809e` |
| pool | `8c58471`, pushed |

`wip` was pushed before this report was written (push-before-report, CLAUDE.md §2E). Working tree
clean; no source file modified.
