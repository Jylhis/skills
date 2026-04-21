---
name: update-config
description: Use this skill to configure the Claude Code harness via settings.json. Automated behaviors ("from now on when X", "each time X", "whenever X", "before/after X") require hooks configured in settings.json - the harness executes these, not Claude, so merely instructing Claude in CLAUDE.md or in a prompt is insufficient. Trigger when the user asks to configure hooks, change permissions, set environment variables, add MCP servers, or make anything automatic.
---

# Update Claude Code Configuration

Configure the Claude Code harness by editing `settings.json`. The harness (not
Claude itself) reads this file at startup and enforces the behaviors it
declares. Instructions placed in CLAUDE.md or a chat prompt are advisory to
Claude but are NOT executed by the harness — only `settings.json` can do that.

## When this skill applies

Use this skill when the user wants any of:

- **Automated behavior** triggered by events ("whenever I save", "before every
  commit", "after each tool call", "from now on, run X when Y happens").
- **Permissions** — allow/deny specific tools, bash commands, file paths,
  network access, or mark certain directories as additional working
  directories.
- **Hooks** — `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Notification`,
  `Stop`, `SubagentStop`, `SessionStart`, `SessionEnd`, `PreCompact`.
- **Environment variables** exposed to Claude's tools.
- **MCP servers** — add, remove, or reconfigure.
- **Model / output style / status line** changes.
- **Sub-agent configuration** and tool enablement.

If the user merely wants Claude to behave differently *within a single
conversation*, that's a CLAUDE.md or prompt concern — not this skill.

## Settings file locations

Claude Code merges settings from several locations (later overrides earlier):

| Scope | Path | Used for |
|---|---|---|
| User | `~/.claude/settings.json` | Personal defaults across all projects |
| Project (shared) | `.claude/settings.json` | Checked into the repo |
| Project (local) | `.claude/settings.local.json` | Per-clone overrides; gitignored |
| Enterprise | platform-specific | Managed policies |

Pick the right scope before editing. Project-shared settings get committed and
affect everyone; local settings are for personal overrides.

## Workflow

1. **Read the existing file first.** Never blind-write `settings.json` — you
   will clobber unrelated configuration. Read, understand, then merge.
2. **Identify the right key** (`hooks`, `permissions`, `env`, `mcpServers`,
   `model`, `statusLine`, `outputStyle`, etc.).
3. **Merge, don't replace.** Append to arrays, extend objects. Preserve keys
   you didn't intend to change.
4. **Validate JSON.** The file must be strict JSON — no comments, no trailing
   commas. Run `jq . settings.json` if available.
5. **Explain to the user** what changed and, for hooks, how to test that the
   harness is actually picking them up (e.g. run a dummy tool call and check
   the hook fires).

## Hook anatomy

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/guard.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

- `matcher` filters which tool invocations the hook applies to (tool name,
  regex, or omitted to match all).
- `command` runs in a shell; exit codes and stdout JSON control whether the
  tool call proceeds.
- Hook scripts live under `.claude/hooks/` by convention and should be
  checked in alongside `settings.json` when committing project hooks.

## Permissions anatomy

```json
{
  "permissions": {
    "allow": ["Bash(git diff:*)", "Read(./**)"],
    "deny":  ["Bash(rm -rf:*)", "Write(/etc/**)"],
    "ask":   ["Bash(gh pr merge:*)"],
    "additionalDirectories": ["../sibling-repo"],
    "defaultMode": "acceptEdits"
  }
}
```

Permission entries use tool-specific matcher syntax — `Tool(pattern)`. Match
patterns are literal prefixes with `:*` wildcards for bash; glob patterns for
file tools.

## Verifying the change took effect

After editing, tell the user to either:

- Restart the session (easiest) — hooks and permissions only re-read on
  session start.
- Trigger the relevant event and confirm the hook command ran (check logs,
  side effects, or add a temporary `echo` to the hook script).

## Common pitfalls

- **Editing CLAUDE.md when a hook is needed.** If the user says "whenever X
  happens, do Y", Claude cannot guarantee it — only a harness hook can.
- **Forgetting to commit hook scripts** along with `settings.json`. A hook
  entry referencing a missing script silently no-ops or errors.
- **JSON syntax errors** make the whole file unreadable and fall back to
  defaults — always validate.
- **Scope confusion** — putting a personal preference in shared project
  settings, or putting a team-wide policy in `settings.local.json`.
