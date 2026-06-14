# Trunk-Based Development — Workflow Reference

## When the work fits in one day

```
git checkout main && git pull
git checkout -b my-feature

# TDD loop (Rule 1)
# write failing test → write code → green → commit

git push -u origin my-feature
# open PR → wait for green CI → merge → delete branch
git checkout main && git pull && git branch -d my-feature
```

## When the work does NOT fit in one day

Do not keep the branch alive for a second day. Instead:

1. **Split:** identify a mergeable vertical slice — one behavior, one test, green CI.
2. **Flag the rest:** create a PostHog flag (Rule 4) for the part that isn't ready.
3. Merge the safe slice behind the flag (flag default: OFF).
4. Continue on a fresh branch tomorrow.

```
# Day 1
git checkout -b my-feature-slice-1
# implement slice, tests green
# merge to main with flag OFF
git checkout main && git pull && git branch -d my-feature-slice-1

# Day 2
git checkout -b my-feature-slice-2
# continue under the same flag
# when fully ready, flip flag ON in PostHog and schedule cleanup
```

## Fix-forward vs. revert decision tree

```
main is red after your merge?
│
├─ Root cause known and fix is ≤ 15 min?
│   └─ YES → fix-forward:
│              git checkout main
│              # make the fix, commit, push
│
└─ Unknown cause OR fix is risky/large?
    └─ YES → revert:
               git revert <merge-commit-sha>
               git push  # main is green again
               # diagnose on a new branch
```

## Code review checklist (pre-merge)

- [ ] Branch is off `main` (not off another branch)
- [ ] Branch lifetime < 1 working day
- [ ] All tests pass (CI green)
- [ ] Any unsafe-for-everyone behavior is behind a PostHog flag (default OFF)
- [ ] No unresolved TODO/FIXME that blocks this PR

## Common mistakes

| Mistake | Correct action |
|---|---|
| "I'll merge tomorrow — tests pass locally" | Push and open the PR now; waiting creates drift |
| Branch based on another in-progress branch | Rebase onto `main`; split the dependency |
| Leaving `main` red to "fix it later" | Stop all new work; revert or fix-forward first |
| Long-lived branch with 40 commits | Identify mergeable slices; add flags for the rest |
