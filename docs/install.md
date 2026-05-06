# Install jylhis-skills

A curated [Agent Skills](https://agentskills.io) catalogue packaged as a
single plugin for Claude Code, Gemini CLI, and Codex.

## Quick install

```bash
bash scripts/install.sh
```

Idempotent; backs up anything it would overwrite. Pass `--dry-run` to preview.

## What the script does

| Tool | Mechanism | Where |
|---|---|---|
| Claude Code | local marketplace + `plugin install` | `~/.claude/plugins/known_marketplaces.json` + `installed_plugins.json` |
| Gemini CLI | symlink | `~/.gemini/extensions/jylhis-skills` → repo root |
| Codex | symlink | `~/.codex/plugins/jylhis-skills` → repo root |

For Claude Code, the script registers this repo as a local marketplace
and then installs the `jylhis-skills` plugin from it, so it appears in
`/plugin`. If the `claude` CLI isn't on `PATH`, run these manually
inside Claude Code instead:

```
/plugin marketplace add <path-to-this-repo>
/plugin install jylhis-skills@jylhis-skills
```

### Install scope (user vs project)

`claude plugin install` records enablement in a `settings.json` file.
The script picks a scope automatically:

- **user** (default) — writes to `~/.claude/settings.json`; plugin
  enabled in every directory.
- **project** — writes to `<repo>/.claude/settings.json`; plugin only
  enabled when running Claude inside this repo. Auto-selected if
  `~/.claude/settings.json` is read-only (e.g. managed by Nix
  home-manager). Override with `CLAUDE_PLUGIN_SCOPE=project bash scripts/install.sh`.

Claude Code also gets direct context links:

```
~/.claude/AGENTS.md  →  AGENTS.md
~/.claude/CLAUDE.md  →  CLAUDE.md
```

## Development

Load the plugin without installing:

```bash
# Claude Code
claude --plugin-dir ./

# Gemini CLI
gemini extensions link .
```

All dev tools come from devenv:

```bash
direnv allow       # or: devenv shell
just               # list recipes
just check         # markdownlint + shellcheck + validate
just validate      # skill frontmatter lint only
just list          # list all SKILL.md files
```

## Contributing

Add a skill:
1. Create `skills/<category>/<name>/SKILL.md` with YAML frontmatter.
2. Add `"./skills/<category>/<name>"` to `.claude-plugin/plugin.json`'s `skills` array.
3. Run `just validate`.

See `docs/skill-authoring-guide.md` for the portability profile and rejected fields.

Promote a skill from `staging/`:
```bash
git mv staging/skills/<name> skills/<category>/<name>
# update SKILL.md to current conventions
just validate
# add path to .claude-plugin/plugin.json
```
