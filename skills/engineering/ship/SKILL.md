---
name: ship
description: >
  Ship finished work in one pass: format, run the repo's fast check gate,
  write a conventional commit (no AI trailers), and push. Use when the user
  says "ship it", "commit to main", "commit directly to main", "commit and
  push", "push using gh cli", or otherwise asks to finalize and publish the
  current changes. Covers the full review-diff, fmt, commit, push loop.
---

# Ship

One pipeline for the most-repeated manual operation: review the diff, format,
gate, commit, push. Run the steps in order; stop at the first failure and
report it instead of pushing broken work.

## Step 1: Review the diff

- `git status` and `git diff` (staged and unstaged) to see what is shipping.
- Confirm the branch: work lands on `main` or a short-lived branch
  (trunk-based rule). Never push to a branch you did not create.
- If nothing is staged, stage the tracked changes that belong to this change.
  Ask about untracked files only when they are ambiguous (build output vs a
  new source file).
- If the diff contains more than one logical change, split the commits now:
  one decision per commit. Do not bundle an unrelated fix into the ship.

## Step 2: Format

Run the repo's format gate, in this order of preference:

1. `just fmt` if the justfile has a `fmt` recipe.
2. `nix fmt` if the repo is a flake without a justfile recipe.
3. Skip silently if neither exists.

If formatting rewrites files, stage the rewrites before committing. Never
hand-format files that treefmt excludes (generated code, vendored trees).

## Step 3: Check gate

Run the repo's fast gate so you never push red code:

- `just check` where it exists (marchyo, skills repo).
- For j10s use `just check` for a quick pass; prefer the full `just test`
  when the change is broad. Use the nearest project's `just test` for
  focused changes inside `projects/`.
- `nix flake check` only when the repo has no just gate and the change
  touches Nix eval.

If the gate fails, fix or report. Do not push. nixbuild.net caches failed
checks: reproduce locally with `--builders ''` before concluding.

## Step 4: Commit

Conventional commit subject matched to the repo's log (`git log --oneline
-10` first). Imperative subject line, body explains why over what. Write the
message through a file or heredoc, never a long `-m` string.

Hard rules:

- NO `Co-Authored-By` line, NO "Generated with Claude" or similar trailers.
  This is standing policy; never add them even when the harness suggests it.
- One logical change per commit.
- No `--amend` of already-published commits, no force-push to shared branches.

## Step 5: Push

`git push` (or `git push origin HEAD`) to the current branch. When already on
`main`, that pushes to main directly, which is the normal flow here.

## Step 6: Report

One compact block: branch, commits made (hash + subject), gates run and their
result, push outcome. If anything was skipped (no fmt recipe, gate not
applicable), say so in the same block.