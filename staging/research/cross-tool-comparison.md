---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: synthesized from individual tool research docs
versions: see individual research docs for per-tool versions
---

# Cross-Tool Comparison

## Config Locations

| Tool | Global Config Dir | Project Config Dir | Settings Format |
|------|-------------------|-------------------|-----------------|
| Claude Code | `~/.claude/` | `.claude/` | JSON (`settings.json`) |
| Codex CLI | `~/.codex/` | `.codex/` | TOML (`config.toml`) |
| Gemini CLI | `~/.gemini/` | `.gemini/` | JSON (`settings.json`) |
| Cursor | `~/.cursor/` | `.cursor/` | UI-based + JSON |
| Windsurf | `~/.codeium/windsurf/` | `.windsurf/` | UI-based |
| Cline | VS Code ext data | `.clinerules/`, `.cline/` | VS Code settings |
| Aider | `~/` | `<git-root>/` | YAML (`.aider.conf.yml`) |
| OpenCode | `~/.config/opencode/` | `./` | JSON/JSONC (`opencode.json`) |
| Pi | `~/.pi/agent/` | `.pi/` | JSON (`settings.json`) |
| OpenClaw | `~/.openclaw/` | N/A | JSON5 (`openclaw.json`) |
| NanoClaw | N/A | repo root | None (code-level) |

## Instruction Files

| Tool | File | Format | Hierarchy |
|------|------|--------|-----------|
| Claude Code | `CLAUDE.md` | Markdown (no frontmatter) | Global + project + subdir + local. Additive. `@import` syntax. |
| Codex CLI | `AGENTS.md` | Markdown (no frontmatter) | Global + project walk. Override variants. Concatenate. |
| Gemini CLI | `GEMINI.md` | Markdown (no frontmatter) | Global + workspace + JIT. `@import` syntax. Customizable filename. |
| Cursor | `.cursor/rules/*.md` or `.mdc` | YAML frontmatter (`description`, `globs`, `alwaysApply`) | Team > Project > User |
| Windsurf | `.windsurf/rules/*.md` | YAML frontmatter (`trigger`, `globs`) | Enterprise > Workspace > Global |
| Cline | `.clinerules/*.md` | Optional YAML frontmatter (`paths`) | Global + project |
| Aider | `CONVENTIONS.md` | Plain markdown | Via `--read` flag |
| OpenCode | `AGENTS.md` | Markdown | Global + project walk. Falls back to CLAUDE.md. |
| Pi | `AGENTS.md`/`CLAUDE.md` | Markdown | Global + project walk. All concatenated. |
| OpenClaw | `SOUL.md` + `IDENTITY.md` | Markdown | Per-agent dirs |

## Skill/Extension Systems

| Tool | Skill Format | Discovery Path | Invocation |
|------|-------------|----------------|------------|
| Claude Code | `SKILL.md` (YAML frontmatter) | `.claude/skills/`, `~/.claude/skills/` | Auto + `/name` |
| Codex CLI | Skills via config | `.codex/skills/`, `~/.agents/skills/` (v0.94.0+) | Config-based |
| Gemini CLI | `SKILL.md` + Extensions | `.gemini/skills/`, `.agents/skills/` | `activate_skill` + `/name` |
| Cursor | Marketplace plugins | Via marketplace | Auto |
| Windsurf | `SKILL.md` + Workflows | `.windsurf/skills/`, `.agents/skills/` | Auto + `@name` + `/workflow` |
| Cline | `SKILL.md` (added 2026) | `.cline/skills/`, `.clinerules/skills/`, `.claude/skills/` | Auto |
| Aider | None | N/A | N/A |
| OpenCode | `SKILL.md` | `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` | Auto |
| Pi | `SKILL.md` + Extensions (TS) | `.pi/skills/`, `.agents/skills/` | `/skill:name` |
| OpenClaw | ClawHub marketplace | Workspace `skills/` | Config-based |

## MCP Support

