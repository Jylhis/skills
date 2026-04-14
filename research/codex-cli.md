---
date: 2026-04-14
researcher: Claude Code (Opus 4.6)
method: web fetch of GitHub repo openai/codex, web search for docs
version: rust-v0.121.0-alpha.9
---

# Codex CLI (OpenAI)

## Config Files

TOML-based, layered resolution (highest priority first):

1. CLI flags (`--model`, `-c key=value`)
2. Profile values (`--profile <name>`)
3. Project: `.codex/config.toml` (only if project trusted)
4. User: `~/.codex/config.toml` (or `$CODEX_HOME/config.toml`)
5. System: `/etc/codex/config.toml` (Unix only)
6. Built-in defaults

Other files:
- `~/.codex/history.jsonl` -- session transcripts
- `~/.codex/hooks.json` -- lifecycle hooks
- `~/.codex/log/codex-tui.log` -- audit log
- SQLite state DB (memories)

Schema: `codex-rs/core/config.schema.json` in repo.

## Settings Schema (key fields)

| Category | Fields |
|----------|--------|
| Model | `model`, `model_provider`, `model_context_window`, `model_reasoning_effort`, `model_instructions_file`, `review_model`, `personality` |
| Sandbox | `sandbox_mode` (read-only/workspace-write/danger-full-access), `approval_policy` (untrusted/on-request/never/granular) |
| Features | ~60 boolean flags: `multi_agent`, `web_search`, `undo`, `plugins`, `memories`, `memory_tool`, `image_generation`, `shell_tool`, `js_repl`, `codex_hooks`, etc. |
| MCP | `[mcp_servers.<id>]` sections |
| Shell | `[shell_environment_policy]`: `inherit` (all/core/none), `exclude`, `include_only`, `set` |
| History | `persistence` (save-all/none), `max_bytes` |
| TUI | `theme`, `animations`, `notifications`, `status_line` |
| Profiles | `[profiles.<name>]` -- named config presets |
| Projects | `[projects.<path>]`: `trust_level` |
| Memories | `generate_memories`, `use_memories`, `consolidation_model`, `max_rollout_age_days` |
| Skills | `[skills]`: `config` array, `bundled` |
| Plugins | `[plugins.<name>]`: `enabled` boolean |

## AGENTS.md Instructions

Plain markdown, no frontmatter. Discovery:

1. Global: `~/.codex/AGENTS.override.md` (else `~/.codex/AGENTS.md`)
2. Project: walk from git root to cwd, checking `AGENTS.override.md` then `AGENTS.md`

Files concatenate root-to-leaf. `AGENTS.override.md` takes precedence at same level.
Fallback filenames configurable via `project_doc_fallback_filenames`.
Size limit: `project_doc_max_bytes` (default 32 KiB).

Can import Claude's `CLAUDE.md` via `ExternalAgentConfigService`.

## MCP Servers

```toml
[mcp_servers.my-server]
command = "binary"           # stdio
args = ["--flag"]
url = "https://..."          # HTTP (alternative)
env = { KEY = "value" }
env_vars = ["PASSTHROUGH"]
enabled = true
enabled_tools = ["tool1"]    # allowlist
disabled_tools = ["tool3"]   # blocklist
startup_timeout_sec = 10.0
tool_timeout_sec = 30.0
supports_parallel_tool_calls = false
required = false
bearer_token_env_var = "TOKEN"
```

Per-tool approval: `[mcp_servers.name.tools.search] approval_mode = "approve"`

Codex can also act as an MCP server itself.

## Built-in Tools

Shell/exec (PTY-backed), file read/write/edit (apply-patch), web search (cached/live),
image input/generation, JS REPL, search tool, multi-agent/subagent, MCP tool calls,
computer use, shell snapshot, undo, git commit.

## Hooks

`hooks.json` adjacent to config layers. Must enable `codex_hooks = true` in features.

Events: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`.

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "shell",
      "hooks": [{
        "type": "command",
        "command": "python3 hook.py",
        "timeoutSec": 10
      }]
    }]
  }
}
```

Output: `continue`, `stopReason`, `decision` (approve/deny/block), `reason`, `systemMessage`.

## Memory

Persistent memory system (feature flags: `memories`, `memory_tool`):
- Extracted from session transcripts, consolidated via configurable model
- SQLite storage, injected at startup when `use_memories = true`
- Pollution guard: threads using MCP/web search excluded
- Session resume: `codex resume --last`

## Sandbox

OS-native:
- macOS: `sandbox-exec` with Seatbelt profiles
- Linux: `bwrap` (bubblewrap) + seccomp
- Windows: ACLs + desktop isolation + firewall

Protected paths: `.git`, `.agents/`, `.codex/` always read-only.
Network disabled by default in workspace-write mode.

## Binary Provisioning

Inherits system PATH, filtered by `[shell_environment_policy]`.
No built-in package management.
