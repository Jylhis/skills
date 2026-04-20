# jstack

Vibecoding setup. Fully managed with Nix. Bundles skills, agents, commands, hooks, settings, development environment, and promptfoo evals.

Currently only supports Claude Code, but Codex and Gemini support is in progress.

Installation with home-manager module or `scripts/install.bash`.

Docs: https://docs.jylhis.com/jstack

## Categories

All things are generally categorised under following categories:

- **supporting** - Not called by user directly, automatically loaded by models when needed e.g. rust-dev
- **workflow** - The main thing you call e.g. /review, /debug, /troubleshoot

## Layout

```
.
├── settings.nix               # canonical settings source (generates settings.json)
├── settings.json              # generated — do not edit directly
├── CLAUDE.md                  # source of truth for ~/.claude/CLAUDE.md
├── bundled-sources.nix        # upstream skill repos bundled as first-class jstack skills
├── skills/                    # personal skills (dir-per-skill, SKILL.md inside)
├── agents/                    # personal subagent .md files
├── commands/                  # personal slash command .md files
├── hooks/                     # hook scripts referenced from settings.json
├── plugins/                   # one directory per plugin (e.g. plugins/rust-dev/)
│   └── <plugin>/
│       ├── plugin.nix         # plugin metadata (source of truth)
│       ├── skills/            # plugin skills
│       ├── .claude-plugin/    # generated: plugin.json
│       ├── .mcp.json          # generated: MCP server config
│       └── .lsp.json          # generated: LSP server config
├── lib/                       # Nix library (discovery, manifests, bundles)
│   ├── default.nix            # library entry point
│   ├── targets.nix            # agent target definitions
│   ├── discover.nix           # recursive SKILL.md scanner
│   ├── manifest.nix           # manifest generators (plugin.json, .mcp.json, .lsp.json)
│   ├── bundle.nix             # bundle builder for third-party skills
│   └── list-catalog.nix       # convenience: list all discovered skills
├── runtime/default.nix        # pkgs.buildEnv with LSPs (auto-aggregates from plugin.nix)
├── modules/                   # multi-target module (NixOS / nix-darwin / Home Manager)
├── evals/                     # promptfoo eval suite
│   ├── promptfooconfig.yaml   # eval harness config
│   └── cases/                 # per-plugin test cases
├── docs/                      # Mintlify documentation site
├── flake.nix                  # source of truth for pinned inputs (nixpkgs, promptfoo, flake-compat)
├── flake.lock                 # pinned input revisions (read by flake + flake-compat)
├── _sources.nix               # flake-compat shim that exposes flake inputs to non-flake consumers
└── scripts/
    ├── install.bash           # link the repo into agent config dirs, build runtime
    └── eval.bash              # run promptfoo (--fast, --plugin)
```

## Plugin definition

Each plugin is defined by a `plugin.nix` file (source of truth). Manifests
(`plugin.json`, `.mcp.json`, `.lsp.json`) are generated from it.

```nix
{ pkgs }:
{
  name = "my-plugin";
  version = "1.0.0";
  description = "What this plugin provides";
  author.name = "Your Name";
  packages = [ pkgs.some-tool ];   # optional: added to runtime PATH
  mcpServers = { ... };            # optional: generates .mcp.json
  lspServers = { ... };            # optional: generates .lsp.json
}
```

## Bundling upstream skill repos

Pin external skill repos as non-flake inputs in `flake.nix`, then list
them in `bundled-sources.nix`. The module auto-registers each entry so
the upstream skills appear as first-class jstack skills to every
downstream consumer.

```nix
# flake.nix
{
  inputs = {
    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
  };
}
```

```bash
nix flake lock   # record the pinned revision in flake.lock
```

```nix
# bundled-sources.nix — key must match the flake input name
{
  anthropic-skills = {
    namespace = "anthropic";
    subdir = "skills";
    include = [ "pdf-processing" "document-skills" ];
  };
}
```

Update a single upstream: `nix flake update anthropic-skills`. Update
everything in lock-step (including devenv): `just update`.

List all discovered skills: `just list-skills`

## Consumer-side extras

Downstream NixOS / nix-darwin / Home Manager consumers append extra
skills, agents, and commands via standard attrset merge — no override
semantics. Example:

```nix
programs.jstack = {
  enable = true;
  skills.my-local-skill.src = ./skills/my-local-skill;
  skillSources.my-org = {
    src = inputs.my-org-skills;
    subdir = "skills";
    include = [ "linting" ];
  };
  agents.my-reviewer.src = ./agents/my-reviewer.md;
};
```
