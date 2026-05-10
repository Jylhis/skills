# AGENTS.md

Always-loaded project context for AI coding agents (Claude Code, Codex,
Gemini CLI, etc.). Tool-specific wrappers (`CLAUDE.md`, `GEMINI.md`)
extend this file via their respective import mechanisms.

## What this repo is

A curated [Agent Skills](https://agentskills.io) **marketplace** by Jylhis
that publishes one default plugin and several opt-in plugins to Claude Code,
Gemini CLI, and Codex. The default plugin (`jylhis-skills-core`) ships
cross-cutting skills (security, ast-grep, offline-docs) plus the shipped
subagents and slash commands. Per-language and per-tool plugins
(`jylhis-python`, `jylhis-typescript`, `jylhis-go`, `jylhis-jvm`,
`jylhis-emacs`, `jylhis-nix`, `jylhis-filesystems`, `jylhis-gitlab`) are
discoverable through the marketplace UI but installed only when the user
opts in. See `docs/install.md` for install instructions.

## Layout

- `skills/` — canonical SKILL.md tree, source of truth. One **umbrella**
  skill per category (`skills/<category>/<category>/SKILL.md`) with sub-topic
  guidance under that umbrella's `references/` directory. Standalone tool
  skills (e.g. `unix/ast-grep`, `unix/offline-docs`) live at
  `skills/<category>/<name>/SKILL.md`. Skill files are NEVER moved out of
  this tree.
- `plugins/<plugin-name>/` — one directory per published plugin, each
  containing its own `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
  `gemini-extension.json`, and a `skills/` directory of symlinks pointing
  back into `skills/<category>/<name>`. The default plugin
  `plugins/jylhis-skills-core/` additionally ships `agents/`, `commands/`,
  `.lsp.json`, and `GEMINI.md`.
- `dev-skills/` — repo-only meta skills (`skill-creator-lang`,
  `upstream-tracker`, `using-skills`). **Not** shipped via any plugin;
  exposed project-locally through `.claude/skills/<name>` symlinks.
- `staging/` — legacy content awaiting per-skill review. Do not edit
  unless promoting an item out of staging or removing it.
- `upstream/sources.yaml` — manifest of tracked upstream skill repos
  (rev pin, review cursor, license, import paths). Created on first
  adoption; absent until then.
- `upstream/decisions/<id>.log` — per-source append-only review log
  (one row per upstream commit decided via `upstream-tracker`).
- `.claude-plugin/marketplace.json` — Claude Code marketplace manifest;
  lists every plugin under `plugins/` (default + opt-in).
- `.agents/plugins/marketplace.json` — Codex local marketplace; mirrors the
  Claude listing and uses `policy.installation` to mark the default
  vs opt-in plugins.
- `scripts/install.sh` — registers the marketplace in each tool and installs
  ONLY the default plugin. Prints opt-in commands for the rest.
- `scripts/validate.py` — portable skill frontmatter lint (two-level paths);
  also runs an advisory `--strict-upstream` pass when `upstream/sources.yaml`
  exists.
- `docs/install.md` — consumer-facing install guide.
- `docs/skill-authoring-guide.md` — how to write a portable SKILL.md.
- `docs/skills-spec-v3.md` — target architecture spec we are growing toward.
- `docs/upstream-sources.md` — list of upstream skill repos parked for later re-import.
- `docs/history/` — archived design docs.
- `evals/` — offline eval harness (no API keys). `cases.yaml` per
  suite under `evals/suites/<suite>/`, deterministic-first assertions
  driven through `promptfoo` `exec:` providers, cross-vendor
  LLM-as-a-judge layer, hash-keyed VCR cassettes for CI replay. See
  `evals/README.md` for recipes and the spec-v3 §10 mapping.

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
just install  # register marketplace in each tool, install jylhis-skills-core only
just list     # find skills -name SKILL.md
just validate # portable skill lint + plugin-manifest cross-check
```

## Installing opt-in plugins

`just install` only deploys `jylhis-skills-core`. To pull in a language or
tool plugin from the same marketplace:

| Tool        | Command                                                                |
|-------------|------------------------------------------------------------------------|
| Claude Code | `/plugin install jylhis-python@jylhis-skills`                          |
| Codex       | `codex plugin install jylhis-python@jylhis-skills` (then enable in `~/.codex/config.toml`) |
| Gemini CLI  | `ln -s <repo>/plugins/jylhis-python ~/.gemini/extensions/jylhis-python` |

Available opt-in plugins: `jylhis-python`, `jylhis-typescript`, `jylhis-go`,
`jylhis-jvm`, `jylhis-emacs`, `jylhis-nix`, `jylhis-filesystems`,
`jylhis-gitlab`.

Ad-hoc devenv environment when a recipe needs an extra package:

```
devenv -O packages:pkgs "ripgrep fd" shell -- rg pattern
```

## Claude runtime layer

Four Claude-only plugin artefacts ship inside the default plugin directory
(`plugins/jylhis-skills-core/`), not at the repo root. Codex's recursive
scan stays scoped to each plugin's local `./skills/` and Gemini's extension
only declares `contextFileName`, so these files are inert in the other
tools — no separate exclusion is needed.

- `plugins/jylhis-skills-core/.lsp.json` — native LSP plugin format (Claude
  Code spawns each entry on demand for matching file extensions). One entry
  per language with a published plugin: `nix`, `python`, `typescript`, `go`.
  Each uses `nix shell nixpkgs#<server> -c <binary>` so the host needs Nix
  but no pre-installed LSP. The LSPs ship with core today; splitting them
  per language plugin is a follow-up.
- `plugins/jylhis-skills-core/agents/<name>.md` — read-only subagents
  callable as `@reviewer`, `@explorer`, `@debugger`. Frontmatter is
  `name` + `description` only; per the plugin reference, plugin-shipped
  agents may not declare `mcpServers`, `hooks`, or `permissionMode`.
- `plugins/jylhis-skills-core/commands/<name>.md` — slash commands
  (`/explore`, `/lsp-status`). Plain markdown with optional `description`,
  `argument-hint`, `allowed-tools` frontmatter. The body is the prompt;
  `$ARGUMENTS` receives the user's command line.
- `.mcp.json` is intentionally absent — the LSP work that would
  otherwise need an MCP bridge (e.g. `mcp-language-server`) is handled
  natively by Claude Code's `.lsp.json` integration.

`scripts/validate.py` only globs `skills/*/*/SKILL.md`, so these
Claude-only files do not need to be excluded explicitly.

## Repo conventions

- The repo root is the **marketplace**, not a plugin. The default plugin is
  `plugins/jylhis-skills-core/`; opt-in plugins are siblings under `plugins/`.
- Each `plugins/<name>/` directory contains its own `.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json`, and `gemini-extension.json`. Skills are not
  copied — each plugin has a `skills/` directory of symlinks pointing into
  the canonical `skills/<category>/<name>/` source tree.
- Skills are two levels deep on disk: `skills/<category>/<name>/SKILL.md`.
- The published catalogue uses an **umbrella per category**:
  `skills/<category>/<category>/SKILL.md` is the entry point, deeper
  guidance lives under `references/<topic>.md` (and nested
  `references/<topic>/...md` for multi-file topics).
- When **adding a new skill**: drop it under `skills/<category>/<name>/`,
  create or extend a `plugins/jylhis-<name>/` directory with the three
  per-tool manifests and a `skills/<name>` symlink, and add the plugin to
  `.claude-plugin/marketplace.json` (and `.agents/plugins/marketplace.json`
  for Codex). `scripts/validate.py` enforces that every on-disk skill is
  referenced by exactly one plugin manifest.
- Codex discovers skills recursively from each plugin's local `skills/`.
- Meta / repo-maintenance skills go in `dev-skills/` (not under
  `skills/`), so they ship neither via the Claude plugin manifest nor
  the Codex recursive scan.
- Skill runtime dependencies use `nix run` shebangs in `scripts/` or MCP/LSP
  config — not in `devenv.nix`.
- No bundled upstream skill repos. To re-import, vendor selected
  `<skill>/SKILL.md` trees into `staging/` then promote individually.
  The previous URL list lives in `docs/upstream-sources.md`.
- Portable skills must pass `scripts/validate.py`. Run on every commit.
