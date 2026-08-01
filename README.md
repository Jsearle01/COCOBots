# COCOBots — Attack of the PETSCII Robots, CoCo3 port

A Tandy Color Computer 3 port of **Attack of the PETSCII Robots**, by **Jay Searle** and
**L. Curtis Boyle**. The PET original is **David Murray**'s.

The port has its own display engine: 320×200 at 16 colours (4bpp), 160 bytes/row, single buffer
written directly to `$8000`. It is an existing, near-complete codebase being finished — not a
translation in progress.

## Layout

| path | contents |
|---|---|
| `src/` | the CoCo3 6809 sources (`PETROBOTS_6809.asm` is the build entry point) |
| `assets/` | `tileset.bin` and the ten level files, `levels/level_a.bin` … `level_j.bin` |
| `art/` | `image.png`, `Amiga_Artwork.png`, `coco_ArtworkSheet.png` — see CLAUDE.md §2M for their differing roles |
| `tools/` | project tooling (empty) |
| `docs/methodology/` | the method this project runs under, plus provenance documents |
| `docs/project/` | project documents (empty) |
| `docs/ground-truth/` | **local-only, not pushed** — see its `MANIFEST.md` |
| `reference/pet/` | **local-only, not pushed** — the pinned PET original; see its `MANIFEST.md` |
| `build/`, `dist/` | build products, ignored |

Two directories are deliberately absent from the remote. Each keeps a **tracked `MANIFEST.md`** so
their contents are knowable without them: `reference/pet/MANIFEST.md` and
`docs/ground-truth/MANIFEST.md`.

## Build

Assembler is **`lwasm`** (lwtools, 6809):

```
lwasm --format=decb --output=petrobots.bin src/PETROBOTS_6809.asm
```

Exactly one warning is expected — `PETROBOTS_6809.asm:3146: Operand size larger than required`.
**Any other warning or error is a regression.**

## Read CLAUDE.md first

[`CLAUDE.md`](CLAUDE.md) holds the standing rules for work on this repo: the ground-truth
hierarchy, the asset protection catalog, the branch model, and the reporting format. It governs;
this README only orients. Read it before changing anything.
