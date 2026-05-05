---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: web fetch of GitHub repos (rigup.nix, agent-skills-nix, openskills, llm-agents.nix) + devenv.sh docs
versions:
  rigup.nix: unversioned (commit 17d9079, 2026-04-16)
  agent-skills-nix: unversioned (commit e29bef0, 2026-03-27, unchanged)
  openskills: v1.5.0 (2026-01-17, unchanged)
  llm-agents.nix: unversioned (commit 1fb51db, 2026-04-16)
  devenv-claude-code: docs fetched 2026-04-16
---

# Nix Repos Audit

## 1. rigup.nix (github.com/YPares/rigup.nix)

**What it is:** Agent environment builder. Core abstraction: "riglet" (executable knowledge) composing into "rig" (full workspace). CLI: `rigup new|show|inspect|build|shell|run`. ~25 pre-built riglets.

**Module options:** Uses Nix module system internally (not NixOS/HM options). Riglet schema:
- `tools` -- packages (split into `wrapped`/`unwrapped`; wrapped get isolated XDG_CONFIG_HOME)
- `meta` -- `description`, `intent` (base/sourcebook/toolbox/cookbook/playbook), `disclosure` (none/lazy/shallow-toc/deep-toc/eager), `whenToUse`, `keywords`, `status`
- `docs` -- documentation folder
- `configFiles` -- merged into shared XDG_CONFIG_HOME
- `denyRules` -- per-tool command deny lists (e.g., `{ git = ["push" "pull"]; }`)
- `promptCommands` -- slash commands with description + template
- `entrypoint` -- launch script (one per rig)
- `mcpServers` -- MCP server definitions (stdio/HTTP)

**Config generation:** Merges all riglet configs via `symlinkJoin`, generates `RIG.md` manifest (XML-structured), permissions config, MCP JSON.

**Progressive disclosure:** 5 levels (none/lazy/shallow-toc/deep-toc/eager) controlling how much skill content appears in manifest.

**Tools supported:** Claude Code (primary), OpenCode, Cursor/cursor-agent, VSCode+Copilot, copilot-cli.

**Uses:** numtide/llm-agents.nix for packages.

**Strengths:** Most architecturally sophisticated. Progressive disclosure. XDG isolation. denyRules. Marketplace import.

**Gaps:** No NixOS/HM/nix-darwin modules. No eval/testing. Requires learning rigup abstractions.

---

## 2. agent-skills-nix (github.com/Kyure-A/agent-skills-nix)

**What it is:** Pure skill management with Home Manager integration. Manages SKILL.md directories only (no tool packaging).

**Module options (`programs.agent-skills`):**
- `sources.<name>.input` -- flake input
- `sources.<name>.subdir` -- skill subdirectory
- `sources.<name>.idPrefix` -- namespace prefix
- `sources.<name>.filter.maxDepth` / `nameRegex`
- `skills.enable` -- list of skill IDs
- `skills.enableAll` -- boolean or source list
- `skills.explicit.<name>.from/path/rename/packages/transform`
- `targets.<name>.enable/dest/structure/systems` (structure: link/symlink-tree/copy-tree)
- `excludePatterns` -- rsync exclusions

**Config generation:** `mkBundle` materializes skills into store derivation. Home Manager `home.file` entries or `rsync` activation scripts.

**8 targets:** claude, codex, copilot, cursor, windsurf, gemini, antigravity, agents (generic).

**Unique features:** Package embedding (symlink binaries into skill dirs via local `./jq` or `./pkg/` refs to reduce agent context consumption). Transform system (receives original content + markdown dependency table). Child flake pattern (parent flake + `./skills/flake.nix` for skill inputs). 7 test files.

**Gaps:** No NixOS/nix-darwin. No tool packaging. No MCP/LSP/hooks/settings generation.

---

## 3. openskills (github.com/numman-ali/openskills)

**What it is:** Node.js CLI (npm) for installing/managing SKILL.md files. NOT a Nix project. Still at v1.5.0 (last release 2026-01-17).

**How it works:** `openskills install <repo>`, `openskills sync` (updates AGENTS.md with XML skill catalog), `openskills read <name>` (progressive loading).

**Targets:** Claude Code, Cursor, Windsurf, Aider, Codex, anything reading AGENTS.md.

**Strengths:** Lowest barrier. Universal mode (`.agent/skills/`). Private repos.

**Gaps:** Not Nix. Imperative. No reproducibility. No config generation.

---

## 4. devenv Claude Code Integration (devenv.sh/integrations/claude-code/)

**What it is:** devenv module for declarative Claude Code configuration. Module has grown since last audit — now includes skill management and significantly expanded hook types.

