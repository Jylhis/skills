Research AI coding tool configuration and skill systems for building Nix modules
that generate correct config files per tool. Write findings to `research/` as
markdown files with YAML frontmatter (date, researcher, method, version).

### Tools to research

For each tool, document:
1. Config file locations and directory structure (global + project)
2. Settings/config schema and format (JSON/TOML/YAML, key fields)
3. Instruction/rules file format, name, frontmatter schema, hierarchy, inheritance
4. Skill/extension/plugin system (file format, discovery paths, activation)
5. MCP server configuration (config location, schema, transports, per-tool control)
6. Hook system (events, handler types, config format)
7. Built-in tools available to the agent
8. How binaries/packages are provided (PATH, sandbox model)
9. Memory/persistence system (auto-memory, session resume, compaction)

#### Primary tools (individual research docs each)

- **Claude Code** — fetch https://code.claude.com/docs/en/features-overview,
  /settings, /hooks, /mcp, /custom-slash-commands, /memory, /agent-skills.
  Also document LSP config (.lsp.json), plugin structure (.claude-plugin/plugin.json),
  and the full SKILL.md frontmatter schema (all fields including paths, context,
  agent, model, effort, allowed-tools, hooks, shell, disable-model-invocation).
  Settings JSON schema: https://json.schemastore.org/claude-code-settings.json

- **Codex CLI (OpenAI)** — fetch GitHub repo openai/codex README and docs.
  TOML config (config.toml), AGENTS.md hierarchy, hooks.json, MCP in TOML,
  sandbox (seatbelt/bwrap/windows), persistent memory (SQLite), profiles,
  shell_environment_policy, feature flags (~60 booleans).

- **Gemini CLI** — fetch GitHub repo google-gemini/gemini-cli README and docs.
  JSON settings, GEMINI.md with @import, TOML commands, extensions
  (gemini-extension.json), 5 sandbox modes, 11 hook events, activate_skill tool.
  Settings schema: https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json

- **Cursor** — web search for docs. .cursor/rules/*.md frontmatter (description,
  globs, alwaysApply → inferred types: Always/Auto-Attach/Agent-Requested/Manual),
  .cursor/mcp.json, .cursor/hooks.json (17+ events), AGENTS.md, Marketplace plugins,
  Seatbelt/Landlock sandbox.

- **Windsurf** — web search for docs. .windsurf/rules/*.md frontmatter (trigger:
  always_on/model_decision/glob/manual), ~/.codeium/windsurf/mcp_config.json
  (global only, 100 tool limit), SKILL.md, workflows (.windsurf/workflows/*.md),
  auto-generated memories, .codeiumignore, no hooks system.

- **Aider** — web search for aider.chat docs. .aider.conf.yml (YAML, 100+ settings),
  CONVENTIONS.md (plain markdown via --read), .aiderignore, no MCP, no skills,
  no plugins, repo map (tree-sitter), watch mode.

- **Cline** — web search for Cline VS Code extension docs. .clinerules/*.md
  (optional paths: frontmatter), cline_mcp_settings.json, 13 built-in tools
  including browser_action (Puppeteer), Memory Bank methodology, /smol compaction.

- **OpenCode** — fetch GitHub repo opencode-ai/opencode. opencode.json (JSONC),
  AGENTS.md (falls back to CLAUDE.md), MCP with per-tool allow/deny/ask,
  SQLite sessions, auto-compaction at ~80%, skills following Agent Skills spec.

- **Pi** — fetch GitHub repo badlogic/pi-mono. Only 4 built-in tools (read/write/
  edit/bash), no built-in MCP (by design), 3-tier extensibility (prompts/skills/
  extensions as TypeScript modules), SYSTEM.md replaces system prompt,
  Pi Packages (npm/git install).

- **OpenClaw** — fetch GitHub repo openclaw/openclaw and docs.openclaw.ai.
  Life-automation platform using Pi engine, SOUL.md + IDENTITY.md,
  multi-channel (WhatsApp/Telegram/Slack/Discord/Signal/iMessage),
  ClawHub marketplace (5700+ skills), openclaw.json (JSON5).

- **NanoClaw** — fetch GitHub repo qwibitai/nanoclaw. Container-first,
  no config files by design, per-group CLAUDE.md, Claude Code skills as
  extensibility, fork-and-modify model.

#### Cross-client standard

- **Agent Skills spec** — fetch https://agentskills.io/home and GitHub repo
  agentskills/agentskills. SKILL.md schema (name, description, license,
  compatibility, metadata, allowed-tools), directory structure, 3-tier
  progressive disclosure, .agents/skills/ cross-client path, 36+ compatible tools.

### Nix repos to audit

For each repo, document: what it provides, module options exposed, how skills are
structured, how configs are generated, which AI tools supported, strengths, gaps,
package/binary management.

- **rigup.nix** — https://github.com/YPares/rigup.nix — riglet/rig abstractions,
  progressive disclosure (5 levels), denyRules, XDG isolation, mcpServers,
  Claude Marketplace import, uses llm-agents.nix.

- **agent-skills-nix** — https://github.com/Kyure-A/agent-skills-nix — Home Manager
  module (programs.agent-skills), 8 target agents, package embedding in skill dirs,
  transform system, child flake pattern.

- **openskills** — https://github.com/numman-ali/openskills — Node.js CLI (not Nix),
  openskills install/sync/read, AGENTS.md XML generation.

- **devenv Claude Code integration** — https://devenv.sh/integrations/claude-code/ —
  claude.code module options (hooks, commands, agents, mcpServers, permissions),
  most complete Claude Code config coverage.

- **llm-agents.nix** — https://github.com/numtide/llm-agents.nix — ~95 AI tool
  packages, daily updates, overlay.

### Synthesis

Create `cross-tool-comparison.md` with side-by-side matrices covering:
- Config locations per tool
- Instruction file names and formats
- Skill/extension systems
- MCP support and config format
- Hook systems
- Built-in tools
- Sandbox models
- Memory/persistence
- Cross-client paths
- What Nix modules need to generate per tool
- Common abstractions across tools

### Output format

Each file: YAML frontmatter with date, researcher, method, version (from
`gh release list` or `gh api repos/owner/repo/commits`), then markdown body.
Keep content to essentials — schemas, key fields, paths, formats. No opinions.

### Post-processing

Retrieve version numbers via `gh release list -R <owner>/<repo> -L 1` and
`gh api repos/<owner>/<repo>/commits -q '.[0].sha'` for unversioned repos.
