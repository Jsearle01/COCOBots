# Form B Report — A1b — `.gitattributes` line-ending protection

**Class:** build (small). `wip`, pushed before reporting. No prod binary involved.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-01, dispatch A1b received. HEAD at receipt `2951ff1` (`wip`), tree clean.
HEAD at report `8d9acf4` + the report commit. Tree clean throughout.

**Ordering note:** A2 was already complete and pushed at receipt (`wip` at `2951ff1`, clean), so
the "do not interleave commits on `wip`" constraint was satisfied without coordination. A1b's
commit sits cleanly on top of A2's.

### 1 — Summary

`.gitattributes` added with `* -text`, exactly as specified. One added file, zero modified. Remote
blobs unchanged, verified by SHA. A fresh clone with `core.autocrlf=true` produces byte-correct
working files.

**Two findings that matter more than the file itself:**

1. **AC4 as specified does not discriminate.** A fresh clone produces correct working files
   *whether or not* `.gitattributes` exists, because git's checkout-side conversion skips any blob
   that already contains CRLF. The checkout direction was never the exposure. I ran the negative
   control, found the test could not fail, and then tested the direction that *is* exposed — the
   **clean (commit) direction** — where the difference is stark and the fix is proven necessary.

2. **The dispatch's canary is inverted.** `BACKGROUND_TASKS_6809.ASM`'s 12 bare CRs are described
   as "the thing most likely to be destroyed". Measured, they are what made that file **immune**:
   a single bare CR trips git's text/binary heuristic, so `autocrlf` never touched it. The files
   actually at risk were `PETROBOTS_6809.asm` and `PETSCII_COCO.asm`, both of which **would have
   been normalised** on any commit from an `autocrlf=true` clone before this change.

The fix is correct and was needed. The reasoning given for it was pointed at the wrong file.

### 2 — Files modified

**Added, tracked:** `.gitattributes` (5 lines, root).

**Modified: none.** No existing file was touched, re-committed, or re-normalised.
`git add --renormalize` was **not** run — in this repo. It was never run anywhere; the clean-direction
test used `git hash-object --path`, which applies the same filters read-only and touches no index.

This report, `docs/reports/A1b-gitattributes.md`, is committed separately per §6.

### 3 — Reasoning

`* -text` is the whole file because the failure mode is silent and blunt beats clever here. Per the
dispatch, no per-extension rules and no `text eol=crlf`.

Worth recording *why* it is sufficient for the `.bat` case that A2 raised: `-text` means git stores
and restores bytes verbatim in both directions. `build.bat` and `run.bat` are stored CRLF, so they
check out CRLF on every machine — which is what idioms §14g needs (`cmd.exe` cannot parse an LF-only
batch file). §14g suggests `*.bat text eol=crlf`; `* -text` reaches the same outcome for
already-correct blobs without granting git licence to rewrite anything.

### 4 — Verification (AC-by-AC)

**AC1 — PASS.** `.gitattributes` exists at the repo root, is tracked, contains `* -text`:

```
$ git ls-files .gitattributes
.gitattributes
$ git show HEAD:.gitattributes | tail -1
* -text
```

**AC2 — PASS.** One added file, zero modifications.

```
$ git status --short
A  .gitattributes

$ git diff --cached --stat
 .gitattributes | 5 +++++
 1 file changed, 5 insertions(+)
```

`git diff --cached --name-status` filtered for anything not `A`: **empty**.
`git diff --name-only` (unstaged): **empty**. Nothing was flagged for modification, so the
stop-condition did not trigger.

**AC3 — PASS.** Remote line endings unchanged after the push. Counted from the pushed blobs
(`git cat-file blob origin/wip:<path>`), not from local files:

| file | CRLF | bare LF | bare CR | expected |
|---|---:|---:|---:|---|
| `src/PETROBOTS_6809.asm` | **4,212** | **102** | **0** | 4,212 / 102 / 0 ✅ |
| `src/PETSCII_COCO.asm` | **1,305** | **0** | **0** | 1,305 / 0 / 0 ✅ |
| `src/BACKGROUND_TASKS_6809.ASM` | **2,362** | **156** | **12** | 2,362 / 156 / 12 ✅ |

All three match exactly. **The 12 bare CRs are intact.** Blob SHAs are byte-identical before
(`2951ff1`) and after (`origin/wip`) — see §5.

