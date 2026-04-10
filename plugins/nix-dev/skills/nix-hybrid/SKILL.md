---
name: nix-hybrid
description: "Use for hybrid non-flake + flake architecture patterns including thin flake wrapper, default.nix with flake re-export, package flake vs module flake classification, npins + devenv + flake lock synchronization, three lock file problem, nixpkgs pin sync, flake-only upstream dependencies, import site audit, making a flake repo work without experimental features, non-flake development with flake export, overlay.nix extraction, or per-system output constructors."
user-invocable: false
---

# Hybrid Non-Flake + Flake Architecture

A pattern where all real Nix logic lives in plain Nix files
(`default.nix`, `overlay.nix`, `devenv.nix`) while `flake.nix` is a
thin re-export wrapper with zero logic. Development uses `devenv.sh`
with no experimental features. Downstream consumers get a valid flake
input. All three pinning mechanisms (`npins`, `devenv.lock`, `flake.lock`)
resolve to the exact same nixpkgs commit for full `cache.nixos.org` hits.

## Flake Type Classification

Before starting, classify the project:

### Package Flake

Primary outputs are `packages.<system>.<name>` — derivations you build
and install.

- `default.nix` takes `{ pkgs ? ... }:` as its interface
- Justfile can verify store-path parity across build methods
- npins provides pkgs directly

```nix
# default.nix — package flake
{
  pkgs ? import (import ./npins).nixpkgs {
    overlays = [ (import ./overlay.nix) ];
  },
  lib ? pkgs.lib,
}:
{
  inherit (pkgs) mypackage;
  overlays.default = import ./overlay.nix;
}
```

### Module Flake

Primary outputs are NixOS/nix-darwin/home-manager modules — lazy
attrsets with `imports` lists that reference upstream flake inputs.

- `default.nix` takes `{ inputs }:` as a required parameter
- Upstream deps (home-manager, stylix) come through flake inputs
- No meaningful "default package" to build
- Store-path parity checks do not apply

```nix
# default.nix — module flake
{ inputs }:
{
  overlays.default = import ./overlay.nix;
  homeManagerModules.default = import ./modules;
  darwinConfigurations = { /* ... */ };
}
```

### Upstream Dependency Audit

Check if any upstream dependencies are flake-only (no `default.nix`,
only `flake.nix` — e.g., home-manager, stylix, nix-darwin). These
cannot be imported from npins without flake-compat. Consequence: npins
pins ONLY nixpkgs. All other upstream deps come through flake inputs,
and `default.nix` accepts `{ inputs }:`.

## Creating overlay.nix

Extract all package definitions into a `final: prev:` overlay. Move
inline `pkgs.callPackage ./packages/foo/package.nix {}` calls from
modules into the overlay — modules then reference `pkgs.foo` instead of
fragile relative `callPackage` paths.

When composing an upstream overlay with custom additions:

```nix
# overlay.nix
final: prev:
(upstream.overlays.default final prev) // {
  my-extra = final.callPackage ./packages/my-extra { };
}
```

This works because `final` is the fixpoint (shared) and `prev` is the
pre-overlay pkgs.

## Per-System Output Constructors

`default.nix` cannot use `forAllSystems` (that requires
`nixpkgs.lib.genAttrs` from the flake). Export constructor functions and
let `flake.nix` apply the system dispatch:

```nix
# default.nix — export constructors
{
  legacyPackages = system: import nixpkgs {
    inherit system;
    overlays = [ (import ./overlay.nix) ];
  };
  mkChecks = { system }: { /* ... */ };

  overlays.default = import ./overlay.nix;
  homeManagerModules.default = import ./modules;
}
```

## Thin flake.nix Wrapper

Zero logic. Forward non-system-specific outputs directly. Use
`forAllSystems` to apply per-system constructors from `default.nix`:

```nix
# flake.nix — thin wrapper
{
  description = "My project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # upstream deps for module flakes:
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      proj = import ./default.nix { inherit inputs; };
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      # Non-system outputs — forwarded directly
      overlays = proj.overlays;
      homeManagerModules = proj.homeManagerModules;

      # System-specific outputs
      legacyPackages = forAllSystems proj.legacyPackages;
    };
}
```

