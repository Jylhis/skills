# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

jstack is a Nix-managed multi-agent AI developer workflow configuration. It bundles skills, agents, commands, hooks, plugins, settings, and promptfoo evals into a system deployed via NixOS/nix-darwin/Home Manager modules or `scripts/install.bash`. The repo is cloned and symlinked into agent config dirs (~/.claude, ~/.codex, ~/.gemini) — it's referenced in-place, not installed as a package.

## Commands

All development happens inside devenv (`devenv shell` or direnv). To skip 1Password authentication (as done in CI), prefix commands with `SECRETSPEC_PROVIDER=env`:

    SECRETSPEC_PROVIDER=env devenv shell -- <command>
    SECRETSPEC_PROVIDER=env just lint

Key commands:

    just check          # Full validation: nix-instantiate, flake check, devenv test, statix, deadnix
    just build          # nix-build -A packages.default (builds jstack-runtime)
    just fmt            # nixfmt on all project nix files
    just lint           # treefmt + markdownlint-cli2 + jq settings.json
    just update         # Sync inputs: nix flake update → extract rev → update devenv.yaml → devenv update
    just verify         # Verify nixpkgs rev parity + build hash parity across nix-build/nix build/devenv
    just generate-settings    # Regenerate settings.json from settings.nix (canonical source)
    just generate-manifests   # Regenerate plugin.json/.mcp.json/.lsp.json from plugin.nix files
    just list-skills          # Discover all skills (local + third-party)

Eval commands (promptfoo):

    just eval                 # Run full eval suite
    just eval-fast            # Fast subset
    just eval-skill <name>    # Single skill
    just eval-plugin <name>   # Single plugin

`devenv test` runs 15 smoke tests covering tools, JSON validity, nix evaluation, module contracts, and nixpkgs rev parity.

When devenv.nix doesn't exist and a command/tool is missing, create ad-hoc environment:

    $ devenv -O languages.rust.enable:bool true -O packages:pkgs "mypackage mypackage2" shell -- cli args

See https://devenv.sh/ad-hoc-developer-environments/

## Architecture

### Input Resolution

`flake.nix` is the source of truth for pinned inputs (nixpkgs, promptfoo, flake-compat). Non-flake consumers re-enter the flake through `flake-compat`: `default.nix` is a thin shim that returns `flake.defaultNix`, and `_sources.nix` re-exports the input attrset for in-tree helpers that need raw source paths. Both paths produce identical store paths.

- `flake.nix` → deployment (NixOS/nix-darwin/HM module consumption, `nix build`, `nix flake check`)
- `default.nix` → non-flake entry point (`nix-build -A packages.default`) — a `flake-compat` shim
- `_sources.nix` → `{ nixpkgs, promptfoo }` sourced from the same `flake-compat` evaluation; used by in-tree helpers (`runtime/`, `tests/`, `lib/list-catalog.nix`)
- `devenv.yaml` → devenv inputs (nixpkgs pinned to same rev as flake.lock, synced via `just update`)

### Module System (module.nix)

Single module serving three contexts — detected at eval time:
- **Home Manager**: `home.file` symlinks via `mkOutOfStoreSymlink`
- **NixOS**: `systemd.tmpfiles.rules` with explicit owner
- **nix-darwin**: `system.activationScripts.postActivation` (mkdir + ln + chown)

Context detection: `isHomeManager = options ? home.homeDirectory`, `isDarwin = pkgs.stdenv.hostPlatform.isDarwin`.

The module discovers skills from local plugins (`plugins/*/skills/`) and third-party sources (`sources.nix` keys mapped to flake inputs via `_sources.nix` / `flake-compat`) via `lib/discover.nix`. Pure eval: module resolves everything from relative paths, never from `cfg.repoPath` at eval time.

### Runtime Package

`overlay.nix` adds `jstack-runtime` to nixpkgs. `runtime/default.nix` scans `plugins/*/plugin.nix`, collects their `packages` lists, and builds a `pkgs.buildEnv` combining them with base packages (pyright, typescript-language-server).

### Canonical Sources

- `settings.nix` → `settings.json` (regenerate with `just generate-settings`)
- `plugin.nix` → `.claude-plugin/plugin.json`, `.mcp.json`, `.lsp.json` (regenerate with `just generate-manifests`)
- `sources.nix` → third-party skill source config (keys must match flake input names)

## Plugin Structure

Each plugin lives in `plugins/<name>/` with a `plugin.nix` as source of truth:

```nix
{ pkgs }:
{
  name = "my-plugin";
  description = "...";
  packages = [ pkgs.some-tool ];     # Added to jstack-runtime PATH
  mcpServers = { ... };              # Optional: generates .mcp.json
  lspServers = { ... };              # Optional: generates .lsp.json
}
```

Skills live in `plugins/<name>/skills/<skill-name>/SKILL.md`. Discovery is recursive (up to maxDepth) — a directory containing SKILL.md is a skill; recursion stops there.

## Skill Structure

Each skill is a directory with a `SKILL.md` file:

```markdown
---
name: my-skill
description: "When to trigger this skill"
---
# Content — reference material, examples, best practices
```

Skill IDs are namespaced: `<plugin>:<skill>` (e.g., `nix-dev:flakes`).

## Adding Third-Party Sources

1. Add non-flake input to `flake.nix`: `my-source = { url = "github:owner/repo"; flake = false; };`
2. Run `nix flake lock`
3. Add entry to `sources.nix`: `my-source = { namespace = "my-ns"; skillsRoot = "path/to/skills"; };`

## Testing

- `nix flake check` — pure flake evaluation + module-eval checks (22 assertions across HM/NixOS/nix-darwin)
- `devenv test` — 15 smoke tests (tools, JSON, nix files, manifests, discovery, module eval, rev parity)
- `tests/module-eval.nix` — synthetic eval driver testing all module contexts + negative cases + pure-eval regression
- `just eval*` — promptfoo evaluation suite (routing, discovery, quality, adversarial)