**AC4 — PASS as specified, but the test is not discriminating.** A fresh clone made with
`core.autocrlf=true` deliberately set produces working files with exactly the counts above, and
`git status` in that clone is clean.

**However** — the negative control (same clone procedure, same `autocrlf=true`, at commit `2951ff1`
which has no `.gitattributes`) produces **identical counts**. The test passes with the fix and
passes without it, so on its own it demonstrates nothing.

Cause: git's checkout-side (smudge) conversion **will not add CRLF to a blob that already contains
CRLF**. Every file here is stored CRLF, so the checkout direction is a no-op regardless of
`autocrlf` or attributes. The exposure A1 identified is real but runs the other way — the **clean
(commit) direction**, where a developer's commit rewrites the blob. That test is in §5 and it
separates the two cases cleanly.

### 5 — Verdict-time evidence

**AC2 — `git diff --stat`, verbatim:**

```
 .gitattributes | 5 +++++
 1 file changed, 5 insertions(+)
```

**AC3 — blob SHAs before and after the push:**

```
unchanged  src/PETROBOTS_6809.asm         470c45dee3717b006b2f3fcc4ef647e5af31a8b7
unchanged  src/PETSCII_COCO.asm           dfd2f2d4b946f821b34d07fe86263cc46b088b52
unchanged  src/BACKGROUND_TASKS_6809.ASM  6f28bf6a6b6bd6ead8af00fe309cd63bb83a949a
```

**AC4 — the fresh clone, verbatim:**

```
$ git -c core.autocrlf=true clone --branch wip https://github.com/Jsearle01/COCOBots.git repo
effective core.autocrlf in the test clone: true
system:                                    true

PETROBOTS_6809.asm                 CRLF=4212   bareLF=102   bareCR=0
PETSCII_COCO.asm                   CRLF=1305   bareLF=0     bareCR=0
BACKGROUND_TASKS_6809.ASM          CRLF=2362   bareLF=156   bareCR=12

$ git status --short
[empty]
```

**Negative control — the same, at `2951ff1` (no `.gitattributes`):**

```
PETROBOTS_6809.asm                 CRLF=4212   bareLF=102   bareCR=0
PETSCII_COCO.asm                   CRLF=1305   bareLF=0     bareCR=0
BACKGROUND_TASKS_6809.ASM          CRLF=2362   bareLF=156   bareCR=12
```

Identical. The check cannot fail, therefore its passing carries no information.

**THE DISCRIMINATING TEST — the clean (commit) direction.**

`git hash-object --path=<p>` applies the attribute and `autocrlf` filters for that path, so it
yields exactly the blob a commit from that clone would produce — read-only, no index touched.
Stored blobs on `origin/wip` are the reference:

```
--- WITHOUT .gitattributes  (commit 2951ff1), core.autocrlf=true ---
  PETROBOTS_6809.asm           NORMALISED -> b86c6102f627875d8d572bfe0b500162cf586cd7
  PETSCII_COCO.asm             NORMALISED -> 989a7bb72d96675cde5f1c288b7209d90484feb4
  BACKGROUND_TASKS_6809.ASM    preserved

--- WITH .gitattributes     (commit 8d9acf4), core.autocrlf=true ---
  PETROBOTS_6809.asm           preserved
  PETSCII_COCO.asm             preserved
  BACKGROUND_TASKS_6809.ASM    preserved
```

**This is the verdict-time evidence for the whole dispatch.** Two of the three sources would have
had their blobs rewritten by any commit from an `autocrlf=true` clone. After `.gitattributes`, none
would.

**Why `BACKGROUND_TASKS_6809.ASM` was already safe — mechanism, confirmed not assumed.** Two
synthetic files in the no-attributes clone, identical but for a single bare CR:

```
Two synthetic files, no .gitattributes in this clone, core.autocrlf=true.
Identical except one contains a single BARE CR.

  t_crlf_only.txt        NORMALISED (git treats it as text)
  t_with_bare_cr.txt     preserved  (git treats it as binary)
```

A lone CR flips git's text/binary heuristic to binary, and binary content is never converted. The
12 bare CRs were not the vulnerability — they were accidental armour, on the one file that had it.

### 6 — Reactive deviations and ROUTE ACCOUNTING

Route as dispatched, with no deviation in what was committed: **one file, `* -text`, exact content
from §3, on `wip`, staged by explicit path (`git add -- .gitattributes`), report committed
separately.** No existing file touched; `git add --renormalize` not run.

