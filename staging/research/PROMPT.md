---
date: 2026-04-14
researcher: Claude Code (Opus 4.6)
---

# Research Prompt

Self-contained prompt to reproduce all research documents in this directory.
Run this as a single prompt in Claude Code from the jstack repo root.

## Prompt

Research AI coding tool configuration and skill systems for building Nix modules
that generate correct config files per tool. Write findings to `research/` as
markdown files with YAML frontmatter (date, researcher, method, version).

### Tools to research

For each tool, document:
1. Config file locations and directory structure (global, project, user)
2. Settings/config schema and format (JSON/TOML/YAML, key fields)
3. Instruction/rules file format, name, frontmatter schema, hierarchy, inheritance
4. Skill/extension/plugin system (file format, discovery paths, activation)
5. MCP server configuration (config location, schema, transports, per-tool control)
6. LSP server configuration (if supported)
7. Hook system (events, handler types, config format)
8. Built-in tools available to the agent (exact tool names — needed for tool name mapping)
9. How binaries/packages are provided (PATH, sandbox model)
10. Memory/persistence system (auto-memory, session resume, compaction)
11. llms.txt availability (URL if exists)
12. Docs-as-MCP-server availability (official MCP server for accessing tool docs)

#### Documentation access methods

| Tool | llms.txt | llms-full.txt | Docs MCP server |
|------|----------|---------------|-----------------|
| Claude Code | https://code.claude.com/docs/llms.txt | Yes | No (use Context7) |
| Codex CLI | https://developers.openai.com/codex/llms.txt | Yes | https://developers.openai.com/mcp |
| Gemini CLI | https://www.geminicli.com/llms.txt | No | No (use Context7) |
| Cursor | https://cursor.com/llms.txt | No | No (use Context7) |
| Windsurf | https://docs.windsurf.com/llms.txt | Yes | No (use Context7) |
| Cline | https://docs.cline.bot/llms.txt | Yes | No (use Context7) |
| Aider | None | None | No (use Context7) |
| OpenCode | None | None | No (use Context7) |
| Pi | None | None | No |
| OpenClaw | https://docs.openclaw.ai/llms.txt | Yes | No |
| NanoClaw | https://docs.nanoclaw.dev/llms.txt | Yes | No |
| Agent Skills | https://agentskills.io/llms.txt | Yes | No |
| devenv | https://devenv.sh/llms.txt | No | mcp.devenv.sh + `devenv mcp` (stdio) |

Context7 MCP covers: Claude Code, Codex, Gemini CLI, Cursor, Windsurf, Cline, Aider, OpenCode.
OpenAI docs MCP: `https://developers.openai.com/mcp` (Streamable HTTP, docs at `developers.openai.com/learn/docs-mcp`).

#### Claude Code

Docs site: https://code.claude.com/docs
Full page index: https://code.claude.com/docs/llms.txt (127 pages)
Settings JSON schema: https://json.schemastore.org/claude-code-settings.json

Key pages (all under `https://code.claude.com/docs/en/`):

| Page | URL suffix |
|------|-----------|
| Features overview | `features-overview` |
| Settings | `settings` |
| Permissions | `permissions` |
| Permission modes | `permission-modes` |
| Skills | `skills` |
| Memory (CLAUDE.md) | `memory` |
| MCP | `mcp` |
| Hooks | `hooks` |
| Hooks guide | `hooks-guide` |
| Plugins | `plugins` |
| Plugins reference | `plugins-reference` |
| Plugin marketplaces | `plugin-marketplaces` |
| Sub-agents | `sub-agents` |
| Agent teams | `agent-teams` |
| Commands | `commands` |
| CLI reference | `cli-reference` |
| Routines | `routines` |
| Channels | `channels` |
| Scheduled tasks | `scheduled-tasks` |
| GitHub Actions | `github-actions` |
| Agent SDK overview | `agent-sdk/overview` |
| Agent SDK hooks | `agent-sdk/hooks` |
| Agent SDK MCP | `agent-sdk/mcp` |
| Agent SDK skills | `agent-sdk/skills` |
| Agent SDK plugins | `agent-sdk/plugins` |
| Agent SDK subagents | `agent-sdk/subagents` |
| Agent SDK custom tools | `agent-sdk/custom-tools` |

