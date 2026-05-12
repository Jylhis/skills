---
name: nix
description: Use for Nix, Nixpkgs, and NixOS work — language fundamentals (lambdas, attrsets, derivations, lib functions), flakes (inputs/outputs, devShells, flake-parts), Nixpkgs packaging (mkDerivation, callPackage, overlays, builders), NixOS modules (mkOption, services, systemd, secrets), nix-darwin macOS config, home-manager dotfiles, devenv developer shells, container builds (dockerTools), nixosTests VMs, debugging (infinite recursion, IFD, hash mismatch), linting (statix/deadnix/nixfmt), performance (closure size, IFD avoidance), Emacs packaging in Nix, and hybrid non-flake + flake repos. Read the matching reference before acting.
---

# Nix skill index

Pick the topic and read its reference before writing or reviewing
Nix code. Each top-level reference covers one domain; nested
sub-references go deeper where needed.

| Topic | When to read | Reference |
|---|---|---|
| Language fundamentals | syntax, lambdas, attrsets, builtins, derivations, lib, callPackage, lazy eval, RFCs | `references/language.md` (+ `language/advanced.md`, `language/rfcs.md`) |
| Flakes | flake.nix, inputs, outputs, devShells, packages, follows, flake-parts, dendritic pattern | `references/flakes.md` (+ `flakes/flake-parts.md`) |
| Nixpkgs packaging | mkDerivation, callPackage, overlays, override, fetchers, builders, cross-compilation | `references/nixpkgs.md` (+ `nixpkgs/builders.md`, `nixpkgs/cross-compilation.md`) |
| NixOS modules | configuration.nix, mkOption, services, systemd, agenix/sops-nix, impermanence | `references/nixos-modules.md` (+ `nixos-modules/type-system.md`, `nixos-modules/testing.md`) |
| nix-darwin | macOS system, system.defaults, launchd, Homebrew cask integration | `references/darwin.md` (+ `darwin/defaults.md`) |
| home-manager | home.nix, programs.*, xdg, declarative dotfiles, home.activation | `references/home-manager.md` (+ `home-manager/programs.md`) |
| devenv | devenv.nix, devenv shell/up/test, languages, processes, services, pre-commit | `references/devenv.md` (+ `devenv/services.md`) |
| Containers | dockerTools, buildLayeredImage, streamLayeredImage, OCI images | `references/containers.md` |
| Testing | nixosTest VM tests, multi-VM, namaka snapshot tests | `references/testing.md` |
| Debugging | infinite recursion, IFD, hash mismatch, --show-trace, nix-tree, nix-diff | `references/debugging.md` (+ `debugging/error-catalog.md`) |
| Linting | statix, deadnix, nixfmt, treefmt-nix, CI pipeline | `references/linting.md` (+ `linting/ci-pipeline.md`) |
| Performance | evaluation speed, IFD avoidance, closure size, garbage collection, distributed builds | `references/performance.md` (+ `performance/tools.md`) |
| Emacs packaging | emacsWithPackages, trivialBuild, melpaBuild, native-comp, tree-sitter grammars | `references/emacs-packaging.md` |
| Hybrid (flake + non-flake) | flake-compat shim, package vs module flakes, lock sync, overlay extraction | `references/hybrid.md` (+ `hybrid/justfile-package.md`, `hybrid/justfile-module.md`, `hybrid/statix-config.md`) |

After reading the reference, follow its guidance for the task.
