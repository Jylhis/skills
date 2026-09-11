---
description: Format, check, commit, and push the current work in one pass.
argument-hint: [optional commit subject hint]
---

Follow the `ship` skill (plugins/jylhis-skills-core/skills/ship) end to end:

1. Review `git status` and `git diff` (staged and unstaged). Confirm the
   branch is the intended target (main or a short-lived branch). Split into
   multiple commits if the diff carries more than one logical change.
2. Format: `just fmt` if the justfile has a `fmt` recipe, else `nix fmt` for
   flakes, else skip silently. Stage any formatting rewrites.
3. Check gate: `just check` where it exists; for j10s prefer `just test` for
   broad changes or the nearest project's `just test` for focused ones.
   On failure: fix or report, do not push. For stale-looking nixbuild.net
   failures, reproduce locally with `--builders ''`.
4. Commit with a Conventional Commits subject matched to the repo's log
   (`git log --oneline -10` first). Imperative subject, body explains why.
   NEVER add Co-Authored-By or "Generated with" trailers. No amending
   published commits, no force-push to shared branches.
   If the user gave an argument, use it as the subject hint; otherwise write
   the subject from the diff.
5. Push the current branch.

Finish with a compact report: branch, commits (hash + subject), gates run
and results, push outcome. Note anything skipped and why.