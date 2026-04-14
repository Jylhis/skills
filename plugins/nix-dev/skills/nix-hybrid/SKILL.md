---
name: nix-hybrid
description: "Use for hybrid non-flake + flake architecture patterns including flake-compat shim default.nix, package flake vs module flake classification, flake + devenv lock synchronization, two lock file problem, nixpkgs pin sync, making a flake repo work without experimental features, non-flake consumption via flake-compat, overlay.nix extraction, or per-system output constructors."
user-invocable: false
---

# Hybrid Non-Flake + Flake Architecture

A pattern where package and module logic lives in plain Nix files
(`overlay.nix`, module `.nix` files) while `flake.nix` orchestrates
composition and `default.nix` is a thin flake-compat shim for non-flake
consumers. Development uses `devenv.sh` with no experimental features.
Downstream consumers get a valid flake input. Non-flake consumers
(`nix-build`, legacy NixOS configs) access the same outputs via
flake-compat.

`flake.lock` is the single source of truth for all pinned inputs.
`devenv.lock` must be synced to the same nixpkgs commit.

## Flake Type Classification

Before starting, classify the project:

### Package Flake

Primary outputs are `packages.<system>.<name>` — derivations you build
and install.

- `flake.nix` imports `overlay.nix` and applies it to nixpkgs
- `default.nix` is a flake-compat shim
- Store-path parity can be verified across `nix build` and `nix-build`

### Module Flake

Primary outputs are NixOS/nix-darwin/home-manager modules — lazy
attrsets with `imports` lists that reference upstream flake inputs.

- Upstream deps (home-manager, stylix, nix-darwin) come through flake inputs
- No meaningful "default package" to build
- Store-path parity checks do not apply

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

## flake.nix — The Orchestrator

`flake.nix` imports shared logic files (`overlay.nix`, module files) and
wires them with flake inputs. It contains composition logic but no
package definitions or module options.

### Package Flake

```nix
# flake.nix — package flake
{
  description = "My project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
    in
    {
      overlays.default = import ./overlay.nix;

      packages = forAllSystems (system: {
        default = (pkgsFor system).mypackage;
      });
    };
}
```

### Module Flake

```nix
# flake.nix — module flake
{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... } @ inputs:
    {
      overlays.default = import ./overlay.nix;
      homeManagerModules.default = import ./modules;
      darwinConfigurations = { /* ... */ };
    };
}
```

All upstream dependencies come through flake inputs — there is no
separate pinning mechanism for dependencies.

## default.nix — flake-compat Shim

`default.nix` is a thin wrapper that uses flake-compat to expose flake
outputs to non-flake consumers. It reads `flake.lock` to fetch
flake-compat at the pinned revision:

```nix
# default.nix
(import
  (
    let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    }
  )
  { src = ./.; }
).defaultNix
```

This returns the full flake outputs attrset. Non-flake consumers use:

```bash
# Package flake — build default package
nix-build default.nix -A packages.x86_64-linux.default

# Or with builtins.currentSystem for convenience
nix-build -E '(import ./default.nix).packages.${builtins.currentSystem}.default'
```

For a `shell.nix` (optional — devenv is the primary dev shell):

```nix
# shell.nix
(import
  (
    let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    }
  )
  { src = ./.; }
).shellNix
```

### Pure Evaluation: What's Safe to Expose

- **`overlays.default`** — arity check only, body not evaluated. Safe.
- **`darwinConfigurations` / `nixosConfigurations`** — shallow check. Safe.
- **`homeManagerModules`** — non-standard output, warns but doesn't fail.
- **`packages.<system>.*`** — FULLY evaluated. Safe when all inputs come
  through flake.lock (no impure references).

## Nixpkgs Pin Synchronization

Two lock files must agree on the same nixpkgs commit:

| Lock file | Contains | Updated by |
|-----------|----------|-----------|
| `flake.lock` | `.nodes.nixpkgs.locked.rev` | `nix flake update` |
| `devenv.lock` | `.nodes.nixpkgs.locked.rev` | `devenv update` |

### Sync Recipe

`flake.lock` is the single source of truth:

```bash
# 1. Update flake inputs
nix flake update

# 2. Extract the new revision
REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)

# 3. Write exact rev into devenv.yaml
sed -i '' "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml

# 4. Regenerate devenv.lock
devenv update
```

Use `sed -i ''` on macOS (BSD sed). On Linux, use `sed -i`.

