default:
    @just --list --justfile {{justfile()}}

# Run all checks (lint + typecheck + eval)
check:
    nix-instantiate --eval default.nix > /dev/null
    nix flake check --no-build
    devenv test
    statix check . --ignore '.devenv/*' 'result/*'
    deadnix --fail --exclude .devenv result .

# Format all nix files
fmt:
    nixfmt .

# Build the default package
build:
    nix-build -A packages.default

# Update all inputs in sync: flake.lock → devenv.lock
update:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake update
    REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    echo "Syncing devenv.lock to nixpkgs $REV"
    sed -i "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml
    devenv update
    echo "Done. All locks pinned to nixpkgs $REV"

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

# Regenerate settings.json from settings.nix
generate-settings:
    nix eval --impure --json --expr 'import ./settings.nix' | jq -S . > settings.json

# Generate all manifests (plugin.json, .mcp.json, .lsp.json) from plugin.nix
generate-manifests:
    @for dir in plugins/*/; do \
      dir="${dir%/}"; \
      name=$(basename "$dir"); \
      [ -f "$dir/plugin.nix" ] || continue; \
      echo "Generating manifests for $name..."; \
      manifest=$( \
        nix eval --impure --json --expr " \
          let sources = import ./_sources.nix; pkgs = import sources.nixpkgs {}; p = import ./$dir/plugin.nix { inherit pkgs; }; \
          in { inherit (p) name description; } \
            // (if p ? version then { inherit (p) version; } else {}) \
            // { author = p.author or {}; } \
        " \
      ); \
      mkdir -p "$dir/.claude-plugin"; \
      echo "$manifest" | jq -S . > "$dir/.claude-plugin/plugin.json"; \
      mcp=$( \
        nix eval --impure --json --expr " \
          let sources = import ./_sources.nix; pkgs = import sources.nixpkgs {}; p = import ./$dir/plugin.nix { inherit pkgs; }; \
          in if p ? mcpServers && p.mcpServers != {} then { mcpServers = p.mcpServers; } else null \
        " \
      ); \
      [ "$mcp" != "null" ] && echo "$mcp" | jq -S . > "$dir/.mcp.json" || true; \
      lsp=$( \
        nix eval --impure --json --expr " \
          let sources = import ./_sources.nix; pkgs = import sources.nixpkgs {}; p = import ./$dir/plugin.nix { inherit pkgs; }; \
          in if p ? lspServers && p.lspServers != {} then p.lspServers else null \
        " \
      ); \
      [ "$lsp" != "null" ] && echo "$lsp" | jq -S . > "$dir/.lsp.json" || true; \
    done
    @echo "Done."

# List all discovered skills from local plugins and third-party sources
list-skills:
    nix eval --impure --json --expr 'import ./lib/list-catalog.nix' | jq .

# Add a third-party skill source (add as non-flake input in flake.nix, then lock)
add-source owner repo:
    @echo "Add the following to flake.nix inputs:"
    @echo '  {{repo}} = { url = "github:{{owner}}/{{repo}}"; flake = false; };'
    @echo "Then run: nix flake lock"
    @echo "Finally, edit sources.nix to configure namespace and discovery."

lint:
    devenv shell -- lint

install *args:
    bash scripts/install.bash {{args}}

# Install for a specific target (claude, codex, gemini, all)
install-target target *args:
    bash scripts/install.bash --target {{target}} {{args}}

eval *args:
    bash scripts/eval.bash {{args}}

eval-fast *args:
    bash scripts/eval.bash --fast {{args}}

# Run quality evals only (llm-rubric assertions)
eval-quality *args:
    bash scripts/eval.bash --quality {{args}}

# Run evals for a specific skill (matches test description)
eval-skill skill *args:
    bash scripts/eval.bash --skill {{skill}} {{args}}

# Run evals for a specific plugin
eval-plugin plugin *args:
    bash scripts/eval.bash --plugin {{plugin}} {{args}}

# Compare routing results across Claude and GPT-4o
eval-compare *args:
    bash scripts/eval.bash --compare {{args}}

# Run adversarial/redteam tests
eval-redteam *args:
    bash scripts/eval.bash --redteam {{args}}
