# `reference/pet/` — MANIFEST

**This directory is gitignored** (Jay, 2026-07-31). The files below are present on disk and are
**never pushed**. This manifest is the only tracked file here.

**Why this file exists.** An ignored directory is invisible to the Orchestrator reading `wip`, and
absent after a context reset (CLAUDE.md §9). Without this manifest a fresh context concludes that
`listing.txt` does not exist — and `listing.txt` is CLAUDE.md §2 **rank-3 ground truth**. If the
files below are missing from your working copy, they must be re-supplied by Jay; they cannot be
recovered from the remote.

**Role of this material.** Authoritative for the **logic and intent of the PET original** — never
for appearance, and never as a target to "fix" the CoCo3 port toward. The port's divergences from
the PET are deliberate (CLAUDE.md §2).

**Why not pushed.** Third-party source material for David Murray's PET original, held locally as
reference. Distribution is not ours to make.

## Expected contents — 8 files (excluding this manifest)

| file | bytes | SHA-256 |
|---|---:|---|
| `BACKGROUND_TASKS.ASM` | 47,885 | `ffdf80c2952ce1202467ae8caaf0b9d420d461d27328cde1bff2f5a320dde568` |
| `listing.txt` | 374,323 | `bc4d663bc2a675158175d586eeb1dd5b2748e279ee258ec81fddb8af372f0e37` |
| `map-editor-instructions.txt` | 6,881 | `388d61da12eb70ede87d21df693f65d1df959013c8c5edcbaab0bf984ca29406` |
| `MinGW-win32_gcc6_3_0.txt` | 2,307 | `b37f5ed57cd36e966840bea74b08a54f36cfdf15aa1e5c0aa4c008cd1e5e8f87` |
| `PETROBOTS.ASM` | 97,204 | `9fc88f2ffb82e1049a6d5533ce4fbd1fd6216bca4a632593c19401174812c224` |
| `pet-source-repairs.diff` | 1,955 | `1deb2a704e56321f1e2b85840d24d764f40ede67bd854da766a41deb9173258d` |
| `PETTILE4032.ASM` | 38,771 | `da8ab834dc19f6e7308f54eb1e4e7884c1734d12ce7d1edffb0fc267f8c6ee6e` |
| `symbols.txt` | 22,894 | `43e135ad8bb18ff2124b8e4c385f3738047cbb67f6500025d77af4b0fae05e17` |

## What each file is

- **`listing.txt`** — ACME `--report` output: a build receipt carrying the full source text of both
  `PETROBOTS.ASM` and `BACKGROUND_TASKS.ASM` with every emitted byte and address, from a build that
  completed (`$0401`–`$452E`). **CLAUDE.md §2 rank 3 — the pinned artifact this project's factual
  claims about the original resolve against.**
- **`symbols.txt`** — 1,049 resolved symbols from that same build. Authoritative for every original
  address.
- **`PETROBOTS.ASM`** — 4,615 lines. **REPAIRED 2026-07-31**: three lines of 6809 code had been
  pasted over the 6502 original (a destroyed `FIRE_LEFT:` label that broke two `JSR`s,
  `CALC_COORDINATES` replaced with `LDD/ADDD/STD`, an `LDX UNIT` replaced with `CLRA/LDB/TFR`).
  Reverted from `listing.txt`. CLAUDE.md §2B.
- **`BACKGROUND_TASKS.ASM`** — 2,546 lines. **REPAIRED 2026-07-31**: four `INCA`/`DECA` reverts in
  the walk routines. CLAUDE.md §2B.
- **`pet-source-repairs.diff`** — the seven reverts above, for review. Both files now verify
  byte-exact against `listing.txt` across all 7,161 lines.
- **`PETTILE4032.ASM`** — the PET tile/map editor. Cannot be built: `SCR1PET.BIN` is absent.
- **`map-editor-instructions.txt`** — usage notes for that editor.
- **`MinGW-win32_gcc6_3_0.txt`** — ACME 0.97 "Zem" usage notes.

## Verifying your copy

```
sha256sum reference/pet/*        # or, PowerShell:
Get-ChildItem reference/pet -File | Get-FileHash -Algorithm SHA256
```

Any mismatch means the file is **not** the pinned artifact — do not use it as ground truth until
resolved with Jay. Note CLAUDE.md §2I: all files here are plain text and have arrived intact;
binaries have not, and none are kept here.

**Keep this manifest in step with the directory.** If a file is added, removed, or re-supplied,
update the table in the same commit.
