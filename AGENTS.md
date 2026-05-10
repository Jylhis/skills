# AGENTS.md

Always-loaded project context for AI coding agents (Claude Code, Codex,
Gemini CLI, etc.). Tool-specific wrappers (`CLAUDE.md`, `GEMINI.md`)
extend this file via their respective import mechanisms.

## What this repo is

A curated [Agent Skills](https://agentskills.io) catalogue packaged as the
`jylhis-skills` plugin for Claude Code, Gemini CLI, and Codex. See
`docs/install.md` for install instructions.

## Layout

- `skills/` — published catalogue. One **umbrella** skill per category
  (`skills/<category>/<category>/SKILL.md`) with sub-topic guidance
  under that umbrella's `references/` directory. Standalone tool
  skills (e.g. `unix/ast-grep`, `unix/offline-docs`) live at
  `skills/<category>/<name>/SKILL.md`.
- `dev-skills/` — repo-only meta skills (`skill-creator-lang`,
  `upstream-tracker`, `using-skills`). **Not** shipped via the plugin;
  exposed project-locally through `.claude/skills/<name>` symlinks.
- `staging/` — legacy content awaiting per-skill review. Do not edit
  unless promoting an item out of staging or removing it.
- `upstream/sources.yaml` — manifest of tracked upstream skill repos
  (rev pin, review cursor, license, import paths). Created on first
  adoption; absent until then.
- `upstream/decisions/<id>.log` — per-source append-only review log
  (one row per upstream commit decided via `upstream-tracker`).
- `.claude-plugin/plugin.json` — Claude Code plugin manifest; lists every skill path explicitly.
- `.lsp.json` — Claude-only: native LSP server registrations (one per language with a skill). Lazily launched via `nix shell nixpkgs#<pkg> -c <lsp>`.
- `agents/` — Claude-only: shipped subagents (`reviewer`, `explorer`, `debugger`).
- `commands/` — Claude-only: slash commands (`/explore`, `/lsp-status`).
- `.codex-plugin/plugin.json` — Codex plugin manifest; loads `skills/` recursively.
- `.agents/plugins/marketplace.json` — Codex local marketplace entry for this plugin.
- `gemini-extension.json` — Gemini CLI extension manifest.
- `scripts/install.sh` — registers local marketplaces for Claude Code and Codex, and symlinks Gemini.
- `scripts/validate.py` — portable skill frontmatter lint (two-level paths);
  also runs an advisory `--strict-upstream` pass when `upstream/sources.yaml`
  exists.
- `docs/install.md` — consumer-facing install guide.
- `docs/skill-authoring-guide.md` — how to write a portable SKILL.md.
- `docs/skills-spec-v3.md` — target architecture spec we are growing toward.
- `docs/upstream-sources.md` — list of upstream skill repos parked for later re-import.
- `docs/history/` — archived design docs.
- `evals/` — eval scaffolding (currently empty; see `evals/README.md`).

For the workflow that operates on `upstream/`, see the
`upstream-tracker` skill in `dev-skills/` (project-local).

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
just check    # shellcheck + validate.py
just install  # symlink repo root as plugin into each tool's plugin directory
just list     # find skills -name SKILL.md
just validate # portable skill lint only
```

Ad-hoc devenv environment when a recipe needs an extra package:

```
devenv -O packages:pkgs "ripgrep fd" shell -- rg pattern
```

## Claude runtime layer

Claude Code reads four kinds of plugin artefact directly from this repo
root. Codex's recursive scan is scoped to `./skills/` and Gemini's
extension only declares `contextFileName`, so these files are inert in
the other tools — no separate exclusion is needed.

- `.lsp.json` — native LSP plugin format (Claude Code spawns each entry
  on demand for matching file extensions). One entry per language with
  a skill: `nix`, `python`, `go`. Each
  uses `nix shell nixpkgs#<server> -c <binary>` so the host needs Nix
  but no pre-installed LSP. To add a language, append an entry mapping
  extensions → language id.
- `agents/<name>.md` — read-only subagents callable as `@reviewer`,
  `@explorer`, `@debugger`. Frontmatter is `name` + `description` only;
  per the plugin reference, plugin-shipped agents may not declare
  `mcpServers`, `hooks`, or `permissionMode`.
- `commands/<name>.md` — slash commands (`/explore`, `/lsp-status`).
  Plain markdown with optional `description`, `argument-hint`,
  `allowed-tools` frontmatter. The body is the prompt; `$ARGUMENTS`
  receives the user's command line.
- `.mcp.json` is intentionally absent — the LSP work that would
  otherwise need an MCP bridge (e.g. `mcp-language-server`) is handled
  natively by Claude Code's `.lsp.json` integration.

`scripts/validate.py` only globs `skills/*/*/SKILL.md`, so these
Claude-only files do not need to be excluded explicitly.

## Repo conventions

- The repo root is the plugin. Tool manifests (`.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json`, `gemini-extension.json`) live at the root.
- Skills are two levels deep: `skills/<category>/<name>/SKILL.md`.
- The published catalogue uses an **umbrella per category**:
  `skills/<category>/<category>/SKILL.md` is the entry point, deeper
  guidance lives under `references/<topic>.md` (and nested
  `references/<topic>/...md` for multi-file topics).
- When promoting a skill, add its path to `.claude-plugin/plugin.json`'s `skills` array.
  Codex discovers skills recursively from `skills/`.
- Meta / repo-maintenance skills go in `dev-skills/` (not under
  `skills/`), so they ship neither via the Claude plugin manifest nor
  the Codex recursive scan.
- Skill runtime dependencies use `nix run` shebangs in `scripts/` or MCP/LSP
  config — not in `devenv.nix`.
- No bundled upstream skill repos. To re-import, vendor selected
  `<skill>/SKILL.md` trees into `staging/` then promote individually.
  The previous URL list lives in `docs/upstream-sources.md`.
- Portable skills must pass `scripts/validate.py`. Run on every commit.
