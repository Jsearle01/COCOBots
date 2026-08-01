# Sound engine — memory costing

**Status:** costing only, 2026-08-01. **Nothing implemented, nothing authorised.** No source or asset
touched. Answers Jay's question: *what would the sound engine cost?*

Sources: **POP3_port's PA.12 sound-feasibility report** (the research Jay remembered — it exists, and
it is a report, not code), and the **PET original's own engine**, measured from the pinned build
receipt in `reference/pet/`.

---

## 1. Answer in brief

| | bytes |
|---|---:|
| new CoCo3 code (timer/DAC init, FIRQ ISR, player, music tick, disk-mask) | **~435** |
| data (sound library + four used music tables) | **~606** |
| **total** | **~1,041** |

**Against the memory that exists:**

| configuration | free | after the level loader | **after sound too** |
|---|---:|---:|---:|
| 221 glyphs, no bootloader | 20 | — | **does not fit** |
| 221 glyphs + bootloader | 1,597 | 1,159 | **118** |
| 192 glyphs + bootloader | 2,525 | 2,087 | **1,046** |

**Sound does not fit without a bootloader**, and at 221 glyphs *with* one it leaves 118 bytes — not
a margin. **192 glyphs is the first configuration where sound, the level loader and the art all fit
with room to spare.**

---

## 2. What POP's research actually established

`POP3_port/reports/20260725-220315-pa-12-sound-feasibility.md`. It is a **CPU-budget** study, not a
memory one — but it settles the hardware, which is the part that would otherwise need discovering:

- **6-bit DAC at `$FF20`**, bits 7-2.
- **GIME timer FIRQ**: `$FF91` bit 5 TINS = 1 → 279.365 ns tick; `$FF93` bit 5 TMR enables;
  `$FF94/95` is the 12-bit reload. Every register verified against `SockmasterGime.md` rather than
  taken from the reference's comments.
- **FIRQ entry is 10 cycles, not 19** (it stacks only CC and PC), and **RTI is 6, not 15**, because
  E=0. Both are the kind of figure that is normally got wrong.
- Reference player: `Run-Dino-Run`'s 3-voice mixer — **85 cycles per interrupt**, 36.96% of a
  1.79 MHz CPU at 7.8 kHz. A minimum 1-voice PCM ISR is **51 cycles**, 22.17%.

**The one hard constraint, and it is forced rather than a preference:** audio must be silenced across
disk I/O. The CoCo FDC transfers through the **HALT line**, and a halted 6809 executes nothing *and
takes no interrupts* — so the audio FIRQ is suspended, not merely delayed. A 256-byte sector is
8.2 ms = **64 missed samples** at 7.8 kHz. The fix is to mask the FIRQ (or stop the timer) across the
sector transfer. **This couples the sound engine to the level loader**, which is the other open piece
of work.

**What POP did NOT have, and we do.** POP's music engine did not exist in its source of record —
`minit`/`mplay` were `ds 3` JMP slots patched at load time from raw disk track 34, so POP could not
transliterate music at all and would have had to re-author it. **PETSCII Robots has its complete
engine in the pinned PET build receipt.** That is a materially better starting position than the
sibling port had.

**Neither sibling port has a working player.** `POP3_port/src/hal/coco3-dsk/sound.s` and
`karateka_coco3/src/hal/coco3-dsk/sound.s` are the *same* 43-line file, and `HAL_sound_init` is a
no-op that clears carry and returns. karateka converted sound *data* (`content/sound/pcm_samples.bin`,
`tone_records.bin`, `tools/sound_convert.py`) but never wrote the engine. **There is no code to copy.**

---

## 3. The PET original's engine, measured

From `reference/pet/symbols.txt` — the pinned ACME build receipt, CLAUDE.md §2 rank 3. The whole
engine is one contiguous block, `$2503`–`$2623`:

| region | range | bytes |
|---|---|---:|
| `PLAY_SOUND` + `PSND1` + `PSND2` | `$2503`–`$2549` | 71 |
| temps (`PATTERN_L/H_TEMP`, `DATA_LINE_TEMP`, `TEMPO_TEMP`) | `$254A`–`$254D` | 4 |
| `SOUND_LIBRARY_L` | `$254E`–`$2561` | 20 |
| `SOUND_LIBRARY_H` | `$2562`–`$2575` | 20 |
| `MUSIC_ROUTINE` + `PS10`…`PS23` | `$2576`–`$25F1` | 124 |
| `STOP_SONG` + `STSN1` | `$25F2`–`$2623` | 50 |
| | **total** | **289** |

Plus scattered callers: `START_INTRO_MUSIC` 24, `START_IN_GAME_MUSIC` 33, `TOGGLE_MUSIC` 30,
`LEVEL_MUSIC` 10 — **97 bytes**.

Music data, the four tables actually used: `INTRO_MUSIC` 256, `WIN_MUSIC` 30, `LOSE_MUSIC` 24,
`IN_GAME_MUSIC1` 256 — **566 bytes**. (`IN_GAME_MUSIC2` and `3` are marked unused in the symbol
table and are excluded.)

**The CoCo3 tree carries none of it.** Zero live references to any sound symbol in
`PETROBOTS_6809.asm` or `BACKGROUND_TASKS_6809.ASM` — only **39 commented-out `JSR PLAY_SOUND`
call sites**. The call sites exist; the engine and the data do not.

---

## 4. The CoCo3 cost

| item | bytes | basis |
|---|---:|---|
| GIME timer + DAC init | ~30 | estimated |
| **FIRQ ISR, 3-voice mixer** | **44** | **measured** from POP's per-instruction table (85 cy ✓) |
| *(alternative: 1-voice PCM ISR)* | *21* | *measured (51 cy ✓)* |
| `PLAY_SOUND` replacement | ~70 | PET's is 71; POP notes handing to an ISR makes it *simpler*, not harder |
| `MUSIC_ROUTINE` equivalent | ~124 | same shape as the PET's — walk the table, set frequencies |
| `STOP_SONG` | ~50 | transliterable |
| FIRQ mask/unmask around disk I/O | ~20 | **required**, §2 |
| callers (`START_INTRO_MUSIC` etc.) | ~97 | transliterable from the PET |
| **code subtotal** | **~435** | |
| `SOUND_LIBRARY_L/H` | 40 | reusable in size; **values need retuning** — they are PET timer periods |
| music data (4 used tables) | 566 | reusable as-is if the note/tempo format is kept |
| **data subtotal** | **606** | |
| **TOTAL** | **~1,041** | |

Choosing the 1-voice PCM ISR instead saves 23 bytes and halves the CPU load, at the cost of the
3-voice music.

---

## 5. What is not costed here

- **CPU load on *this* game.** POP measured 36.96% of the CPU for 3-voice at 7.8 kHz against *POP's*
  frame budget. PETSCII Robots is a much lighter game, and its VSYNC handler already drives the game
  clock and unit timers. **Nobody has measured the CoCo3 port's per-frame budget**, so whether
  36.96% is comfortable or fatal here is unknown. This is the single biggest open question and it is
  cheap to answer with a MAME frame count.
- **Retuning the sound library.** The 20 entries are PET timer periods; the GIME timer runs at a
  different rate. Same byte count, but the values must be recomputed and then judged by ear — which
  is Jay's gate, like 25.3.
- **Whether the PET music format survives transliteration.** The 566 bytes are reusable *if* the
  player keeps the original's note/tempo encoding. Not verified.
- **Interaction with the level loader.** The disk-mask requirement (§2) means these two pieces of
  work touch each other. Doing sound first would need the mask hooks stubbed; doing the loader first
  is the cleaner order.

---

## 6. Provenance

- POP research: `POP3_port/reports/20260725-220315-pa-12-sound-feasibility.md`, and its instrument
  `poc/sound-budget/isr_count.py` — both ISR variants re-summed here and matching its headline
  figures (85 and 51 cycles) exactly.
- PET engine: `reference/pet/symbols.txt`, the pinned build receipt (CLAUDE.md §2 rank 3).
- Memory figures: [`loader-costing.md`](loader-costing.md) and
  [`glyph-budget-decision.md`](glyph-budget-decision.md).
