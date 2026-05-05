---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: |
  - Home Manager, nix-darwin, and nixpkgs module trees enumerated by GitHub Contents
    API against `nix-community/home-manager@master`, `LnL7/nix-darwin@master` (plus
    the canonical `module-list.nix`), and `NixOS/nixpkgs@nixos-unstable` under
    `nixos/modules/programs` and `nixos/modules/services`.
  - Individual module schemas extracted directly from raw `.nix` sources via
    WebFetch (raw.githubusercontent.com).
  - devenv options pulled live from the devenv MCP server
    (`mcp__devenv__search_options`) and cross-checked against
    `https://devenv.sh/integrations/claude-code/`.
  - Search engines (search.nixos.org, home-manager-options.extranix.com) were
    attempted but returned client-rendered shells; findings below are based on
    source-of-truth file inspection instead.
version: 1
---

# Nix Module Options for AI Tools

Scope: modules that generate configuration files (settings, agents, commands,
hooks, MCP servers, skills) for AI coding tools. LLM runtime daemons
(`services.ollama`, `services.litellm`, `services.open-webui`) are noted for
completeness but are out of scope for jstack's per-tool config generation.

## NixOS (nixpkgs)

Searched `nixos/modules/programs` (205 module files) and `nixos/modules/services`
on `nixos-unstable`.

### AI coding-tool modules in `programs.*`
None. No `programs.claude-code`, `programs.codex`, `programs.gemini-cli`,
`programs.cursor`, `programs.aider*`, `programs.opencode`, `programs.windsurf`,
`programs.cline`, `programs.continue`, or `programs.copilot*` module exists in
nixpkgs.

### AI-adjacent modules found
Under `nixos/modules/services/misc`:

| Option root | Scope | Notes |
|---|---|---|
| `services.ollama` | LLM runtime daemon | Not a coding-tool config generator |
| `services.litellm` | LLM proxy daemon | Not a coding-tool config generator |
| `services.open-webui` | LLM chat UI service | Not a coding-tool config generator |

Under `nixos/modules/programs` the only string matches for AI-adjacent terms
(`ai`, `mcp`, `llm`, etc.) are false positives: `extra-container.nix`,
`firejail.nix`, `proxychains.nix`.

### Packages (not modules) in nixpkgs
`claude-code`, `aider-chat`, `gemini-cli`, `codex`, `opencode`, `aichat`, `aiac`,
`fabric-ai`, and similar are packaged under `pkgs.*` but have no NixOS module
wrappers. Third-party flakes exist for Claude Code specifically
(`sadjow/claude-code-nix`, `ryoppippi/nix-claude-code`,
`numtide/llm-agents.nix`) but they package binaries only, not module systems.

## Home Manager

Source: `nix-community/home-manager` master branch, `modules/programs/` (module
count > 200). Nine AI-tool modules exist.

