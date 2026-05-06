---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: web search + web fetch of GitHub repos and docs for OpenCode, Pi, OpenClaw, NanoClaw
versions:
  opencode: v1.4.6 (anomalyco/opencode, 2026-04-15)
  pi: v0.67.5 (2026-04-16)
  openclaw: v2026.4.16 (rolling)
  nanoclaw: unversioned (commit eba94b7, 2026-04-16)
---

# OpenCode

TypeScript-based terminal AI coding agent. 144k+ GitHub stars, 16.3k forks.
Originally `opencode-ai/opencode` (archived Sep 2025, ~12k stars). Now active at
`anomalyco/opencode`; `github.com/sst/opencode` 301-redirects to the same repo
(SST transferred ownership to AnomalyCo). Not to be confused with
`charmbracelet/crush` -- a distinct agent ("Glamourous agentic coding")
with its own JSON config and skills discovery (`.crush/skills`, `.agents/skills`).

## Config Files

`opencode.json` or `opencode.jsonc` (JSONC supported), loaded with precedence:

1. Remote org config (`.well-known/opencode`)
2. Global: `~/.config/opencode/opencode.json`
3. `OPENCODE_CONFIG` env var
4. Project: `opencode.json`
5. `.opencode/` directories
6. `OPENCODE_CONFIG_CONTENT` env var
7. Managed: `/Library/Application Support/opencode/` (macOS), `/etc/opencode/` (Linux)
8. macOS MDM preferences (highest)

Configs merged. Supports `{env:VAR}` and `{file:path}` substitution.

## Instructions

- `AGENTS.md` in project root (traverses up) -- primary
- `~/.config/opencode/AGENTS.md` -- global
- Falls back to `CLAUDE.md` if no `AGENTS.md` found
- Additional via `instructions` field (supports globs + remote URLs)
- `/init` auto-generates `AGENTS.md`

## MCP

Full support in `mcp` field. Stdio + remote HTTP (auto-OAuth).
Per-tool permissions: `allow`, `deny`, `ask`. Org-managed servers can ship
disabled-by-default.

## Built-in Tools (13)

`bash`, `edit`, `write`, `read`, `grep`, `glob`, `lsp`, `apply_patch`,
`skill`, `todowrite`, `webfetch`, `websearch` (Exa AI), `question`

## Skills

Agent Skills spec format. Six discovery paths (project walks up to git
worktree, global from home):

- `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` (project)
- `~/.config/opencode/skills/`, `~/.claude/skills/`, `~/.agents/skills/` (global)

Plugins: `.opencode/` dirs for agents, commands, modes, tools, themes.

## Memory

SQLite for sessions. Auto-compaction at ~80% context window.

Two built-in agents: `build` (full-access) and `plan` (read-only).

## Binary Provisioning

npm, Homebrew, Arch, Chocolatey, Scoop, Docker; desktop apps for macOS/Windows/Linux.

---

# Pi

Minimal TypeScript terminal agent by Mario Zechner. "Primitives, not features."
Powers OpenClaw ecosystem. 36.3k stars. Monorepo (`badlogic/pi-mono`) contains
seven packages: `pi-ai`, `pi-agent-core`, `pi-coding-agent`, `pi-mom`,
`pi-tui`, `pi-web-ui`, `pi-pods`.

## Config Files

Global: `~/.pi/agent/`
- `settings.json`, `AGENTS.md`/`CLAUDE.md`, `SYSTEM.md`, `APPEND_SYSTEM.md`
- `keybindings.json`, `models.json`, `mcp.json`
- `sessions/`, `prompts/`, `skills/`, `extensions/`, `themes/`

Project: `.pi/` (walks up directory tree)
- `settings.json`, `AGENTS.md`/`CLAUDE.md`, `SYSTEM.md`
- `prompts/`, `skills/`, `extensions/`, `themes/`

Cross-client: `~/.agents/skills/`, `.agents/skills/`

All `AGENTS.md`/`CLAUDE.md` files concatenated.

## Instructions

- `AGENTS.md` / `CLAUDE.md` -- concatenated from all scopes
- `SYSTEM.md` -- completely replaces default system prompt
- `APPEND_SYSTEM.md` -- appends to default system prompt

## MCP

**Not built-in by design.** Community adapters exist:
- `pi-mcp-adapter` (npm)
- `pi-mcp-tools` extension
- Config in `mcp.json` via extensions

## Built-in Tools (only 4)

