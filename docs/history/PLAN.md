> **Archived 2026-05-05.** Describes a prior `jstack v2` design that was
> not adopted. The current repo is a flat skills catalogue with one small
> Nix module — see top-level `README.md`.

# jstack v2 Plan

Remove plugins and manual install setups. Only support:
- NixOS modules
- Home Manager modules
- nix-darwin
- devenv
- plain nix

## Goals

1. Define own skills, import third-party skills, patch/extend third-party skills declaratively
2. Bundle tools, LSP, MCP servers with skills
3. Generate correct config files for each supported AI tool
4. Single module serving all deployment contexts (NixOS / HM / nix-darwin)

## Ideas

### Prefer scripts/skills over MCP

Only use MCP if really necessary and it provides value.
See: https://mariozechner.at/posts/2025-11-02-what-if-you-dont-need-mcp/

First see if same functionality can be provided by a script in `skills/<name>/scripts/`
with `allowed-tools: Bash(./scripts/*)` in the SKILL.md frontmatter.

### Tool name abstraction

Define tool references using generic Nix variables, then template them to each
agent's specific tool names. Example:

```nix
# In skill definition
allowedTools = [ tools.read tools.edit tools.bash tools.askUser ];

# Expands per-agent:
# Claude Code: "Read Edit Bash(npm run *) AskUserQuestion"
# Codex CLI:   "read_file edit shell ask_user"
# Gemini CLI:  "read_file replace run_shell_command ask_user"
# OpenCode:    "read edit bash question"
```

This lets skills be written once with abstract tool references and deployed
to any agent with correct tool names. The mapping lives in a Nix attrset
per tool (e.g., `lib/tool-mappings.nix`).

Known mapping (see `research/cross-tool-comparison.md` for full table):

| Operation | Claude Code | Codex CLI | Gemini CLI | OpenCode | Pi |
|-----------|------------|-----------|------------|----------|-----|
| Read file | `Read` | `read_file` | `read_file` | `read` | `read` |
| Write file | `Write` | `write_file` | `write_file` | `write` | `write` |
| Edit file | `Edit` | `apply_patch` | `replace` | `edit` | `edit` |
| Run shell | `Bash` | `shell` | `run_shell_command` | `bash` | `bash` |
| Search files | `Glob` | `search` | `glob` | `glob` | N/A |
| Search content | `Grep` | `search` | `grep_search` | `grep` | N/A |
| Ask user | `AskUserQuestion` | N/A | `ask_user` | `question` | N/A |

## Supported Tools

| Tool | Instruction File | Config Dir | Skills Path | MCP Config |
|------|-----------------|------------|-------------|------------|
| Claude Code | `CLAUDE.md` | `.claude/` | `.claude/skills/` | `.mcp.json` |
| Codex CLI | `AGENTS.md` | `.codex/` | `.codex/skills/` | `config.toml` `[mcp_servers]` |
| Gemini CLI | `GEMINI.md` | `.gemini/` | `.gemini/skills/` | `settings.json` `mcpServers` |
| Cursor | `AGENTS.md` | `.cursor/` | `.cursor/skills/` | `.cursor/mcp.json` |
| Windsurf | `.windsurfrules` | `.windsurf/` | `.windsurf/skills/` | `~/.codeium/windsurf/mcp_config.json` |
| OpenCode | `AGENTS.md` | `.opencode/` | `.opencode/skills/` | `opencode.json` `mcp` |
| Pi | `AGENTS.md` | `.pi/` | `.pi/skills/` | `mcp.json` (via ext) |
| Cline | `.clinerules/*.md` | VS Code ext | N/A | `cline_mcp_settings.json` |
| Aider | `CONVENTIONS.md` | `~/` | N/A | N/A |

Cross-client path: `.agents/skills/` (scanned by Claude, Codex, Gemini, Cursor, Windsurf, OpenCode, Pi).

## Module Options

### Core options (tool-agnostic)

```nix
programs.jstack = {
  enable = true;

  # Which tools to configure
  tools.claude-code.enable = true;
  tools.codex.enable = true;
  tools.gemini.enable = true;
  tools.cursor.enable = true;
  tools.windsurf.enable = true;
  tools.opencode.enable = true;
  # ... etc.

  # Skills (shared across all enabled tools)
  skills = {
    # Local skills
    my-skill = {
      src = ./skills/my-skill;           # dir with SKILL.md
      packages = [ pkgs.ripgrep ];       # bundled binaries
    };

    # Third-party skills (from flake inputs)
    imported = {
      source = inputs.some-skills;
      subdir = "skills";
      include = [ "skill-a" "skill-b" ]; # selective
      exclude = [];
      transform = skill: skill;          # patch SKILL.md
    };
  };

  # MCP servers (shared, generated per-tool format)
  mcpServers = {
    github = {
      command = "github-mcp-server";
      args = [ "--stdio" ];
      env = { GITHUB_TOKEN = "\${GITHUB_TOKEN}"; };
    };
  };

  # LSP servers
  lspServers = {
    typescript = {
      command = "typescript-language-server";
      args = [ "--stdio" ];
      extensionToLanguage = { ".ts" = "typescript"; ".tsx" = "typescriptreact"; };
    };
  };

  # Packages added to PATH for all tools
  packages = [ pkgs.ripgrep pkgs.fd pkgs.jq ];

  # Instructions (tool-agnostic, mapped to CLAUDE.md / AGENTS.md / GEMINI.md)
  instructions = ''
    Project-wide instructions here.
  '';
};
```

### Per-tool overrides

