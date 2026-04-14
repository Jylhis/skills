---
date: 2026-04-14
researcher: Claude Code (Opus 4.6)
method: web search + web fetch of GitHub repos and docs for OpenCode, Pi, OpenClaw, NanoClaw
versions:
  opencode: v0.0.55
  pi: v0.67.1
  openclaw: v2026.4.14
  nanoclaw: unversioned (commit 934f063, 2026-04-07)
---

# OpenCode

Go-based terminal AI coding agent (SST/AnomalyCo). 100K+ GitHub stars.
Originally `opencode-ai/opencode` (archived Sep 2025), continues as "Crush" at `anomalyco/opencode`.

## Config Files

`opencode.json` (or `.jsonc`), loaded with precedence:

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
Per-tool permissions: `allow`, `deny`, `ask`.

## Built-in Tools

`bash`, `edit`, `write`, `read`, `grep`, `glob`, `list`, `lsp`, `apply_patch`,
`skill`, `todowrite`, `webfetch`, `websearch` (Exa AI), `question`

## Skills

Agent Skills spec format. Discovery:
- `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` (project)
- `~/.config/opencode/skills/` (global)

Plugins: `.opencode/` dirs for agents, commands, modes, tools, themes.

## Memory

SQLite for sessions. Auto-compaction at ~80% context window.

## Binary Provisioning

npm, Homebrew, Arch, Chocolatey, Scoop, Docker.

---

# Pi

Minimal TypeScript terminal agent by Mario Zechner. "Primitives, not features."
Powers OpenClaw ecosystem. Integrated into Ollama (`ollama launch pi`).

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

## Memory

Compaction on overflow (lossy). Tree-structured sessions with branching.
No built-in persistent memory -- by design, left to extensions.

## Binary Provisioning

npm: `npm install -g @mariozechner/pi-coding-agent`.

---

# OpenClaw

Life-automation platform (not just coding). Uses Pi as underlying engine.
Connects to WhatsApp, Telegram, Slack, Discord, Signal, iMessage, Teams, etc.
Created by Peter Steinberger. 5,705+ skills on ClawHub marketplace.

## Config Files

- `~/.openclaw/openclaw.json` (JSON5) -- main config, hot-reloaded
- `~/.openclaw/.env` -- secrets
- Interactive: `openclaw onboard`, `openclaw configure`
- CLI: `openclaw config get/set/unset`
- Web UI: `http://127.0.0.1:18789`

Key sections: `agents`, `channels`, `session`, `gateway`, `mcp`, `cron`, `hooks`.

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

## Memory

Per-conversation isolation. Active Memory plugin. Persistent preference profile.
Per-group `CLAUDE.md` isolation.

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
