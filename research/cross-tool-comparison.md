---
date: 2026-04-14
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
| Cline | VS Code ext data | `.clinerules/` | VS Code settings |
| Aider | `~/` | `<git-root>/` | YAML (`.aider.conf.yml`) |
| OpenCode | `~/.config/opencode/` | `./` | JSON (`opencode.json`) |
| Pi | `~/.pi/agent/` | `.pi/` | JSON (`settings.json`) |
| OpenClaw | `~/.openclaw/` | N/A | JSON5 (`openclaw.json`) |
| NanoClaw | N/A | repo root | None (code-level) |

## Instruction Files

| Tool | File | Format | Hierarchy |
|------|------|--------|-----------|
| Claude Code | `CLAUDE.md` | Markdown (no frontmatter) | Global + project + subdir + local. Additive. `@import` syntax. |
| Codex CLI | `AGENTS.md` | Markdown (no frontmatter) | Global + project walk. Override variants. Concatenate. |
| Gemini CLI | `GEMINI.md` | Markdown (no frontmatter) | Global + workspace + JIT. `@import` syntax. Customizable filename. |
| Cursor | `.cursor/rules/*.md` | YAML frontmatter (`description`, `globs`, `alwaysApply`) | Team > Project > User |
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
| Codex CLI | Skills via config | `.codex/skills/` | Config-based |
| Gemini CLI | `SKILL.md` + Extensions | `.gemini/skills/`, `.agents/skills/` | `activate_skill` + `/name` |
| Cursor | Marketplace plugins | Via marketplace | Auto |
| Windsurf | `SKILL.md` + Workflows | `.windsurf/skills/`, `.agents/skills/` | Auto + `@name` + `/workflow` |
| Cline | None (Memory Bank methodology) | N/A | N/A |
| Aider | None | N/A | N/A |
| OpenCode | `SKILL.md` | `.opencode/skills/`, `.agents/skills/` | Auto |
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
| Claude Code | `settings.json` `hooks` | 20+ events | command, http, prompt, agent |
| Codex CLI | `hooks.json` | 5 events | command |
| Gemini CLI | `settings.json` `hooks` | 11 events | command (JSON stdio) |
| Cursor | `.cursor/hooks.json` | 17+ events | command, prompt |
| Windsurf | None | N/A | N/A |
| Cline | None | N/A | N/A |
| Aider | None | N/A | N/A |
| OpenCode | None documented | N/A | N/A |
| Pi | Via extensions | N/A | TypeScript |

## Built-in Tools

| Tool | File Ops | Shell | Search | Web | Browser | Planning | Tasks | MCP | LSP |
|------|----------|-------|--------|-----|---------|----------|-------|-----|-----|
| Claude Code | R/W/E | Yes | Glob+Grep | Fetch+Search | No | Yes | Yes | Yes | Yes |
| Codex CLI | R/W/E | Yes | Yes | Yes | No | Yes | No | Yes | No |
| Gemini CLI | R/W/E | Yes | Glob+Grep | Google+Fetch | No | Yes | Yes (6 tools) | Yes | No |
| Cursor | R/W/E | Yes | Semantic | Yes | Yes | No | No | Yes | No |
| Windsurf | R/W/E | Yes | Semantic | Yes | No | Yes | No | Yes | No |
| Cline | R/W/E | Yes | Regex | No | Puppeteer | No | No | Yes | No |
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
Tools that scan it: Claude Code, Codex, Gemini CLI, Cursor, Windsurf, OpenCode, Pi.

## Nix Module Implications

### What jstack needs to generate per tool

| Tool | Config Files to Generate |
|------|-------------------------|
| Claude Code | `settings.json`, `.mcp.json`, `.lsp.json`, `CLAUDE.md`, `skills/*/SKILL.md`, `commands/*.md`, `agents/*.md`, `hooks/hooks.json` |
| Codex CLI | `config.toml`, `hooks.json`, `AGENTS.md`, skills dirs |
| Gemini CLI | `settings.json`, `GEMINI.md`, `commands/*.toml`, skills dirs, `gemini-extension.json` |
| Cursor | `rules/*.md`, `mcp.json`, `hooks.json`, `AGENTS.md`, skills dirs |
| Windsurf | `rules/*.md`, `mcp_config.json`, `global_rules.md`, skills dirs, `workflows/*.md` |
| Cline | `cline_mcp_settings.json`, `.clinerules/*.md` |
| Aider | `.aider.conf.yml`, `.env`, `CONVENTIONS.md` |
| OpenCode | `opencode.json`, `AGENTS.md`, skills dirs |
| Pi | `settings.json`, `mcp.json`, `AGENTS.md`, skills dirs |

### Common abstractions across tools

1. **Skills** -- SKILL.md is near-universal (Claude, Codex, Gemini, Cursor, Windsurf, OpenCode, Pi)
2. **MCP servers** -- JSON config with command/args/env (all except Aider and Pi)
3. **Instructions** -- markdown file with tool-specific name (CLAUDE.md/AGENTS.md/GEMINI.md)
4. **Rules** -- frontmatter-enabled conditional instructions (Cursor, Windsurf, Cline)
5. **Hooks** -- event-driven scripts with JSON I/O (Claude, Codex, Gemini, Cursor)
6. **Sandbox** -- OS-native isolation (Claude, Codex, Gemini, Cursor)