```nix
programs.jstack.tools.claude-code = {
  enable = true;
  model = "claude-sonnet-4-6";
  settings = { };                        # extra settings.json fields
  hooks = { };                           # Claude Code hooks
  commands = { };                        # slash commands
  agents = { };                          # subagent definitions
  permissions = {
    defaultMode = "normal";
    allow = [ "Read" "Glob" "Grep" ];
    deny = [ "Bash(rm -rf *)" ];
  };
  extraInstructions = ''
    Claude-specific additions to CLAUDE.md
  '';
};

programs.jstack.tools.gemini = {
  enable = true;
  settings = { };                        # extra settings.json fields
  hooks = { };                           # Gemini hooks
  commands = { };                        # TOML commands
  extensions = { };                      # Gemini extensions
  extraInstructions = ''
    Gemini-specific additions to GEMINI.md
  '';
};

programs.jstack.tools.codex = {
  enable = true;
  settings = { };                        # extra config.toml fields
  hooks = { };                           # Codex hooks
  sandboxMode = "workspace-write";
  extraInstructions = ''
    Codex-specific additions to AGENTS.md
  '';
};
```

### devenv integration

```nix
# devenv.nix
{ pkgs, ... }: {
  jstack = {
    enable = true;
    tools.claude-code.enable = true;
    skills.my-skill.src = ./skills/my-skill;
    mcpServers.github = { command = "github-mcp-server"; };
  };

  # Language-specific skills auto-discovered
  languages.rust.enable = true;  # -> activates rust skills if available
}
```

## Config Generation

The module generates per-tool config files and symlinks them:

| Tool | Generated Files |
|------|----------------|
| Claude Code | `settings.json`, `.mcp.json`, `.lsp.json`, `CLAUDE.md`, skills dirs, commands, agents, hooks |
| Codex CLI | `config.toml`, `hooks.json`, `AGENTS.md`, skills dirs |
| Gemini CLI | `settings.json`, `GEMINI.md`, `commands/*.toml`, skills dirs |
| Cursor | `rules/*.md`, `mcp.json`, `hooks.json`, `AGENTS.md`, skills dirs |
| Windsurf | `rules/*.md`, `mcp_config.json`, skills dirs, workflows |
| OpenCode | `opencode.json`, `AGENTS.md`, skills dirs |
| Pi | `settings.json`, `AGENTS.md`, skills dirs |
| Cline | `cline_mcp_settings.json`, `.clinerules/*.md` |
| Aider | `.aider.conf.yml`, `CONVENTIONS.md` |

## Deployment Contexts

Same module, three contexts (detected at eval time):

| Context | Mechanism | Why |
|---------|-----------|-----|
| Home Manager | `home.file.<name>.source = storePath` | Standard HM primitive. Symlinks `~/.claude/skills` -> `/nix/store/...-skills`. |
| NixOS | `systemd.tmpfiles.rules` `L+` -> store path | Only NixOS primitive for per-user home dir files without HM. Needs explicit owner. |
| nix-darwin | `system.activationScripts.postActivation` `ln -sfn` -> store path | nix-darwin has no tmpfiles equivalent. Runs as root, needs `chown -h`. |

Context detection (unchanged):
- `isHomeManager = options ? home.homeDirectory`
- `isDarwin = pkgs.stdenv.hostPlatform.isDarwin`

## Skill System

### Skill format

Follow Agent Skills spec (agentskills.io):
```
skill-name/
  SKILL.md          # Required (YAML frontmatter + markdown)
  scripts/          # Optional
  references/       # Optional
  assets/           # Optional
```

### Skill operations

1. **Define** -- local `SKILL.md` dirs
2. **Import** -- from flake inputs (third-party repos)
3. **Select** -- include/exclude by name
4. **Patch** -- transform function modifies SKILL.md content
5. **Bundle** -- attach packages (binaries symlinked into skill dir)
6. **Deploy** -- symlink to correct path per enabled tool

### Cross-client deployment

Skills deployed to `.agents/skills/` for cross-client discovery, plus tool-specific paths for tools that don't scan `.agents/`.

## Package Sources

- nixpkgs (base packages)
- numtide/llm-agents.nix (AI tool binaries, daily updates, ~95 packages)
- Custom overlay for additional packages

## References

### Specs
- https://agentskills.io/home -- Agent Skills open standard (36+ compatible tools)
- https://code.claude.com/docs/en/features-overview
- https://json.schemastore.org/claude-code-settings.json
- https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json

### Repos to follow
- https://github.com/YPares/rigup.nix -- progressive disclosure, denyRules, XDG isolation
- https://github.com/Kyure-A/agent-skills-nix -- 8 targets, package embedding, transforms
- https://github.com/numman-ali/openskills -- cross-tool skill installer
- https://devenv.sh/integrations/claude-code/ -- hooks, permissions, agents config
- https://github.com/numtide/llm-agents.nix -- canonical Nix package source for AI tools

### Research
- `research/agentskills-spec.md` -- Agent Skills open standard
- `research/claude-code.md` -- Claude Code full spec
- `research/codex-cli.md` -- OpenAI Codex CLI spec
- `research/gemini-cli.md` -- Google Gemini CLI spec
- `research/cursor-windsurf.md` -- Cursor + Windsurf specs
- `research/aider-cline.md` -- Aider + Cline specs
- `research/opencode-pi-openclaw-nanoclaw.md` -- OpenCode, Pi, OpenClaw, NanoClaw specs
- `research/nix-repos-audit.md` -- Full audit of 5 Nix repos
- `research/cross-tool-comparison.md` -- Cross-tool comparison matrix
