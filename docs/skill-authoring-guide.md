# Skill authoring guide

A skill is a directory under `skills/` containing a `SKILL.md` and
optional helper material. This repo follows the
[Agent Skills](https://agentskills.io) open standard with a strict
portability profile (see [`skills-spec-v3.md`](skills-spec-v3.md)).

## Directory shape

```
skills/<skill-name>/
├── SKILL.md           # required
├── references/        # optional — task-specific reference docs
├── scripts/           # optional — deterministic helper scripts
└── assets/            # optional — fixtures, templates
```

`<skill-name>` must:

- match the `name:` in frontmatter (verified by `scripts/validate.py`)
- be lowercase letters, numbers, and hyphens only
- have no leading/trailing hyphen and no consecutive hyphens

## Frontmatter

```yaml
---
name: review-pr
description: |
  Review pull requests and local diffs for correctness, regressions,
  missing tests, security issues, and risky architecture changes. Use
  when asked to review a PR, inspect a diff, or audit changes.
license: MIT
---
```

Required:

- `name` — must equal the parent directory basename
- `description` — 50–1024 chars; should include explicit trigger phrases

Optional:

- `license` — string
- `compatibility` — environment requirements (e.g. "Requires git")
- `metadata` — free-form map; values should be strings

### Vendored from upstream

Skills imported from an external repo via the `meta/upstream-tracker`
workflow include a `metadata.upstream-*` block recording the baseline
sha and source id. The fields are advisory — `validate.py` warns on
unknown ids when `upstream/sources.yaml` exists but doesn't error in
default mode. See
[meta/upstream-tracker/references/frontmatter-block.md](../meta/upstream-tracker/references/frontmatter-block.md)
for the exact shape and the validator's strict-mode behaviour.

## Rejected fields

The portable lint rejects target-specific frontmatter:

```
allowed-tools, disable-model-invocation, user-invocable, argument-hint,
arguments, paths, hooks, context, agent, model, effort, tools,
disallowedTools, mcpServers, permissionMode, isolation, shell
```

It also rejects target-specific path syntax in the body:

```
${CLAUDE_PLUGIN_ROOT}, ${CLAUDE_SKILL_DIR}, ${extensionPath},
${workspacePath}, !`...`, !{...}
```

If a skill genuinely requires target-specific behavior, fork it into
`target-skills/<target>/<name>/SKILL.md` (not yet wired in this repo —
see `docs/skills-spec-v3.md` §8).

## Body shape

A useful SKILL.md typically has:

1. **One-line purpose** — what this skill does in plain language.
2. **Process** — numbered procedural steps. Concrete and verifiable.
3. **Verification** — checks the agent should run before finishing.
4. **References** — pointers to `references/*.md` for deep material.
5. **Helper scripts** — pointers to `scripts/*` with usage notes.

Keep `SKILL.md` under ~8 KB. Move long tables, API listings, and
worked examples into `references/`.

## Verification

Before opening a PR:

```
just validate    # portable skill lint
just check       # full validation (lint + nix + markdown + shellcheck)
```

`scripts/validate.py` ignores `staging/` — only catalogue skills under
`skills/` are linted.

## Evals

Eval-driven iteration on a skill — test cases, deterministic and
LLM-as-judge assertions, grading, train/validation splits, the
`trigger_rate` metric, and benchmark replay — is covered end-to-end by
[`evals/README.md`](../evals/README.md) and
[`docs/skills-spec-v3.md`](skills-spec-v3.md) §10. The harness reuses
hash-keyed VCR cassettes so CI replays without API keys.
_Source: https://agentskills.io/skill-creation/evaluating-skills, reviewed 2026-05-11_

## Scripts

Bundled helpers under `scripts/` are how a skill stays deterministic.
They run non-interactively, are introspectable via `--help`, and emit
machine-readable output. The rules below apply to every script shipped
with a skill.

### Language preference

For new scripts, pick the lowest-numbered language that fits the task:
1) Go, 2) TypeScript with a `#!/usr/bin/env -S bun run` shebang,
3) Python with full type hints (`mypy --strict` clean). Shell shebangs
and `nix run` wrappers under ~5 lines are exempt. The current inventory
and migration priorities live in
[`script-migrations.md`](script-migrations.md).

### No interactive prompts

Agents run scripts non-interactively. Never call `read`, `input()`, or
TTY prompts. Bail fast with a clear error to stderr when a required
flag or env var is missing.

### `--help` is the contract