### Verification

```bash
# Extract revs from both lock files
FLAKE_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
DEVENV_REV=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)

# Both must match
[ "$FLAKE_REV" = "$DEVENV_REV" ] \
  && echo "Synced: $FLAKE_REV" \
  || echo "DESYNC: flake=$FLAKE_REV devenv=$DEVENV_REV"
```

For package flakes, also verify store-path parity:

```bash
nix-build -E '(import ./default.nix).packages.${builtins.currentSystem}.default'
nix build .#default
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

1. **Prerequisites** — classify flake type, verify tool availability
2. **Format** — if no existing formatter, run `nixfmt .` and commit
   separately as `style: nixfmt`
3. **Create overlay.nix** — extract package definitions
4. **Create/rewrite flake.nix** — orchestrator that imports overlay.nix
   and modules; add `flake-compat` input
5. **Create default.nix** — flake-compat shim
6. **Set up devenv** — `devenv.nix` + `devenv.yaml` with exact nixpkgs commit
7. **Remove npins** — delete `npins/` directory if present
8. **Sync pins** — run the sync recipe above
9. **Git stage** — `git add` all new files before verification
10. **Verify** — `just check`, `just build`, `just fmt`, `nix flake show`,
    `devenv shell`, `just verify`

## Hard Constraints

- Keep `flake.lock` committed for flake consumers and flake-compat
- `default.nix` is a flake-compat shim only — no logic, no imports
  beyond flake-compat
- `overlay.nix` and module files contain the real logic — `flake.nix`
  only composes them
- devenv.sh is the dev shell — do not duplicate it as a flake `devShell`
- `flake-compat` must be declared as a non-flake input:
  `flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };`

## nix-darwin Variant

For macOS systems using nix-darwin, the hybrid pattern works the same
way with `darwin-rebuild` instead of `nixos-rebuild`:

```nix
# flake.nix — module flake with nix-darwin
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nix-darwin, home-manager, ... }:
    {
      overlays.default = import ./overlay.nix;
      darwinConfigurations.myhost = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./hosts/myhost/configuration.nix
          home-manager.darwinModules.home-manager
        ];
      };
    };
}
```

Rebuild: `darwin-rebuild switch --flake .#myhost`

See the nix-darwin skill for configuration details.

## flake-parts Integration Path

For projects that benefit from modular flake composition, replace the
manual `forAllSystems` wrapper with flake-parts:

```nix
# flake.nix — with flake-parts
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      flake = {
        overlays.default = import ./overlay.nix;
        homeManagerModules = inputs.self.homeManagerModules or { };
      };
      perSystem =
        { pkgs, system, ... }:
        {
          packages.default = pkgs.mypackage;
        };
    };
}
```

The key constraint remains: `overlay.nix` and module files contain the
real logic, `flake.nix` (even with flake-parts) only composes them. See
the flakes skill's `references/flake-parts.md` for the full flake-parts
pattern reference.

## Source Filtering

Use `lib.fileset` in the overlay to avoid copying the entire
project directory to the store:

```nix
# In overlay.nix or package.nix
let
  fs = prev.lib.fileset;
in
{
  myapp = prev.callPackage (
    { stdenv }:
    stdenv.mkDerivation {
      pname = "myapp";
      src = fs.toSource {
        root = ./.;
        fileset = fs.unions [
          ./src
          ./Cargo.toml
          ./Cargo.lock
        ];
      };
    }
  ) { };
}
```

## CI Integration

The lint pipeline from the nix-linting skill works with hybrid projects:

```bash
nixfmt --check .
statix check . --ignore '.devenv/*' 'result/*'
deadnix --fail --exclude .devenv result .
nix flake check     # validates flake outputs
```

For CI binary caching, see `references/ci-pipeline.md` in the
nix-linting skill.

## Related Skills

- **devenv** — developer environment, services, processes
- **flakes** — flake structure, inputs, outputs, pure evaluation
- **nix-linting** — statix, deadnix, nixfmt, CI pipeline
- **nix-darwin** — macOS system configuration with nix-darwin
- **nixos-modules** — NixOS module patterns shared with nix-darwin
- **nix-performance** — closure optimization, IFD avoidance

## Reference Files

See `references/justfile-package.md` for the package flake Justfile
template, `references/justfile-module.md` for the module flake variant,
and `references/statix-config.md` for the statix.toml template.
