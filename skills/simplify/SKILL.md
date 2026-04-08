---
name: simplify
description: Review changed code for reuse, quality, and efficiency, then fix any issues found. Use when the user says "simplify this", "/simplify", "clean up this code", "review my changes for duplication or dead code", "any way this could be simpler", or after a chunk of code has just been written and should be passed over with a skeptical eye before committing.
---

# Simplify

Review the *recently changed* code (not the whole repo) with a skeptical,
efficiency-focused eye, and fix any issues you find. The goal is to leave
behind the simplest correct code that satisfies the task — nothing more.

## Scope

Only look at code that was changed in this session or in the current
uncommitted diff. Do not "improve" unrelated areas. If the user provides a
specific file or range, confine the review to that.

If there is no diff to inspect, ask the user which files to review.

## What to look for

Work through the changed code with these lenses, in order:

### 1. Reuse

- Is there already a function / helper / library call that does this? Prefer
  the existing one, even if it's slightly less convenient.
- Does the new code duplicate logic that lives elsewhere in the codebase?
  Consolidate or delete the duplicate.
- Is the SDK / framework already providing this? (e.g. typed SDK exceptions,
  built-in iteration helpers, standard library utilities.)

### 2. Dead weight

- Unused parameters, variables, imports, or functions.
- Commented-out code — delete it; git remembers.
- "Just in case" validation on values that can't be invalid.
- Try/except blocks that catch something that can't be raised.
- Configurability that has exactly one caller.
- Abstractions introduced for a hypothetical second caller that never arrived.

### 3. Speculation

- Feature flags guarding code the user didn't ask for.
- Backwards-compat shims for an API nobody else uses.
- Premature generalization — a single-use helper pretending to be a library.
- Parameters defaulted to "the only value anyone passes".

### 4. Efficiency

- O(n²) where O(n) is free (dict lookup vs repeated list scan).
- Repeated work inside a loop that could be hoisted out.
- Unnecessary allocations, copies, or serialization round-trips.
- Network / filesystem calls inside a loop when a batch API exists.
- Pay attention to efficiency but do not rewrite for speculative perf wins —
  simplify is primarily about *complexity*, not micro-optimization.

### 5. Clarity

- A helper whose name is longer than its body.
- A comment explaining code that would be clearer if rewritten.
- A three-layer abstraction where a two-line inline call would read better.
- Names that describe mechanism instead of intent.

## Workflow

1. **Identify the diff.** Use git (`git diff`, `git diff --staged`,
   `git diff main...HEAD`) or the list of files changed in this session. Read
   the changed files in full — not just the hunks — to understand context.
2. **Read the surrounding code** that the changes interact with. Reuse
   opportunities usually hide one directory over.
3. **Make a list** of concrete issues with file:line references. Group them
   by category (Reuse / Dead weight / Speculation / Efficiency / Clarity).
4. **Fix them.** Apply edits directly. Do not fabricate issues just to have
   something to report — if the diff is already clean, say so.
5. **Run verification** — at minimum, typecheck / lint / run the tests
   relevant to the files touched. Do not hand back "simplified" code that no
   longer compiles.
6. **Report** what was changed and why, in a few lines per fix. Group the
   report so the user can scan it quickly.

## What NOT to do

- Don't "improve" code you weren't asked to touch.
- Don't add docstrings, type annotations, or comments to code you didn't
  change as part of a real simplification.
- Don't introduce new abstractions, helpers, or utility modules unless they
  eliminate more complexity than they add, *right now*, across multiple
  existing callers.
- Don't reformat for style — that's what formatters are for.
- Don't rename things unless the old name is actively misleading.
- Don't silently remove error handling that looks paranoid but is actually
  guarding a real failure mode you haven't investigated.

## Calibration

Three similar lines are usually better than a premature abstraction. A
function with one caller rarely deserves to exist. A comment explaining
*what* the code does is usually a sign the code should be rewritten; a
comment explaining *why* is usually worth keeping.

When in doubt, delete. You can always re-add, and git remembers.
