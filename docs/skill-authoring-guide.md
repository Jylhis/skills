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