`read`, `write`, `edit`, `bash`

Bash prefixes: `!command` (run + send to LLM), `!!command` (run only).

## Extensibility (3 tiers)

1. **Prompt Templates**: Markdown in `prompts/`, Mustache variables, invoked via `/name`
2. **Skills**: Agent Skills spec (`SKILL.md`), invoked via `/skill:name`
3. **Extensions**: TypeScript modules -- can replace/add tools, sub-agents, plan mode, permission gates, custom UI

**Pi Packages**: bundle extensions/skills/prompts/themes. Install from npm or git.

Four run modes: interactive terminal, print/JSON output, RPC protocol, SDK embedding.

## Memory

Compaction on overflow (lossy). Tree-structured sessions with branching.
No built-in persistent memory -- by design, left to extensions.

## Binary Provisioning

npm: `npm install -g @mariozechner/pi-coding-agent`.

---

# OpenClaw

Life-automation platform (not just coding). Uses Pi as underlying engine.
Self-hosted gateway connecting Discord, Google Chat, iMessage, Matrix,
Microsoft Teams, Signal, Slack, Telegram, WhatsApp, Zalo, and more to AI
coding agents. Created by Peter Steinberger. ClawHub marketplace at
https://clawhub.ai (skill count not published in docs).

## Config Files

- `~/.openclaw/openclaw.json` (JSON5 -- comments + trailing commas) -- main config
- `~/.openclaw/.env` -- secrets
- Reload modes: `hybrid` (default, auto-restart when needed), `hot`, `restart`
- Strict schema: unknown keys or invalid types refuse to start the Gateway
- Env: `OPENCLAW_HOME`, `OPENCLAW_STATE_DIR`, `OPENCLAW_CONFIG_PATH`
- Interactive: `openclaw onboard`, `openclaw configure`
- CLI: `openclaw config get/set/unset`
- Web UI: `http://127.0.0.1:18789`

Key sections: `channels`, `agents`, `session`, `gateway`, `mcp`, `cron`,
`hooks`, `skills`, `security`.

## Instructions

- `SOUL.md` -- personality/philosophy/boundaries (per-agent)
- `IDENTITY.md` -- name/emoji/vibe (per-agent)
- Per-group `CLAUDE.md` for isolated memory
- Pi engine reads `AGENTS.md`/`CLAUDE.md` from project dirs

## MCP

Full host support. Stdio + SSE/HTTP + streamable-http.
`openclaw mcp set/list/show/unset`. Built-in `mcporter` skill.
`openclaw mcp serve` exposes bridge tools.

## Built-in Tools

Browser (CDP), Canvas, Camera/screen/location/notifications,
`system.run`, cron/webhooks, session management, multi-channel messaging.

## Skills

AgentSkills spec. Six-path precedence (highest to lowest):

1. Workspace: `<workspace>/skills`
2. Project agent: `<workspace>/.agents/skills`
3. Personal agent: `~/.agents/skills`
4. Managed/local: `~/.openclaw/skills`
5. Bundled (ships with install)
6. `skills.load.extraDirs` from config

Per-skill config under `skills.entries`: `enabled`, `env`, `apiKey`, `config`.
Parser requires single-line frontmatter keys.

## Memory

Per-conversation isolation. Active Memory plugin. Persistent preference profile.
Memory engines: builtin, Honcho, QMD. Per-group `CLAUDE.md` isolation.

## Binary Provisioning

npm: `npm install -g openclaw@latest`. Gateway daemon on `ws://127.0.0.1:18789`.

---

# NanoClaw

Lightweight container-first alternative to OpenClaw. ~4000 lines TypeScript.
Runs Claude agents in Docker containers. Built on Claude Agent SDK.

## Config

**No config files by design.** "Want different behavior? Modify the code."
- `.env` for credentials
- Per-group `groups/*/CLAUDE.md` for memory
- `.mcp.json` for MCP servers

## Instructions

- `CLAUDE.md` at repo root
- Per-group `CLAUDE.md` in `groups/<name>/`
- Codebase IS the configuration

## Tools

Container execution, IPC (filesystem-based), SQLite persistence, message queue.
All bash sandboxed inside containers.

## Skills

Claude Code skills as primary extensibility. `/setup`, `/customize`, `/add-whatsapp`, etc.
No runtime plugin system -- all customization via code modification in your fork.

## Binary Provisioning

Fork the repo, run `claude` inside it. `/setup` handles deps.
