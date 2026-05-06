# AGENTS.md

Always-loaded project context for AI coding agents (Claude Code, Codex,
Gemini CLI, etc.). Tool-specific wrappers (`CLAUDE.md`, `GEMINI.md`)
extend this file via their respective import mechanisms.

## What this repo is

A curated [Agent Skills](https://agentskills.io) catalogue packaged as the
`jylhis-skills` plugin for Claude Code, Gemini CLI, and Codex. See
`docs/install.md` for install instructions.

## Layout

- `skills/` — curated skills (`skills/<category>/<name>/SKILL.md`).
- `staging/` — legacy content awaiting per-skill review. Do not edit
  unless promoting an item out of staging or removing it.
- `.claude-plugin/plugin.json` — Claude Code plugin manifest; lists every skill path explicitly.
- `gemini-extension.json` — Gemini CLI extension manifest.
- `scripts/install.sh` — symlinks the repo root into each tool's plugin directory.
- `scripts/validate.py` — portable skill frontmatter lint (two-level paths).
- `docs/install.md` — consumer-facing install guide.
- `docs/skill-authoring-guide.md` — how to write a portable SKILL.md.
- `docs/skills-spec-v3.md` — target architecture spec we are growing toward.
- `docs/upstream-sources.md` — list of upstream skill repos parked for later re-import.
- `docs/history/` — archived design docs.
- `evals/` — eval scaffolding (currently empty; see `evals/README.md`).

## Skill format

Skills live at `skills/<category>/<name>/SKILL.md` with YAML frontmatter:

```markdown
---
name: <matches the directory basename>
description: When to trigger this skill (50–1024 chars).
---
# Markdown body
```

Optional siblings: `scripts/`, `references/`, `assets/`.

The portable lint (`scripts/validate.py`) rejects target-specific
frontmatter fields (`allowed-tools`, `tools`, `model`, etc.) and tool-
specific path variables (`${CLAUDE_PLUGIN_ROOT}`, `${extensionPath}`,
`!\`...\``).

## Development workflow

All tools come from devenv. Enter the shell with `direnv allow` or
`devenv shell`.

```
just check    # markdownlint + shellcheck + validate.py
just install  # symlink repo root as plugin into each tool's plugin directory
just list     # find skills -name SKILL.md
just validate # portable skill lint only
```

Ad-hoc devenv environment when a recipe needs an extra package:

```
devenv -O packages:pkgs "ripgrep fd" shell -- rg pattern
```

## Repo conventions

- The repo root is the plugin. All three tool manifests (`.claude-plugin/plugin.json`,
  `gemini-extension.json`) live at the root.
- Skills are two levels deep: `skills/<category>/<name>/SKILL.md`.
- When promoting a skill, add its path to `.claude-plugin/plugin.json`'s `skills` array.
- Skill runtime dependencies use `nix run` shebangs in `scripts/` or MCP/LSP
  config — not in `devenv.nix`.
- No bundled upstream skill repos. To re-import, vendor selected
  `<skill>/SKILL.md` trees into `staging/` then promote individually.
  The previous URL list lives in `docs/upstream-sources.md`.
- Portable skills must pass `scripts/validate.py`. Run on every commit.
