# Form B Report — C6-A3 — accept the quantised reference as an authored edit

**Class:** build (feature). `wip`, pushed before reporting. **No 25.3 gate** — tool, not game output.
**Jay's acceptance is by using it.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C6-A3 received. HEAD at receipt `207a5b1` (`wip`), tree clean.

### 1 — Summary

**Both buttons built, with the cost shown before the write and the outcome after it.**
`uitest.py` **55 checks** and `selftest.py` **58 checks**, both 0 failed. Round-trip unchanged, no
shipped asset touched, `check_fits()` passes.

**The dispatch's warning about layout space was justified.** Built as the obvious stack — buttons,
then checkboxes, then a multi-line cost label inside the left column — it added **142 px** and took
the window to **861 px against an 824 px budget**. AC10 said verify rather than assume, and there
was not room. Rebuilt as one full-width row it costs **~40 px**; the window is **803 px** and
`check_fits()` is green.

**One refinement to §2's conflict figure that is worth having.** §2 counts a glyph as conflicted when
it is written from more than one cell. But sometimes the competing art is **identical**, and then
nothing is lost. Tile 4 in the shipped mapping is exactly that case: four glyphs are written twice
or more, but only **two** carry differing art. The tool reports the two separately from the two, so
the warning means "you will lose art here" rather than "something might be wrong".

### 2 — Files modified

| path | change |
|---|---|
| `tools/glyph_tool/accept.py` | **new**, 190 lines — planning, conflict resolution, cost/outcome text, blast radius |
| `tools/glyph_tool/edit_model.py` | one history across all glyphs; `apply_txn` writes N glyphs as ONE undo |
| `tools/glyph_tool/glyph_tool_app.py` | the accept row, per-cell tick boxes, live cost, rebound undo/redo |
| `tools/glyph_tool/progress.py` | `ACCEPTED` provenance, distinct from hand-drawn |
| `tools/glyph_tool/queues.py` | `cheap-accept` queue, ascending blast radius |
| `tools/glyph_tool/uitest.py` | +8 driven tests for the new paths |

**Read, never written:** `assets/tileset.bin`, `assets/palette.json`, `art/*.png`.

### 3 — Reasoning

**Why a `plan` step exists at all.** Copying pixels is four lines. Everything else in `accept.py` is
there because the two hazards are near-universal: 253 of 256 tiles write some glyph from more than
one cell, and **no tile in the shipped mapping has all nine cells on glyphs unique to it**. So the
module computes the full consequence — which glyphs, which tiles, which cells lose the tie-break,
which text/UI consumers are hit — *before* anything is written, and the same structure produces both
the before-text and the after-text. They cannot drift apart because they are the same object.

**Conflict rule: first cell in TL→BR order wins.** Deterministic, explainable in one line, and the
losers are named. The alternative the dispatch allows — asking Jay to pick per glyph — is a modal
dialog per conflicted glyph on 252 of 256 tiles, which would make the feature slower than drawing.

**Inverse cells.** `wanted()` stores `15 − px` where a cell is inverse-coded, because the plotter
complements every nibble at draw time. This is a **no-op in a192** (inverse was removed) and only
matters in the shipped mapping — but storing the wrong polarity there would be invisible until
someone looked at the game.

**One history, not two stacks.** `FontEdit` now keeps a single list of "which glyphs moved together".
A paint stroke records one glyph; an accept records all of them. Undo pops the entry and undoes that
stroke on each. The per-glyph stacks still exist underneath and still work, so nothing C6 or C6-A2
asserted about them changed — this only records the grouping, which a per-glyph stack cannot know.

### 4 — Verification (AC-by-AC)

`uitest.py` **55 checks, 0 failed** · `selftest.py` **58 checks, 0 failed**. Logs tracked.

**AC1 — visible labelled buttons with shortcuts.**
`accept cell (a)` and `accept tile (9)  (Shift-A)`, with `accept from QUANTISED art:` beside them so
the source is unambiguous while a different reference view is showing. `a` was the strip toggle in
C6-A2; the strip moved to `s` and its button label updated.
```
PASS A3-AC1 accept buttons exist and name their key   []
PASS A3-AC1 the source is named beside them           accept from QUANTISED art:
```

**AC2 — cost computed from the loaded tileset. Reconciled against §2.**

The tool loads **a192**; §2's figures are from **shipped**. Both measured:

