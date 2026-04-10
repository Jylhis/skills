# Justfile — Module Flake Variant

Template for projects where the primary outputs are NixOS/nix-darwin/
home-manager modules. No store-path parity checks (modules are lazy
attrsets, not derivations).

```just
# Build a specific system configuration
build target:
    nix build .#{{target}} --impure

# Build the local darwin/NixOS configuration
build-local hostname=`hostname -s`:
    nix build .#darwinConfigurations.{{hostname}}.system --impure

# Run all linters and checks
check:
    nixfmt --check .
    statix check . --ignore 'npins/*' '.devenv/*' 'result/*'
    deadnix --fail --exclude npins .devenv result .
    nix-instantiate --eval default.nix
    nix flake check

# Format all Nix files
fmt:
    nixfmt .

# Run statix and deadnix
lint:
    statix check . --ignore 'npins/*' '.devenv/*' 'result/*'
    deadnix --fail --exclude npins .devenv result .

# Auto-fix linter findings
lint-fix:
    statix fix .
    deadnix --edit .

# Update all pins and sync lock files
update:
    npins update
    #!/usr/bin/env bash
    set -euo pipefail
    REV=$(jq -r '.pins.nixpkgs.revision' npins/sources.json)
    echo "Syncing nixpkgs to $REV"
    sed -i '' "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml
    devenv update
    nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$REV"

# Verify all three lock files point to the same nixpkgs rev
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    NPINS_REV=$(jq -r '.pins.nixpkgs.revision' npins/sources.json)
    DEVENV_REV=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)
    FLAKE_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)

    echo "npins:  $NPINS_REV"
    echo "devenv: $DEVENV_REV"
    echo "flake:  $FLAKE_REV"

    if [ "$NPINS_REV" != "$DEVENV_REV" ] || [ "$DEVENV_REV" != "$FLAKE_REV" ]; then
        echo "ERROR: nixpkgs revisions are out of sync"
        exit 1
    fi
    echo "All lock files in sync."

# Show flake outputs
show:
    nix flake show
```
