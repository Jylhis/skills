# Script migrations

Inventory of every script under a `scripts/` directory in this repo,
its current language, the target language under the preference
(`AGENTS.md` § Script language preference), and the migration priority.

**This document is the plan, not the work.** Migrations land in
separate PRs. `scripts/validate.py` emits advisory warnings for files
not yet on the preferred language; `--strict-scripts` promotes them to
hard errors for use in CI gates once enough has migrated.

## Preference recap

1. Go
2. TypeScript + Bun
3. Typed Python (`mypy --strict`)

Shell stays only for ~5-line `nix run` wrappers. Everything bigger is in
scope for migration.

## Inventory

| Path | Current | Target | Priority | Rationale |
|------|---------|--------|----------|-----------|
| `scripts/install.sh` (321 lines) | bash | Go | medium | Real installer with multiple registration paths; would benefit from typed config + tests. |
| `scripts/validate.py` (533 lines) | typed Python (advisory-clean) | Go | low | Bootstrap concern — the validator can't validate itself if rewritten in Go yet. Already typed; keep as the typed-Python exemplar until Go is in `devenv.nix`. |
| `scripts/append-correction.py` (new) | typed Python | Go | high | Small (~80 lines), called from a slash command. Easy first Go target once `devenv.nix` ships a Go toolchain. |
| `evals/scripts/cassette.py` | Python | typed Python (exemption) | defer | Heavy YAML + jsonschema reliance; rewriting in Go is high-effort, low-value. Keep but ensure `mypy --strict` clean. |
| `evals/scripts/expand.py` | Python | typed Python (exemption) | defer | Same — PyYAML-driven case expansion. |
| `evals/scripts/invariants.py` | Python | typed Python (exemption) | defer | Same — jsonschema-driven invariants. |
| `evals/scripts/seed_synthetic.py` | Python | typed Python (exemption) | defer | Same — synthetic cassette seeding via PyYAML. |
| `meta/upstream-tracker/scripts/_lib.py` | typed Python | Go | low | Stable; git plumbing — straightforward to port. |
| `meta/upstream-tracker/scripts/fetch.py` | typed Python | Go | low | git fetch wrapper; trivial Go rewrite. |
| `meta/upstream-tracker/scripts/import.py` | typed Python | Go | low | Tree walk + frontmatter inject; doable in Go. |
| `meta/upstream-tracker/scripts/review.py` | typed Python | Go | low | Append-only decision log; trivial Go rewrite. |
| `skills/gitlab/gitlab/scripts/ci-debug.sh` | bash | Go | medium | GitLab API call + JSON manipulation — Go is the right shape (`net/http` + `encoding/json`). |
| `skills/gitlab/gitlab/scripts/sync-fork.sh` | bash | Go | medium | Same. |

## Order of operations

1. Add a Go toolchain to `devenv.nix` (separate PR).
2. Port the smallest helper first: `scripts/append-correction.py`. Use
   it as the reference implementation for the rest.
3. Port `meta/upstream-tracker/scripts/` next — small, internal,
   no end-user impact.
4. Port `skills/gitlab/gitlab/scripts/` as a group; one PR per script
   or a single PR if the diff stays reviewable.
5. Port `scripts/install.sh` once a Go port of `validate.py` exists
   (so `just check` can shell out to one Go binary instead of two).
6. Port `scripts/validate.py` last; rewriting it in Go closes the
   bootstrap question.

## Out of scope here

- Adding Bun to `devenv.nix` — only needed when a TypeScript candidate
  appears.
- Rewriting eval scripts; the `mypy --strict` exemption is permanent
  until the ecosystem ergonomics in Go catch up to PyYAML/jsonschema.
- Backfilling tests for the existing Bash scripts — port them, then
  add table-driven Go tests in the new file.
