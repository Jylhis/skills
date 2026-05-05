---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: web fetch of code.claude.com docs (features, settings, hooks, mcp, skills, memory)
version: "2.1.111"
---

# Claude Code

## Config File Locations

| Purpose | Path | Shared? |
|---------|------|---------|
| Managed settings | `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS) | Org-wide |
| User settings | `~/.claude/settings.json` | No |
| Project settings | `.claude/settings.json` | Yes (git) |
| Local settings | `.claude/settings.local.json` | No (gitignored) |
| User MCP + prefs | `~/.claude.json` | No |
| Project MCP | `.mcp.json` | Yes |
| Project memory | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Yes |
| User memory | `~/.claude/CLAUDE.md` | No |
| Local memory | `./CLAUDE.local.md` | No |
| Managed memory | `/Library/Application Support/ClaudeCode/CLAUDE.md` | Org-wide |
| Auto memory | `~/.claude/projects/<project>/memory/MEMORY.md` | No |
| Path-scoped rules | `.claude/rules/*.md` | Yes |
| Skills | `.claude/skills/<name>/SKILL.md` | Yes |
| Commands (legacy) | `.claude/commands/<name>.md` | Yes |
| Subagents | `.claude/agents/<name>.md` | Yes |
| Keybindings | `~/.claude/keybindings.json` | No |
| LSP config | `.lsp.json` (plugin root) | Via plugin |

Settings precedence: Managed > CLI args > Local > Project > User

## Settings Schema

Schema URL: `https://json.schemastore.org/claude-code-settings.json`

Key fields: `permissions` (allow/deny/ask arrays with `Tool(specifier)` syntax), `hooks`, `env`,
`model`, `effortLevel`, `sandbox`, `autoMemoryEnabled`, `enabledPlugins`, `enableAllProjectMcpServers`,
`enabledMcpjsonServers`, `claudeMdExcludes`, `worktree`, `autoMode`, `disableSkillShellExecution`.

### Sandbox settings (nested)

- `filesystem`: `allowWrite`, `denyWrite`, `denyRead`, `allowRead`
- `network`: `allowedDomains`, `allowUnixSockets`, `allowLocalBinding`

### Permission rule syntax

`Tool` or `Tool(specifier)` with globs. Order: deny > ask > allow.
Examples: `Bash(npm run *)`, `Read(./.env)`, `Edit(*.ts)`, `Skill(commit)`, `Skill(name *)`, `mcp__server__tool`

## SKILL.md Frontmatter

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name + `/slash-command`. Lowercase + hyphens, max 64. Default: dir name |
| `description` | Recommended | What + when. Truncated at 1536 chars |
| `when_to_use` | No | Additional trigger context |
| `argument-hint` | No | Autocomplete hint, e.g. `[issue-number]` |
| `disable-model-invocation` | No | `true` = user-only invoke |
| `user-invocable` | No | `false` = hidden from `/` menu |
| `allowed-tools` | No | Pre-approved tools (list or space-separated string) |
| `model` | No | Model override when active |
| `effort` | No | `low`/`medium`/`high`/`max`/`xhigh` |
| `context` | No | `fork` = run in subagent |
| `agent` | No | Subagent type for `context: fork` (default `general-purpose`) |
| `hooks` | No | Hooks scoped to skill lifecycle |
| `paths` | No | Glob patterns to auto-activate |
| `shell` | No | `bash` (default) or `powershell` |

String substitutions: `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N` (shorthand), `${CLAUDE_SESSION_ID}`, `${CLAUDE_SKILL_DIR}`

Dynamic context: `` !`command` `` inline or fenced `` ```! `` block runs shell at skill load time.

## MCP Configuration

`.mcp.json` schema:
```json
{
  "mcpServers": {
    "name": {
      "command": "binary", "args": [], "env": {},
      "type": "http", "url": "https://...",
      "headers": {"Authorization": "Bearer ${TOKEN}"}
    }
  }
}
```

Transports: `stdio`, `http` (streamable, recommended), `sse` (deprecated).
Env var expansion: `${VAR}`, `${VAR:-default}`.
Scope precedence: local > project > user > plugin > claude.ai connectors.
Permission naming: `mcp__<server>__<tool>`

## Hooks

31 events grouped by category:

- **Session**: `SessionStart`, `SessionEnd`
- **Per-turn**: `UserPromptSubmit`, `Stop`, `StopFailure`, `PermissionRequest`, `PermissionDenied`
- **Tool loop**: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`
- **Subagent + Task**: `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`
- **File + Config**: `FileChanged`, `CwdChanged`, `ConfigChange`, `InstructionsLoaded`, `WorktreeCreate`, `WorktreeRemove`
- **Compaction**: `PreCompact`, `PostCompact`
- **MCP**: `Elicitation`, `ElicitationResult`
- **Notification**: `Notification`

Handler types: `command` (shell), `http`, `prompt` (LLM), `agent`.
Common handler fields: `if` (conditional), `timeout` (defaults 600/30/60s by type), `statusMessage`, `once`.
Exit codes: 0 = success, 2 = block. Decision JSON shape varies per event.

## CLAUDE.md Memory

Loading: hierarchy above cwd loaded at launch. Subdirectory files loaded lazily. All additive.
Import syntax: `@path/to/file` (max depth 5). HTML comments stripped.
Auto memory: `~/.claude/projects/<project>/memory/MEMORY.md` (first 200 lines loaded).
Additional dirs flag: `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` to include CLAUDE.md from extra dirs.

## Built-in Tools

Read, Write, Edit, Bash, Glob, Grep, Agent, WebFetch, WebSearch, Skill, LSP,
NotebookEdit, Monitor, EnterPlanMode/ExitPlanMode, EnterWorktree/ExitWorktree,
TaskCreate/TaskGet/TaskList/TaskUpdate/TaskStop/TaskOutput, AskUserQuestion, SendMessage,
CronCreate/CronDelete/CronList, ToolSearch, ScheduleWakeup, RemoteTrigger,
ListMcpResourcesTool, ReadMcpResourceTool, PowerShell (opt-in via `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`)

## Documentation Access

- llms.txt: https://code.claude.com/docs/llms.txt (127 pages)
- llms-full.txt: available
- Settings schema: https://json.schemastore.org/claude-code-settings.json
- Docs MCP: none (use Context7)

## Binary/Package Provisioning

Inherits shell `$PATH`. No built-in package management.
Plugin `bin/` directories added to Bash tool's `$PATH`.
`CLAUDE_ENV_FILE` for persistent env vars across Bash commands.

## LSP Configuration

Via plugin `.lsp.json`: `command`, `extensionToLanguage` (required), `args`, `transport`,
`env`, `initializationOptions`, `settings`, `restartOnCrash`, `maxRestarts`.

## Plugin Structure

```
plugin-root/
  .claude-plugin/plugin.json    # Manifest (name required)
  skills/<name>/SKILL.md
  commands/<name>.md
  agents/<name>.md
  hooks/hooks.json
  bin/                          # Added to PATH
  .mcp.json
  .lsp.json
  settings.json
```

Env vars: `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`
