# AGENTS.md

Always-loaded project context for AI coding agents (Claude Code, Pi,
etc.). The tool-specific wrapper `CLAUDE.md` extends this file via Claude
Code's import mechanism.

## What this repo is

A curated [Agent Skills](https://agentskills.io) **marketplace** by Jylhis
that publishes one default plugin and several opt-in plugins. Supported
targets are **Claude Code** (CLI and Claude Code on the web — same plugin
marketplace), **Pi** (`pi-coding-agent`), and **claude.ai Skills** (per-skill
`.zip` upload). The default plugin (`jylhis-skills-core`) ships
cross-cutting engineering and productivity skills (security, ast-grep,
semgrep, tdd, diagnose, triage, handoff, humanizer, and more) plus the
shipped subagents and plugin-local command skills (invoked as
`/jylhis-skills-core:<name>`).
Per-language, per-service, and per-tool plugins (`jylhis-python`,
`jylhis-go`, `jylhis-nix`, `jylhis-gitlab`, `jylhis-obsidian`, and ten
more) are discoverable through the marketplace UI but installed only when
the user opts in. `docs/install.md` has the full plugin roster and install
instructions.

## Layout

- `skills/` — canonical SKILL.md tree, source of truth. Skills live at
  `skills/<category>/<name>/SKILL.md`. The eight categories are
  `engineering` (practices and workflows), `languages` (per-language
  guidance), `domains` (cross-cutting topic deep dives), `services`
  (specific named platforms and ecosystems), `stack` (deep dives on
  specific named technologies), `productivity`, `personal` (Obsidian and
  knowledge-management workflows), and `misc` (uncategorised).
  Umbrella-style skills carry sub-topic guidance under the skill's
  `references/` directory. Skill files are NEVER moved out of this tree.
- `plugins/<plugin-name>/` — one directory per published plugin, each
  containing its own `.claude-plugin/plugin.json` and a `skills/` directory
  of symlinks pointing back into `skills/<category>/<name>`. The default
  plugin `plugins/jylhis-skills-core/` additionally ships `agents/` and
  plugin-local Claude-only skills; language plugins ship a per-language
  `.lsp.json` (see Claude runtime layer below).
- `meta/` — repo-only meta skills (`skill-creator-lang`, `skill-improver`,
  `upstream-tracker`, `using-skills`, `skill-extractor`). **Not** shipped
  via any plugin and not auto-loaded by any tool; only relevant when
  developing skills inside this repo.
- `upstream/sources.yaml` — manifest of tracked upstream skill repos
  (rev pin, review cursor, license, import paths); absent until first
  adoption. `upstream/decisions/<id>.log` — per-source append-only review
  log. The workflow that operates on both is the `upstream-tracker` skill
  in `meta/`.
- `.claude-plugin/marketplace.json` — Claude Code marketplace manifest
  listing every plugin under `plugins/` (default + opt-in); used by both
  the Claude Code CLI and Claude Code on the web.
- `scripts/install.sh` — registers the Claude Code marketplace and installs
  ONLY the default plugin; mirrors the default plugin's skills into Pi
  (`~/.pi/agent/skills/`) and links `AGENTS.md`. Prints opt-in commands for
  the rest.
- `scripts/validate.py` — portable skill frontmatter lint (two-level paths);
  also runs an advisory `--strict-upstream` pass when `upstream/sources.yaml`
  exists.
- `docs/` — `install.md` (consumer install guide), `skill-authoring-guide.md`
  (how to write a portable SKILL.md), `script-migrations.md` (script-language
  migration plan), `skills-organization-review.md` (taxonomy review notes),
  `skills-spec-v4.md` (current target architecture spec; supersedes
  `skills-spec-v3.md`, kept for history), `upstream-sources.md` (upstream
  repos parked for later re-import).
- `evals/` — offline eval harness (no API keys). `cases.yaml` lives next
  to the skill it exercises at `skills/<category>/<name>/evals/`;
  deterministic-first assertions via `promptfoo` `exec:` providers.
  See `evals/README.md` for recipes.

## Skill format

Skills live at `skills/<category>/<name>/SKILL.md` with YAML frontmatter
requiring `name` (matches the directory basename) and `description` (when
to trigger, 50-1024 chars). Optional siblings: `scripts/`, `references/`,
`assets/`. The portable lint (`scripts/validate.py`) rejects
target-specific frontmatter fields and tool-specific path variables;
`docs/skill-authoring-guide.md` covers the full contract, including
optional fields and the rejected-fields list.

## Development workflow

All tools come from devenv. Enter the shell with `direnv allow` or
`devenv shell`.

```
just check    # shellcheck + validate.py
just install  # register marketplace in each tool, install jylhis-skills-core only
just list     # find skills -name SKILL.md
just validate # portable skill lint + plugin-manifest cross-check
```

`just install` deploys only the default plugin; `docs/install.md` has the
per-tool commands for installing opt-in plugins.

Ad-hoc devenv environment when a recipe needs an extra package:

```
devenv -O packages:pkgs "ripgrep fd" shell -- rg pattern
```

## Claude runtime layer

Claude-only plugin artefacts ship inside per-plugin directories, not at the
repo root. Pi discovers skills by scanning for `SKILL.md` and ignores the
non-skill artefacts (`agents/`, `commands/`, `.lsp.json`, `.mcp.json`);
`install.sh` mirrors only each plugin's `skills/` into `~/.pi/agent/skills/`,
so these files never reach Pi. claude.ai Skills are skills-only too — they
carry none of this layer.

- `plugins/jylhis-<lang>/.lsp.json` — native LSP plugin format (Claude
  Code spawns each entry on demand for matching file extensions). One file
  per language plugin: `jylhis-nix` registers `nixd`, `jylhis-python`
  registers `basedpyright`, `jylhis-typescript` registers
  `typescript-language-server`, `jylhis-go` registers `gopls`,
  `jylhis-rust` registers `rust-analyzer`. Each uses
  `nix shell nixpkgs#<server> -c <binary>` so the host needs Nix but no
  pre-installed LSP. Installing a language plugin wires its LSP; not
  installing it leaves Claude Code unaware of that language.
- `plugins/jylhis-skills-core/agents/<name>.md` — read-only subagents
  callable as `@reviewer`, `@explorer`, `@debugger`. Frontmatter is
  `name` + `description` only; per the plugin reference, plugin-shipped
  agents may not declare `mcpServers`, `hooks`, or `permissionMode`.
- `plugins/jylhis-skills-core/commands/<name>.md` — slash commands
  (`/explore`, `/lsp-status`, `/remember-correction`). Plain markdown with
  optional `description`, `argument-hint`, `allowed-tools` frontmatter.
  The body is the prompt; `$ARGUMENTS` receives the user's command line.
  `/lsp-status` discovers every installed language plugin's `.lsp.json` at
  runtime, so it reflects only the LSPs the user has opted into.
  `/remember-correction` appends to the improvement-memory JSONL via
  `go run "${CLAUDE_PLUGIN_ROOT}/scripts/append-correction.go" --json -`.
- `.mcp.json` is intentionally absent — the LSP work that would
  otherwise need an MCP bridge (e.g. `mcp-language-server`) is handled
  natively by Claude Code's `.lsp.json` integration.

`scripts/validate.py` only validates `SKILL.md` files under `skills/` and
enforces the published `skills/<category>/<name>/SKILL.md` layout, so these
Claude-only files do not need to be excluded explicitly.

## Repo conventions

- The repo root is the **marketplace**, not a plugin. The default plugin is
  `plugins/jylhis-skills-core/`; opt-in plugins are siblings under `plugins/`.
- Each `plugins/<name>/` directory contains its own `.claude-plugin/plugin.json`.
  Skills are not copied — each plugin has a `skills/` directory of symlinks
  pointing into the canonical `skills/<category>/<name>/` source tree.
- Skills are two levels deep on disk, `skills/<category>/<name>/SKILL.md`,
  using the eight categories listed under Layout. An umbrella skill (one
  that gathers sub-topics) keeps those under its own `references/<topic>.md`
  (and nested `references/<topic>/...md` for multi-file topics).
- When **adding a new skill**: drop it under `skills/<category>/<name>/`,
  create or extend a `plugins/jylhis-<plugin>/` directory with its
  `.claude-plugin/plugin.json` manifest and a `skills/<name>` symlink
  (relative target `../../../skills/<category>/<name>`), and add the plugin to
  `.claude-plugin/marketplace.json`. `scripts/validate.py` enforces that every
  on-disk skill is referenced by exactly one plugin manifest.
- Pi discovers skills recursively from `~/.pi/agent/skills/`, into which
  `install.sh` mirrors each installed plugin's `skills/` tree.
- Meta / repo-maintenance skills go in `meta/` (not under `skills/`), so
  they ship neither via the Claude plugin manifest nor the Pi skills mirror.
- Skill runtime dependencies use `nix run` shebangs in `scripts/` or MCP/LSP
  config — not in `devenv.nix`.
- No bundled upstream skill repos. Adoption flows through
  `meta/upstream-tracker/`. The parked URL list lives in
  `docs/upstream-sources.md`.
- Portable skills must pass `scripts/validate.py`. A PreToolUse hook in
  `.claude/settings.json` enforces this where that hook is configured; in
  any case run it on every commit.

### Script language preference

For new scripts, pick the lowest-numbered language that fits the task:

1. **Go** — single static binary, simplest distribution, fewest runtime
   surprises.
2. **TypeScript with Bun** — `#!/usr/bin/env -S bun run` shebang, fast
   startup, inline deps via Bun auto-install. Use when an ecosystem is
   strongly TS-shaped.
3. **Python with full type hints** — `mypy --strict` clean. Last resort,
   when ecosystem libraries (e.g. PyYAML, jsonschema) make rewriting
   prohibitive.

Exemption: shell shebangs and `nix run` wrappers under ~5 lines may stay
shell. `scripts/validate.py` emits advisory warnings on other `.sh` and
untyped `.py` files under the repo's `scripts/` directories; promote to an
error with `--strict-scripts`. Migration plan: `docs/script-migrations.md`.

### Recording corrections

When a user corrects skill-related behaviour, append one entry to the
host-private improvement-memory JSONL at
`${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl`
using `go run scripts/append-correction.go --json -` (one JSON object on
stdin; also reachable via `/remember-correction <note>`). It is scoped to
skill iteration (the `skill-improver` meta-skill reads it), not a general
scratchpad. Schema reference: `meta/skill-improver/references/schema.md`.
