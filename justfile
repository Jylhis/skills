default:
    @just --list --justfile {{justfile()}}

# Run all checks (lint + typecheck)
check:
    nix-instantiate --eval default.nix > /dev/null
    nix flake check --no-build
    devenv test
    statix check . --ignore '.devenv/*' 'result/*'
    deadnix --fail --exclude .devenv result .
    python3 scripts/validate_skills.py

# Run module evaluation tests directly
check-modules:
    nix eval --impure --raw --apply 'f: f {}' --file tests/module-eval.nix

# Format all nix files
fmt:
    nixfmt .

# Build the default package
build:
    nix-build -A packages.default

# Update all inputs in sync: flake.lock → devenv.yaml → devenv.lock
update:
    #!/usr/bin/env bash
    set -euo pipefail
    before=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock 2>/dev/null || echo none)
    nix flake update
    after=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    echo "nixpkgs: $before -> $after"
    # Portable (BSD/GNU) in-place edit without -i'' quoting quirks.
    tmp=$(mktemp)
    sed "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$after|" devenv.yaml > "$tmp"
    mv "$tmp" devenv.yaml
    grep -q "url: github:NixOS/nixpkgs/$after" devenv.yaml \
      || { echo "FAIL: devenv.yaml sync failed"; exit 1; }
    devenv update
    devenv_rev=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)
    [ "$devenv_rev" = "$after" ] \
      || { echo "FAIL: devenv.lock rev $devenv_rev != flake.lock $after"; exit 1; }
    echo "OK: all locks pinned to $after"

# Verify all build methods produce identical store paths and revs are in sync
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking nixpkgs rev sync..."
    FLAKE_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    DEVENV_REV=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)
    if [ "$FLAKE_REV" != "$DEVENV_REV" ]; then
        echo "FAIL: nixpkgs revs diverged"
        echo "  flake:  $FLAKE_REV"
        echo "  devenv: $DEVENV_REV"
        exit 1
    fi
    echo "OK: all locks pinned to $FLAKE_REV"

    echo "Checking build hash parity..."
    HASH_NIX_BUILD=$(nix-build -A packages.default --no-out-link)
    HASH_NIX=$(nix build --impure .#packages.$(nix eval --impure --expr builtins.currentSystem --raw).default --no-link --print-out-paths)
    HASH_DEVENV=$(devenv build packages.default | jq -r '."packages.default"')
    if [ "$HASH_NIX_BUILD" != "$HASH_NIX" ] || [ "$HASH_NIX_BUILD" != "$HASH_DEVENV" ]; then
        echo "FAIL: store paths differ"
        echo "  nix-build: $HASH_NIX_BUILD"
        echo "  nix build: $HASH_NIX"
        echo "  devenv:    $HASH_DEVENV"
        exit 1
    fi
    echo "OK: all three produce $HASH_NIX_BUILD"

# Generate .mcp.json and .lsp.json from lib/servers.nix
generate-servers:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Generating .mcp.json..."
    nix eval --impure --json --expr '
      let sources = import ./_sources.nix; pkgs = import sources.nixpkgs {};
          s = import ./lib/servers.nix { inherit pkgs; };
      in { mcpServers = s.mcpServers; }
    ' | jq -S . > .mcp.json
    echo "Generating .lsp.json..."
    nix eval --impure --json --expr '
      let sources = import ./_sources.nix; pkgs = import sources.nixpkgs {};
          s = import ./lib/servers.nix { inherit pkgs; };
      in s.lspServers
    ' | jq -S . > .lsp.json
    echo "Done."

# List all discovered skills from local plugins and third-party sources
list-skills:
    nix eval --impure --json --expr 'import ./lib/list-catalog.nix' | jq .


# Fast contributor validation for skill content
check-skills:
    python3 scripts/validate_skills.py

# Security-scan an imported bundled source (pass the source key from bundled-sources.nix)
scan-source source:
    #!/usr/bin/env bash
    set -euo pipefail
    src=$(nix eval --impure --raw --expr "(import ./_sources.nix).{{source}}")
    python3 scripts/scan_bundled_source.py "$src"

# Bundle an upstream skill repo (add non-flake input, then lock)
add-source owner repo:
    @echo "Add the following to flake.nix inputs:"
    @echo '  {{repo}} = { url = "github:{{owner}}/{{repo}}"; flake = false; };'
    @echo "Then run: nix flake lock"
    @echo "Finally, add an entry to bundled-sources.nix with namespace, subdir, and include list."

lint:
    devenv shell -- lint

install *args:
    bash scripts/install.bash {{args}}

# Install for a specific target (claude, codex, gemini, all)
install-target target *args:
    bash scripts/install.bash --target {{target}} {{args}}

research:
    cat research/PROMPT.md | claude --effort max --name jstack-research --print --verbose --allowedTools "Read Write Edit Bash Glob Grep Agent WebFetch WebSearch mcp__devenv__search_options mcp__claude_ai_Context7__resolve-library-id mcp__claude_ai_Context7__query-docs"

# Resume research session interactively (see thinking + tool calls)
research-resume:
    claude --resume --name jstack-research
