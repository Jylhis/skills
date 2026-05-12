# Install jylhis-skills

A curated [Agent Skills](https://agentskills.io) **marketplace** that publishes
one default plugin (`jylhis-skills-core`) and several opt-in plugins to Claude
Code, Gemini CLI, and Codex.

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
| Gemini CLI | symlink the default plugin as an extension | `~/.gemini/extensions/jylhis-skills-core` → `plugins/jylhis-skills-core` |
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

Install one in each tool (example: `jylhis-python`):

| Tool | Command |
|---|---|
| Claude Code | `/plugin install jylhis-python@jylhis-skills` |
| Codex | `codex plugin install jylhis-python@jylhis-skills` — then set `[plugins."jylhis-python@jylhis-skills"] enabled = true` in `~/.codex/config.toml` |
| Gemini CLI | `ln -s <repo>/plugins/jylhis-python ~/.gemini/extensions/jylhis-python` |

## Development

Load the marketplace without installing:

```bash
# Claude Code
claude --plugin-dir ./

# Gemini CLI
gemini extensions link ./plugins/jylhis-skills-core

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
   `plugins/jylhis-<plugin>/` with `.claude-plugin/plugin.json`,
   `.codex-plugin/plugin.json`, and `gemini-extension.json`, plus a
   `skills/<name>` symlink with relative target
   `../../../skills/<category>/<name>`.
3. Add the plugin to `.claude-plugin/marketplace.json` and
   `.agents/plugins/marketplace.json`.
4. Run `just validate` — the cross-check enforces that every on-disk skill is
   referenced by exactly one plugin manifest.

See `docs/skill-authoring-guide.md` for the portability profile and the
rejected target-specific frontmatter fields.
