---
name: trunk-based-development
description: Trunk-based development with short-lived branches, daily integration, and never-break-main. Use when branching, planning commit cadence, handling work that spans more than a day, or deciding whether to fix-forward or revert.
metadata:
  jylhis-hard-rule: "3"
  jylhis-ratified: "JYL-140"
  authored: "2026-06-03"
---

# Trunk-Based Development

Hard Rule #3 at Jylhis. Read [references/workflow.md](references/workflow.md) for the full decision guide.

## Core constraints

| Constraint | Rule |
|---|---|
| Integration target | `main` only — no long-lived feature branches |
| Branch lifetime | Under one working day (target) |
| Merge gate | PR + green CI required before merge |
| Broken `main` | Fix-forward or revert immediately; nothing else starts |
| Incomplete work | Ship behind a feature flag (Rule 4), not on a branch |

## Daily rhythm

1. Pull `main`, create a short-lived branch: `git checkout -b <short-slug>`.
2. Write tests first (Rule 1 — TDD). Red → green → commit.
3. Keep commits small and self-contained. Push at least once per working day.
4. Open a PR; wait for green CI.
5. Merge same day. Delete the branch.

If you cannot finish in one day → split the work or add a feature flag and merge what you have. A partial merge behind a flag is always better than a day-old branch.

## Branching rules

- Branch name: `<short-description>` — no ticket numbers in the branch name are required, but keep it readable.
- One concern per branch. A branch that touches auth AND billing is too big — split it.
- Never branch off another branch. Always branch from `main`.

## When main is red

You are responsible for `main` being green. If your merge broke CI:

1. **Fix-forward** when the fix is ≤ 15 min. Commit the fix directly.
2. **Revert** (`git revert`) when the fix is unknown or risky. Revert first, diagnose on a branch.
3. Do not start new work until `main` is green.

Prefer fix-forward for small typos / config errors. Prefer revert for behavioral regressions.

## Slicing work small

Good slices have: one reviewable behavior change, a test that proves it, and no hidden dependencies on other in-progress work.

Ask: "Can I merge this without breaking anything, even if the feature isn't user-visible yet?" If yes, merge it (behind a flag if needed).

## Interaction with other Hard Rules

- **Rule 1 (TDD):** Red → green happens on the branch; only green code merges to `main`.
- **Rule 4 (Feature flags):** Anything not safe for all users on merge day gets a PostHog flag. The branch stays short-lived; the flag controls the rollout window.

See [references/workflow.md](references/workflow.md) for worked examples.
