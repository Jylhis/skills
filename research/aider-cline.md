---
date: 2026-04-14
researcher: Claude Code (Opus 4.6)
method: web search + web fetch of aider.chat docs and Cline VS Code extension docs
versions:
  aider: v0.86.0
  cline: v3.78.0
---

# Aider

## Config Files

| File | Locations (searched in order) | Purpose |
|------|-------------------------------|---------|
| `.aider.conf.yml` | `~/`, `<git-root>/`, `./` | Main YAML config (100+ settings) |
| `.env` | `~/`, `<git-root>/`, `./` | Environment vars + API keys |
| `.aider.model.settings.yml` | Same 3 locations | Per-model behavioral settings |
| `.aider.model.metadata.json` | Same 3 locations | Context windows + token costs |
| `.aiderignore` | Git root | Gitignore-syntax exclusions |

Last loaded wins (cwd overrides git-root overrides home).

## Instructions

**Conventions file** (typically `CONVENTIONS.md`):
- Plain markdown, no frontmatter
- Loaded via `--read CONVENTIONS.md` or `read: CONVENTIONS.md` in YAML config
- Included as read-only context in every prompt, prompt-cached

No skill/plugin system. Monolithic CLI tool.

## Tool Integration

- **No MCP support** (third-party adapter exists but not core)
- External tools only via `--lint-cmd` and `--test-cmd`

## Built-in Capabilities

37+ in-chat commands: `/add`, `/drop`, `/ask`, `/code`, `/architect`, `/run`, `/git`,
`/lint`, `/test`, `/commit`, `/undo`, `/diff`, `/web`, `/voice`, `/map`, `/model`, etc.

**Repo map**: tree-sitter indexing of all files/classes/functions across 100+ languages.
**Git integration**: auto-commits, attribution, `/undo`.
**Watch mode**: monitors for `AI!`/`AI?` comments in files.

## Memory

No persistent memory across sessions. Chat history in `.aider.chat.history.md`.
`/save` and `/load` for file sets. Context is manual (`/add`, `/drop`).

## Binary Provisioning

Python package via PyPI. Install: `uv tool install`, `pipx`, `pip`. Docker image available.
No package management for project tools.

---

# Cline (VS Code Extension)

## Config Files

| File | Location | Purpose |
|------|----------|---------|
| VS Code `settings.json` | Standard VS Code paths | `cline.*` keys |
| `cline_mcp_settings.json` | VS Code extension data dir | MCP servers |
| `.clinerules/*.md` | Project root | Workspace rules |
| `~/Documents/Cline/Rules/` | Home dir | Global rules |
| `.clineignore` | Project root | Gitignore-syntax exclusions |

## Rules Format

`.clinerules/` directory with `.md` and `.txt` files. Optional YAML frontmatter:

```yaml
---
paths:
  - "src/components/**"
  - "**/*.test.ts"
---
```

Rules without frontmatter: always active. With `paths`: conditional on matching files.
Numeric prefixes for ordering: `01-coding-style.md`, `02-docs.md`.
Cross-tool compat: auto-detects `.cursorrules`, `.windsurfrules`, `AGENTS.md`.

## MCP

`cline_mcp_settings.json`:
```json
{
  "mcpServers": {
    "name": {
      "command": "node", "args": ["/path/to/server.js"],
      "env": {}, "alwaysAllow": ["tool1"], "disabled": false
    }
  }
}
```

Transports: STDIO, SSE. Per-server enable/disable + `alwaysAllow`.
Cline can self-build MCP servers from GitHub URLs.

## Built-in Tools (13)

`write_to_file`, `read_file`, `replace_in_file`, `search_files`, `list_files`,
`list_code_definition_names`, `execute_command`, `browser_action` (Puppeteer),
`use_mcp_tool`, `access_mcp_resource`, `ask_followup_question`, `attempt_completion`,
`new_task`

Slash commands: `/newtask`, `/smol` (compress), `/newrule`.

## Memory

**Memory Bank** (methodology, not hard feature): `memory-bank/` with 6 structured files
(`projectbrief.md`, `productContext.md`, `activeContext.md`, `systemPatterns.md`,
`techContext.md`, `progress.md`). All read at task start.

**Checkpoints**: snapshots after each tool call, restorable.
**`/smol`**: compresses conversation history (irreversible).
**`/newtask`**: distills progress into fresh task.

## Binary Provisioning

VS Code extension. Commands via VS Code integrated terminal.
CLI: `npm install -g cline`. No package management for project tools.
