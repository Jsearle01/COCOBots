# Form B Report — C6-A5 — sibling outline colour

**Class:** build (small). `wip`, pushed before reporting. **No 25.3 gate** — tool, not game output.
**Jay's acceptance is by using it.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch C6-A5 received. HEAD at receipt `1cf7fa7` (`wip`), tree clean.

### 1 — Summary

**The one-line change is done — sibling outlines are `#FF00FF`, 208 units from the nearest palette
colour, the furthest of any candidate tested.** But AC4 is where the value is, and it found more than
a colour preference.

**The sweep found six decorations within 100 units of a palette colour, two of them at exactly
0.0** — a marker that *is* palette `$34`, and selection boxes that *are* palette `$3F`. Since C6-A4
put the sheet in the adopted palette, each of those disappears wherever a tile uses that colour.

**One correction to the dispatch's premise.** §1 says the sheet outlines are orange. They were
**cyan `#00E0FF`** (139 units — actually fine). The **orange** was `#FF7800` on the *composed tile*,
marking other cells of the same tile on the same glyph — a different marker in a different panel, and
at 35 units it was genuinely colliding. **Both are now magenta**, deliberately: magenta means "this
glyph is also somewhere else" on both panels.

**All decoration colours now live in one module** (`decor.py`) that measures every one of them
against `assets/palette.json`. Scattering them across two files is how a marker sat at distance 0.0
for four dispatches. `uitest.py` asserts the sweep is clean and that no drawing call bypasses it.

`uitest.py` **75 checks**, `selftest.py` **58 checks**, both 0 failed.

**Separately: Jay has been using the tool, and it produced work I nearly tripped over.** §6.

### 2 — Files modified

| path | change |
|---|---|
| `tools/glyph_tool/decor.py` | **new**, 145 lines — every over-artwork colour, plus the sweep |
| `tools/glyph_tool/glyph_tool_app.py` | sheet colours from `decor`; two-tone selection markers |
| `tools/glyph_tool/render.py` | composed-tile / glyph-canvas colours from `decor`; two-tone cell box |
| `tools/glyph_tool/uitest.py` | +11 checks: the sweep, the bypass scan, the re-verified sibling sets |

**Read, never written:** `assets/tileset.bin`, `assets/palette.json`, the font, the levels.

### 3 — Reasoning

**Why magenta is safe, and it is not just that Jay likes it.** C5 §9 item 2 recorded that magenta has
**zero slots** in the adopted palette — 0.44% of art pixels, displaced to blue. That was written down
as a gap in the palette. It is exactly what makes it usable here: **it is the one hue that cannot
appear on the sheet**, so an outline in it can never be mistaken for content.

**Why the selection marker has no hue at all.** §3 asked for the selected tile to be distinguishable
from its siblings "not another hue". That turns out to be forced rather than a preference: the
palette's greys are {0, 85, 170, 255}, and **no grey is more than ~75 units from one of them**. Hue
separation is simply unavailable for a neutral marker. So the separation is structural — a dark line
immediately outside a light one. A black tile hides the dark half, a white tile hides the light half,
**and nothing hides both.**

**Why the constants moved into one module.** The sweep is only meaningful if it sees every
decoration. A colour literal written straight into a `create_rectangle` call is a decoration nobody
checked — and there was one (`#FF66FF`, the no-data caption). `uitest.py` now greps both drawing
modules for `outline=`/`fill=` colour literals and fails if it finds any.

### 4 — Verification (AC-by-AC)

`uitest.py` **75 checks, 0 failed** · `selftest.py` **58 checks, 0 failed**. Logs tracked.

**AC1 — sibling outlines are `#FF00FF`.** Screenshots for a high-sibling glyph and a single-tile one:
`A5-01-siblings-3A-108-magenta.png` (108 tiles), `A5-02-siblings-4D-122-magenta.png` (122),
`A5-03-siblings-0E-single-tile.png` (1). Outline width kept at **1 px** per §3.

**AC2 — the selected tile is distinguishable without hue.** Two-tone: a 2 px dark rectangle
immediately outside a 2 px light one, and the same pairing on the cell box inside it.
`A5-04-selected-vs-siblings-3x.png`.
```
PASS A5-AC2 the neutral marker is two-tone   #FFFFFF beside #000000 — no flat colour hides both
```

**AC3 — outline not sourced from the palette.** `#FF00FF`, **minimum distance 208.2** to any of the
16 (nearest is `$38` Light grey). Asserted in the test, not just measured once.

**AC4 — the collision sweep. THE ONE WITH VALUE.**

