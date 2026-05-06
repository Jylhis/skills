# Justfile — Module Flake Variant

Template for projects where the primary outputs are NixOS/nix-darwin/
home-manager modules. No store-path parity checks (modules are lazy
attrsets, not derivations).

```just
# Build a specific system configuration
build target:
    nix build .#{{target}}

# Build the local darwin/NixOS configuration
build-local hostname=`hostname -s`:
    nix build .#darwinConfigurations.{{hostname}}.system

# Run all linters and checks
check:
    nixfmt --check .
    statix check . --ignore '.devenv/*' 'result/*'
    deadnix --fail --exclude .devenv result .
    nix flake check

# Format all Nix files
fmt:
    nixfmt .

# Run statix and deadnix
lint:
    statix check . --ignore '.devenv/*' 'result/*'
    deadnix --fail --exclude .devenv result .

# Auto-fix linter findings
lint-fix:
    statix fix .
    deadnix --edit .

# Update all pins and sync lock files
update:
    nix flake update
    #!/usr/bin/env bash
    set -euo pipefail
    REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    echo "Syncing nixpkgs to $REV"
    sed -i '' "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml
    devenv update

# Verify both lock files point to the same nixpkgs rev
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    FLAKE_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    DEVENV_REV=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)

    echo "flake:  $FLAKE_REV"
    echo "devenv: $DEVENV_REV"

    if [ "$FLAKE_REV" != "$DEVENV_REV" ]; then
        echo "ERROR: nixpkgs revisions are out of sync"
        exit 1
    fi
    echo "All lock files in sync."

# Show flake outputs
show:
    nix flake show
```
