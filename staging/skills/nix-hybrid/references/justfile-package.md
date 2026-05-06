# Justfile — Package Flake Variant

Template for projects where the primary outputs are packages (derivations).
Includes store-path parity verification across build methods.

```just
default_target := "default"

# Build the default package via flake
build target=default_target:
    nix build .#{{target}}

# Build via flake-compat (non-flake, no experimental features)
build-legacy target=default_target:
    nix-build -E "(import ./default.nix).packages.${builtins.currentSystem}.{{target}}"

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
    # macOS/BSD sed — use sed -i for GNU/Linux
    sed -i '' "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml
    devenv update

# Verify both lock files point to the same nixpkgs rev
# and that store paths match across build methods
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

    # Store-path parity check
    echo "Checking store-path parity..."
    LEGACY_PATH=$(nix-build -E '(import ./default.nix).packages.${builtins.currentSystem}.default' --no-out-link 2>/dev/null)
    FLAKE_PATH=$(nix build --no-link --print-out-paths 2>/dev/null)

    echo "legacy build: $LEGACY_PATH"
    echo "flake build:  $FLAKE_PATH"

    if [ "$LEGACY_PATH" != "$FLAKE_PATH" ]; then
        echo "WARNING: store paths differ"
        exit 1
    fi
    echo "Store paths match."
```

## Additional Recipes

```just
# Build with progress display (requires nom / nix-output-monitor)
build-nom:
    nom build

# Browse closure interactively (requires nix-tree)
closure:
    nix-tree .#default

# Show closure size
closure-size:
    nix path-info -rsSh .#default
```

## Platform Notes

- `sed -i ''` is macOS/BSD form. On GNU/Linux, use `sed -i` (no empty
  string argument).
- To make the Justfile portable, detect the platform:

```just
_sed_inplace := if os() == "macos" { "sed -i ''" } else { "sed -i" }
```

Then use `{{_sed_inplace}}` in recipes.