Deviations in *verification*, both additive:

1. **Ran a negative control on AC4, which the dispatch did not ask for**, and it showed the test
   could not fail. Reported rather than quietly passing a green check — CLAUDE.md §8: a green check
   proves nothing until its input provenance is shown.

2. **Added the clean-direction test** because AC4 could not carry the verdict. This is the evidence
   the dispatch wanted AC4 to be. Read-only (`git hash-object --path`), performed in throwaway
   clones under the system temp directory, never in the project repo.

3. **Confirmed the binary-heuristic mechanism with synthetic files** rather than asserting it from
   the observed asymmetry. The asymmetry alone is consistent with several explanations; one
   two-file experiment settles it.

Temp clones removed afterwards. Nothing outside the repo persists.

### 7 — Uncertainty flags

1. **AC4 as written cannot fail** (§4, §5). The dispatch calls it "the real test"; it is not, for
   this repo's content. Flagging because the same AC would be written again next time and would
   again pass regardless. The clean-direction check is the one worth keeping.

2. **The canary is inverted** (§1, §5). The dispatch's stated reason for the change — protecting
   the 12 bare CRs — is the one part of the tree that was never at risk. The change is still
   correct and still needed; only for different files than stated. Worth correcting wherever that
   reasoning is recorded, since it will otherwise be repeated.

3. **`* -text` also disables git's own EOL safety net for files added later.** Intended per §5 of
   the dispatch, and correct for this repo, but it means a future contributor committing an
   LF-only `.bat` gets no warning and no conversion — the file stays broken. A1's and A2's `.bat`
   files are verified CRLF today; the protection is against *change*, not a repair mechanism.

4. **Existing blobs are unaffected by `.gitattributes`.** It governs future conversions only. The
   remote content was already correct (A1 established this, and AC3 re-confirms it), so there is
   nothing to repair — but if any blob *had* been damaged before now, this change would freeze the
   damage rather than fix it. Checked: none is damaged.

5. **`core.autocrlf=false` remains set at repo scope locally** from A1. Now redundant given
   `-text`, and harmless. Left in place rather than removed, since removing it is a change nobody
   asked for and the two agree.

6. **Line-ending counting is my own script**, not a git facility. Method stated so it can be
   checked: a byte scan where `CR LF` counts as one CRLF and consumes both bytes, a `CR` not
   followed by `LF` counts as a bare CR, and an `LF` not preceded by `CR` counts as a bare LF.
   Cross-checked against the A1 figures independently derived at the time — 4,212 / 1,305 / 12 all
   agree.

### 8 — Follow-up candidates

- **Correct the bare-CR reasoning** wherever it is recorded (CLAUDE.md §10 lists the 12 bare CRs as
  known-and-tolerated, which is accurate; the "most likely to be destroyed" framing came with this
  dispatch). §2D — the Orchestrator's to fold in, not mine.
- **A pre-commit or CI check that the three source blobs still hash as expected** would catch a
  regression from any direction, including one `.gitattributes` cannot prevent (a deliberate
  rewrite, a bad merge, an editor stripping CRs). Cheap; the digests are already pinned in
  `build.sh` for the built artifact, so the pattern exists.
- A1's flag 5 and A2's flag 5 are now **closed** by this dispatch.

### 9 — User interaction during task

None. The dispatch was self-sufficient. The two judgment calls — running a negative control, and
adding the clean-direction test when AC4 proved non-discriminating — were made under CLAUDE.md §8
and are recorded in §6 rather than raised as questions, since neither changed what was committed.

### 10 — Candidate(s) captured this task

One new row in `seeds/cocobots/live/`, **new rows only, no existing entry read or edited**:

| slug | one line |
|---|---|
| `a-test-that-cannot-fail-is-not-evidence-find-the-exposed-direction` | Before reporting a pass, run the check against a system *without* the fix; if it still passes, the test is measuring the wrong direction of a two-directional mechanism |

Pool commit in §11.

### 11 — Commit

| | |
|---|---|
| `.gitattributes` | **`8d9acf4aa8f1dedf2f8f9677ccc02e47f5a2b6c4`** |
| this report | see below — committed separately per §6 |
| branch | `wip`, pushed |
| `main` | untouched at `a62809e` — not promoted, per §5 |
| pool | `190148f`, pushed |

Working tree clean. One added file in the `.gitattributes` commit, zero modified.
