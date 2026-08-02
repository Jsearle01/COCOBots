# Asset protection catalog — additions

**Status:** authored 2026-08-01, C6. Extends **CLAUDE.md §2B**, which stays the
authoritative table for the assets it already lists. This file records assets created
*after* §2B was written, so the protection exists from the moment the asset does rather
than after something has already destroyed it.

**Orchestrator:** the row below is a candidate for folding into §2B. Per CLAUDE.md §2D
this file does not edit §2B's body.

---

## New entry

| Asset | State | Why protected |
|---|---|---|
| `assets/authored/font-a192.bin` + `font-a192.json` | **HAND-AUTHORED** from 2026-08-01 | The 192-glyph font under hand edit (C6). Each glyph is 64 nibbles drawn by hand against the artwork; **151 tile slots, ~9,664 nibbles, and none of it is reproducible from source.** A re-run of `tools/ladder.py` regenerates `build/c4/font-192.bin` and would silently replace the hand work if the two were ever the same file. They are deliberately not. |
| `assets/authored/versions/` | **HISTORY** | One immutable snapshot per save. This is the actual backstop: the current file can be replaced, a version never is. |
| `assets/tileset.bin` | **MODIFIED 2026-08-01 (C7)** — supersedes §2B's "CONVERTED, origin unknown" | **Completed to its full 11 × 256 = 2,816 data bytes.** It shipped with 2,815, one short, and the shortfall landed on exactly one cell: `TILE_DATA_BR[255]`. **A converter or re-export that regenerates it at 2,815 bytes reintroduces the bug** — anything drawn in tile 255 and placed in a level would make `DRAW_MAP_WINDOW` read `$5CFF`, one byte past the loaded data, and draw whatever is in RAM. Eight cells of art plus one garbage cell, presenting as a rendering bug rather than a file-length bug. |

---

## Why this asset is different from everything else in §2B

Every other protected asset in this project is **converted or repaired** — destroying one
costs a re-run of a converter plus the repair notes. This one is **drawn**. There is no
process that reproduces it and no source it can be re-derived from. Jay's ruling on
2026-08-01 is the whole reason it exists:

> *"I think I'm going to have to hand edit the glyphs because Clyde is just not reproducing
> the structure of the glyphs properly with his process."*

---

## The protections, and what each one actually stops

| protection | stops |
|---|---|
| output lives under `assets/`, **never `build/`** | `build/` is gitignored, so an artifact there is one `git clean` from gone. This is C4 §7 flag 7, whose third occurrence was the reason the rule was made permanent. |
| the tool **never writes its own input** | `tools/ladder.py` owns `build/c4/font-192.bin`; the editor owns `assets/authored/font-a192.bin`. A converter re-run cannot reach the authored file because it does not know the path. |
| **versioned save** — every save also writes `versions/font-a192-<stamp>-<n>.bin` | a bad save, a mis-click, or a crash mid-write. No previous save is ever overwritten. |
| **atomic replace** of the current file (`.tmp` + `os.replace`) | a half-written font. The bytes land in a temp file and are renamed, so the current file is either the old one or the new one. |
| **autosave** to `assets/authored/autosave/`, on a separate path a save never touches | losing an unsaved session to a crash. Deliberately **not tracked** — it is a crash buffer, not a record. |
| the sidecar records the **source font's sha256** | opening the editor against a different starting font than the one the work was based on. |

---

## Round-trip, verified

`tools/glyph_tool/selftest.py` proves load → save-with-no-edits is byte-identical, and
that an *edited* save differs — so "identical" is a real check and not a vacuous one. The
seeding run on 2026-08-01:

```
source   build/c4/font-192.bin        sha256 b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c
authored assets/authored/font-a192.bin sha256 b034d241e17640e89bca1785f934e7a2bc8a3b5f1e16f33c451946658e98621c
```

---

## `assets/tileset.bin` — the C7 change, in full

One byte appended and one header field bumped. Nothing else.

```
BEFORE  type $00  len 2815 ($0AFF)  load $5200   data $5200-$5CFE   file 2825 B
        sha256 1d2c02c7bcd4168534296f0ec710a4e3a2fe27e500ac8876f06a86a22d87783c
AFTER   type $00  len 2816 ($0B00)  load $5200   data $5200-$5CFF   file 2826 B
        sha256 2b7090562412c79b91dc4acfe55bc20a497ae1fe3fee18f872aa446ce90dd4af
```

The appended byte is `$20` (PETSCII space) — the same value every blank tile's cells
hold, so the previously-missing cell renders empty rather than as arbitrary data. The
first 2,815 data bytes were compared against `git HEAD` byte for byte and are
identical; the 5-byte END block is carried through untouched. `$5200 + 2816 − 1 =
$5CFF` and `$5D00` is `UNIT_TYPE`, so it fits exactly with no memory-map consequence.

**How to restore it if a converter ever shortens it again:** append one `$20` before
the END block and set the length field to `$0B00`. The `assets/authored/versions/`
convention does not cover this file; `git` history is its record.

**Downstream, and deliberately not chased:** `build/c4/tileset-192.bin` was generated
by C4 from the 2,815-byte file and still lacks the cell. It is a gitignored build
artifact and regenerating it is out of C7's scope. `tools/glyph_tool/selftest.py`
asserts both states — no missing cell in the shipped mapping, one still missing in the
a192 artifact — so the difference is recorded rather than latent.

---

## Unchanged, and verified unchanged

C6 modifies **no** shipped asset. `assets/tileset.bin` is read-only to the glyph editor
by design — it is opened, never written; the C7 change above was made by a separate
authorised task, not by the tool. `selftest.py`'s last check runs `git diff HEAD`
against `tileset.bin`, `src/graphics.asm`, `src/PETSCII_COCO.asm` and all ten level
files and fails if any of them differs.