### `programs.claude-code`
Source: `modules/programs/claude-code.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | null | Package selection |
| `finalPackage` | package (readOnly) | — | Computed customized package |
| `enableMcpIntegration` | bool | false | Merge `programs.mcp.servers` into settings |
| `settings` | JSON attrs | `{}` | Becomes `~/.claude/settings.json` |
| `context` | lines\|path | `""` | Becomes `~/.claude/CLAUDE.md` |
| `plugins` | list of package\|path | `[]` | Plugin directories |
| `marketplaces` | attrs of package\|path | `{}` | Plugin marketplaces → `known_marketplaces.json` |
| `agents` | attrs of lines\|path | `{}` | → `.claude/agents/<name>.md` |
| `agentsDir` | nullable path | null | Directory symlinked to `.claude/agents/` |
| `commands` | attrs of lines\|path | `{}` | → `.claude/commands/<name>.md` |
| `commandsDir` | nullable path | null | Directory symlinked to `.claude/commands/` |
| `hooks` | attrs of lines | `{}` | → `.claude/hooks/` |
| `hooksDir` | nullable path | null | Directory symlinked to `.claude/hooks/` |
| `rules` | attrs of lines\|path | `{}` | → `.claude/rules/<name>.md` |
| `rulesDir` | nullable path | null | Directory symlinked to `.claude/rules/` |
| `outputStyles` | attrs of lines\|path | `{}` | → `.claude/output-styles/` |
| `skills` | attrs\|path | `{}` | → `~/.claude/skills/` |
| `lspServers` | JSON attrs | `{}` | Language-server configuration |
| `mcpServers` | JSON attrs | `{}` | MCP server configuration |

Generated files:
- `~/.claude/settings.json`
- `~/.claude/CLAUDE.md`
- `~/.claude/plugins/known_marketplaces.json`
- `~/.claude/agents/*.md`, `.claude/commands/*.md`, `.claude/rules/*.md`,
  `.claude/hooks/*`, `.claude/output-styles/*.md`
- `~/.claude/skills/` (directory symlink or per-skill)

### `programs.codex`
Source: `modules/programs/codex.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | null | Package selection |
| `enableMcpIntegration` | bool | false | Merge `programs.mcp.servers` into `settings.mcp_servers` |
| `settings` | nullable TOML | `{}` | → `config.toml` (TOML on v0.2.0+, YAML on older) |
| `context` | lines\|path | `""` | → `$CODEX_HOME/AGENTS.md` |
| `skills` | attrs of lines\|path, or path | `{}` | → `~/.agents/skills/` (v0.94.0+) or `~/.codex/skills/` |
| `rules` | attrs of lines\|path | `{}` | → `$CODEX_HOME/rules/<name>.rules` |

Generated files:
- `~/.codex/config.toml` or `~/.config/codex/config.toml`
- `~/.codex/AGENTS.md`
- `~/.agents/skills/<name>/` or `~/.codex/skills/<name>/`
- `~/.codex/rules/<name>.rules`

### `programs.gemini-cli`
Source: `modules/programs/gemini-cli.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | `pkgs.gemini-cli` | Package selection |
| `enableMcpIntegration` | bool | false | Merge `programs.mcp.servers` into settings |
| `settings` | JSON attrs | `{}` | → `~/.gemini/settings.json` |
| `commands` | attrs of submodule ({prompt, description}) | `{}` | → `~/.gemini/commands/<name>.toml` |
| `policies` | attrs of path\|TOML | `{}` | → `~/.gemini/policies/<name>.toml` |
| `defaultModel` | nullable string | null | Sets `$GEMINI_MODEL` |
| `context` | attrs of string\|path | `{}` | → `~/.gemini/<name>.md` |
| `skills` | attrs of string\|path, or path | `{}` | → `~/.gemini/skills/<name>/SKILL.md` |

Generated files as above; when `enableMcpIntegration=true` the `programs.mcp.servers`
tree is merged into `settings.mcpServers` (existing keys win).

### `programs.opencode`
Source: `modules/programs/opencode.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | `pkgs.opencode` | Package selection |
| `enableMcpIntegration` | bool | false | Merge from `programs.mcp.servers` |
| `settings` | JSON attrs | `{}` | → `opencode/opencode.json` |
| `tui` | JSON attrs | `{}` | → `opencode/tui.json` |
| `web.enable` | bool | false | Enable `opencode web` service |
| `web.extraArgs` | list of string | `[]` | Extra args for serve |
| `web.environmentFile` | nullable path | null | Env file for web service |
| `context` | string\|path | `""` | → `opencode/AGENTS.md` |
| `commands` | attrs\|path | `{}` | → `opencode/commands/` |
| `agents` | attrs\|path | `{}` | → `opencode/agents/` |
| `skills` | attrs\|path | `{}` | → `opencode/skills/` |
| `tools` | attrs\|path | `{}` | → `opencode/tools/<name>.ts` |
| `themes` | attrs\|path | `{}` | → `opencode/themes/<name>.json` |

Config written under `$XDG_CONFIG_HOME/opencode/`.

### `programs.aider-chat`
Source: `modules/programs/aider-chat.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | `pkgs.aider-chat` | Package selection |
| `settings` | YAML attrs | `{}` | → `~/.aider.conf.yml` |

Minimal surface: only settings passthrough. No agents/commands/context/skills
options.

### `programs.aichat`
Source: `modules/programs/aichat.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | `pkgs.aichat` | Package selection |
| `settings` | YAML attrs | `{}` | → `$XDG_CONFIG_HOME/aichat/config.yaml` |
| `agents` | attrs of YAML | `{}` | → `aichat/agents/<name>/config.yaml` |

### `programs.aiac`
Source: `modules/programs/aiac.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | `pkgs.aiac` | Package selection |
| `settings` | TOML attrs | `{}` | `aiac` config file |

### `programs.fabric-ai`
Source: `modules/programs/fabric-ai.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `package` | nullable package | `pkgs.fabric-ai` | Package selection |
| `enablePatternsAliases` | bool | false | Shell aliases for fabric patterns |
| `enableYtAlias` | bool | true | `yt` YouTube alias |
| `enableBashIntegration` | bool | shell-dependent | Bash init hook |
| `enableZshIntegration` | bool | shell-dependent | Zsh init hook |

### `programs.mcp`
Source: `modules/programs/mcp.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | false | Activate module |
| `servers` | JSON attrs | `{}` | → `$XDG_CONFIG_HOME/mcp/mcp.json` |

Central MCP registry consumed by `programs.claude-code`, `programs.codex`,
`programs.gemini-cli`, and `programs.opencode` when their
`enableMcpIntegration = true`.

### Absent from Home Manager
- `programs.cursor` — no module (Cursor IDE)
- `programs.windsurf` — no module
- `programs.cline` — no module
- `programs.continue` — no module (continue.dev)
- `programs.copilot-cli` — no module
- Standalone `programs.anthropic` / `programs.openai` clients — none

## nix-darwin

Source: `LnL7/nix-darwin` master branch, `modules/module-list.nix` (123 lines,
complete enumeration of all nix-darwin modules).

### AI coding-tool modules
None. The full `programs.*` set shipped by nix-darwin:
`_1password`, `_1password-gui`, `arqbackup`, `bash`, `direnv`, `fish`, `gnupg`,
`info`, `man`, `nix-index`, `ssh`, `tmux`, `vim`, `zsh`.

No AI tool has a first-party nix-darwin module. The `services.*` tree
(aerospace, autossh, buildkite-agents, emacs, github-runner, lorri, sketchybar,
skhd, yabai, tailscale, etc.) also contains no AI tool entries.

Practice on macOS: Home Manager is layered on top of nix-darwin; users get the
`programs.claude-code` / `programs.codex` / `programs.gemini-cli` /
`programs.opencode` modules via the HM module, not via nix-darwin itself.

## devenv

Source: devenv MCP server (`mcp__devenv__search_options`).

### `claude.code.*` (full tree)

Top-level:

| Option | Type | Default | Purpose |
|---|---|---|---|
| `claude.code.enable` | bool | false | Activate integration |
| `claude.code.model` | nullable string | null | Override default model |
| `claude.code.apiKeyHelper` | nullable string | null | Script that emits API key to stdout |
| `claude.code.cleanupPeriodDays` | nullable int | null | Transcript retention |
| `claude.code.forceLoginMethod` | nullable enum | null | "browser" \| "apiKey" |
| `claude.code.env` | attrs | `{}` | Env vars for Claude Code sessions |

`claude.code.permissions`:

| Option | Type | Default |
|---|---|---|
| `permissions.defaultMode` | nullable enum | null (`default`/`acceptEdits`/`plan`/`bypassPermissions`) |
| `permissions.disableBypassPermissionsMode` | nullable bool | null |
| `permissions.additionalDirectories` | list of string | `[]` |
| `permissions.rules.<name>.allow` | list of string | `[]` |
| `permissions.rules.<name>.ask` | list of string | `[]` |
| `permissions.rules.<name>.deny` | list of string | `[]` |
| `permissions.<name>.allow` | list of string | `[]` (legacy, backward compatible with `rules`) |
| `permissions.<name>.ask` | list of string | `[]` (legacy) |
| `permissions.<name>.deny` | list of string | `[]` (legacy) |

`claude.code.agents.<name>`:

| Option | Type | Default |
|---|---|---|
| `description` | string | — |
| `prompt` | string | — |
| `model` | nullable string | null |
| `permissionMode` | nullable enum | null |
| `proactive` | bool | false |
| `tools` | list of string | `[]` |

`claude.code.commands` — attrs per slash command (schema mirrors Claude Code
slash commands; option surfaces in tree as `commands` attr without submodule
breakdown in the search output).

`claude.code.hooks.<name>`:

| Option | Type | Default |
|---|---|---|
| `name` | string | `""` |
| `enable` | bool | true |
| `hookType` | enum | `"PostToolUse"` (covers PreToolUse, PostToolUse, PostToolUseFailure, Notification, UserPromptSubmit, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop, PreCompact, PermissionRequest, WorktreeCreate, WorktreeRemove, TeammateIdle, TaskCompleted, ConfigChange) |
| `matcher` | string (regex) | `""` |
| `command` | string | — |

A built-in `claude.code.hooks.git-hooks-run` is auto-enabled when
`git-hooks.enable = true`; it runs `git-hooks run` after Edit/MultiEdit/Write.

`claude.code.mcpServers.<name>`:

| Option | Type | Default |
|---|---|---|
| `type` | enum | — (`stdio`/`http`) |
| `command` | nullable string | null (stdio) |
| `args` | list of string | `[]` (stdio) |
| `env` | attrs of string | `{}` (stdio) |
| `url` | nullable string | null (http) |
| `headers` | attrs of string | `{}` (http) |

Default contains `"mcp.devenv.sh" = { type = "http"; url = "https://mcp.devenv.sh"; }`.

`claude.code.skills.<name>` (third-party discovery, jstack-style):

| Option | Type | Default |
|---|---|---|
| `source` | path | — |
| `namespace` | string | — |
| `skillsRoot` | string | `"."` |
| `maxDepth` | int | 5 |

Config generation target: devenv writes `.mcp.json` at the project root (from
`claude.code.mcpServers`) and generates `.claude/` artifacts in-project.

### `opencode.*`

| Option | Type | Default |
|---|---|---|
| `opencode.enable` | bool | false |
| `opencode.settings` | attrs | `{}` → `opencode.jsonc` |
| `opencode.mcp` | attrs | `{}` → `opencode.jsonc` under `mcp` key |
| `opencode.rules` | string | `""` → `.opencode/AGENTS.md` |
| `opencode.agents` | attrs\|path | `{}` → `.opencode/agents/` |
| `opencode.commands` | attrs\|path | `{}` → `.opencode/commands/` |
| `opencode.skills` | attrs\|path | `{}` → `.opencode/skills/<name>/SKILL.md` |
| `opencode.tools` | attrs\|path | `{}` → `.opencode/tools/` |
| `opencode.themes` | attrs\|path | `{}` → `.opencode/themes/` |
| `opencode.web.enable` | bool | false |
| `opencode.web.extraArgs` | list of string | `[]` |

### Other AI tools in devenv
No `codex.*`, `gemini.*`/`gemini-cli.*`, `cursor.*`, `aider.*`, `cline.*`, or
`windsurf.*` option namespace is present in the devenv option tree as of the
search above. Claude Code and OpenCode are the only first-class AI integrations.

## Summary Matrix

`G` = generator module (produces config files). `P` = package only (no module).
`-` = absent.

| Tool                | NixOS (nixpkgs) | Home Manager         | nix-darwin | devenv         |
|---------------------|-----------------|----------------------|------------|----------------|
| Claude Code         | P               | `programs.claude-code` G | -          | `claude.code` G |
| Codex CLI           | P               | `programs.codex` G   | -          | -              |
| Gemini CLI          | P               | `programs.gemini-cli` G | -        | -              |
| OpenCode            | P               | `programs.opencode` G | -         | `opencode` G   |
| Aider               | P               | `programs.aider-chat` G (settings-only) | - | -     |
| aichat              | P               | `programs.aichat` G  | -          | -              |
| aiac                | P               | `programs.aiac` G (settings-only) | - | -          |
| fabric-ai           | P               | `programs.fabric-ai` G (integration-only) | - | - |
| Cursor              | -               | -                    | -          | -              |
| Windsurf            | -               | -                    | -          | -              |
| Cline               | -               | -                    | -          | -              |
| Continue.dev        | -               | -                    | -          | -              |
| MCP (shared)        | -               | `programs.mcp` G     | -          | (per-tool)     |
| Ollama (runtime)    | `services.ollama` | -                  | -          | -              |
| LiteLLM (runtime)   | `services.litellm` | -                 | -          | -              |
| Open WebUI (runtime)| `services.open-webui` | -              | -          | -              |

## Gaps / Implications for jstack

1. **No NixOS-side AI coding-tool modules exist.** A jstack NixOS module that
   provisions `/etc/` or root-owned skill/rule directories would not overlap
   with any upstream option tree.

2. **No nix-darwin AI modules exist.** jstack's nix-darwin branch is free of
   collisions. Users on macOS get per-tool modules only through HM today.

3. **Home Manager covers four of jstack's target tools** (Claude Code, Codex,
   Gemini CLI, OpenCode) plus Aider/aichat/aiac/fabric-ai. Schemas converge on
   a common shape: `enable`, `package`, `settings`, `context`, `agents`,
   `commands`, `hooks`, `rules`, `skills`, `mcpServers`, `enableMcpIntegration`.
   Mismatches vs jstack's surface area:
   - HM `programs.claude-code` has `plugins`, `marketplaces`, `lspServers`
     (jstack also emits `.lsp.json` from `plugin.nix`); tree matches jstack's
     emitted file set for Claude.
   - HM `programs.codex` uses `~/.agents/skills/` (v0.94.0+) vs jstack symlinking
     into `~/.codex/`. Output path has moved upstream.
   - HM `programs.gemini-cli` stores skills at
     `~/.gemini/skills/<name>/SKILL.md`; matches jstack's namespacing assumption.
   - HM `programs.opencode` writes `opencode.json` (not `.jsonc`); devenv writes
     `.jsonc`. Emission format differs between ecosystems.
   - HM `programs.aider-chat` has no agents/skills/context surface — only
     `~/.aider.conf.yml`. Any "skills for Aider" concept would be net-new.
   - Cursor, Windsurf, Cline, Continue.dev: no upstream module anywhere. jstack
     would be first-party if it adds them.

4. **`programs.mcp` is the emerging shared registry** in Home Manager. Four HM
   AI modules already consume it via `enableMcpIntegration`. If jstack generates
   `.mcp.json` per tool, interop with `programs.mcp.servers` would let users
   declare MCP servers once across ecosystems.

5. **devenv's `claude.code.*` is the most complete schema in the ecosystem for
   Claude specifically**, with first-class permission rules (allow/ask/deny per
   tool), 18 hook types (most HM/jstack modules enumerate fewer), sub-agent
   submodules with `permissionMode` and `proactive`, and third-party skill
   discovery (`source`/`namespace`/`skillsRoot`/`maxDepth`) — the same schema
   jstack uses. devenv is project-scoped (writes `.mcp.json` and `.claude/` in
   repo), while HM is user-scoped (`~/.claude/`). Both shapes are needed.

6. **Cross-ecosystem duplication risk.** For Claude Code alone, there are now
   three independent option trees (HM `programs.claude-code`, devenv
   `claude.code`, jstack's module) plus two packaging flakes
   (`sadjow/claude-code-nix`, `ryoppippi/nix-claude-code`). jstack's
   differentiator — per-plugin `plugin.nix` source-of-truth generating
   `.claude-plugin/plugin.json` + `.mcp.json` + `.lsp.json` together, plus
   multi-context deployment (HM / NixOS / nix-darwin) — has no upstream
   counterpart.

7. **No upstream module emits a `plugin.json` / `.claude-plugin/` marketplace
   layout.** HM `programs.claude-code.marketplaces` accepts marketplace paths
   but does not generate per-plugin manifests. This is jstack-unique.
