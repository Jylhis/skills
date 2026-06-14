---
name: git-surgeon
description: Use for non-interactive, hunk-level git surgery with the `git-surgeon` CLI — when you need `git add -p` precision but cannot drive interactive prompts. Covers listing and showing hunks (`hunks`, `show`), staging/unstaging/discarding individual hunks or line ranges (`stage`, `unstage`, `discard --lines`), committing selected hunks (`commit`, `commit-to <branch>`), and history rewriting (`fold`, `amend`, `reword`, `squash`, `split`, `move`, `undo`). Reach for this instead of `git checkout` / `git reset` workarounds that destroy uncommitted work.
---

# git-surgeon

`git-surgeon` is a CLI that gives an agent surgical, **non-interactive**
control over git changes: stage, unstage, discard, commit, and rewrite
history at the granularity of a single hunk — or a line range inside a
hunk. It exists because an agent cannot drive `git add -p`, `git
rebase -i`, or other interactive porcelain, and the usual fallbacks
(`git checkout -- <file>`, `git reset --hard`, `git stash drop`) are
blunt and lossy — they throw away uncommitted work you meant to keep.

Reach for `git-surgeon` whenever you want "only these lines" precision:
committing one logical change out of a dirty tree, discarding a stray
debug edit without touching the rest of a file, or reshaping a messy
branch before review. It is the mechanical primitive layer; for the
narrative side of history (commit subjects/bodies, what to squash and
why) pair it with the `commit-stories` skill.

## Install

```bash
cargo install git-surgeon                       # Rust
brew install raine/git-surgeon/git-surgeon      # Homebrew
curl -fsSL https://raw.githubusercontent.com/raine/git-surgeon/main/scripts/install.sh | bash
```

Requires git ≥ 2.0. The binary is `git-surgeon`. (It also ships a
`git-surgeon install-skill --claude|--codex|--opencode` that drops its
own agent skill — not needed here, since this skill already covers it.)

Daily update checks can be silenced with `GIT_SURGEON_NO_UPDATE_CHECK=1`.

## Hunk IDs — the addressing model

Every command targets a **hunk ID**: a 7-char hex string derived from a
SHA-1 of the file path plus the hunk's `+`/`-`/context lines (the `@@`
header is excluded). Properties to rely on:

- **Stable** — adding lines *above* a hunk does not change its ID.
- **Deterministic** — identical content always yields the same ID.
- **Collision-safe** — ambiguous IDs get `-2`, `-3` suffixes
  (e.g. `a1b2c3d-2`).

Many commands accept an inline **line range** suffix on the ID to act on
part of a hunk: `a1b2c3d:5-30`, or multiple ranges `a1b2c3d:1-11,20-30`.
The standalone `--lines <range>` flag does the same for single-hunk
commands. Line numbers are 1-based against the output of `show`.

## Inspect

```bash
git-surgeon hunks                    # list unstaged hunks: ID, path, fn context, ± counts
git-surgeon hunks --staged           # what's already staged
git-surgeon hunks --file src/app.rs  # filter by path
git-surgeon hunks --commit <sha>     # hunks introduced by a commit
git-surgeon hunks --full             # complete diff with line numbers
git-surgeon hunks --blame            # which commit introduced each line
git-surgeon show <id>                # full diff for one hunk, 1-based line numbers
```

Always `hunks` / `show` first — IDs and line numbers come from here, and
it is your only "dry run" (see footguns).

## Stage / unstage / discard

```bash
git-surgeon stage <id> [<id>...]            # stage whole hunks
git-surgeon stage <id> --lines 5-30         # stage only part of a hunk
git-surgeon unstage <id> [--lines 5-30]     # move staged changes back to the worktree
git-surgeon discard <id> [--lines 5-30]     # DESTROY uncommitted changes — irreversible
```

`discard` permanently deletes the matching uncommitted changes; there is
no undo. Confirm the target with `show <id>` before discarding.

## Commit selected hunks

```bash
git-surgeon commit <id> [<id>...] -m "message"        # stage + commit in one step
git-surgeon commit a1b2c3d:1-11 d4e5f6a -m "message"  # inline line ranges allowed
git-surgeon commit-to <branch> <id>... -m "message"   # commit onto another branch, no checkout
```

- `commit` stages the named hunks and commits them; if the commit
  fails, it auto-unstages so the index is left clean.
- `commit-to` applies the hunks to the target branch's tree via git
  plumbing **without checking it out**. It is atomic — if the patch
  doesn't apply cleanly the repo is left untouched.
- Both **refuse to run if the index already has staged changes** —
  unstage or commit those first.

## Rewrite history

```bash
git-surgeon fold <sha> [--from <sha>]                 # fold commit(s) into an earlier one (HEAD by default)
git-surgeon amend <sha>                               # fold currently-staged changes into an earlier commit
git-surgeon reword <sha> -m "subject" [-m "body"]     # change a message, not the content
git-surgeon squash <sha> -m "message"                 # squash <sha>..HEAD into one commit
git-surgeon split <sha> --pick <ids> -m "msg" [--rest-message "msg"]
git-surgeon move <sha> --after <target>               # also --before <target> or --to-end
git-surgeon undo <id> --from <sha>                    # reverse-apply hunks from a commit onto the worktree
```

Notes:

- `amend` uses `git commit --amend` for HEAD, or an autosquash rebase
  for older commits; unstaged work is preserved via autostash.
- `squash` flags: `--force` (flatten merge commits),
  `--no-preserve-author` (attribute to the current user).
- `split` needs a clean working tree; repeat `--pick <ids> -m <msg>` for
  each output commit, with inline ranges (`a1b2c3d:1-11,20-30`) allowed.
- `undo` reverse-applies the hunks as **unstaged** worktree changes — a
  surgical alternative to `git revert` when you only want part of a
  commit backed out.

## Safety & footguns

- **No dry-run, no automatic backups.** `discard`, `commit-to`, and all
  the history-rewriting commands act for real. `hunks` / `show` are your
  only preview — use them.
- **Autostash** saves and restores uncommitted work around rebases, so
  history rewrites won't silently eat your worktree.
- **Conflicts are left in-tree.** If a rebase-backed command
  (`fold`, `amend`, `squash`, `split`, `move`) hits a conflict, the repo
  is left in the conflict state for you to resolve manually — it does not
  auto-commit a guess.
- **Index-must-be-clean refusals.** `commit` and `commit-to` won't run
  with staged changes already present; that's a guard, not a bug.
- Rewriting published history still rewrites SHAs — only do it on
  branches you can force-push.

## References

- Repository: <https://github.com/raine/git-surgeon>
- README / command docs: <https://github.com/raine/git-surgeon#readme>