Focus on:
- **Config**: settings.json (JSON), 5 scopes (managed > cli > local > project > user)
- **Instructions**: CLAUDE.md (no frontmatter), hierarchy up dirs, @import syntax, CLAUDE.local.md
- **Rules**: .claude/rules/*.md with optional `paths:` frontmatter for glob scoping
- **Skills**: SKILL.md full frontmatter (name, description, paths, context, agent, model, effort, allowed-tools, hooks, shell, disable-model-invocation, user-invocable, argument-hint, when_to_use)
- **MCP**: .mcp.json, transports (stdio/http/sse), permission naming `mcp__<server>__<tool>`
- **LSP**: .lsp.json (command, extensionToLanguage, transport, initializationOptions)
- **Hooks**: 20+ events, 4 handler types (command/http/prompt/agent), exit codes
- **Tools**: Read, Write, Edit, Bash, Glob, Grep, Agent, WebFetch, WebSearch, AskUserQuestion, Skill, LSP, Monitor, NotebookEdit, TaskCreate/Update, EnterPlanMode, etc.
- **Sandbox**: seatbelt (macOS), filesystem/network allowlists in settings
- **Memory**: auto-memory (file-based), CLAUDE.md hierarchy, compaction: none
- **Plugins**: .claude-plugin/plugin.json, bin/ on PATH, skills/, commands/, agents/, hooks/
- **Permissions**: allow/deny/ask arrays with `Tool(specifier)` glob syntax

#### Codex CLI (OpenAI)

Docs site: https://developers.openai.com/codex
GitHub: https://github.com/openai/codex

Key pages (all under `https://developers.openai.com/codex/`):

| Page | URL suffix |
|------|-----------|
| CLI overview | `cli` |
| CLI features | `cli/features` |
| CLI reference | `cli/reference` |
| Slash commands | `cli/slash-commands` |
| Config basics | `config-basic` |
| Advanced config | `config-advanced` |
| Config reference | `config-reference` |
| Config sample | `config-sample` |
| Rules | `rules` |
| Hooks | `hooks` |
| AGENTS.md | `guides/agents-md` |
| MCP | `mcp` |
| Plugins | `plugins` |
| Skills | `skills` |
| Subagents | `subagents` |
| Auth/API keys | `auth#sign-in-with-an-api-key` |
| IDE extensions | `ide` |
| Speed | `speed` |

Focus on:
- **Config**: config.toml (TOML), 5 scopes (cli > profile > project > user > system). Schema: `codex-rs/core/config.schema.json`
- **Instructions**: AGENTS.md (no frontmatter), walk from git root to cwd, AGENTS.override.md precedence
- **Rules**: via AGENTS.md hierarchy + `rules` config key
- **Skills**: `[skills]` config section, follows Agent Skills spec
- **MCP**: `[mcp_servers.<id>]` in TOML, per-tool approval overrides, parallel call support
- **LSP**: unknown — check docs
- **Hooks**: hooks.json, 5 events (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop)
- **Tools**: shell/exec, file read/write/edit (apply-patch), web search, image gen, JS REPL, multi-agent, undo
- **Sandbox**: seatbelt (macOS), bwrap+seccomp (Linux), ACLs (Windows). Protected paths: .git, .agents/, .codex/
- **Memory**: SQLite persistent memory, consolidation model, session resume (`codex resume`)
- **Plugins**: `[plugins.<name>]` with enabled toggle
- **Permissions**: `approval_policy`, `default_permissions`, `sandbox_mode`, `shell_environment_policy`

#### Gemini CLI

Docs site: https://www.geminicli.com/docs/
GitHub: https://github.com/google-gemini/gemini-cli
Settings schema: https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json

Key pages (all under `https://www.geminicli.com/docs/`):

| Page | URL suffix |
|------|-----------|
| Getting started | `get-started` |
| Installation | `get-started/installation` |
| Authentication | `get-started/authentication` |
| Configuration | `reference/configuration` |
| GEMINI.md context | `cli/gemini-md` |
| Commands reference | `reference/commands` |
| Tools reference | `reference/tools` |
| MCP servers | `tools/mcp-server` |
| Writing extensions | `extensions/writing-extensions` |
| Sandboxing | `cli/sandbox` |
| Checkpointing | `cli/checkpointing` |
| Headless mode | `cli/headless` |
| IDE integration | `ide-integration` |

Focus on:
- **Config**: settings.json (JSON), 4 tiers (system-defaults < user < project < system-lockdown). Schema URL above
- **Instructions**: GEMINI.md (no frontmatter), hierarchy + JIT discovery, @import syntax, customizable filename
- **Rules**: via GEMINI.md hierarchy (no separate rules system)
- **Skills**: SKILL.md (Agent Skills spec), `activate_skill` tool, `gemini skills install|link|uninstall`
- **MCP**: settings.json `mcpServers`, 3 transports, `includeTools`/`excludeTools` per server, OAuth support
- **LSP**: unknown — check docs
- **Hooks**: 11 events (SessionStart/End, Before/AfterAgent, Before/AfterModel, BeforeToolSelection, Before/AfterTool, PreCompress, Notification)
- **Tools**: run_shell_command, glob, grep_search, list_directory, read_file, read_many_files, replace, write_file, ask_user, activate_skill, save_memory, enter/exit_plan_mode, tracker_*, google_web_search, web_fetch
- **Sandbox**: 5 modes (Seatbelt, Docker/Podman, Windows icacls, gVisor, LXC)
- **Memory**: save_memory appends to GEMINI.md, experimental memoryManager, checkpointing, context compression
- **Extensions**: gemini-extension.json manifest, bundles MCP+commands+skills+hooks+themes+policies
- **Commands**: TOML files in commands/ dirs, `{{args}}` placeholder, `!{cmd}` shell injection, `@{path}` file injection

#### Cursor

Docs site: https://cursor.com/docs

Key pages (all under `https://cursor.com/docs/`):

| Page | URL suffix |
|------|-----------|
| Agent | `agent` |
| Rules | `rules` |
| Hooks | `hooks` |
| Skills | `skills` |
| MCP | `mcp` |
| Plugins | `plugins` |
| CLI overview | `cli/overview` |
| Models and pricing | `models-and-pricing` |

Focus on:
- **Config**: UI-based (VS Code fork), no plain settings file for AI config
- **Instructions**: AGENTS.md (plain markdown, nested subdirs)
- **Rules**: .cursor/rules/*.md with frontmatter (description, globs, alwaysApply -> Always/Auto-Attach/Agent-Requested/Manual)
- **Skills**: via Marketplace plugins (Cursor 2.5+)
- **MCP**: .cursor/mcp.json (project + global), variables `${env:NAME}`, `${userHome}`, `${workspaceFolder}`, ~40 tool limit
- **LSP**: via VS Code extensions (not standalone config)
- **Hooks**: .cursor/hooks.json, 17+ events, command + prompt handler types
- **Tools**: Semantic Search, Search Files, Read Files, Edit Files, Run Shell, Web Search, Browser, Image Gen, Fetch Rules, Ask Questions
- **Sandbox**: Seatbelt (macOS), Landlock/bwrap (Linux), WSL2 (Windows). CURSOR_AGENT env var
- **Memory**: no persistent memory, checkpoints for revert
- **Plugins**: Marketplace (skills, subagents, MCP, hooks, rules)
- **Permissions**: sandbox.json network allowlist, command approval

#### Windsurf

Docs site: https://docs.windsurf.com
Full page index: https://docs.windsurf.com/llms.txt (80+ pages)

Key pages (all under `https://docs.windsurf.com/`):

| Page | URL suffix |
|------|-----------|
| Getting started | `windsurf/getting-started` |
| Cascade overview | `windsurf/cascade/cascade` |
| MCP | `windsurf/cascade/mcp` |
| Memories & rules | `windsurf/cascade/memories` |
| Workflows | `windsurf/cascade/workflows` |
| Skills | `windsurf/cascade/skills` |
| Hooks | `windsurf/cascade/hooks` |
| Modes | `windsurf/cascade/modes` |
| AGENTS.md | `windsurf/cascade/agents-md` |
| Worktrees | `windsurf/cascade/worktrees` |
| Advanced config | `windsurf/advanced` |
| Terminal | `windsurf/terminal` |
| Models | `windsurf/models` |
| Context awareness | `context-awareness/overview` |

Focus on:
- **Config**: UI-based (VS Code fork), enterprise rules at system paths
- **Instructions**: AGENTS.md (plain markdown, nested subdirs), global_rules.md (6000 char limit)
- **Rules**: .windsurf/rules/*.md with frontmatter (trigger: always_on/model_decision/glob/manual)
- **Skills**: .windsurf/skills/<name>/SKILL.md, also scans .agents/skills/ and .claude/skills/
- **MCP**: ~/.codeium/windsurf/mcp_config.json (global only), `disabledTools`, 100 tool hard limit
- **LSP**: via VS Code extensions (not standalone config)
- **Hooks**: check docs (previously reported as none — may have changed per docs.windsurf.com/windsurf/cascade/hooks)
- **Tools**: Search, Analyze, Read/Edit/Create, Run Command, Web Search, Planning — 20 calls/prompt limit
- **Sandbox**: allow/deny command lists, no OS-level sandbox. Dedicated zsh terminal (loads .zshrc)
- **Memory**: auto-generated memories in ~/.codeium/windsurf/memories/, machine-local
- **Workflows**: .windsurf/workflows/*.md, manual-only (/workflow-name), 12000 char limit
- **Ignore**: .codeiumignore (gitignore syntax)

#### Aider

Docs site: https://aider.chat/docs

Key pages (all under `https://aider.chat/docs/`):

| Page | URL suffix |
|------|-----------|
| Configuration | `config.html` |
| Options reference | `config/options.html` |
| YAML config file | `config/aider_conf.html` |
| Config with .env | `config/dotenv.html` |
| API keys | `config/api-keys.html` |
| Advanced model settings | `config/adv-model-settings.html` |
| Coding conventions | `usage/conventions.html` |
| In-chat commands | `usage/commands.html` |

Focus on:
- **Config**: .aider.conf.yml (YAML, 100+ settings), .env, 3-location search (home > git-root > cwd)
- **Instructions**: CONVENTIONS.md (plain markdown, loaded via --read flag)
- **Rules**: none (no frontmatter, no conditional rules)
- **Skills**: none
- **MCP**: none (no native MCP support)
- **LSP**: none
- **Hooks**: none
- **Tools**: 37+ in-chat commands (/add, /drop, /ask, /code, /architect, /run, /git, /lint, /test, /commit, /undo, /web, /voice)
- **Sandbox**: none
- **Memory**: none persistent (chat history in .aider.chat.history.md, readline in .aider.input.history)
- **Repo map**: tree-sitter indexing (100+ languages), graph-ranked
- **Watch mode**: monitors for AI!/AI?/AI comments in source files
- Document absences explicitly — Aider is deliberately simple

#### Cline

Docs site: https://docs.cline.bot
Full page index: https://docs.cline.bot/llms.txt (90+ pages)
GitHub: https://github.com/cline/cline

Key pages (all under `https://docs.cline.bot/`):

| Page | URL suffix |
|------|-----------|
| Quick start | `getting-started/quick-start` |
| Customization overview | `customization/overview` |
| Rules | `customization/cline-rules` |
| Skills | `customization/skills` |
| Workflows | `customization/workflows` |
| Hooks | `customization/hooks` |
| .clineignore | `customization/clineignore` |
| MCP overview | `mcp/mcp-overview` |
| MCP adding servers | `mcp/adding-and-configuring-servers` |
| MCP marketplace | `mcp/mcp-marketplace` |
| MCP transport | `mcp/mcp-transport-mechanisms` |
| Subagents | `features/subagents` |
| Memory bank | `features/memory-bank` |
| All tools reference | `tools-reference/all-cline-tools` |
| CLI overview | `cline-cli/overview` |
| CLI configuration | `cline-cli/configuration` |

Focus on:
- **Config**: VS Code settings.json under `cline.*`, cline_mcp_settings.json
- **Instructions**: none (rules serve this purpose)
- **Rules**: .clinerules/*.md with optional `paths:` frontmatter for conditional activation, numeric prefix ordering
- **Skills**: check docs (customization/skills page)
- **MCP**: cline_mcp_settings.json, STDIO + SSE, `alwaysAllow` per-server, can self-build MCP servers from GitHub URLs
- **LSP**: via VS Code (not standalone)
- **Hooks**: check docs (customization/hooks page)
- **Tools**: write_to_file, read_file, replace_in_file, search_files, list_files, list_code_definition_names, execute_command, browser_action (Puppeteer), use_mcp_tool, access_mcp_resource, ask_followup_question, attempt_completion, new_task
- **Sandbox**: VS Code terminal, no OS-level sandbox
- **Memory**: Memory Bank (methodology: 6 structured files in memory-bank/), checkpoints after each tool call, /smol compaction
- **Cross-tool compat**: auto-detects .cursorrules, .windsurfrules, AGENTS.md

#### OpenCode

GitHub (archived): https://github.com/opencode-ai/opencode (archived Sep 2025)
Successor: https://github.com/charmbracelet/crush
Schema: https://charm.land/crush.json

Focus on:
- **Config**: opencode.json (JSONC), 8-level precedence (remote > global > env > project > .opencode/ > env-content > managed > MDM)
- **Instructions**: AGENTS.md (walks up from cwd), falls back to CLAUDE.md
- **Rules**: via AGENTS.md + `instructions` config field (supports globs + remote URLs)
- **Skills**: Agent Skills spec, discovery: .opencode/skills/, .claude/skills/, .agents/skills/
- **MCP**: `mcp` field in config, stdio + remote HTTP (auto-OAuth), per-tool allow/deny/ask
- **LSP**: `lsp` tool (experimental)
- **Hooks**: unknown — check docs
- **Tools**: bash, edit, write, read, grep, glob, list, lsp, apply_patch, skill, todowrite, webfetch, websearch, question
- **Sandbox**: none documented
- **Memory**: SQLite sessions, auto-compaction at ~80% context window
- Note: project archived Sep 2025, successor is Crush (charmbracelet/crush)

#### Pi

Site: https://pi.dev
GitHub monorepo: https://github.com/badlogic/pi-mono
Coding agent: https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
Package browser: https://pi.dev/packages
Anti-MCP rationale: https://mariozechner.at/posts/2025-11-02-what-if-you-dont-need-mcp/

Key docs in GitHub (`packages/coding-agent/`):
- README (main docs, extensions, skills sections)
- `docs/models.md` — models configuration
- `docs/custom-provider.md` — custom provider guide
- `docs/rpc.md` — RPC protocol
- `examples/extensions/` — 50+ extension examples

Focus on:
- **Config**: settings.json (JSON), global (~/.pi/agent/) + project (.pi/), walks up dir tree
- **Instructions**: AGENTS.md / CLAUDE.md (all concatenated), SYSTEM.md replaces system prompt, APPEND_SYSTEM.md appends
- **Rules**: none (instructions serve this purpose)
- **Skills**: Agent Skills spec, .pi/skills/, ~/.pi/agent/skills/, .agents/skills/
- **MCP**: not built-in by design. Community adapters: pi-mcp-adapter, pi-mcp-tools extension
- **LSP**: none
- **Hooks**: via extensions only (TypeScript)
- **Tools**: only 4: read, write, edit, bash. Bash prefixes: !cmd (run+send), !!cmd (run only)
- **Sandbox**: none
- **Memory**: compaction on overflow (lossy), tree-structured sessions. No persistent memory (by design, left to extensions)
- **Extensions**: TypeScript modules — can replace/add tools, sub-agents, plan mode, permission gates
- **Pi Packages**: npm/git installable bundles of extensions/skills/prompts/themes

#### OpenClaw

Docs site: https://docs.openclaw.ai
Full page index: https://docs.openclaw.ai/llms.txt (250+ pages)

Key pages (all under `https://docs.openclaw.ai/`):

| Page | URL suffix |
|------|-----------|
| Getting started | `start/getting-started` |
| Gateway config | `gateway/configuration` |
| Config reference | `gateway/configuration-reference` |
| Config examples | `gateway/configuration-examples` |
| Skills | `tools/skills` |
| Creating skills | `tools/creating-skills` |
| Skills config | `tools/skills-config` |
| Plugins | `tools/plugin` |
| Slash commands | `tools/slash-commands` |
| Hooks | `automation/hooks` |
| CLI MCP | `cli/mcp` |
| CLI skills | `cli/skills` |
| CLI plugins | `cli/plugins` |
| Subagents | `tools/subagents` |
| Memory | `concepts/memory` |
| System prompt | `concepts/system-prompt` |
| Sandboxing | `gateway/sandboxing` |
| Plugin architecture | `plugins/architecture` |
| Building plugins | `plugins/building-plugins` |
| Plugin SDK | `plugins/sdk-overview` |

Focus on:
- **Config**: openclaw.json (JSON5), hot-reloaded by Gateway, schema validation
- **Instructions**: SOUL.md (personality/boundaries), IDENTITY.md (name/emoji/vibe), per-group CLAUDE.md
- **Rules**: none (SOUL.md serves this purpose)
- **Skills**: ClawHub marketplace (5700+ skills), workspace skills/ dir
- **MCP**: full host support (stdio/SSE/HTTP), `openclaw mcp set/list/show`, built-in mcporter skill
- **LSP**: none
- **Hooks**: webhooks in config, cron automation
- **Tools**: browser (CDP), canvas, system.run, cron, session tools, multi-channel messaging
- **Sandbox**: configurable per-agent
- **Memory**: session isolation, Active Memory plugin, persistent preference profile, per-group CLAUDE.md
- Life-automation platform (not just coding) — uses Pi engine underneath

#### NanoClaw

Docs site: https://docs.nanoclaw.dev
Full page index: https://docs.nanoclaw.dev/llms.txt (44 pages)
GitHub: https://github.com/qwibitai/nanoclaw

Key pages (all under `https://docs.nanoclaw.dev/`):

| Page | URL suffix |
|------|-----------|
| Quickstart | `quickstart` |
| Installation | `installation` |
| Architecture | `concepts/architecture` |
| Security | `concepts/security` |
| Skills system | `integrations/skills-system` |
| Creating skills | `api/skills/creating-skills` |
| Skill structure | `api/skills/skill-structure` |
| Configuration API | `api/configuration` |
| Group management | `api/group-management` |
| Customization | `features/customization` |
| Docker sandboxes | `advanced/docker-sandboxes` |
| Security model | `advanced/security-model` |

Focus on:
- **Config**: none by design ("modify the code"). .env for credentials, .mcp.json for MCP
- **Instructions**: CLAUDE.md at repo root + per-group groups/*/CLAUDE.md
- **Rules**: none (codebase IS the configuration)
- **Skills**: Claude Code skills (/setup, /customize, /add-whatsapp, etc.)
- **MCP**: .mcp.json (details sparse)
- **LSP**: none
- **Hooks**: none
- **Tools**: container execution, IPC (filesystem-based), SQLite persistence, message queue
- **Sandbox**: Docker containers per-group (all bash sandboxed inside)
- **Memory**: per-group CLAUDE.md isolation, SQLite for messages/sessions
- Container-first, ~4000 lines TypeScript, fork-and-modify model

