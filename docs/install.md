# Install jylhis-skills

A curated [Agent Skills](https://agentskills.io) **marketplace** that publishes
one default plugin (`jylhis-skills-core`) and several opt-in plugins. Supported
targets: **Claude Code** (CLI + Claude Code on the web), **Pi**
(`pi-coding-agent`), and **claude.ai Skills** (per-skill `.zip` upload).

## Quick install

```bash
just install
# without just:
bash scripts/install.sh
```

Both run the same script; `just install` is the devenv-shell shortcut.

Idempotent; backs up anything it would overwrite under `~/.skills-backup-<ts>/`.
Pass `--dry-run` to preview. Installs the default plugin only — opt-in plugins
are registered with the marketplace and surface in each tool's UI but are not
installed automatically.

## What the script does

| Tool | Mechanism | Where |
|---|---|---|
| Claude Code (CLI + web) | local marketplace + `plugin install jylhis-skills-core@jylhis-skills` | `~/.claude/plugins/known_marketplaces.json` + `installed_plugins.json` |
| Pi (`pi-coding-agent`) | mirror default plugin's skills + link `AGENTS.md` | `~/.pi/agent/skills/jylhis-skills-core/` + `~/.pi/agent/AGENTS.md` |

For Claude Code the script registers this repo as a local marketplace and
installs the `jylhis-skills-core` plugin. If the `claude` CLI is not on
`PATH`, run these manually inside Claude Code instead:

```
/plugin marketplace add <path-to-this-repo>
/plugin install jylhis-skills-core@jylhis-skills
```

### Install scope (user vs project)

`claude plugin install` records enablement in a `settings.json` file.
The script picks a scope automatically:

- **user** (default) — writes to `~/.claude/settings.json`; the plugin is
  enabled in every directory.
- **project** — writes to `<repo>/.claude/settings.json`; the plugin is
  enabled only when running Claude inside this repo. Auto-selected if
  `~/.claude/settings.json` is read-only (e.g. managed by Nix
  home-manager). Override with `CLAUDE_PLUGIN_SCOPE=project bash scripts/install.sh`.

Claude Code also gets direct context links so `@AGENTS.md` resolves:

```
~/.claude/AGENTS.md  →  AGENTS.md
~/.claude/CLAUDE.md  →  CLAUDE.md
```

### Claude Code on the web

Claude Code on the web (code.claude.com sessions) uses the **same** plugin
marketplace as the CLI, so no separate step is needed — install the marketplace
once and web sessions pick up `jylhis-skills-core`.

### Pi (`pi-coding-agent`)

Pi reads `~/.pi/agent/AGENTS.md` for project context and auto-discovers
`SKILL.md` files under `~/.pi/agent/skills/`. The install script mirrors the
default plugin's skills there (real files, symlinks flattened) and links
`AGENTS.md`. If the `pi` CLI is not on `PATH`, install it first:

```bash
npm install -g @earendil-works/pi-coding-agent
# or: curl -fsSL https://pi.dev/install.sh | sh
```

then re-run `just install` (or `bash scripts/install.sh`). Override the agent dir with
`PI_AGENT_DIR=… bash scripts/install.sh`.

### claude.ai Skills

For the claude.ai chat app, package skills into per-skill `.zip` archives and
upload them via **Settings → Capabilities → Skills**:

```bash
just package          # writes dist/skills/<name>.zip
```

Each archive is self-contained (`SKILL.md` + `scripts/`/`references/`/`assets/`).

## Opt-in plugins

The marketplace publishes these language and tool plugins; none are installed
by default.

| Plugin | Adds |
|---|---|
| `jylhis-python` | Python skill + `basedpyright` LSP |
| `jylhis-typescript` | TypeScript skill + `typescript-language-server` LSP |
| `jylhis-go` | Go skill + `gopls` LSP |
| `jylhis-rust` | Rust + Leptos skills + `rust-analyzer` LSP |
| `jylhis-jvm` | Java/Kotlin skill |
| `jylhis-emacs` | Emacs Lisp skill |
| `jylhis-nix` | Nix skill + `nixd` LSP |
| `jylhis-filesystems` | DuckDB / filesystem tooling skill |
| `jylhis-gitlab` | GitLab push + MR-create skill |
| `jylhis-terraform` | Terraform skill |
| `jylhis-azure` | Azure cloud skill |
| `jylhis-obsidian` | Obsidian note-taking and knowledge management skill |
| `jylhis-grafana` | Grafana observability skill |
| `jylhis-taste` | UI/UX design taste and critique skill |
| `jylhis-duckdb` | DuckDB query / attach / spatial skill set |

Install one (example: `jylhis-python`):

| Tool | Command |
|---|---|
| Claude Code | `/plugin install jylhis-python@jylhis-skills` |
| Pi | run `just install` (or `bash scripts/install.sh`); the installer mirrors each installed plugin's symlinked skills into `~/.pi/agent/skills/` |
| claude.ai | `just package jylhis-python` is not a unit; package individual skills (`just package <name>`) and upload the `.zip` |

## Development

Load the marketplace without installing:

```bash
# Claude Code
claude --plugin-dir ./
```

All dev tools come from devenv:

```bash
direnv allow       # or: devenv shell
just               # list recipes
just check         # shellcheck + validate
just validate      # portable skill lint only
just list          # list all SKILL.md files
```

## Contributing

To add a skill:

1. Create `skills/<category>/<name>/SKILL.md` with two-field YAML frontmatter
   (`name`, `description`). Categories: `engineering`, `languages`,
   `domains`, `services`, `stack`, `productivity`, `personal`, `misc`.
2. Decide which plugin owns it. For a brand-new plugin, create
   `plugins/jylhis-<plugin>/` with `.claude-plugin/plugin.json`, plus a
   `skills/<name>` symlink with relative target
   `../../../skills/<category>/<name>`.
3. Add the plugin to `.claude-plugin/marketplace.json`.
4. Run `just validate` — the cross-check enforces that every on-disk skill is
   referenced by exactly one plugin manifest.

See `docs/skill-authoring-guide.md` for the portability profile and the
rejected target-specific frontmatter fields.
