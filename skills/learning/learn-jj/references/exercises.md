# jj practice scenarios

Guided, escalating exercises. Run each in a fresh scratch repo
(`scripts/jj-scratch`). After every step, have the learner run `jj log` and `jj op
log` and explain what changed before moving on. The point is to build trust in the
model and the undo safety net.

## 1. The working copy is a commit (no staging)
1. `jj status` — note `@` is the working-copy change.
2. Edit `README.md`. Run `jj status` and `jj diff` — the change is *already*
   tracked; there was no `git add`.
3. `jj describe -m "Edit the readme"` — give the change a message.
- **Explain back:** where did the edit go, and why was there no staging step?

## 2. Stacking changes
1. `jj new -m "Add feature A"`; create `a.txt`.
2. `jj new -m "Add feature B"`; create `b.txt`.
3. `jj log` — observe the stack and the stable change-ids.
- **Explain back:** what is each change's parent?

## 3. Undo (build trust)
1. `jj describe -m "oops wrong message"`.
2. `jj op log` — find the describe operation.
3. `jj undo` — the message reverts. Confirm with `jj log`.
- **Explain back:** what exactly did `jj undo` reverse — a commit or an operation?

## 4. Edit a change in the middle of a stack (auto-rebase)
1. With the stack from #2, `jj edit <change-id of feature A>`.
2. Modify `a.txt`. Run `jj log` — feature B was rebased onto the new A
   automatically.
- **Explain back:** what would this have required in Git?

## 5. Squash and split
1. `jj new -m "tweak"`; make a small edit.
2. `jj squash` — fold it into its parent. Confirm with `jj log`.
3. On a change with two unrelated edits, `jj split` and separate them.
- **Explain back:** when would you reach for squash vs split?

## 6. Rebase deliberately, then recover
1. `jj rebase -d <some other change>` to move a change.
2. Inspect `jj log`.
3. `jj undo` (or `jj op restore <id>`) to put it back.
- **Explain back:** how is recovery here different from a botched `git rebase`?

## 7. Bookmarks and a (local) push dry-run
1. `jj bookmark set feature -r @`.
2. `jj log` — see the bookmark label on the change.
3. Discuss `jj git push --bookmark feature` (don't push from a scratch repo;
   explain what it would create on the remote).
- **Explain back:** how is a bookmark different from a Git branch?

## Logging weak spots
Whenever a step needs a second attempt, capture it via the tutor-engine:
`learn.go log-error --subject jj --concept <changes|rebase|bookmarks|op-log> --note "…"`.