#### Cross-client standard: Agent Skills spec

Spec site: https://agentskills.io/home
GitHub: https://github.com/agentskills/agentskills

Focus on: SKILL.md schema (name, description, license, compatibility, metadata,
allowed-tools), directory structure, 3-tier progressive disclosure,
.agents/skills/ cross-client path, 36+ compatible tools, skills-ref validation
library.

### Tool name mapping

For each tool, document the **exact built-in tool names** so we can build a
cross-agent tool name mapping in Nix. We need to map abstract operations to
each agent's specific tool name:

| Operation | Claude Code | Codex CLI | Gemini CLI | Cursor | Windsurf | OpenCode | Pi |
|-----------|------------|-----------|------------|--------|----------|----------|-----|
| Read file | `Read` | ? | `read_file` | ? | ? | `read` | `read` |
| Write file | `Write` | ? | `write_file` | ? | ? | `write` | `write` |
| Edit file | `Edit` | ? | `replace` | ? | ? | `edit` | `edit` |
| Run shell | `Bash` | ? | `run_shell_command` | ? | ? | `bash` | `bash` |
| Search files | `Glob` | ? | `glob` | ? | ? | `glob` | N/A |
| Search content | `Grep` | ? | `grep_search` | ? | ? | `grep` | N/A |
| Ask user | `AskUserQuestion` | ? | `ask_user` | ? | ? | `question` | N/A |
| Web fetch | `WebFetch` | ? | `web_fetch` | ? | ? | `webfetch` | N/A |
| Web search | `WebSearch` | ? | `google_web_search` | ? | ? | `websearch` | N/A |

