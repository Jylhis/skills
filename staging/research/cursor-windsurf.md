---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: web search + web fetch of Cursor and Windsurf docs
versions:
  cursor: "3.1 (2026-04-13)"
  windsurf: unknown (docs fetched 2026-04-16)
---

# Cursor

## Config Files

| File | Location | Purpose |
|------|----------|---------|
| `.cursor/rules/*.md` / `.mdc` | Project | Rules with frontmatter |
| `~/.cursor/mcp.json` | Global | MCP servers |
| `.cursor/mcp.json` | Project | MCP servers |
| `.cursor/hooks.json` | Project | Hooks |
| `~/.cursor/hooks.json` | Global | Hooks |
| `AGENTS.md` | Project/subdir | Plain-markdown instructions |
| `.cursorrules` | Project root | **Legacy** (deprecated) |

User Rules: via Settings UI only. Team Rules: via Cursor dashboard.

## Rules Format

`.cursor/rules/*.md` or `.mdc` (recommended when frontmatter is needed). YAML frontmatter:

```yaml
---
description: "Standards for React components"
globs: ["src/components/**/*.tsx"]
alwaysApply: false
---
```

| alwaysApply | globs | description | Type |
|-------------|-------|-------------|------|
| `true` | -- | -- | Always Apply |
| `false` | defined | -- | Apply to Specific Files (on glob match) |
| `false`/absent | absent | present | Apply Intelligently |
| absent | absent | absent | Apply Manually (`@rule-name`) |

Precedence: Team > Project > User.

AGENTS.md nested in subdirs supported. Remote rule imports from GitHub now documented.

## MCP

`.cursor/mcp.json` or `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "name": {
      "command": "binary", "args": [], "env": {},
      "envFile": ".env"
    }
  }
}
```

Transports: stdio, SSE (`url`, `headers`), Streamable HTTP (`url`, `headers`, `auth`).
Variables: `${env:NAME}`, `${userHome}`, `${workspaceFolder}`, `${/}`.
Limit: ~40 tools recommended.

## Built-in Tools

Semantic Search, Search Files/Folders, Read Files, Edit Files, Run Shell Commands,
Web Search, Browser (screenshots, navigation), Image Generation, Fetch Rules, Ask Questions.

## Hooks

21 events, split into Agent + Tab categories.

**Agent hooks**: `sessionStart`, `sessionEnd`, `preToolUse`, `postToolUse`, `postToolUseFailure`,
`subagentStart`, `subagentStop`, `beforeShellExecution`, `afterShellExecution`,
`beforeMCPExecution`, `afterMCPExecution`, `beforeReadFile`, `afterFileEdit`,
`beforeSubmitPrompt`, `preCompact`, `stop`, `afterAgentResponse`, `afterAgentThought`

**Tab hooks**: `beforeTabFileRead`, `afterTabFileEdit`

Types: command (shell) and prompt (LLM). Exit 0 = success, 2 = block.

## Sandbox

macOS: Seatbelt. Linux: Landlock v3 / Bubblewrap. Windows: WSL2.
Agent terminals don't inherit shell state. `CURSOR_AGENT` env var set.

## Plugin Marketplace

Cursor 2.5+. Plugins bundle skills, subagents, MCP servers, hooks, rules.

## Memory

No persistent memory system. Context from rules, MCP, and codebase indexing.
Checkpoints for revert.

---

# Windsurf (Codeium / Cognition)

## Config Files

| File | Location | Purpose |
|------|----------|---------|
| `~/.codeium/windsurf/memories/global_rules.md` | Global | Always-on rules (6000 char limit) |
| `.windsurf/rules/*.md` | Project | Rules with frontmatter (12000 char/file) |
| `~/.codeium/windsurf/mcp_config.json` | Global | MCP servers (global only) |
| `~/.codeium/windsurf/memories/` | Global | Auto-generated memories |
| `.windsurf/skills/<name>/SKILL.md` | Project | Skills |
| `~/.codeium/windsurf/skills/<name>/SKILL.md` | Global | Skills |
| `.windsurf/workflows/*.md` | Project | Workflows |
| `~/.codeium/windsurf/global_workflows/*.md` | Global | Workflows |
| `AGENTS.md` | Project/subdir | Plain-markdown instructions |
| `.windsurfrules` | Project root | **Legacy** |

Enterprise rules: `/Library/Application Support/Windsurf/rules/*.md` (macOS), `/etc/windsurf/rules/*.md` (Linux)

## Rules Format

`.windsurf/rules/*.md` with YAML frontmatter:

```yaml
---
trigger: always_on | model_decision | glob | manual
globs: "src/**/*.ts"     # only with trigger: glob
---
```

Global rules: `global_rules.md`, plain markdown, no frontmatter, 6000 char limit.

## MCP

Global only: `~/.codeium/windsurf/mcp_config.json` (no project-scoped config).

```json
{
  "mcpServers": {
    "name": {
      "command": "binary", "args": [], "env": {},
      "disabledTools": ["tool1"]
    }
  }
}
```

Variables: `${env:VAR_NAME}`, `${file:/path}`. Hard limit: 100 tools total.

## Built-in Tools

Search, Analyze, Read/Edit/Create files, Run Command, Web Search, MCP tools, Planning.
Tool call limit: 20 per prompt (Auto-Continue available).

## Skills

Same SKILL.md format. Discovery: `.windsurf/skills/`, `~/.codeium/windsurf/skills/`,
`.agents/skills/`, `.claude/skills/` (cross-tool compat).

## Workflows

Manual-only (`/workflow-name`). Location: `.windsurf/workflows/*.md`.
12000 char limit. Can nest. Never auto-invoked.

## Memory

Auto-generated memories stored locally in `~/.codeium/windsurf/memories/`.
Machine-local only. Flow awareness tracks IDE actions.
Codebase indexed as 768-dim vectors for semantic search.

## Hooks

12 events: `pre_read_code`, `post_read_code`, `pre_write_code`, `post_write_code`,
`pre_run_command`, `post_run_command`, `pre_mcp_tool_use`, `post_mcp_tool_use`,
`pre_user_prompt`, `post_cascade_response`, `post_cascade_response_with_transcript`,
`post_setup_worktree`.

Config: `hooks.json` with `command`/`powershell`/`show_output`/`working_directory` fields.

Locations:
- Project: `.windsurf/hooks.json`
- IDE global: `~/.codeium/windsurf/hooks.json`
- JetBrains: `~/.codeium/hooks.json`
- System: `/Library/Application Support/Windsurf/hooks.json` (macOS),
  `/etc/windsurf/hooks.json` (Linux), `C:\ProgramData\Windsurf\hooks.json` (Windows)

## Binary Provisioning

Dedicated terminal always uses zsh (loads `.zshrc`). Tools from PATH.
No sandboxing. Allow/deny lists for command execution.
No built-in package management.

---

## Cursor vs Windsurf Comparison

| Feature | Cursor | Windsurf |
|---------|--------|----------|
| Rules location | `.cursor/rules/` | `.windsurf/rules/` |
| Rule frontmatter | `description`, `globs`, `alwaysApply` | `trigger`, `globs` |
| MCP config | Project + global | Global only |
| MCP tool limit | ~40 recommended | 100 hard limit |
| Auto-memories | No | Yes |
| Skills | Via Marketplace | Built-in SKILL.md |
| Workflows | No | Yes (manual slash commands) |
| Hooks | Yes (21 events) | Yes (12 events, added 2026) |
| Marketplace | Yes | No |
| Sandbox | OS-level | Allow/deny lists |
| Shell | Fresh context | Dedicated zsh |
