# flake-parts Reference

## Table of Contents

- [Overview](#overview)
- [Basic Structure](#basic-structure)
- [perSystem Module](#persystem-module)
- [Flake-Level Attributes](#flake-level-attributes)
- [The Dendritic Pattern](#the-dendritic-pattern)
- [flake-parts vs flake-utils](#flake-parts-vs-flake-utils)
- [Integration with devenv](#integration-with-devenv)
- [Key Ecosystem Modules](#key-ecosystem-modules)
- [When NOT to Use flake-parts](#when-not-to-use-flake-parts)

## Overview

flake-parts applies the NixOS module system to flake outputs. Instead of manually constructing the outputs attribute set, you declare typed options that flake-parts merges and validates.

Benefits:
- **Type checking** -- module options have types, catching mistakes at eval time
- **Composability** -- split flake logic across files, each file is a module
- **Modularity** -- ecosystem modules (devenv, treefmt, pre-commit) plug in as imports
- **No manual system iteration** -- `perSystem` handles `forAllSystems` automatically

## Basic Structure

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { pkgs, ... }: {
        packages.default = pkgs.hello;
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.nixfmt-rfc-style ];
        };
      };
    };
}
```

`mkFlake` takes the flake's own arguments and a module (or list of modules). The `systems` option controls which platforms `perSystem` iterates over.

## perSystem Module

The `perSystem` function receives a module argument set with these key attributes:

| Attribute | Description |
|---|---|
| `pkgs` | `nixpkgs.legacyPackages.${system}` (auto-resolved) |
| `system` | The current system string, e.g. `"x86_64-linux"` |
| `self'` | The current flake's `perSystem` outputs for this system |
| `inputs'` | All flake inputs' `perSystem` outputs for this system |
| `config` | The fully resolved perSystem config (for self-references) |
| `lib` | `pkgs.lib` shorthand |
| `final` | The final merged config (alias for `config`) |

Example using `self'` for cross-references:

```nix
perSystem = { pkgs, self', ... }: {
  packages.default = self'.packages.my-app;
  packages.my-app = pkgs.callPackage ./app.nix {};
  checks.default = self'.packages.my-app.tests;
};
```

## Flake-Level Attributes

Attributes that are not per-system (e.g. NixOS configurations, overlays) go in the top-level module, outside `perSystem`:

```nix
inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [ "x86_64-linux" "aarch64-darwin" ];

  flake = {
    nixosConfigurations.myhost = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/myhost ];
    };

    overlays.default = final: prev: {
      my-tool = final.callPackage ./tool.nix {};
    };
  };

  perSystem = { pkgs, ... }: {
    packages.default = pkgs.callPackage ./. {};
  };
};
```

The `flake` attribute is an escape hatch for anything flake-parts does not model with typed options.

## The Dendritic Pattern

Every file is a flake-parts module. The top-level `flake.nix` only imports them:

```
.
├── flake.nix
├── packages/
│   └── default.nix      # flake-parts module
├── devshells/
│   └── default.nix      # flake-parts module
├── checks/
│   └── default.nix      # flake-parts module
└── nixos/
    └── default.nix      # flake-parts module
```

`flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      imports = [
        ./packages
        ./devshells
        ./checks
        ./nixos
      ];
    };
}
```

`packages/default.nix`:

```nix
{ lib, ... }: {
  perSystem = { pkgs, ... }: {
    packages.my-tool = pkgs.callPackage ./my-tool.nix {};
    packages.default = pkgs.callPackage ./my-tool.nix {};
  };
}
```

Each module file receives the standard module arguments (`lib`, `config`, `self`, `inputs`, etc.) and can define `perSystem`, `flake`, options, or imports of its own.

## flake-parts vs flake-utils

| Feature | flake-utils | flake-parts |
|---|---|---|
| System iteration | `eachDefaultSystem` helper | `systems` option + `perSystem` |
| Type safety | None | Full NixOS module types |
| Modularity | Manual imports | Module system with `imports` |
| Cross-references | Manual wiring | `self'`, `inputs'`, `config` |
| Ecosystem plugins | None | devenv, treefmt, pre-commit, etc. |
| Learning curve | Low (thin wrapper) | Medium (module system concepts) |
| Overhead | Minimal | Small eval-time cost for module merge |
| Maturity | Stable, maintenance mode | Actively developed |

## Integration with devenv

devenv provides a flake-parts module that wires `devShells` automatically:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      perSystem = { pkgs, ... }: {
        devenv.shells.default = {
          languages.rust.enable = true;
          packages = [ pkgs.openssl ];
        };
      };
    };
}
```

The `devenv.flakeModule` maps each `devenv.shells.<name>` to the corresponding `devShells.<name>` output.

## Key Ecosystem Modules

| Module | Purpose |
|---|---|
| `devenv` | Developer environments with services, languages, scripts |
| `treefmt-nix` | Unified multi-language formatting (`nix fmt`) |
| `pre-commit-hooks-nix` | Git pre-commit hooks as Nix derivations |
| `haskell-flake` | Opinionated Haskell project setup |
| `process-compose-flake` | Process orchestration for dev services |
| `services-flake` | NixOS-style services in non-NixOS dev environments |
| `nix-oci` | OCI/Docker image building |
| `flake-root` | Locate flake root directory in modules |

Find more at: https://flake.parts/options

## When NOT to Use flake-parts

flake-parts adds value through modularity and type safety, but is overhead when neither is needed:

- **Single-package flakes** -- a 20-line `flake.nix` with one package and one devShell does not benefit from the module system.
- **No ecosystem module usage** -- if you are not pulling in devenv, treefmt, or similar, the module plumbing has no payoff.
- **Team unfamiliar with the NixOS module system** -- the learning curve may not be justified for a small project with few contributors.
- **Performance-critical evaluation** -- the module merge adds a small but non-zero eval-time cost; in extremely large monorepos this can matter.

In these cases, a plain `flake.nix` with a manual `forAllSystems` helper or `flake-utils` is sufficient.