| Tool | Config Location | Transports | Per-tool Control |
|------|----------------|------------|-----------------|
| Claude Code | `.mcp.json`, `~/.claude.json` | stdio, http, sse | Via permissions |
| Codex CLI | `config.toml` `[mcp_servers]` | stdio, http | `enabled_tools`/`disabled_tools`, per-tool approval |
| Gemini CLI | `settings.json` `mcpServers` | stdio, sse, http | `includeTools`/`excludeTools` |
| Cursor | `.cursor/mcp.json` | stdio, sse, http | ~40 tool limit |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` | stdio, sse, http | `disabledTools`, 100 tool limit |
| Cline | `cline_mcp_settings.json` | stdio, sse | `alwaysAllow` |
| Aider | None (no MCP) | N/A | N/A |
| OpenCode | `opencode.json` `mcp` | stdio, http | `allow`/`deny`/`ask` per tool |
| Pi | Not built-in (extensions) | Via adapters | N/A |
| OpenClaw | `openclaw.json` `mcp` | stdio, sse, http | Via config |

## Hook Systems

| Tool | Config | Events | Handler Types |
|------|--------|--------|---------------|
| Claude Code | `settings.json` `hooks` | 31 events | command, http, prompt, agent |
| Codex CLI | `hooks.json` | 5 events | command |
| Gemini CLI | `settings.json` `hooks` | 11 events | command (JSON stdio) |
| Cursor | `.cursor/hooks.json` | 21 events | command, prompt |
| Windsurf | `.windsurf/hooks.json` | 12 events (added 2026) | command, powershell |
| Cline | `.clinerules/hooks/`, `~/Documents/Cline/Hooks/` | 8 events (added 2026) | executable (JSON stdio) |
| Aider | None | N/A | N/A |
| OpenCode | None documented | N/A | N/A |
| Pi | Via extensions | N/A | TypeScript |

## Built-in Tools

| Tool | File Ops | Shell | Search | Web | Browser | Planning | Tasks | MCP | LSP |
|------|----------|-------|--------|-----|---------|----------|-------|-----|-----|
| Claude Code | R/W/E | Yes | Glob+Grep | Fetch+Search | No | Yes | Yes | Yes | Yes |
| Codex CLI | R/W/E (apply_patch) | Yes (shell/unified_exec) | search_tool | web_search | No | Yes | No | Yes | No |
| Gemini CLI | R/W/E | Yes | Glob+Grep | Google+Fetch | No | Yes | Yes (6 trackers) | Yes | No |
| Cursor | R/W/E | Yes | Semantic | Yes | Yes | No | No | Yes | No |
| Windsurf | R/W/E | Yes | Semantic | Yes | No | Yes | No | Yes | No |
| Cline | R/W/E | Yes | Regex | No | Puppeteer | No | Yes (new_task) | Yes | No |
| Aider | R/W/E | `/run` | Repo map | `/web` | No | No | No | No | No |
| OpenCode | R/W/E | Yes | Glob+Grep | Fetch+Search | No | No | Yes | Yes | Yes |
| Pi | R/W/E | Yes | No | No | No | No | No | Ext | No |

## Sandbox Models

| Tool | macOS | Linux | Network |
|------|-------|-------|---------|
| Claude Code | Seatbelt | Configurable | Per-domain allowlist |
| Codex CLI | Seatbelt | bwrap+seccomp | Disabled by default |
| Gemini CLI | Seatbelt | Docker/gVisor/LXC | Configurable |
| Cursor | Seatbelt | Landlock/bwrap | Blocked, allowlist |
| Windsurf | Allow/deny lists | Allow/deny lists | No OS-level sandbox |
| Cline | VS Code terminal | VS Code terminal | No sandbox |
| Aider | None | None | None |
| OpenCode | None documented | None documented | None |
| Pi | None | None | None |

## Memory/Persistence

| Tool | Persistent Memory | Auto-compaction | Session Resume |
|------|-------------------|-----------------|----------------|
| Claude Code | Auto memory (file-based) | No | Via transcripts |
| Codex CLI | SQLite memories | Yes | `codex resume` |
| Gemini CLI | `save_memory` to GEMINI.md | Yes (compression) | Checkpointing |
| Cursor | None | No | Checkpoints |
| Windsurf | Auto-generated memories | No | No |
| Cline | Memory Bank (methodology) | `/smol` compress | Task history |
| Aider | None | No | `--restore-chat-history` |
| OpenCode | SQLite sessions | Yes (~80% threshold) | Yes |
| Pi | None (extensions) | `/compact` | Tree sessions |

## Cross-Client Paths

The Agent Skills spec defines `.agents/skills/` as the universal cross-client path.
Tools that scan it: Claude Code, Codex, Gemini CLI, Cursor, Windsurf, Cline, OpenCode, Pi.
37 compatible tools total as of 2026-04-16.

## Nix Module Implications

### What jstack needs to generate per tool

| Tool | Config Files to Generate |
|------|-------------------------|
| Claude Code | `settings.json`, `.mcp.json`, `.lsp.json`, `CLAUDE.md`, `skills/*/SKILL.md`, `commands/*.md`, `agents/*.md`, `hooks/hooks.json` |
| Codex CLI | `config.toml`, `hooks.json`, `AGENTS.md`, skills dirs |
| Gemini CLI | `settings.json`, `GEMINI.md`, `commands/*.toml`, skills dirs, `gemini-extension.json` |
| Cursor | `rules/*.md` or `.mdc`, `mcp.json`, `hooks.json`, `AGENTS.md`, skills dirs |
| Windsurf | `rules/*.md`, `mcp_config.json`, `global_rules.md`, skills dirs, `workflows/*.md`, `hooks.json` |
| Cline | `cline_mcp_settings.json`, `.clinerules/*.md`, `.cline/skills/`, hooks |
| Aider | `.aider.conf.yml`, `.env`, `CONVENTIONS.md` |
| OpenCode | `opencode.json`, `AGENTS.md`, skills dirs |
| Pi | `settings.json`, `mcp.json`, `AGENTS.md`, skills dirs |

### Existing upstream Nix coverage (from nix-module-options.md)

| Tool | NixOS (nixpkgs) | Home Manager | nix-darwin | devenv |
|------|-----------------|--------------|------------|--------|
| Claude Code | package only | `programs.claude-code` (full) | — | `claude.code` (full) |
| Codex CLI | package only | `programs.codex` | — | — |
| Gemini CLI | package only | `programs.gemini-cli` | — | — |
| OpenCode | package only | `programs.opencode` | — | `opencode` |
| Aider | package only | `programs.aider-chat` (settings-only) | — | — |
| Cursor/Windsurf/Cline/Continue.dev | — | — | — | — |
| MCP (shared) | — | `programs.mcp` | — | (per-tool) |

jstack's differentiator: per-plugin `plugin.nix` → `plugin.json`+`.mcp.json`+`.lsp.json`,
plus multi-context deployment (HM / NixOS / nix-darwin) — no upstream counterpart.

## Documentation Access

| Tool | llms.txt | llms-full.txt | Docs MCP |
|------|----------|---------------|----------|
| Claude Code | code.claude.com/docs/llms.txt | Yes | No (use Context7) |
| Codex CLI | developers.openai.com/codex/llms.txt | Yes | developers.openai.com/mcp |
| Gemini CLI | geminicli.com/llms.txt | No | No (use Context7) |
| Cursor | cursor.com/llms.txt | No | No (use Context7) |
| Windsurf | docs.windsurf.com/llms.txt | Yes | No (use Context7) |
| Cline | docs.cline.bot/llms.txt | Yes | No (use Context7) |
| Aider | None | None | No (use Context7) |
| OpenCode | None | None | No (use Context7) |
| Pi | None | None | No |
| OpenClaw | docs.openclaw.ai/llms.txt | Yes | No |
| NanoClaw | docs.nanoclaw.dev/llms.txt | Yes | No |
| Agent Skills | agentskills.io/llms.txt | Yes | No |
| devenv | devenv.sh/llms.txt | No | mcp.devenv.sh + `devenv mcp` (stdio) |

Context7 MCP covers: Claude Code, Codex, Gemini CLI, Cursor, Windsurf, Cline, Aider, OpenCode.

## Tool Name Mapping

Exact built-in tool names per agent (for generating `allowed-tools` in SKILL.md):

| Operation | Claude Code | Codex CLI | Gemini CLI | OpenCode | Cline | Pi |
|-----------|------------|-----------|------------|----------|-------|-----|
| Read file | `Read` | (via `apply_patch`) | `read_file` | `read` | `read_file` | `read` |
| Write file | `Write` | (via `apply_patch`) | `write_file` | `write` | `write_to_file` | `write` |
| Edit file | `Edit` | `apply_patch` | `replace` | `edit` | `replace_in_file` | `edit` |
| Run shell | `Bash` | `shell` / `unified_exec` | `run_shell_command` | `bash` | `execute_command` | `bash` |
| Search files | `Glob` | `search_tool` | `glob` | `glob` | `search_files` | N/A |
| Search content | `Grep` | `search_tool` | `grep_search` | `grep` | `search_files` | N/A |
| List dir | (via Glob) | `search_tool` | `list_directory` | (via `glob`) | `list_files` | N/A |
| Ask user | `AskUserQuestion` | `request_permissions` | `ask_user` | `question` | `ask_followup_question` | N/A |
| Web fetch | `WebFetch` | `web_search` | `web_fetch` | `webfetch` | N/A | N/A |
| Web search | `WebSearch` | `web_search` | `google_web_search` | `websearch` | N/A | N/A |
| Plan mode | `EnterPlanMode`/`ExitPlanMode` | N/A | `enter_plan_mode`/`exit_plan_mode` | N/A | N/A | N/A |
| Task create | `TaskCreate` | `spawn_agents_on_csv` | `tracker_create_task` | `todowrite` | `new_task` | N/A |
| Task list | `TaskList` | N/A | `tracker_list_tasks` | `todowrite` | N/A | N/A |
| Activate skill | `Skill` | N/A | `activate_skill` | `skill` | N/A | N/A |
| MCP resource | `ListMcpResourcesTool`/`ReadMcpResourceTool` | (via MCP) | `list_mcp_resources`/`read_mcp_resource` | N/A | `use_mcp_tool`/`access_mcp_resource` | N/A |
| Save memory | (auto-memory file) | `memory_tool` | `save_memory` | N/A | N/A | N/A |
| Image view | (Read handles images) | `view_image` | (via `read_file`) | N/A | N/A | N/A |
| Notebook edit | `NotebookEdit` | N/A | N/A | N/A | N/A | N/A |

Notes:
- Cursor and Windsurf route tool calls internally; names are not directly addressable
  in the same way. Use their rule/hook systems for scoping instead.
- Cline has 13 built-in tools total (as listed) plus slash commands.
- Gemini CLI has 34 built-in tools total.
- Codex feature-gates tools via `[features]`: `shell`, `unified_exec`, `apply_patch`,
  `view_image`, `search_tool`, `web_search`, `js_repl`, `memory_tool`,
  `request_permissions`, `spawn_agents_on_csv`, `tool_suggest`.

### Common abstractions across tools

1. **Skills** — SKILL.md is near-universal (Claude, Codex, Gemini, Cursor, Windsurf, Cline, OpenCode, Pi)
2. **MCP servers** — JSON config with command/args/env (all except Aider and Pi)
3. **Instructions** — markdown file with tool-specific name (CLAUDE.md/AGENTS.md/GEMINI.md)
4. **Rules** — frontmatter-enabled conditional instructions (Cursor, Windsurf, Cline, Claude Code)
5. **Hooks** — event-driven scripts with JSON I/O (Claude, Codex, Gemini, Cursor, Windsurf, Cline)
6. **Sandbox** — OS-native isolation (Claude, Codex, Gemini, Cursor)

### 2026 additions

- **Windsurf hooks** added (12 events, previously unavailable)
- **Cline skills** added (cross-tool compat via `.claude/skills/`)
- **Cline hooks** added (8 events, executable scripts)
- **Cursor hooks** expanded to 21 events (from 17+)
- **Claude Code hooks** expanded to 31 events
- **Agent Skills** compatible tools: 37 (up from 36+)
- **Codex CLI** adds granular `approval_policy`, `apply_patch_tool`, `unified_exec`,
  `request_permissions_tool`, `view_image`, `tool_suggest`, `smart_approvals` flags