| | shipped (§2's basis) | a192 (what the tool loads) |
|---|---|---|
| tiles with an intra-tile conflict | **253 / 256** ✓ matches §2 | 252 / 256 |
| tiles with all nine cells on unique glyphs | **0** ✓ matches §2 | 1 |
| blast radius min / median / max | 2 / 184 / **231** | 1 / 85 / 171 |
| **tile 4** | 4 glyphs → **193 tiles** | 5 glyphs → 87 tiles |
| **tile 136** | 6 glyphs → **231 tiles** ✓ matches §2 | 6 glyphs → 144 tiles |

**§2's "tile 136 touches 231 tiles" reproduces exactly.** The a192 profile is roughly half as
severe — median blast 85 against 184 — which is what removing inverse and spending 82 more slots
buys.

Live output for tile 4, shipped:
```
accept tile $04 (9 cells) -> 4 distinct glyphs -> changes 193 tiles
  ! 2 glyphs receive conflicting art: $20 x3, $4D x2
  ! TL->BR wins: keeping $20<-TL, $4D<-MM, dropping MR, BM, BR
  (2 glyphs written twice with identical art - no loss: $64, $67)
  ! also drawn by text/UI: $20 (also used by text)
```
**This is where §2's figure refines.** §2 lists tile 4's conflicts as `$20 x3, $64 x2, $67 x2,
$4D x2` — four glyphs. All four *are* written from multiple cells, but `$64` and `$67` receive
**identical art** from both, so nothing is lost. The tool separates the two, and says so.

The cost also tracks the tick boxes rather than being a constant (`A3-AC2 cost tracks the tick
boxes`). Screenshots `A3-01`, `A3-03`, `A3-05`.

**AC3 — no silent last-write-wins. LOAD-BEARING.**
Rule implemented: **first cell in TL→BR order wins.** Proved on tile `$02`, which has two glyphs
written from multiple cells with **differing** art — not a tile where the competing art happens to
agree, which would prove nothing about the tie-break:
```
PASS A3-AC3 a tile with DIFFERING conflicting art exists  tile $02, 2 glyph(s): $3A x5, $3B x4
PASS A3-AC3 first cell in TL->BR order wins              winner == min(cells) for all
PASS A3-AC3 dropped cells are recorded                   2 glyphs with dropped cells
PASS A3-AC3 conflict stated BEFORE and AFTER the write   before: names them; after: names what was dropped
```
After the write the banner reads e.g. `applied TL->$20, MM->$4D; DROPPED MR, BM, BR (same glyph,
different art)`.

**AC4 — per-cell opt-out.** Nine tick boxes labelled `TL…BR`, plus `all` / `none`. Verified by
ticking the top row only and confirming the other glyphs were untouched:
```
PASS A3-AC4 included_cells reflects the boxes     [0, 1, 2]
PASS A3-AC4 only the ticked cells were written    wrote ['$0E', '$3C']; left ['$24', '$40', '$8E'] untouched
```
Screenshot `A3-02`.

**AC5 — one undo step. LOAD-BEARING.**
```
PASS A3-AC5 accept changed the font                1f25ee246820 -> e418fc086ebf
PASS A3-AC5 accept is exactly ONE history entry    5 glyphs written in 1 entry
PASS A3-AC5 one undo restores byte-identically     1f25ee246820 == 1f25ee246820
PASS A3-AC5 undo cleared the accepted provenance   sidecar does not claim art the font no longer holds
```
Hashed before, accepted, undone once, hashed again — **byte-identical**. The fourth check is one the
dispatch did not ask for: undo also drops the `accepted` provenance, or the sidecar would claim art
the font no longer holds.

**AC6 — provenance distinguishable.** New sidecar state `accepted`, its own `accepted` map recording
`<when> tile $NN <cell>`, and its own count. A later hand stroke promotes the glyph to `edited`,
which is the honest description once someone has drawn over it.
```
PASS A3-AC6 accepted glyphs are marked `accepted`   glyph $0E -> accepted (2026-08-01T21:53:48 tile $04 TM)
PASS A3-AC6 the sidecar counts them separately      {'untouched': 187, 'edited': 0, 'accepted': 5, 'done': 0}
PASS A3-AC6 drawing over an accept promotes it to `edited`
```

**AC7 — source is the quantised reference regardless of view.** Accepted the same tile with the view
on `raw`, on `C64 oracle`, and on `quantised`; all three produce the identical font hash
`e418fc086ebf32f2`. Also asserted the source really is an index map 0–15, not RGB.

**AC8 — cheap-first queue.** `cheap-accept`, all 256 tiles sorted by ascending blast radius:
`first [1, 4, 5, 5] … last [154, 167, 171]`. Screenshot `A3-04`.

**AC9 —** `uitest.py` **55 checks, 0 failed**; `selftest.py` **58 checks, 0 failed**.

**AC10 — no regression.** Round-trip still
`b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c` on an unedited load/save; the
seven sharing figures still reproduce; `git diff HEAD` over the 13 shipped assets is empty;
`check_fits()` passes — **verified, not assumed**, and it initially did not (§1).

### 5 — Verdict-time evidence

Six screenshots, **6 distinct hashes**, plus both logs, tracked under `docs/reports/C6-A3-renders/`.
Surfaced for Jay's inspection per CLAUDE.md §3; **their content is not analysed or judged here.**

| file | state |
|---|---|
| `A3-01-cost-tile4-all9.png` | tile 4, all nine ticked, full cost shown |
| `A3-02-subset-top-row.png` | only TL/TM/TR ticked — the cost changes with them |
| `A3-03-cost-tile136-high-blast.png` | tile 136, the worst case in a192 |
| `A3-04-cheap-accept-queue.png` | the cheap-first queue at its head |
| `A3-05-shipped-tile4-conflicts.png` | shipped config, §2's worked example |
| `A3-06-quantised-view-source.png` | the quantised view — what accept takes |

The authored font is byte-identical before and after every test run (`1f25ee24…`) — checked
explicitly this time, after C6-A2 §6 deviation 5.

### 6 — Reactive deviations and ROUTE ACCOUNTING

**Deviation 1 — the accept controls were rebuilt after failing the layout check.** Described in §1.
The first arrangement was the natural one and it did not fit; `check_fits()` — rewritten in C6-A2 to
report only real clipping — caught it immediately, which is the first time that guard has earned its
place rather than crying wolf.

**Deviation 2 — `a` was reassigned and the strip moved to `s`.** The dispatch's own button label
(`accept cell (a)`) collides with C6-A2's strip toggle. Accept is the more frequent action, so it
took `a`; the strip button label and the docstring were updated together so no stale shortcut is
advertised.

**Deviation 3 — `STATE_BG` had no colour for the new state**, which crashed `refresh_status` with
`KeyError: 'accepted'` the moment a glyph was accepted. Caught by the driven tests, not by
inspection — a model test would not have exercised the status bar.

**Deviation 4 — two small evidence-only CLI flags** (`--queue`, `--include`) so the screenshots show
real states rather than states I describe in a caption. Same reason C6-A2 added `--view`.

**Route accounting:** `assets/tileset.bin` opened read-only, never written; no cell→glyph
reassignment; palette untouched; **no bulk-accept anywhere** — every write is one deliberate click,
per §6; explicit-path staging.

### 7 — Uncertainty flags

1. **Identical-art conflicts are reported as "no loss", and that is a judgement about pixels.** Two
   cells whose quantised art is byte-identical genuinely lose nothing — but if the JPEG noise
   differs by a single pixel they count as a real conflict and get the warning. The threshold is
   exact equality; there is no tolerance. That is the conservative direction, but it will
   occasionally warn about a difference nobody could see.
2. **TL→BR tie-break is arbitrary in the cases that matter.** When three cells write one glyph with
   three different pictures, "the first one" is not obviously the best one. The dispatch permitted
   asking Jay to choose; I judged a modal per conflicted glyph on 252 of 256 tiles to be worse than
   the rule. **If the wrong cell keeps winning in practice, the fix is a per-glyph winner picker and
   it is not large.**
3. **No preview of the accepted result before committing.** You see the cost, then the outcome. You
   do not see the pixels first. Undo is one step, so the loop is cheap — but a ghosted preview on
   the composed tile would be better and I did not build it.
4. **The quantised source is a JPEG** (§7 of the dispatch). Accepted glyphs inherit its ringing —
   stray single pixels at cell edges. That is the source, not a bug, and it arrives with the accept.
   **This is the thing most likely to make an accepted glyph look subtly wrong.**
5. **`accept cell` uses the currently selected cell**, which after a sheet click is the sub-cell you
   clicked. If Jay expects "the cell I am looking at in the composed tile" to differ from that, they
   are the same thing by construction — but it is worth confirming in use.
6. **Accepting does not mark the glyph `done`.** Provenance and completion stay separate; `d` still
   marks done by hand. Arguable either way.
7. **Undo drops the `accepted` provenance but a *redo* does not restore it.** Redo restores the
   pixels; the sidecar will then call the glyph `edited` rather than `accepted`. Minor, and the
   conservative direction — it never claims art it does not have.
8. **I have not judged the tool's output appearance** and this report contains no such judgement.

### 8 — Follow-up candidates

- **Ghosted preview of an accept** on the composed tile before committing (flag 3).
- **Per-glyph winner picker** for conflicted cells, if TL→BR proves wrong in practice (flag 2).
- **Carried, unchanged:** which palette, and whether the allocator should reserve the 15 text slots
  at 192 glyphs. `dist/ROBOTSA.BIN`'s fate (C7 §7). Scrollable glyph canvas (C6-A2 §7 flag 1).
  Settle the 27 no-static-reference tiles by MAME trace. Retune slots 2/11 toward the art's greens.
  Per-frame CPU budget before sound. **`main` is seventeen dispatches behind at `a62809e`.**

### 9 — User interaction during task

None. The dispatch was self-contained, and its §2 measurements were quoted with enough precision to
reconcile against — which is what surfaced the identical-art refinement in §4 AC2.

### 10 — Candidate(s) captured this task

One, to `seeds/cocobots/live/` — pool commit **`62898ac`**, pushed.

- **`a-conflict-whose-outcomes-agree-is-not-a-conflict`** — counting *contention* and counting *loss*
  give different numbers, and the difference is the one the user cares about. Reporting the first as
  though it were the second trains people to ignore the warning.

### 11 — Commit

| | |
|---|---|
| the feature | **`d615bdfd9a5796224c36d2428c8bc7bd6bab64fe`** |
| this report + `C6-A3-renders/` | committed separately; SHA in the delivering message |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`62898ac`**, pushed |

Explicit-path staging; no `git add -A`. No shipped asset modified.