**Module options (`claude.code`):**
- `enable`, `model`, `forceLoginMethod`, `apiKeyHelper`, `cleanupPeriodDays`, `env`
- `commands.<name>` -- slash commands (string pairs)
- `hooks.<name>` -- `enable`, `hookType`, `matcher`, `command`, `name`. Hook types expanded to: PreToolUse, PostToolUse, PostToolUseFailure, Notification, UserPromptSubmit, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop, PreCompact, PermissionRequest, WorktreeCreate, WorktreeRemove, TeammateIdle, TaskCompleted, ConfigChange
- `hooks.git-hooks-run` -- pre-configured auto-format hook
- `agents.<name>` -- `description`, `model`, `permissionMode`, `proactive`, `prompt`, `tools`
- `mcpServers.<name>` -- `type` (stdio/sse/http), `command`, `args`, `env`, `url`, `headers`. Default includes `mcp.devenv.sh` HTTP server.
- `permissions.defaultMode`, `disableBypassPermissionsMode`, `additionalDirectories`
- `permissions.rules.<name>.allow/ask/deny` (plus backward-compat `permissions.<name>.allow/ask/deny`)
- **NEW:** `skills.<name>.source/namespace/skillsRoot/maxDepth` -- third-party skill sources auto-discovered via `lib/discover.nix` and symlinked into `.claude/skills/`

**Config generation:** `.mcp.json`, settings, hook scripts, command files, skill symlinks.

**Strengths:** Most complete Claude Code config coverage. Permissions system. Agent config. Auto-format via git-hooks. Now has skill management (parity with jstack's discovery model).

**Gaps:** Claude Code only. No tool packaging. Tied to devenv.

---

## 5. llm-agents.nix (github.com/numtide/llm-agents.nix)

**What it is:** Package collection providing 95 AI tool binaries (verified via `packages/` directory count on 2026-04-16). Daily automated updates.

**What it packages:** Claude Code, Codex, Gemini CLI, Copilot, OpenCode, Goose, Amp, openskills, claudebox, and ~85 more.

**How:** Per-package `default.nix` + `package.nix`. Fetches pre-built binaries or builds from source. `makeWrapper` for env vars. Platform support: x86_64/aarch64 Linux/Darwin.

**Used by:** rigup.nix (as input).

**Strengths:** Largest AI tool package collection in Nix. Daily updates (latest commit 2026-04-16). Proper platform handling.

**Gaps:** Zero configuration. Packages only.

---

## Comparative Matrix

| Feature | jstack | rigup.nix | agent-skills-nix | openskills | devenv claude | llm-agents.nix |
|---------|--------|-----------|-------------------|------------|---------------|----------------|
| NixOS module | Yes | No | No | No | No | No |
| nix-darwin module | Yes | No | No | No | No | No |
| Home Manager module | Yes | No | Yes | No | No | No |
| Skill management | Yes | Yes (riglets) | Yes | Yes | Yes (new) | No |
| Progressive disclosure | No | Yes (5 levels) | No | Yes | No | No |
| MCP config | Yes | Yes | No | No | Yes | No |
| LSP config | Yes | Yes | No | No | No | No |
| Hooks/commands | No | Yes | No | No | Yes (17 hook types) | No |
| Permissions config | No | Yes (denyRules) | No | No | Yes | No |
| Tool packaging | Yes (buildEnv) | Yes | No | No | Via devenv | Yes (95 pkgs) |
| Multi-tool targets | 3 | 5 | 8 | 6 | 1 | N/A |
| Third-party sources | Yes | Yes | Yes | Yes | Yes (new) | N/A |
| Eval/testing | Yes | No | Yes | Yes | No | No |
| Package in skills | No | No | Yes | No | No | No |

## Key Takeaways for jstack

**Adopt from rigup.nix:** Progressive disclosure (5 levels). denyRules for safety. XDG isolation for tools.

**Adopt from agent-skills-nix:** 8 target agents. Package embedding in skills. Transform system for SKILL.md modification. Child flake pattern.

**Adopt from devenv integration:** Expanded hook taxonomy (17 types including SessionStart/End, WorktreeCreate, PermissionRequest, TaskCompleted). Commands, agents, permissions options. Auto-format via git-hooks. Their new `skills.<name>` option tree mirrors jstack's `sources.nix` — convergent design.

**Adopt from llm-agents.nix:** Use as package source (rigup.nix already does this).

**jstack unique advantages:** Only project with NixOS + nix-darwin + HM in single module. Only project with flake + non-flake entry points and module evaluation across supported targets.