| decoration | colour | drawn over | distance | nearest | verdict |
|---|---|---|---:|---|---|
| `SIBLING_OUTLINE` | `#FF00FF` | sheet | **208.2** | `$38` Light grey | OK |
| `CELL_SIBLING` | `#FF00FF` | composed tile | **208.2** | `$38` Light grey | OK |
| `CHANGED_PIXEL` | `#00FFC0` | glyph canvas | **181.3** | `$0B` Light blue | OK |
| `UNVERIFIED_MARK` | `#00FFFF` | sheet | **170.0** | `$0B` Light blue | OK |
| `NODATA_FILL` | `#FF0080` | composed tile | **153.7** | `$26` Orange | OK |
| `AVAILABLE_MARK` | `#00FF88` | sheet | **136.0** | `$12` Light green | OK |
| `CELL_EDIT_TICK` | `#00FF88` | composed tile | **136.0** | `$12` Light green | OK |
| `GLYPH_GRID` | `#464646` | glyph canvas | 26.0 | `$07` Dark grey | **EXCEPTION** |
| `MARK_LIGHT` | `#FFFFFF` | both (two-tone) | **0.0** | `$3F` White | **EXCEPTION** |
| `MARK_DARK` | `#000000` | both (two-tone) | **0.0** | `$00` Black | **EXCEPTION** |

**What was wrong before, and what it cost:**

| decoration | was | distance | consequence |
|---|---|---:|---|
| `UNVERIFIED_MARK` | `#FFAA00` | **0.0** | **IS palette `$34`** — the no-static-reference dot vanished on every light-orange tile |
| `CELL_SIBLING` | `#FF7800` | 35.0 | near `$26` Orange — the marker §1 called unreadable |
| `CHANGED_PIXEL` | `#FFE400` | 58.0 | near `$34` — the "you changed this" outline, on the canvas you draw on |
| selected tile | `#FFE400` | 58.0 | same |
| `NODATA_FILL` | `#780078` | 98.4 | near `$07` Dark grey, and now too near the sibling magenta |
| no-data caption | `#FF66FF` | — | a literal bypassing every constant |

**Three argued exceptions, not oversights.** `MARK_LIGHT`/`MARK_DARK` are at 0.0 by construction and
are never drawn alone. `GLYPH_GRID` **cannot** satisfy the rule: no neutral is more than ~75 units
from a palette grey, its job is subdividing the 8×8 while drawing rather than being read against
content, and a saturated grid would obscure the pixels being edited. Each reason is stored in code
beside the constant, and the test asserts every exception actually carries one — which caught my
first attempt at `MARK_DARK`'s, which was too terse to be an argument.

**AC5 — outlines still correct. "I only changed a colour" re-verified.**
```
PASS A5-AC5 sibling sets unchanged by the colour change   $3A=108/396 $4D=122/210 $20=122/438 +4 more
PASS A5-AC5 outline set $3A recounts                      108 tiles
PASS A5-AC5 outline set $4D recounts                      122 tiles
PASS A5-AC5 sibling-count profile reported                a192: min 1 median 4 mean 7 max 95
```
All seven C6 AC6 figures reproduce (with `$20` at 122/438 post-C7, as C7 recorded), and the outline
sets are recounted from the raw codes rather than read back from the same index the sheet draws from.

**Note the sibling profile differs from the dispatch's.** §3 quotes min 1 / median 88 / mean 77 /
max 122 — those are the **shipped** mapping. The tool loads **a192**, where it is **min 1 / median 4
/ mean 7 / max 95**. So the sheet is far less densely outlined in practice than §3's "a third to a
half of the sheet" — the median selection lights **4** tiles, not 88. The 1 px choice still stands.

**AC6 —** `uitest.py` **75 checks, 0 failed**; `selftest.py` **58 checks, 0 failed**.

**AC7 — no regression.** Round-trip still
`b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c`; `git diff HEAD` over the 13
shipped assets empty.

### 5 — Verdict-time evidence

Four screenshots, **4 distinct hashes**, plus three logs, tracked under `docs/reports/C6-A5-renders/`.
Surfaced for Jay's inspection per CLAUDE.md §3; **their content is not analysed or judged here.**
`decor-sweep.log` is the AC4 table, re-runnable with `python tools/glyph_tool/decor.py`.

### 6 — Reactive deviations and ROUTE ACCOUNTING

**Deviation 1 — the dispatch's premise about which marker was orange was inverted.** §1 says the
sheet outlines are orange; they were cyan at 139 units. The orange was the composed-tile marker at
35. Both changed to magenta, so the outcome matches the intent either way — but the report should
say which was which.

**Deviation 2 — five decorations changed, not one.** §3 asks for the sweep and says "any within 100
units is flagged and changed", so this is in scope rather than beyond it. Naming it anyway: the
functional change Jay asked for is one colour; four more moved because the sweep said they had to.

