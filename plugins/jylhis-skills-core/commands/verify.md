---
description: Run the repo's full verification gate (fmt-independent) and summarize pass or fail.
argument-hint: [scope: current project | full | all-systems]
---

Follow the `verify` skill (plugins/jylhis-skills-core/skills/verify):

1. Pick the gates: if the justfile has `check` and `test` recipes run both;
   for focused work inside a j10s project run that project's `just test`;
   for flakes without just recipes run `nix flake check`; otherwise the
   project's native test command. If the user passed a scope argument,
   honor it (full = just check + just test; all-systems = include Darwin
   targets where the repo supports them, e.g. j10s `just darwin-build`).
2. Run each gate separately with a generous timeout; say which gate is
   running. nixbuild.net caches failures; reproduce stale ones locally with
   `--builders ''`.
3. Summarize one line per gate with pass/fail and duration. On failure show
   the gate name, the first real error, and a one-sentence most-likely fix.
   Give the re-run command instead of pasting full logs.