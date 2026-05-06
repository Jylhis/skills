# Install jylhis-skills

A curated [Agent Skills](https://agentskills.io) catalogue packaged as a
single plugin for Claude Code, Gemini CLI, and Codex.

## Quick install

```bash
bash scripts/install.sh
```

Creates symlinks from each tool's plugin/extension directory to this repo.
Idempotent; backs up any existing files first. Pass `--dry-run` to preview.

## What gets linked

| Tool | Symlink target | Points to |
|---|---|---|
| Claude Code | `~/.claude/plugins/jylhis-skills` | repo root |
| Gemini CLI | `~/.gemini/extensions/jylhis-skills` | repo root |
| Codex | `~/.codex/plugins/jylhis-skills` | repo root |

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
