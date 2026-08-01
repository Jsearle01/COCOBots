# Gate record — A2 25.3 — first live run of the CoCo3 port

```
25.3: PASSED — Jay, live-disk, RGB — 2026-08-01
```

**Observer:** Jay (project owner and co-author of the port).
**Launch path:** `live-disk` — `./run.sh --auto`, real `LOADM"ROBOTSA"` + `EXEC` from a mounted
floppy. **Not `poke`, not `static-png`.** This is the only path that gates delivery (CLAUDE.md §4).
**Monitor:** RGB, applied from `tools/mame-cfg/coco3.cfg` and verified against a negative control.
**Under test:** `ROBOTSA.BIN`, sha256 `13b8b4c078174abba8f059ebd35a1e9fb0b892b83a42ce8dd5fb34134b8f6c9a`,
27,460 bytes — the artifact `build.sh` pins and reproduces.

---

## What was observed

Jay confirmed the run matched the pre-stated expectations in A2 §5 in full:

| # | expected | observed |
|---|---|---|
| 1 | `LOADM` completes, DECB returns `OK` | ✅ |
| 2 | `EXEC` transfers control; screen leaves DECB text mode | ✅ |
| 3 | intro menu renders | ✅ |
| 4 | keyboard responds; menu navigates | ✅ |
| 5 | selecting START GAME enters the main loop | ✅ |
| 6 | **monochrome white-on-black** — correct, not a defect (§4) | ✅ as expected |
| 7 | **player health bar renders wrong** — glyph `$66` corrupt (§2J) | ✅ as expected |

Items 6 and 7 were **predicted before the run** and confirmed as predicted. That is the point of
having listed them: neither is a defect, and neither should be filed as one.

**Nothing unexpected was reported.**

---

## What this establishes

**The CoCo3 port runs.** First execution in the project's history, on the real disk path, with no
source modification of any kind. Every claim previously derived from static analysis that could be
checked against a running machine has now been checked:

- video mode `$FF98/$FF99 = $80/$3E` — as CLAUDE.md §2G specifies, measured by write tap
- all 16 palette registers written match `graphics.asm` exactly, independently verified
- the `$034D` line-buffer collision is **latent, not active** — the sprite table was byte-intact
  after typing `EXEC` (CLAUDE.md §2H). **A bootloader is not required.**
- stack stayed within `$01F5`–`$01FD`, nowhere near DECB's `$010C`

---

## What this does NOT establish

State these plainly so nothing is over-claimed on the strength of one gate:

1. **Gameplay correctness.** The gate confirms the port reaches and runs the main loop. It does not
   confirm robot AI, collision, weapons, items, doors, or scoring behave correctly.
2. **The other nine levels.** Only `level_a` was in the binary under test.
3. **Restart / level select.** Known not to work — `MAP_LOAD_ROUTINE` is commented out.
4. **Sound.** Entirely commented out in the port.
5. **Long-run stability.** The observed window was short.

---

## A2 §7 flag 7 — CLOSED by Jay's ruling

A2 measured that three in-game framebuffer captures spanning ~16 emulated seconds were
byte-identical while the PC continued to range across `$1321`–`$26E1`.

**Jay's ruling, 2026-08-01: not a concern. The live run is the verification; static captures are
supporting evidence and do not raise findings on their own.** Flag closed.

Recorded precisely so the basis is not misremembered later: this is closed **by ruling on what
counts as evidence**, not by an observation that the game does animate. Should a future dispatch
have reason to investigate background tasks — the VSYNC IRQ handler, the cascaded unit timers, or
`BACKGROUND_TASKS_6809.asm` — this measurement exists and can be re-read. It is not a defect and
must not be carried forward as one.

**General consequence, applies from here on:** a static-capture measurement is not a finding.
Anything worth raising about running behaviour must be raised from a live run.

---

## Follow-ups carried forward

| item | source | state |
|---|---|---|
| §7 flag 7 — static in-game framebuffer | A2 | **CLOSED** — Jay's ruling, see above |
| Decide where run captures live (`build/` is gitignored) | A2 §7 flag 4 | open |
| Fold three new MAME idioms into `mame-idioms-coco3-port.md` | A2 §10 | open (§2D — Orchestrator) |
| Pinned-digest check on the three source blobs | A1b §8 | open |
| A1 flag 5 / A2 flag 5 (`.gitattributes`) | — | **CLOSED by A1b** |

---

## Phase status

**Phase A complete** (A1, A1b, A2). **Phase B absorbed into A2** — the poke harness (B1) was never
built because live-disk worked on the first attempt, which is the better outcome; B2 became A2c.

Phase C is unblocked, all three items independent:

- **C1 — level loading** (resident loader; POP3_port as disk-access reference; CLAUDE.md §2L)
- **C2 — sound** (oracle already in-repo: `SOUND_LIBRARY_L`/`_H`, three music tables, 39 commented
  `PLAY_SOUND` call sites)
- **C3 — art conversion** (CLAUDE.md §2M; prerequisites: repair `$55`/`$66`/`$CD`, then verify the
  `image.png` ↔ `tileset.bin` correspondence)
