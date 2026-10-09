# flake-parts Reference

## Table of Contents

- [Overview](#overview)
- [Basic Structure](#basic-structure)
- [perSystem Module](#persystem-module)
- [Flake-Level Attributes](#flake-level-attributes)
- [Publishing and Reusing Modules](#publishing-and-reusing-modules)
- [The Dendritic Pattern](#the-dendritic-pattern)
- [Partitions](#partitions)
- [flake-parts vs flake-utils](#flake-parts-vs-flake-utils)
- [Integration with devenv](#integration-with-devenv)
- [Key Ecosystem Modules](#key-ecosystem-modules)
- [When NOT to Use flake-parts](#when-not-to-use-flake-parts)

## Overview

flake-parts applies the NixOS module system to flake outputs. Instead of manually constructing the outputs attribute set, you declare typed options that flake-parts merges and validates.

flake-parts is a rolling project with no release tags: pin it through `flake.lock` like any other input. Its only input is `nixpkgs-lib` (`github:nix-community/nixpkgs.lib`), which supplies the `lib` module argument.

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
      # x86_64-darwin is dropped from Nixpkgs after 26.05
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { pkgs, ... }: {
        packages.default = pkgs.hello;
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.nixfmt ];
        };
      };
    };
}
```

`mkFlake` takes the flake's own arguments and a module (or list of modules). The `systems` option controls which platforms `perSystem` iterates over.

Starter templates: `nix flake init -t github:hercules-ci/flake-parts` (also `#multi-module`, `#unfree`, `#package`).

## perSystem Module

The `perSystem` function receives a module argument set with these key attributes:

| Attribute | Description |
|---|---|
| `pkgs` | `inputs.nixpkgs.legacyPackages.${system}` by default; override with `_module.args.pkgs` (e.g. to set overlays or `config.allowUnfree`) |
| `system` | The current system string, e.g. `"x86_64-linux"` |
| `self'` | The current flake's `perSystem` outputs for this system |
| `inputs'` | All flake inputs' `perSystem` outputs for this system |
| `config` | The fully resolved perSystem config (for self-references) |
| `lib` | Nixpkgs `lib` from flake-parts' `nixpkgs-lib` input (not necessarily `pkgs.lib`) |

`self` and `inputs` are deliberately not module arguments inside `perSystem` (they throw); take them from the enclosing top-level module. Only arguments named in the function signature are passed, so `args: args.pkgs` fails while `{ pkgs, ... }:` works.

Top-level modules additionally receive `withSystem` (enter a system's `perSystem` scope, e.g. to build `nixosConfigurations` from `perSystem` packages), `moduleWithSystem` (bring `perSystem` arguments into a published NixOS module), and `getSystem`.

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

## Publishing and Reusing Modules

flake-parts ships optional extra modules under `inputs.flake-parts.flakeModules.<name>`; import them explicitly:

| Extra module | Adds |
|---|---|
| `modules` | `flake.modules.<class>.<name>`: publish modules of any module class (`nixos`, `flake`, ..., or `generic` for class-less) as `deferredModule`s that merge by name |
| `flakeModules` | `flake.flakeModules.<name>` (and `flakeModule`) for publishing flake-parts modules |
| `partitions` | `partitions` and `partitionedAttrs`; see [Partitions](#partitions) |
| `easyOverlay` | `perSystem.overlayAttrs` become `overlays.default` (re-evaluates `perSystem` with the overlay's `prev` as `pkgs`) |
| `bundlers` | `bundlers` output for `nix bundle` |
| `touchup` | Filter or hide attributes in the final flake output |

Library helpers:

- `importApply ./nixos-module.nix { localFlake = self; inherit withSystem; }` (from the `flake-parts-lib` module argument or `flake-parts.lib`): import a file that is a function from static arguments to a module, keeping the file location for error messages. Use it for modules you publish, so they close over *your* flake rather than the consumer's.
- `flake-parts.lib.importAndPublish "name" ./module.nix`: import a module and expose it as `flake.modules.flake.<name>` in one step (pulls in the `modules` extra).

```nix
{ inputs, ... }: {
  imports = [ inputs.flake-parts.flakeModules.modules ];
  flake.modules.nixos.noBoot = { boot.loader.enable = false; };
  flake.modules.nixos.autoDeploy = ./nixos/auto-deploy.nix;
}
```

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

The pattern as written up in `mightyiam/dendritic` goes further than a directory split:

- Every Nix file except entry points (`flake.nix`, `default.nix`) is a top-level module, implementing one feature across every configuration it applies to; the file path names the feature, not its type or target host.
- Lower-level modules (NixOS, nix-darwin, home-manager) are stored as option values of the top-level configuration, typically `flake.modules.<class>.<name>` from the `modules` extra above, and merge by name, so several files can contribute to e.g. `flake.modules.nixos.pc`.
- Because every file has the same type, the whole tree is auto-imported, commonly with `import-tree` (now `github:denful/import-tree`; `vic/import-tree` redirects):

```nix
{
  inputs.import-tree.url = "github:denful/import-tree";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
    (inputs.import-tree ./modules);
}
```

import-tree ignores paths containing `/_` by default, which is the usual place for non-module helper files.

## Partitions

`flakeModules.partitions` avoids fetching development-only inputs (formatters, test frameworks, CI tooling) when a consumer only evaluates `packages`. Each partition is a separate module evaluation with its own extra inputs, typically from a sub-flake whose lock file only the developers use:

```nix
{ inputs, ... }: {
  imports = [ inputs.flake-parts.flakeModules.partitions ];
  partitionedAttrs.checks = "dev";
  partitionedAttrs.devShells = "dev";
  partitions.dev.extraInputsFlake = ./dev;   # ./dev/flake.nix + flake.lock
  partitions.dev.module = { imports = [ ./dev/flake-module.nix ]; };
}
```

This is the shape flake-parts uses for its own repo. `follows` inside `./dev/flake.nix` cannot reference inputs of the main flake.

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

The `devenv.flakeModule` maps each `devenv.shells.<name>` to the corresponding `devShells.<name>` output. Enter it with `nix develop --no-pure-eval`: devenv needs to know the project directory, which pure evaluation hides. Template: `nix flake init --template github:cachix/devenv#flake-parts`.

## Key Ecosystem Modules

| Module | Purpose |
|---|---|
| `devenv` | Developer environments with services, languages, scripts |
| `treefmt-nix` | Unified multi-language formatting (`nix fmt`) |
| `git-hooks-nix` | Git pre-commit hooks as Nix derivations (`cachix/git-hooks.nix`, formerly `pre-commit-hooks.nix`) |
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
