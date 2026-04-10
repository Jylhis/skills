# Justfile — Package Flake Variant

Template for projects where the primary outputs are packages (derivations).
Includes store-path parity verification across build methods.

```just
default_target := "default"

# Build the default package via npins (non-flake)
build target=default_target:
    nix-build default.nix -A {{target}}

# Build via flake (requires --impure for npins)
build-flake target=default_target:
    nix build .#{{target}} --impure

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
    # macOS/BSD sed — use sed -i for GNU/Linux
    sed -i '' "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml
    devenv update
    nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$REV"

# Verify all three lock files point to the same nixpkgs rev
# and that store paths match across build methods
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

    # Store-path parity check
    echo "Checking store-path parity..."
    NPINS_PATH=$(nix-build default.nix --no-out-link 2>/dev/null)
    FLAKE_PATH=$(nix build --impure --no-link --print-out-paths 2>/dev/null)

    echo "npins build: $NPINS_PATH"
    echo "flake build: $FLAKE_PATH"

    if [ "$NPINS_PATH" != "$FLAKE_PATH" ]; then
        echo "WARNING: store paths differ"
        exit 1
    fi
    echo "Store paths match."
```

## Platform Notes

- `sed -i ''` is macOS/BSD form. On GNU/Linux, use `sed -i` (no empty
  string argument).
- To make the Justfile portable, detect the platform:

```just
_sed_inplace := if os() == "macos" { "sed -i ''" } else { "sed -i" }
```

Then use `{{_sed_inplace}}` in recipes.
