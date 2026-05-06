# AGENTS.md

Always-loaded project context for AI coding agents (Claude Code, Codex,
Gemini CLI, etc.). Tool-specific wrappers (`CLAUDE.md`, `GEMINI.md`)
extend this file via their respective import mechanisms.

## What this repo is

A flat catalogue of [Agent Skills](https://agentskills.io) plus one
small Nix module that symlinks the catalogue into `~/.claude/`. See
`README.md` for the consumer-facing description.

## Layout

- `skills/` — curated skills (one directory per skill, each with `SKILL.md`).
- `staging/` — legacy content awaiting per-skill review. Do not edit
  unless promoting an item out of staging or removing it. Nothing here
  is built or deployed.
- `modules/default.nix` — single Nix module covering Home Manager,
  NixOS, and nix-darwin. Detects context at eval time.
- `scripts/install.sh` — non-Nix install path (plain symlinks).
- `scripts/validate.py` — portable skill frontmatter lint.
- `docs/upstream-sources.md` — list of upstream skill repos parked for
  later re-import. Not wired into the build.
- `docs/skills-spec-v3.md` — target architecture spec we are growing
  toward. Not all sections are implemented.
- `docs/skill-authoring-guide.md` — how to write a portable SKILL.md.
- `docs/history/` — archived design docs (`PLAN.md`, `TODO.md`).
- `evals/` — eval scaffolding (currently empty; see `evals/README.md`).

## Skill format

A skill is a directory under `skills/` containing a `SKILL.md` with YAML
frontmatter:

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
`!\`...\``). Skills that need target-specific behavior live under
`target-skills/<target>/<name>/` (not yet populated).

## Development workflow

All tools come from devenv. Enter the shell with `direnv allow` or
`devenv shell`.

```
just check    # nix-instantiate + nix flake check + statix + deadnix + markdownlint + shellcheck + validate.py
just fmt      # nixfmt all .nix files
just build    # nix build (produces a derivation containing skills/)
just install  # symlink skills/ + AGENTS.md + CLAUDE.md into ~/.claude/
just list     # find skills -name SKILL.md
just validate # portable skill lint only
```

Ad-hoc devenv environment when a recipe needs an extra package:

```
devenv -O packages:pkgs "ripgrep fd" shell -- rg pattern
```

## Repo conventions

- Single Nix module; no per-tool deployment logic. The previous
  multi-tool design is parked in `docs/history/PLAN.md`.
- Module option namespace: `programs.skills` (not `programs.jstack`).
- No bundled upstream skill repos. To re-import, vendor selected
  `<skill>/SKILL.md` trees into `staging/` (or `skills/` directly).
  The previous URL list lives in `docs/upstream-sources.md`.
- No generated `settings.json`, `.mcp.json`, or `.lsp.json` in this
  repo. Configure those in your tool config directly.
- Portable skills must pass `scripts/validate.py`. Run on every commit.