Every script must support `--help` and document: one-line description,
every flag, every positional argument, expected env vars, exit codes,
and a worked example. Agents discover the interface through `--help`,
not by reading the source.

### Structured output

stdout is data; stderr is diagnostics. Prefer JSON or TSV over
whitespace-aligned tables — they survive `| jq` and `| cut` without
ad-hoc parsing.

### Helpful error messages

A good error says what went wrong, what was expected, and what to try
next. "missing --target" beats "error: 2". Include the offending value
when it is short and not a secret.

### Idempotency, dry-run, exit codes

Re-running a script with the same inputs must produce the same result.
Mutating scripts ship a `--dry-run` flag that prints the planned
actions. Use distinct exit codes per failure mode (e.g. 0 ok, 2 usage,
3 validation, 4 IO) and document them under `--help`.

### Inline deps

Pin runtime deps inside the script, not via a separate manifest:

- Bun (`#!/usr/bin/env -S bun run`) auto-installs `import` targets on
  first run.
- Go: `go run example.com/cmd@v1.2.3` resolves and caches.
- Typed Python (exemption): PEP 723 inline metadata block consumed by
  `uv run --script <file>`.

### Version pinning

Pin every external tool: `npx eslint@9.0.0`, `go run pkg@v0.28.0`,
`uv run --with ruff==0.6.9 -- ruff check`. Floating versions break
replay.

### When to bundle vs one-off

A tested script in `scripts/` beats inlining long commands in
`SKILL.md` — it is reviewable, version-pinned, and re-runnable.
One-off shell commands are fine when an existing tool already does
what you need and the call is short enough to read in place.

_Source: https://agentskills.io/skill-creation/using-scripts, reviewed 2026-05-11_

## Description triggering

The `description:` is how the routing layer decides whether to load the
skill. Write it in the imperative ("Use this skill when…") and focus
on the user's intent, not the implementation. Be explicit about every
applicable context — including ones the user is unlikely to name by
domain (e.g. "also when reviewing diffs, audits, and security
inspections", not just "when reviewing a PR"). The 1024-char hard cap
is enforced by `scripts/validate.py:32`; under-using it costs trigger
recall.

For measuring trigger quality, `evals/scripts/expand.py` produces a
`trigger_rate` metric per skill against a labelled set; see
`docs/skills-spec-v3.md` §10 for the surrounding harness.

_Source: https://agentskills.io/skill-creation/optimizing-descriptions, reviewed 2026-05-11_

## Patterns

Five recurring shapes show up in skills that work well. Pick the ones
that fit; do not force every skill through all five.

### Gotchas

Project-specific corrections the agent must see before triggering the
situation. Keep them in `SKILL.md`, not under `references/` — the
references are only read on demand.

```markdown
## Gotchas

- The `users` table uses soft-delete; filter `deleted_at IS NULL`.
- Account IDs differ between `billing` and `auth` services — never
  join across them by `id`.
- `/health` is liveness; readiness is `/ready`. Don't conflate.
```

### Templates for output format

When a skill has a fixed report shape, ship the template. Inline if
short; under `assets/<name>.md` if long. Reference it explicitly from
the body.

```markdown
## Output format

### Summary
<one paragraph>

### Findings
- [severity] <finding> — <file:line>

### Next actions
1. <action>
```

### Checklists for multi-step workflows

Use explicit `[ ]` boxes so the agent can track progress visibly
across steps.

```markdown
## Checklist

- [ ] Identify the form schema
- [ ] Extract field labels and types
- [ ] Map inputs to fields
- [ ] Fill the form
- [ ] Validate the filled form against the schema
```

### Validation loops

Pair every mutating step with a validator. The shape is do → validate
→ fix → re-run until clean.

```markdown
## Validation loop

1. Run the generator.
2. Run `scripts/validate.py` (or the skill's own validator).
3. If validation fails, read the diagnostics and fix.
4. Re-run from step 1 until validation passes.
```

### Plan-validate-execute

For risky or expensive work, separate planning from execution. The
agent emits a plan file, a validator script checks the plan against
ground truth, then a separate executor consumes the validated plan.

```markdown
## Plan-validate-execute

1. `scripts/analyze_form.py form.pdf > field_values.json`  # plan
2. `scripts/validate_fields.py field_values.json schema.json`  # check
3. `scripts/fill_form.py form.pdf field_values.json`  # execute
```

_Source: https://agentskills.io/skill-creation/best-practices, reviewed 2026-05-11_
