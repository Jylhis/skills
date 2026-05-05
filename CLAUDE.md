# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A flat catalogue of Agent Skills for Claude Code, plus one small Nix
module that symlinks the catalogue into `~/.claude/`.

- `skills/` — curated skills (one directory per skill, each with `SKILL.md`).
- `staging/` — legacy content awaiting review. Do **not** edit unless
  promoting a skill out of staging or removing it. Nothing in `staging/`
  is built or deployed.
- `modules/default.nix` — single Nix module covering Home Manager, NixOS,
  and nix-darwin. Detects context at eval time.
- `scripts/install.sh` — non-Nix install path (plain symlinks).
- `docs/upstream-sources.md` — list of upstream skill repos parked for
  later re-import. Not wired into the build.
- `docs/history/` — archived design documents (`PLAN.md`, `TODO.md`).

## Skill format

```markdown
---
name: <matches the directory basename>
description: When to trigger this skill (50–1024 chars).
---
# Markdown body
```

Optional sibling directories: `scripts/`, `references/`, `assets/`.

## Development workflow

All tools come from devenv. Enter the shell with `direnv allow` or
`devenv shell`.

```
just check    # nix-instantiate + nix flake check + statix + deadnix + markdownlint + shellcheck
just fmt      # nixfmt all .nix files
just build    # nix build (produces a derivation containing skills/)
just install  # symlink skills/ + CLAUDE.md into ~/.claude/
just list     # find skills -name SKILL.md
```

When `nix` is missing or a recipe needs an extra package, use an ad-hoc
devenv environment:

```
devenv -O packages:pkgs "ripgrep fd" shell -- rg pattern
```

## Repo conventions

- Single Nix module; no per-tool deployment logic. Multi-tool support
  was removed in v3 — see `docs/history/PLAN.md` for the dropped design.
- No `programs.jstack.*` options. The current namespace is `programs.skills`.
- No bundled upstream skill repos. To re-import, vendor selected
  `<skill>/SKILL.md` trees into `staging/` (or `skills/` directly), or
  add a purpose-built import path. The previous URL list lives in
  `docs/upstream-sources.md`.
- No generated `settings.json`, `.mcp.json`, or `.lsp.json` in this repo.
  Configure those in your Claude Code config directly.