Fill in the `?` cells from the docs. This mapping is critical for generating
`allowed-tools` fields in SKILL.md that work across agents.

### Nix module options research

Research existing Nix module options for AI tools across all module systems.
Document what options already exist, their structure, and gaps.

#### NixOS (nixpkgs)

Search nixpkgs for any existing AI tool modules:
- `programs.claude-code` or similar
- Any options under `services.*` for AI tools
- Check https://search.nixos.org/options for "claude", "codex", "gemini", "cursor", "aider"

#### Home Manager

Search home-manager for existing AI tool modules:
- Check https://home-manager-options.extranix.com/ or `nix-community/home-manager` repo
- Look for `programs.claude-code`, `programs.aider`, etc.
- Document option schemas for any that exist

#### nix-darwin

Search nix-darwin for existing AI tool modules:
- Check `LnL7/nix-darwin` repo for any AI tool options
- Look for `programs.*` or `services.*` related to AI tools

#### devenv

Search devenv for AI tool integrations:
- https://devenv.sh/integrations/claude-code/ (known)
- Check devenv MCP: use `mcp__devenv__search_options` tool to search for
  "claude", "ai", "agent", "codex", "gemini", "cursor"
- Document the full option tree for `claude.code.*`
- Check if devenv has options for other AI tools beyond Claude Code

