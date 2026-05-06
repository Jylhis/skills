---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: web fetch of GitHub repo google-gemini/gemini-cli, web search for docs
version: v0.38.1 (2026-04-15)
---

# Gemini CLI

## Config File Locations

```
~/.gemini/
  settings.json          # User-global settings
  GEMINI.md              # User-global instructions
  commands/              # Custom commands (.toml)
  skills/                # Agent skills (SKILL.md dirs)
  extensions/            # Installed extensions
  tmp/                   # Plans storage

<project>/.gemini/
  settings.json          # Project-specific (overrides user)
  commands/              # Project commands
  skills/                # Project skills
  hooks/                 # Hook scripts
  sandbox.Dockerfile     # Custom sandbox
  .env                   # Extension env vars
```

Cross-client: `.agents/skills/` at both project and user scope (takes precedence over `.gemini/skills/`).

### Settings precedence (4 tiers)

1. System defaults: `/Library/Application Support/GeminiCli/system-defaults.json`
2. User: `~/.gemini/settings.json`
3. Project: `<project>/.gemini/settings.json`
4. System lockdown: `/Library/Application Support/GeminiCli/settings.json`
5. Environment variables
6. CLI arguments (highest)

Schema: `https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json`

## Settings Schema (key categories)

| Category | Notable fields |
|----------|---------------|
| `general` | `defaultApprovalMode`, `plan.enabled`, `checkpointing.enabled`, `sessionRetention` (age/count cleanup) |
| `model` | `name`, `compressionThreshold` (default 0.5), `maxSessionTurns` |
| `modelConfigs` | Pro/Flash model routing for plan mode |
| `tools` | `sandbox` (docker/podman/sandbox-exec/runsc/lxc), `sandboxAllowedPaths`, `useRipgrep` |
| `security` | `toolSandboxing`, `disableYoloMode`, `enableConseca`, `folderTrust` |
| `context` | `fileName` (array, default `["GEMINI.md"]`), `discoveryMaxDirs` |
| `mcpServers` | Server definitions |
| `hooks` | Event-keyed hook definitions |
| `skills` | `enabled` (boolean) |
| `output` | Output formatting settings |
| `ui` | UI preferences |
| `ide` | IDE integration settings |
| `privacy` | Privacy settings |
| `telemetry` | Telemetry settings |
| `billing` | Billing settings |
| `policyPaths` | User policy file paths |
| `adminPolicyPaths` | Admin policy file paths |
| `experimental` | `worktrees`, `memoryManager`, `contextManagement` |

Env var expansion: `$VAR`, `${VAR}`, `${VAR:-default}`

## GEMINI.md Instructions

Plain Markdown (no required frontmatter). All found files concatenated.

Locations: `~/.gemini/GEMINI.md` + workspace hierarchy + JIT discovery when tools access files.
Import syntax: `@./path/to/file.md` (nested up to 5 levels, circular detection).
Customizable filename: `context.fileName` can be `["AGENTS.md", "CONTEXT.md", "GEMINI.md"]`.

## Custom Commands

TOML files in `commands/` directories.

```toml
description = "One-line description"
prompt = """The prompt text"""
```

Naming: `commands/git/commit.toml` -> `/git:commit`
Argument: `{{args}}` placeholder. Shell injection: `!{command}`. File injection: `@{path}`.

## MCP Servers

Three transports: stdio (`command`, `args`, `env`), SSE (`url`, `headers`), Streamable HTTP (`httpUrl`).

```json
{
  "mcpServers": {
    "name": {
      "command": "binary", "args": [], "env": {},
      "timeout": 30000, "trust": false,
      "includeTools": ["tool1"], "excludeTools": ["tool2"]
    }
  }
}
```

Per-server `includeTools`/`excludeTools` filtering. OAuth/IAP auth support.

## Built-in Tools (34 total)

| Tool | Description |
|------|-------------|
| `run_shell_command` | Shell execution |
| `glob` | File pattern matching |
| `grep_search` | Regex search (ripgrep) |
| `list_directory` | Directory listing |
| `read_file` | Read file (text, image, audio, PDF) |
| `read_many_files` | Read multiple files |
| `replace` | Text replacement |
| `write_file` | Create/overwrite |
| `write_todos` | Create/update TODO list |
| `ask_user` | Request clarification |
| `activate_skill` | Load skill |
| `save_memory` | Persist to GEMINI.md |
| `enter_plan_mode` / `exit_plan_mode` | Planning |
| `tracker_create_task` / `tracker_get_task` / `tracker_list_tasks` / `tracker_update_task` / `tracker_add_dependency` / `tracker_visualize` | Task tracking |
| `complete_task` | Mark task complete |
| `update_topic` | Update session topic |
| `list_mcp_resources` / `read_mcp_resource` | MCP resource access |
| `get_internal_docs` | Retrieve internal documentation |
| `google_web_search` | Google Search |
| `web_fetch` | URL retrieval |

## Skills

Same format as Agent Skills spec. YAML frontmatter (`name`, `description`) + Markdown body.

Discovery: `.gemini/skills/` or `.agents/skills/` (project + user). `.agents/` takes precedence.
Lifecycle: discover -> catalog in prompt -> `activate_skill` -> consent -> inject.
Management: `/skills list|disable|enable|reload`, `gemini skills install|link|uninstall`.

## Extensions

Full packages bundling MCP servers, commands, skills, hooks, themes, policies.

Manifest: `gemini-extension.json` with `name`, `version`, `mcpServers`, `settings`, `themes`.
Management: `gemini extensions install|link|update|disable|enable|uninstall|new`.
Variables: `${extensionPath}`, `${workspacePath}`, `${/}`.

## Hooks

11 events: `SessionStart`, `SessionEnd`, `BeforeAgent`, `AfterAgent`, `BeforeModel`, `AfterModel`,
`BeforeToolSelection`, `BeforeTool`, `AfterTool`, `PreCompress`, `Notification`.

JSON via stdin/stdout. Exit 0 = success, 2 = block. Matcher supports regex.
Management: `/hooks panel|enable-all|disable-all|enable|disable`.

## Sandbox

5 options: macOS Seatbelt (default), Docker/Podman, Windows icacls, gVisor/runsc, LXC.
Dynamic permission expansion on sandbox failures.

## Binary Provisioning

Node.js app via npm/Homebrew. Tools must be on PATH. No built-in package management.
