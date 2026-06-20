# jj vs Git — concept mapping and command crib

jj stores its history in a Git repository (`jj git init` / `jj git clone`), so it
interoperates with GitHub/GitLab and with teammates using Git. The model on top is
different.

## Concept mapping

| Git | Jujutsu (jj) | Note |
|-----|--------------|------|
| commit (immutable hash) | **change** (stable change-id) + commit hash | the change-id survives amend/rebase; the hash changes |
| staging area / index | **none** | the working copy *is* a commit (`@`); edits auto-commit |
| `git add` | **nothing** | files are already part of `@` |
| branch (moves with commits) | **bookmark** (a named pointer you move/push) | jj is branchless by default |
| `HEAD` | `@` (the working-copy change) | `@-` is its parent |
| `git stash` | just `jj new` | start a fresh change; the old one is saved as-is |
| detached HEAD | normal | working anywhere is fine; no special state |
| `git reflog` (fragile) | **`jj op log`** (first-class) | every operation is recorded |
| `git reset/revert` to recover | **`jj undo`** / `jj op restore` | reverses operations, not just commits |
| merge conflict blocks you | **conflicts stored in the commit** | keep working; resolve later |

## Command crib

| Task | Git | jj |
|------|-----|-----|
| init | `git init` | `jj git init` |
| clone | `git clone URL` | `jj git clone URL` |
| status | `git status` | `jj status` |
| see history | `git log --graph` | `jj log` |
| diff working copy | `git diff` | `jj diff` |
| start new work | `git checkout -b x` | `jj new` (name later with a bookmark) |
| describe current work | `git commit -m` | `jj describe -m "…"` |
| amend current work | `git commit --amend` | (just edit files — `@` updates) or `jj squash` |
| split a commit | `git rebase -i` … | `jj split` |
| squash into parent | `git rebase -i` / `--fixup` | `jj squash` |
| move work onto another base | `git rebase` | `jj rebase -d <dest>` |
| switch to a change | `git checkout <c>` | `jj edit <change-id>` or `jj new <id>` |
| create/move a branch | `git branch x` | `jj bookmark set x` |
| push | `git push origin x` | `jj git push --bookmark x` (or `--all`) |
| fetch | `git fetch` | `jj git fetch` |
| undo last action | `git reset --hard@{1}` (risky) | `jj undo` |

## The biggest mindset shifts
- **No staging.** Stop reaching for `git add`. To put part of a change elsewhere,
  use `jj split` / `jj squash --interactive`.
- **Edit history freely.** Amending a mid-stack change auto-rebases descendants;
  you don't manually replay them.
- **Undo is cheap and total.** `jj undo` reverses the *operation*, so even a botched
  rebase or a bad `bookmark set` is one command to reverse.
- **Branches are optional.** Bookmarks are just labels you add when you need to
  push or share; day-to-day you can work entirely by change-id.