Do not wire devenv into `flake.nix` — devenv.sh is the dev shell.

### Pure Evaluation: What's Safe to Expose

- **`overlays.default`** — arity check only, body not evaluated. Safe.
- **`darwinConfigurations` / `nixosConfigurations`** — shallow check. Safe.
- **`homeManagerModules`** — non-standard output, warns but doesn't fail.
- **`packages.<system>.*`** — FULLY evaluated. Fails if `default.nix`
  uses impure npins transitively. Do NOT expose unless packages are
  built purely.

## Import Site Audit

When converting a file from `let...in expr` to `{ pkgs ? ... }: let...in expr`,
the return type changes from a value to a function. **Every caller** must
be updated:

```bash
# Find all import sites
grep -r 'import ./default.nix' .
grep -r 'import ./overlay.nix' .
```

Update each:
- `import ./default.nix` → `import ./default.nix {}` or
  `import ./default.nix { inherit inputs; }`
- Missing a caller breaks evaluation silently — it returns `<LAMBDA>`
  instead of the expected value

## Nixpkgs Pin Synchronization

Three lock files must agree on the same nixpkgs commit:

| Lock file | Contains | Updated by |
|-----------|----------|-----------|
| `npins/sources.json` | `.pins.nixpkgs.revision` | `npins update` |
| `devenv.lock` | `.nodes.nixpkgs.locked.rev` | `devenv update` |
| `flake.lock` | `.nodes.nixpkgs.locked.rev` | `nix flake lock` |

### Sync Recipe

npins is the single source of truth:

```bash
# 1. Update npins
npins update

# 2. Extract the new revision
REV=$(jq -r '.pins.nixpkgs.revision' npins/sources.json)

# 3. Write exact rev into devenv.yaml
sed -i '' "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml

# 4. Regenerate devenv.lock
devenv update

# 5. Sync flake.lock
nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$REV"
```

Use `sed -i ''` on macOS (BSD sed). On Linux, use `sed -i`.

### Verification

```bash
# Extract revs from all three lock files
NPINS_REV=$(jq -r '.pins.nixpkgs.revision' npins/sources.json)
DEVENV_REV=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)
FLAKE_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)

# All three must match
[ "$NPINS_REV" = "$DEVENV_REV" ] && [ "$DEVENV_REV" = "$FLAKE_REV" ] \
  && echo "Synced: $NPINS_REV" \
  || echo "DESYNC: npins=$NPINS_REV devenv=$DEVENV_REV flake=$FLAKE_REV"
```

For package flakes, also verify store-path parity:

```bash
nix-build default.nix  # via npins
nix build --impure     # via flake
# Compare resulting store paths
```

## Git Staging Requirement

Nix flake commands only see git-tracked files. Stage new files BEFORE
running any flake commands:

```bash
git add flake.nix default.nix overlay.nix devenv.yaml devenv.nix
```

Otherwise: `error: Path 'flake.nix' in the repository is not tracked by Git.`

## Migration Workflow

This is a single atomic migration — do it in one linear pass:

1. **Prerequisites** — classify flake type, audit upstream deps, check
   npins pin type (must be GitHub, not Channel), verify tool availability
2. **Format** — if no existing formatter, run `nixfmt .` and commit
   separately as `style: nixfmt`
3. **Create overlay.nix** — extract package definitions
4. **Create default.nix** — appropriate interface for flake type
5. **Set up devenv** — `devenv.nix` + `devenv.yaml` with exact nixpkgs commit
6. **Create/rewrite flake.nix** — thin wrapper only
7. **Sync pins** — run the sync recipe above
8. **Git stage** — `git add` all new files before verification
9. **Verify** — `just check`, `just build`, `just fmt`, `nix flake show`,
   `devenv shell`, `just verify`

## Hard Constraints

- Do not use flake-compat
- Keep `flake.lock` committed for flake consumers
- Never read `flake.lock` from `default.nix` — it reads npins (package
  flakes) or receives inputs from `flake.nix` (module flakes)
- devenv.sh is the dev shell — do not duplicate it as a flake `devShell`

## Reference Files

See `references/justfile-package.md` for the package flake Justfile
template, `references/justfile-module.md` for the module flake variant,
and `references/statix-config.md` for the statix.toml template.
