# Briefing — adapting this CLAUDE.md for the Petscii Robots → CoCo3 port

**Paste or upload this alongside `POP-CLAUDE.md` into the Petscii Robots Claude project.**

---

## What the attached file is

`POP-CLAUDE.md` is the standing-rules document from a **different** port — Prince of Persia (Apple II, 1989) →
Tandy CoCo3, 4-colour. It was written by the orchestrator *alongside* the code, over ~30 dispatches, and
**nearly every rule in it was paid for by a specific failure.** It is scar tissue, not design.

That is why it is worth adapting, and also why it must not be copied wholesale: the rules encode facts about
a project you cannot see.

## What the new project is

- **Attack of the Petscii Robots → CoCo3, 16-colour.**
- **Near completion.** The work is *finishing and polishing*, not building.
- **Clyde is coming to it COLD** — he did not write it, and neither did anyone in the room.

That last point is the most important difference. The POP rules were written by someone building their own
code. Here, most decisions in the codebase are someone else's, and cannot be verified from a dispatch.

## What to do with it

**Classify every section into one of three buckets** before writing anything:

1. **Transfers unchanged** — the machine and the method don't care which game is being ported. Expect most of
   the value here: the MAME instrumentation reference (§2A), PNG rules (§3), the visual gate with launch-path
   provenance (§4), the timing receipt (§5), failed-approach protocol (§6), the Form B report structure
   including **route accounting** (§7), general behavioural rules (§8), context reset (§9), the heredoc rule
   (§2H), and the doc-ownership split (§2D).
2. **Needs rebinding** — same rule, different values: §1 project bindings (repos, paths, what counts as 25.1),
   §2C candidate capture path, §2B asset catalog.
3. **Must be rewritten or dropped** — encodes a POP-specific fact and **will mislead if carried over**.

## The three sharpest edges

- **§2 Ground Truth Hierarchy says the source is a TRUSTED DEFAULT you plan and build from.** That is true
  *only* because POP has real, buildable Mechner assembly pinned to the exact tree the oracle disk image was
  built from — an unusually favourable situation. **Do not inherit this ranking.** Establish what the Petscii
  Robots source situation actually is first; if it is a disassembly or binary-only, the honest ranking is
  probably trace-first.
- **§2G casts Karateka as the read-only sibling CoCo3 substrate.** For a new port that relationship may not
  exist at all, or may point somewhere else entirely. Rewrite or drop.
- **The framebuffer arithmetic is load-bearing throughout POP's file and INVERTS at 16 colours.** POP's
  cutscene runs 4-colour = **15,360 B/buffer**; 16-colour (4bpp) is **30,720 B/buffer**. Any memory reasoning
  carried over unexamined will be wrong by 2×.

## One rule the POP file does NOT have, and this project needs

Every lesson in the attached file came from **building**. The characteristic failure when **finishing**
someone else's near-complete code is different: a refactor that breaks something already working and gated.

Add something to the effect of: **changes stay minimal and local; a restructure of working code requires
authorization BEFORE it is written, not after it is proposed.**

## The invariants most worth preserving verbatim

These are the ones that matter *more* on a finishing project than they did on a building one, because they
are about not trusting what you did not verify:

- **A green check proves nothing until its input provenance is shown.** A checker that shares the thing-under-
  test's input is tautological. This failed **five times** in POP, in five disguises (assume the position;
  assume the input provenance; assume the cel; assume the cel is current; assume the position is current).
- **Instruments fail silently — six did in POP**, including two that were reporting nothing at all while
  appearing green.
- **A prior report's classification is a HYPOTHESIS, not a finding.** Re-measure before scoping work to it.
- **An assumption true when written can silently become false** when a later feature invalidates its premise.
- **A partial fix can look complete.**
- **Ablate/probe before theorising** — mechanical bisection beat modelling every time it was tried.
- **Route accounting** (§7 §6): state which parts of a route *you proposed* the change actually contains. A
  plan diverging from its implementation is **invisible in a diff**.
- **Accumulating vs systematic defects are read from STABILITY** — always two separated captures; a single
  zero proves nothing.

## Suggested first move for the new project

**Recon, not work.** Before any CLAUDE.md is finalised or any code is touched: does it build, does it run,
what is the oracle, what tests/instruments exist (if any), and what is actually left to finish? A cold start
on someone else's near-complete code with no instruments is the riskiest configuration there is.

## What to ask the human before writing

1. **The source situation** — buildable original source, disassembly, or binary only? (Determines §2 entirely.)
2. **The oracle** — what runs as the reference, on which platform? (Determines the visual gate.)
3. **Repo name, local path**, and whether the methodology candidate pool is shared.
4. **The build toolchain**, and whether it currently works on this machine.
5. **What "finish" consists of** — a known punch list, or open-ended?
