# Form B Report — A1 — COCOBots repo setup, file placement, push

**Class:** build. `main` + `wip`. No prod binary touched — nothing built (A2's job).

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch A1 received. HEAD at receipt: **none — repo was empty**, no commits
existed. HEAD at report time `a62809e`, tracking `origin/main` and `origin/wip`. `git status` clean.

### 1 — Summary

Repo was confirmed empty (`isEmpty: true` via `gh`, and clone warned "you appear to have cloned an
empty repository"), so §0.3's stop condition did not trigger. Tree built per §2, four packages
placed, `.gitignore` + two `MANIFEST.md` + `README.md` written, 33 files staged by explicit path,
committed to `main`, `wip` branched from it, both pushed. Zips and `PLACEMENT.md` files deleted.

One thing the dispatch did not anticipate and I had to handle: **`core.autocrlf=true` was inherited
from system git config** and would have rewritten line endings in every committed blob — a direct
violation of §8's "do not modify any file you are placing." Detected before staging, disabled at
repo scope, and proved harmless by comparing all 33 staged blob SHAs against `git hash-object` of
the on-disk files. Details in §6 and §7.

### 2 — Files modified

Nothing modified — everything created. 33 tracked files: `CLAUDE.md`, `mame-idioms-coco3-port.md`,
`mame-idioms-addendum.md`, `README.md`, `.gitignore`; `src/` ×6; `assets/tileset.bin` +
`assets/levels/` ×10; `art/` ×3; `docs/methodology/` ×4; `docs/project/.gitkeep`; `tools/.gitkeep`;
`reference/pet/MANIFEST.md`; `docs/ground-truth/MANIFEST.md`.

Untracked-but-present on disk: `reference/pet/` ×8, `dist/ROBOTSA.BIN`, `build/` (empty).

Authored by me: `.gitignore`, `README.md`, both `MANIFEST.md` files, two `.gitkeep`. **No placed
file was edited.**

**Added after the dispatch commit, on `wip` only** (see §6 item 6): `docs/reports/A1-repo-setup.md`
— this file.

### 3 — Reasoning

The `.gitignore` un-ignore is the load-bearing part. `/reference/` with a trailing slash excludes
the directory itself, so git never descends and the `!` re-include cannot fire. I used
`/reference/**` — which matches everything *under* `reference/` but not `reference/` itself — then
`!/reference/pet/` to let git descend into the subdirectory, then `!/reference/pet/MANIFEST.md`.
`docs/ground-truth/*` needed no such treatment since the directory itself is not excluded.

`assets/` is tracked and `dist/` is not, so no blanket `*.bin` rule — `/dist/` and `/build/` are
path-anchored instead.

### 4 — Verification (AC-by-AC)

**AC1 — PASS.** Full tree listed and compared against §2. No extra files, no missing files. One
deliberate omission, flagged in §7: `docs.zip` shipped a `ground-truth/.gitkeep` which §2 does not
list; I did not place it, since `MANIFEST.md` already keeps the directory present on disk.

**AC2 — PASS.** Measured:

| item | required | actual |
|---|---|---|
| `src/` | 6 files | **6** |
| `assets/tileset.bin` | 2,825 B | **2,825** |
| `assets/levels/` | 10 files @ 8,714 B | **10 files, all 8,714** (distinct sizes = {8714}) |
| `art/` | 3 files | **3** |
| `docs/methodology/` | 4 files | **4** |
| `reference/pet/` | 9 files + MANIFEST | **8 files + MANIFEST** — see §7 |
| `dist/ROBOTSA.BIN` | 27,460 B | **27,460** |

**AC3 — PASS.** Counted by newline bytes (PowerShell's `Measure-Object -Line` silently skips blank
lines and gave 4448 / 2453 / 529 — wrong; discarded):

- `PETROBOTS.ASM` = **4,615** lines
- `BACKGROUND_TASKS.ASM` = **2,546** lines
- `CLAUDE.md` = **667** lines

Also verified `src/BACKGROUND_TASKS_6809.ASM` retains exactly **12 bare CRs** after placement.

**AC4 — PASS.** Verbatim output in §5.

**AC5 — PASS.** `git ls-files reference/` returns exactly `reference/pet/MANIFEST.md`.
`git ls-files docs/ground-truth/` returns exactly `docs/ground-truth/MANIFEST.md`. Verbatim in §5.

**AC6 — PASS.** All 8 SHA-256s and byte sizes in `reference/pet/MANIFEST.md` recomputed from disk
and matched against the file's own table — 8 verified, 0 failed. `docs/ground-truth/` confirmed
empty apart from its manifest, which is what that manifest claims.

**AC7 — PASS.** No `.zip` and no `PLACEMENT.md` anywhere in the tree. `git log --stat` for
`a62809e` contains neither.

**AC8 — PASS.** `main` and `wip` both exist locally and on the remote, all four refs at
`a62809e0347bcc4f17068d9cb74502b20deb5fb5`.

**Skipped as instructed:** the coco3 build check in `coco3-source/PLACEMENT.md`
(`lwasm --format=decb --output=petrobots.bin src/PETROBOTS_6809.asm`, expecting exactly one warning
at line 3146 and segments `$034D/138  $0E01/1721  $14BB/9875  $41F6/4096  exec=$0E01`). Not run —
that is A2's.

### 5 — Verdict-time evidence

`git check-ignore -v`, verbatim:

```
=== AC4a: reference/pet/listing.txt (MUST be ignored) ===
.gitignore:4:/reference/**	reference/pet/listing.txt
exit=0
=== AC4b: docs/ground-truth/anything.md (MUST be ignored) ===
.gitignore:8:/docs/ground-truth/*	docs/ground-truth/anything.md
exit=0
=== AC4c: assets/tileset.bin (MUST return NOTHING) ===
exit=1
=== manifests MUST NOT be ignored ===
.gitignore:6:!/reference/pet/MANIFEST.md	reference/pet/MANIFEST.md
exit=0
.gitignore:9:!/docs/ground-truth/MANIFEST.md	docs/ground-truth/MANIFEST.md
exit=0
```

**Read the last two carefully — `exit=0` there does not mean "ignored."** `check-ignore` exits 0
whenever any rule matches, and a `!` negation is a match. The `!` prefix on the printed rule is the
only signal distinguishing the two cases, which is why the verdict does not rest on this command
(§7, and captured as a pool candidate in §10).

Spot checks: `reference/pet/PETROBOTS.ASM` and `symbols.txt` ignored via `/reference/**`;
`dist/ROBOTSA.BIN` via `/dist/`; `build/x.o` via `/build/`; `coco3-source.zip` via `/*.zip`.
Not ignored: `assets/levels/level_a.bin`, `art/image.png`, `docs/methodology/POP-CLAUDE.md`,
`src/PETROBOTS_6809.asm`.

`git ls-files` after commit — the definitive test:

```
reference/        -> reference/pet/MANIFEST.md
docs/ground-truth -> docs/ground-truth/MANIFEST.md
```

Byte-identity of every staged blob against disk (`git ls-files -s` blob SHA vs `git hash-object`):
**33 files, 0 mismatches.**

Independent confirmation from a **fresh clone of the pushed remote** — 33 files, and:

```
CLEAN — no reference material, no zips, no PLACEMENT.md on the remote
```

### 6 — Reactive deviations and ROUTE ACCOUNTING

Route as dispatched, with what the commit actually contains:

1. **`main`, not `wip`, for this dispatch** — as §3 directed, and flagged here as required. The
   skeleton is on `main`; `wip` was branched from it at the same SHA and both were pushed. Every
   subsequent dispatch works on `wip`. This is a deliberate departure from the normal "work on
   `wip`, Orchestrator promotes" flow (CLAUDE.md §2E), **visible rather than assumed.**

2. **`.gitignore` pattern differs from the dispatch's draft**, as §4 anticipated and instructed.
   Shipped: `/reference/**` + `!/reference/pet/` + `!/reference/pet/MANIFEST.md`. The draft's
   `/reference/` would have excluded the directory outright and lost the manifest. Verified by
   command before proceeding. **Recorded per §10's request for what worked.**

3. **`core.autocrlf` disabled at repo scope — a config change the dispatch did not call for.** Not
   a code change and not a tracked file, but a deliberate act, so accounting for it: system config
   had `autocrlf=true`; the sources are heavily CRLF (`PETROBOTS_6809.asm` 4,212 CRLF endings,
   `PETSCII_COCO.asm` 100% CRLF, `mame-idioms-coco3-port.md` 1,491), so committing under that
   setting would have normalised them to LF in the blobs and invalidated the pre-verified sources —
   with nothing in a normal diff view to show it. Disabled locally, then *proved* by the 33/33
   blob-vs-disk hash comparison rather than assumed. **The commit contains the files exactly as
   delivered.**

4. **Explicit-path staging throughout** — 33 individual `git add --` invocations, no `-A`, no `.`,
   no wildcard.

5. **Verification exceeded the ACs in one place**: the fresh-clone-of-remote check was added. The
   ACs test the local index; only a clone tests what actually landed on GitHub, and the whole point
   of the ignore rules is what does *not* land there.

6. **This report file was added after the dispatch commit, on `wip` only** — a follow-on request,
   not part of the dispatch. It is deliberately **not** on `main`: AC1 pins `main` to §2's tree
   with "no extra files", and `main` has been verified against that. `wip` is where in-flight work
   lives and where the Orchestrator reads (CLAUDE.md §2E), so `wip` is now one commit ahead of
   `main` — the normal state, with promotion the Orchestrator's call. Path chosen as
   `docs/reports/`; the dispatch tree defined no reports directory, so this is a new convention
   (§7 flag 6).

### 7 — Uncertainty flags

1. **AC2 says `reference/pet/` is "9 files + MANIFEST.md"; there are 8 + MANIFEST.** The zip
   contained 8 material files plus its own `PLACEMENT.md` (deleted per §6.10), and
   `petscii-reference/PLACEMENT.md` enumerates exactly those 8. I read the AC's 9 as counting
   `PLACEMENT.md`. **Nothing is missing** — all 8 named in `PLACEMENT.md` are present and
   hash-verified. Flagging rather than silently reconciling.

2. **`docs.zip` shipped `ground-truth/.gitkeep`, which §2's tree does not list.** Not placed: AC1
   requires the tree to match §2 with no extra files, and the tracked `MANIFEST.md` already keeps
   the directory on disk. Were a `.gitkeep` wanted there it would be ignored by
   `/docs/ground-truth/*` anyway, so it would serve no purpose.

3. **`core.autocrlf=false` is repo-local and therefore not pushed.** The *blobs* are correct and
   safe. But another Windows clone on a machine with system `autocrlf=true` will get
   line-ending-converted **working files**. The durable fix is a tracked `.gitattributes` with
   `* -text`. **Not added** — it is a file the dispatch's tree does not contain, and AC1 forbids
   extras. This is an Orchestrator decision, and worth taking before A2 builds or anyone else
   clones.

4. **CLAUDE.md §2C carried "⛔ OPEN — candidate pool path not set"** with an instruction to stop and
   ask Jay rather than capture. This dispatch's §9/§10 supplies the path, which I treated as
   closing that binding. The pool was reachable, so the stop condition never arose. **§2C's ⛔ OPEN
   marker is now stale and wants updating** — an authored-doc edit, so per §2D the Orchestrator's
   to make, not mine.

5. **`art/*.png` are JPEG data with `.png` extensions** — confirmed present, left alone per §10.

6. **`docs/reports/` is a new convention, chosen not specified.** The dispatch tree has
   `docs/project/` (tracked, empty) and no reports directory. Reports are project documents, so
   `docs/project/` was a plausible home; a dedicated `docs/reports/` was chosen so per-dispatch
   Form B reports accumulate without crowding project docs. Filename `A1-repo-setup.md` sorts by
   dispatch ID rather than date, since dispatch IDs (A1, A2, A3, B1) are the project's index.
   **Trivially renamed or relocated if the Orchestrator prefers otherwise.**

### 8 — Follow-up candidates

- Add `.gitattributes` (`* -text`) — see flag 3. Cheap, and the exposure grows with every clone.
- Update CLAUDE.md §2C to record the now-set pool path — see flag 4.
- Confirm or correct the `docs/reports/` convention — see flag 6.
- **A2: reproducible build.** The build check in `coco3-source/PLACEMENT.md` is unrun and its
  expected output is recorded above in §4.

### 9 — User interaction during task

None during the dispatch itself. No questions were raised and no clarification requested; the
dispatch was self-sufficient given the four `PLACEMENT.md` files.

After the dispatch completed and was reported, one follow-on instruction: create a reports
directory and place this report in it. Handled per §6 item 6 and §7 flag 6.

### 10 — Candidates captured this task

Pushed to `github.com/Jsearle01/methodology-candidate-pool`, commit `2b561d9`, into the newly
created `seeds/cocobots/live/`. Format per the pool's root `SCHEMA.md`. **New rows only — no
existing entry was read or edited** (only `seeds/POP/` filenames were listed, to learn the naming
convention).

- **`inherited-tool-config-rewrites-protected-content`** — a byte-fidelity task must audit inherited
  tool configuration, not just its own edits, and prove identity independently rather than trusting
  the fix. `scope_judgment: methodology`, `proposed_disposition: promote`.
- **`verification-command-answers-a-different-question`** — when a contract mandates verification by
  a named command, check that the command's success signal is one-to-one with the property under
  test. `git check-ignore` exits 0 for both "ignored" and "explicitly not ignored".
  `scope_judgment: methodology`, `proposed_disposition: promote`.

Both relate to CLAUDE.md §8's "a green check proves nothing until its input provenance is shown",
arriving from a new angle — the check's *input* was fine, its *output encoding* was ambiguous.
Noted in the prose bodies for the reconciler.

### 11 — Commit

| | |
|---|---|
| dispatch commit | **`a62809e0347bcc4f17068d9cb74502b20deb5fb5`** |
| `main` | local `a62809e` = `origin/main` `a62809e` — pushed |
| `wip` | branched from `main` at `a62809e`, pushed; now +1 commit carrying this report |
| tree state | clean, 33 tracked files at `a62809e` |
| pool commit | `2b561d9` (separate repo), pushed |

At dispatch completion both branches were at the same SHA and only one commit existed — there was
no second SHA, as `wip` was branched from `main` rather than committed separately. The follow-on
commit adding this file sits on `wip` alone; its SHA is recorded in the delivering message rather
than here, since a commit cannot contain its own hash.
