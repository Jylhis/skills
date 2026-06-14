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

# Or fetch the upstream install script, read it, then run it (don't pipe to a shell unread):
curl -fsSL https://raw.githubusercontent.com/raine/git-surgeon/main/scripts/install.sh -o install-git-surgeon.sh
bash install-git-surgeon.sh                      # after reviewing it
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

To act on part of a hunk you give it a **line range** (1-based against the
output of `show`). Two syntaxes, and they are **not interchangeable**:

- Inline `id:range` suffix — `a1b2c3d:5-30` or `a1b2c3d:1-11,20-30` — is
  parsed **only** by `commit`, `commit-to`, and `split`.
- The `--lines <range>` flag is how `stage`, `unstage`, `discard`, and
  `undo` take a range; they **reject** an ID containing `:`.

## Inspect

```bash
git-surgeon hunks                    # list unstaged hunks: ID, path, fn context, ± counts
git-surgeon hunks --staged           # what's already staged
git-surgeon hunks --file src/app.rs  # filter by path
git-surgeon hunks --commit <sha>     # hunks introduced by a commit
git-surgeon hunks --full             # complete diff with line numbers
git-surgeon hunks --blame            # which commit introduced each line
git-surgeon show <id>                # full diff for one hunk, 1-based line numbers
git-surgeon show <id> --commit <sha> # a hunk from a specific commit
```

Always `hunks` / `show` first — IDs and line numbers come from here, and
it is your only "dry run" (see footguns). `show` without `--commit`
searches only the staged + unstaged diffs, so an ID you got from
`hunks --commit <sha>` must be shown (and later split/undone) with the
**same** `--commit <sha>` — otherwise it reports "not found" or hands you
line numbers from an unrelated worktree hunk.

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
  doesn't apply cleanly the repo is left untouched. On success it
  **discards the committed hunks from your working tree** — the selected
  local changes move to the target branch and disappear locally, they are
  not left behind as uncommitted edits.
- Both **refuse to run if the index already has staged changes** —
  unstage or commit those first.

## Rewrite history

```bash
git-surgeon fold <sha> [--from <sha>]                 # fold commit(s) into an earlier one (HEAD by default)
git-surgeon amend <sha>                               # fold currently-staged changes into an earlier commit
git-surgeon reword <sha> -m "subject" [-m "body"]     # change a message (clean index only — see safety)
git-surgeon squash <sha> -m "message"                 # squash <sha> through HEAD (inclusive) into one commit
git-surgeon split <sha> --pick <ids> -m "msg" [--rest-message "msg"]
git-surgeon move <sha> --after <target>               # also --before <target> or --to-end
git-surgeon undo <id> --from <sha> [--lines 2-10]     # reverse-apply hunks from a commit onto the worktree
```

Notes:

- `amend` uses `git commit --amend` for HEAD, or an autosquash rebase
  for older commits; unstaged work is preserved via autostash.
- `squash` takes the **oldest** commit to fold and combines it *through*
  HEAD, inclusively — `git-surgeon squash HEAD~1 -m ...` squashes the last
  two commits. It is not git's exclusive `<sha>..HEAD` range, so don't pass
  the parent of the commit you mean. Flags: `--force` (flatten merge
  commits), `--no-preserve-author` (attribute to the current user).
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
- **`reword` / `amend` do *not* guard the index.** `reword` is
  "message-only" **only on a clean index** — it amends via
  `git commit --amend -m`, so any changes you have staged get folded into
  the rewritten commit. Stash or unstage first if you intend to touch the
  message alone. (`amend` folding the staged index is its purpose, not a
  surprise — but the same caveat applies if you forgot what was staged.)
- Rewriting published history still rewrites SHAs — only do it on
  branches you can force-push.

## References

- Repository: <https://github.com/raine/git-surgeon>
- README / command docs: <https://github.com/raine/git-surgeon#readme>