For each module system, document:
1. Which AI tools have existing options
2. Option tree structure and types
3. What config files the options generate
4. Gaps (what's missing compared to the tool's full config surface)

### Nix repos to audit

For each repo, document: what it provides, module options exposed, how skills are
structured, how configs are generated, which AI tools supported, strengths, gaps,
package/binary management.

| Repo | URL |
|------|-----|
| rigup.nix | https://github.com/YPares/rigup.nix |
| agent-skills-nix | https://github.com/Kyure-A/agent-skills-nix |
| openskills | https://github.com/numman-ali/openskills |
| devenv Claude Code | https://devenv.sh/integrations/claude-code/ |
| llm-agents.nix | https://github.com/numtide/llm-agents.nix |

Key things to look for per repo:
- **rigup.nix**: riglet/rig abstractions, progressive disclosure (5 levels),
  denyRules, XDG isolation, mcpServers, Claude Marketplace import, uses llm-agents.nix
- **agent-skills-nix**: Home Manager module (programs.agent-skills), 8 target agents,
  package embedding in skill dirs, transform system, child flake pattern
- **openskills**: Node.js CLI (not Nix), openskills install/sync/read, AGENTS.md XML
- **devenv**: claude.code module options (hooks, commands, agents, mcpServers,
  permissions), most complete Claude Code config coverage
- **llm-agents.nix**: ~95 AI tool packages, daily updates, overlay

### Synthesis

Create `cross-tool-comparison.md` with side-by-side matrices covering:
- Config locations per tool
- Instruction file names and formats
- Skill/extension systems
- MCP support and config format
- LSP support
- Hook systems
- Built-in tools with **exact tool names per agent** (for tool name mapping table)
- Sandbox models
- Memory/persistence
- Cross-client paths
- llms.txt and docs MCP availability
- What Nix modules need to generate per tool
- Common abstractions across tools
- **Tool name mapping**: complete table mapping abstract operations (read, write, edit,
  shell, search-files, search-content, ask-user, web-fetch, web-search, plan-mode,
  create-task) to each agent's exact tool name. This drives the Nix `lib/tool-mappings.nix`.

### Output format

Each file: YAML frontmatter with date, researcher, method, version (from
`gh release list` or `gh api repos/owner/repo/commits`), then markdown body.
Keep content to essentials — schemas, key fields, paths, formats. No opinions.

### Post-processing

Retrieve version numbers via `gh release list -R <owner>/<repo> -L 1` and
`gh api repos/<owner>/<repo>/commits -q '.[0].sha'` for unversioned repos.
