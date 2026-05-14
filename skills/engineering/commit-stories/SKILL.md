---
name: commit-stories
description: Write git commit messages and curate branch history so the log reads as a narrative — capturing what changed, why, and how the work evolved. Trigger when preparing a commit (subject + body, diff review, splitting/squashing), when auditing a branch log before opening or merging a PR, when generating a changelog, or when the user asks for help making a commit history readable.
---

# Commit stories

A commit log is a manuscript about your manuscript. Good commits let a future reader (or you, six months from now) reconstruct **what changed, why, and where the work struggled** — without re-reading the diff. "WIP", "minor edits", and "fix stuff" throw that signal away.

This skill is about the *content* of commits. The mechanics — HEREDOC for the message, no `--amend` of already-published commits, no `--no-verify`, no force-push to main — come from the harness rules and are not restated here.

## When to use this skill

- You are about to write a commit (single, or the last of a series).
- You are auditing a branch log before opening or merging a PR.
- You are generating a changelog or release note from a range of commits.
- The user asks to "rewrite history", "clean up the log", "squash these", or "make this readable".

## Step 1 — Review the diff before naming it

Run `git diff --staged` (or `git diff --staged --word-diff` for prose-heavy or doc changes). Read it as if you didn't write it.

Ask, in order:

1. **Is this one decision?** A single change in behaviour, schema, contract, or intent. If you find yourself writing "and" in the subject — split.
2. **What changed in *intent*, not in files?** "Updated `auth.py`" is not a commit message; "Reject expired tokens at the auth boundary" is.
3. **Is anything in here unrelated drift?** Stray formatting, accidental file additions, a TODO you fixed in passing. Unstage and commit separately, or drop.

## Step 2 — The subject line

- **Imperative, present tense.** "Add", "Fix", "Reject", "Cut" — not "Added"/"Adds"/"Adding".
- **~50 characters.** Hard ceiling around 72. Many tools truncate at 50.
- **Names the change in behaviour or contract**, not the file.
- **No trailing period.** Match the existing repo style: capitalised first word, no period (e.g. `Add mattpocock-inspired skills-organization review memo`).
- **Optional `scope:` prefix** when one part of the repo dominates the change (e.g. `upstream-tracker: import 6 remaining sources`). Don't force one.

Bad → good:

| Bad | Better |
|---|---|
| `WIP` | `Reject expired tokens at auth boundary` |
| `fixes` | `Fix off-by-one in pagination cursor` |
| `update auth.py` | `Require MFA for service-account logins` |
| `cleanup` | `Remove dead OAuth1 fallback path` |
| `more changes` | `Cut /v1 retry loop to one attempt` |
| `Address review comments` | (squash into the relevant commit instead) |

## Step 3 — The body (only when it earns its keep)

Skip the body for trivial, self-evident changes. Write one when the **why** isn't obvious from the diff. Capture, in priority order:

1. **Motivation** — what prompted this; what was broken or missing.
2. **Constraint** — what the fix could not change (compat, perf budget, security boundary).
3. **Alternative considered** — what you tried or rejected, and why.
4. **Follow-up** — debt the change leaves behind, or a deliberate omission.

Format: one blank line after subject, wrap at ~72 cols, prose paragraphs (not bullets unless genuinely a list).

A body that just restates the diff is noise. If you can't write a sentence the diff doesn't already say, leave it out.

## Step 4 — One commit = one decision

The 50–500-line range is a common rhythm, not a rule. The real test:

> Can you write a single honest subject for everything in this commit?

If not, split. If two commits would have the same subject, squash. Exploratory commits ("typo", "try harder", "fix fix") get squashed into the decision commit **before** you push — `git rebase -i`, or `git commit --fixup=<sha>` while working and `git rebase --autosquash` at the end.

## Step 5 — Milestones use tags, not commits

Commits are the daily journal. Tags are the chapter markers.

- `git tag -a v1.2.0 -m "..."` for releases, deprecation boundaries, and breaking-change points.
- Annotated tags (`-a`) only — they carry a message and author. Lightweight tags are silent.
- Don't try to make a commit subject carry the weight of a release note. That's what the tag's message and the changelog are for.

## Step 6 — Late-arriving context uses git notes

Once a commit is published, the message is frozen. New context that surfaces later — review feedback that didn't make it in, a postmortem link, perf numbers from staging — goes in a git note, not a rewrite.

```
git notes add -m "Reverted in <sha>; root cause was config drift, not this commit." <sha>
git notes show <sha>
```

Notes ship in `refs/notes/commits` and are visible in `git log --show-notes`. They are the right place for "what we learned after the fact".

## Step 7 — Audit the log before the PR

Before pushing or opening the PR, read the branch as a story:

```
git log --oneline <base>..HEAD
```

Hand it to a teammate cold (or imagine doing so). Can they tell:

- What the branch is *for*?
- Which commit is the core change vs. setup vs. cleanup?
- Where the hard part was?

If not, fix it before review:

- `git rebase -i <base>` to reorder, squash, or reword.
- `git commit --fixup=<sha>` during work, then `git rebase -i --autosquash <base>` to fold "fixup!" commits into their targets.
- Reword vague subjects (`r` in interactive rebase) with the specific change.
- Drop `Address review comments` / `Apply suggestions from code review` — fold them into the commit they relate to.

Only rewrite history that is **local or on your own feature branch**. Don't rewrite shared branches or anything others have pulled.

## Anti-patterns

- **"WIP" / "more" / "stuff" / "updates"** — name the actual change, or don't commit yet.
- **Megacommits** — one commit, 40 files, subject `Implement feature X`. Split by decision.
- **Commit-per-file noise** — one commit per touched file with no cohesion. Squash by intent.
- **`Fix bug` with no body** — at minimum, name the bug or link the issue.
- **Subject in past tense / gerund** — `Added X` / `Adding X`. Use the imperative: `Add X`.
- **Trailing period on a 50-char subject** — wastes a character and doesn't match repo style.
- **`Merge branch 'main' into feature/...` left in the log** — rebase instead, or squash on merge.

## What a good log reveals

- **Where momentum built** — a run of crisp, decision-shaped subjects.
- **Where the work struggled** — a cluster around one area; bodies that note alternatives tried.
- **What the branch is *for*** — readable in 10 seconds from `git log --oneline`.
- **What the reviewer needs to focus on** — the core-decision commit stands out from setup and cleanup.

## References

- Chris Maiorana, *Let the Commits Tell the Story* — <https://chrismaiorana.com/git-commits-tell-the-story/> (the writer-side framing that inspired this skill).
- `git help log`, `git help notes`, `git help tag`, `git help rebase` — the underlying mechanics.