**Deviation 3 — Jay was using the tool while I worked on it, and two of my tests broke on his work.**
Mid-run, `assets/authored/font-a192.bin` changed under me again — `1f25ee24…` → `22c87975…`, two new
version snapshots, an autosave between them, and the sidecar showing **10 accepted + 3 edited**
glyphs.

**I diagnosed before touching anything this time.** The accept provenance names **tile `$84` BM,
tile `$84` MR, tile `$09` TL** — tiles no test in this repo touches (`uitest.py` works on 0, 4, 7,
136 and 250 only), and the autosave-then-save timing is an interactive signature. **This is Jay's
authoring session, using C6-A3's accept-quantised.** Committed separately as `68fa60a`, not reverted.

**Two of my tests were asserting on his session rather than on the tool**, and both are now fixed:

| test | assumed | now |
|---|---|---|
| `A3-AC5 undo cleared the accepted provenance` | `prog.accepted` is globally empty | only the glyphs *this accept wrote* are released |
| `A4-AC5 engine sheet agrees with compose_tile` | `art/coco-engine.png` matches the live font | renders the engine sheet **live**, so it tests geometry rather than how recently the PNG was re-emitted |

The second was already flagged as a hazard in C6-A4 §7 flag 3 — *"the file goes stale; the in-tool
view is always correct"* — and I wrote the test against the file anyway. **Both tests failed for the
right reason: the tool was being used.**

**Route accounting:** which tiles are outlined is unchanged and re-verified; palette untouched;
`assets/tileset.bin` opened read-only; explicit-path staging.

### 7 — Uncertainty flags

1. **Magenta at 1 px is unverified at the default zoom by anyone but me.** The dispatch names this
   hazard. It is 208 units from anything on the sheet, but 1 px is 1 px — **if it does not read at
   1×, the fix is width 2, one constant.**
2. **`CELL_SIBLING` and `SIBLING_OUTLINE` are the same magenta**, deliberately, so magenta means one
   thing across both panels. If Jay would rather the composed tile use a different marker from the
   sheet, they are separate constants already.
3. **`NODATA_FILL` `#FF0080` is a pink-red near the sibling magenta** (63 units apart). They co-occur
   only on tile 255 in a192, and one is a filled 8×8 while the other is a 1 px outline — but it is
   the weakest pair in the table.
4. **`AVAILABLE_MARK` and `CELL_EDIT_TICK` are both `#00FF88`** on different panels. Same reasoning
   as flag 2; say if it confuses.
5. **The 100-unit threshold is mine**, chosen so `#FF00FF` (208) and the palette's own spacing sit
   comfortably either side. Nothing derives it from perception.
6. **Euclidean RGB distance is a crude perceptual metric.** A proper ΔE would be better; RGB
   distance is what makes the "IS palette `$34`" cases obvious, which is the failure that mattered.
7. **I have not judged the tool's output appearance** and this report contains no such judgement —
   including whether magenta reads well, which is Jay's call.

### 8 — Follow-up candidates

- **Widen the sibling outline to 2 px** if 1 px does not read at 1× (flag 1).
- **Re-emit `art/coco-engine.png`** — Jay's session has moved the font, so the tracked snapshot is
  now stale (C6-A4 §7 flag 3). The in-tool view is unaffected.
- **Carried, unchanged:** which palette variant, and whether the allocator should reserve the 15 text
  slots at 192 glyphs. `dist/ROBOTSA.BIN`'s fate (C7 §7). Ghosted accept preview and the per-glyph
  conflict winner (C6-A3 §7). Scrollable glyph canvas (C6-A2 §7). Settle the 27 no-static-reference
  tiles by MAME trace. Retune slots 2/11 toward the art's greens. Per-frame CPU budget before sound.
  **`main` is nineteen dispatches behind at `a62809e`.**

### 9 — User interaction during task

None directly. But Jay used the tool during it, and that session is the first evidence that
C6-A3's accept path is doing real work — 10 glyphs accepted, 3 hand-edited, across tiles `$09` and
`$84`. Committed as `68fa60a`.

### 10 — Candidate(s) captured this task

One, to `seeds/cocobots/live/` — pool commit **`02c0352`**, pushed.

- **`a-tests-fixture-is-not-the-users-working-file`** — asserting on global state of a live artifact
  makes the test fail exactly when the feature succeeds. Both of mine broke the first time the
  operator actually used the tool; scoping each assertion to what the test itself did fixes it.

### 11 — Commit

| | |
|---|---|
| Jay's authoring session | **`68fa60a1ef5f52de8bd51cf614fce44747112704`** |
| the colour change + sweep | **`109751cbb1c41cc57f7dc5bcd92cae51b8a3b4e0`** |
| this report + `C6-A5-renders/` | committed separately; SHA in the delivering message |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` |
| pool | **`02c0352`**, pushed |

Explicit-path staging; no `git add -A`. No shipped asset modified.
