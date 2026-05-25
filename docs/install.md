# Install jylhis-skills

A curated [Agent Skills](https://agentskills.io) **marketplace** that publishes
one default plugin (`jylhis-skills-core`) and several opt-in plugins to Claude
Code, Codex, and Google Antigravity.

## Quick install

```bash
bash scripts/install.sh
```

Idempotent; backs up anything it would overwrite under `~/.skills-backup-<ts>/`.
Pass `--dry-run` to preview. Installs the default plugin only — opt-in plugins
are registered with the marketplace and surface in each tool's UI but are not
installed automatically.

## What the script does

| Tool | Mechanism | Where |
|---|---|---|
| Claude Code | local marketplace + `plugin install jylhis-skills-core@jylhis-skills` | `~/.claude/plugins/known_marketplaces.json` + `installed_plugins.json` |
| Antigravity | per-skill symlinks (one per skill in the default plugin) | `~/.gemini/antigravity/skills/<skill-name>` → `plugins/jylhis-skills-core/skills/<skill-name>` |
| Codex | local marketplace + enabled default plugin in config | `~/.codex/config.toml` + plugin cache under `~/.codex/plugins/cache/jylhis-skills/jylhis-skills-core` |

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

The Codex flow registers `.agents/plugins/marketplace.json` as a local
marketplace and enables `jylhis-skills-core@jylhis-skills` in
`~/.codex/config.toml`. Older raw symlinks at `~/.codex/plugins/jylhis-skills`
and the pre-split monolithic plugin install are migrated aside on first run.

## Nix users

This repo also ships a `flake.nix` with a custom `aiTooling` output that exposes
every skill, agent, slash command, MCP server, LSP server, and plugin as a
structured Nix attribute. Downstream NixOS / home-manager / devenv configs can
consume the catalogue directly instead of running `scripts/install.sh`.

```bash
nix run github:Jylhis/skills#install                   # = bash scripts/install.sh
nix run github:Jylhis/skills#list                      # dump the catalogue as JSON
nix run github:Jylhis/skills#list -- --kind skills     # filter by kind
nix run github:Jylhis/skills#show -- ast-grep          # one artefact
nix run github:Jylhis/skills#show -- --kind lspServers python
```

From a flake consumer:

```nix
inputs.jylhis-skills.url = "github:Jylhis/skills";

# anywhere a path is accepted:
home.file.".claude/plugins/jylhis-python".source =
  inputs.jylhis-skills.aiTooling.${system}.plugins.jylhis-python.path;
```

Catalogue shape per kind: `{ skills, agents, commands, lspServers, mcpServers, plugins }`.
Each entry carries `{ type, name, description, path, frontmatter }` plus
kind-specific fields (skills add `category`, lspServers add `command`/`args`/
`packageName`, plugins add `version` and reference-back lists into the other
kinds). The MCP slot is reserved and currently empty.

The bash installer remains the supported on-ramp for users without Nix; the
flake is additive.

## Opt-in plugins

The marketplace publishes these language and tool plugins; none are installed
by default.

| Plugin | Adds |
|---|---|
| `jylhis-python` | Python skill + `basedpyright` LSP |
| `jylhis-typescript` | TypeScript skill + `typescript-language-server` LSP |
| `jylhis-go` | Go skill + `gopls` LSP |
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

Install one in each tool (example: `jylhis-python`):

| Tool | Command |
|---|---|
| Claude Code | `/plugin install jylhis-python@jylhis-skills` |
| Codex | `codex plugin install jylhis-python@jylhis-skills` — then set `[plugins."jylhis-python@jylhis-skills"] enabled = true` in `~/.codex/config.toml` |
| Antigravity | `for s in <repo>/plugins/jylhis-python/skills/*; do ln -s "$s" ~/.gemini/antigravity/skills/$(basename "$s"); done` |

## Development

Load the marketplace without installing:

```bash
# Claude Code
claude --plugin-dir ./

# Antigravity (workspace-scoped: skills visible only inside this repo)
mkdir -p .agent/skills
for s in plugins/jylhis-skills-core/skills/*; do
  ln -s "../../$s" ".agent/skills/$(basename "$s")"
done

# Codex
codex plugin marketplace add ./
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
   `plugins/jylhis-<plugin>/` with `.claude-plugin/plugin.json` and
   `.codex-plugin/plugin.json`, plus a `skills/<name>` symlink with relative
   target `../../../skills/<category>/<name>`. (No per-plugin manifest is
   needed for Antigravity — it discovers skills via the symlinks
   `scripts/install.sh` creates under `~/.gemini/antigravity/skills/`.)
3. Add the plugin to `.claude-plugin/marketplace.json` and
   `.agents/plugins/marketplace.json`.
4. Run `just validate` — the cross-check enforces that every on-disk skill is
   referenced by exactly one plugin manifest.

See `docs/skill-authoring-guide.md` for the portability profile and the
rejected target-specific frontmatter fields.
