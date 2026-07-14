---
name: learn-jj
description: Tutor the user in Jujutsu (jj), the Git-compatible version control system, by contrast with Git and through hands-on practice in a throwaway scratch repo. Use when the user wants to learn, study, or practice jj/Jujutsu, asks how jj differs from git, is confused about changes vs commits, bookmarks, the working-copy-as-commit model, the operation log, or jj undo, or wants guided jj exercises. Runs sessions and tracks progress through the tutor-engine skill (subject id `jj`).
---

# learn-jj

Subject expertise for teaching **Jujutsu (jj)** — a Git-compatible VCS. **Session
mechanics and progress tracking come from the `tutor-engine` skill** (subject id
`jj`) — load it for any session. This skill supplies the concepts, the
git→jj mapping, and safe practice scenarios.

## Teach by contrast with Git, then by doing

Most learners already know Git, so anchor each jj concept to its Git counterpart,
then have them *do it* in a scratch repo. jj's safety net (the operation log +
`jj undo`) makes mistakes nearly free, so practice should be hands-on from minute
one.

## The five ideas that reframe everything

1. **Changes, not (just) commits.** A *change* is a unit of work with a **stable
   change-id** that survives amends and rebases (the underlying commit hash
   changes; the change-id doesn't). This decouples "the work" from "its current
   snapshot".
2. **The working copy is a commit.** Your edits live in a real commit (`@`) that
   updates automatically as you type. **There is no staging area / `git add`.**
3. **Bookmarks, not branches.** jj is branchless by default; named **bookmarks**
   point at changes and are what you push. You can stack work without ever naming
   a branch.
4. **Automatic rebasing.** Edit a change in the middle of a stack and jj rebases
   the descendants for you. Conflicts are *stored in commits*, not a blocking
   state — you can resolve them later.
5. **The operation log.** Every jj operation is recorded (`jj op log`); **`jj
   undo`** reverses the last one, and `jj op restore` jumps to any prior repo
   state. Losing work is very hard.

Full mapping and command crib: `references/jj-vs-git.md`. Everyday workflows:
`references/workflows.md`.

## Practice safely in a scratch repo

Never practice on real work. Spin up a seeded throwaway repo:

```
scripts/jj-scratch            # prints a path to a fresh jj repo with some history
cd "$(scripts/jj-scratch)"    # or capture the path
jj log        # see the changes
jj op log     # see the operations
```

(The helper needs `jj` installed; it refuses to touch a non-empty directory.)
Guided scenarios are in `references/exercises.md`.

## Teaching moves specific to jj

- **Show the graph constantly.** After every operation run `jj log` and `jj op
  log` and have the learner narrate what changed (dual coding + explain-it-back).
- **Lead with `jj status` / `jj diff`** so they see the working-copy commit update
  with no `add` step — this is the biggest mindset shift from Git.
- **Make undo a habit early.** Have them deliberately "break" something and recover
  with `jj undo` so the safety net feels real and exploration feels safe.
- **Don't overteach bookmarks at first.** Let them experience branchless stacking,
  then introduce bookmarks when it's time to push.
- Capture sticky points as `tutor-engine` cards tagged `changes`, `bookmarks`,
  `op-log`, `rebase`, `squash`.

## Verification
- [ ] Practice happened in a scratch repo, never real work.
- [ ] The learner inspected `jj log` / `jj op log` and explained each step back.
- [ ] They recovered from a deliberate mistake with `jj undo` at least once.
