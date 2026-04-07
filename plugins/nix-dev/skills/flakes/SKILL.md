---
name: flakes
description: "Use for Nix flakes structure and workflows including flake.nix, flake.lock, nix flake commands, nix develop, nix build, nix run, nix shell, nix fmt, inputs, outputs, devShells, packages, nixosConfigurations, follows, flake-utils, flake-parts, flake templates, eachDefaultSystem, or flake checks."
user-invocable: false
---

# Nix Flakes

## Flake Structure

A flake is a directory with a `flake.nix` at its root:

```nix
{
  description = "My project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.default = pkgs.callPackage ./default.nix { };

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.go pkgs.gopls ];
        };
      }
    );
}
```

## Standard Outputs

| Output | Purpose | CLI |
|--------|---------|-----|
| `packages.<system>.default` | Default package | `nix build` |
| `packages.<system>.<name>` | Named package | `nix build .#name` |
| `devShells.<system>.default` | Dev environment | `nix develop` |
| `apps.<system>.default` | Runnable app | `nix run` |
| `overlays.default` | Package overlay | — |
| `nixosConfigurations.<host>` | NixOS system config | `nixos-rebuild --flake .#host` |
| `nixosModules.default` | Reusable NixOS module | — |
| `homeConfigurations.<user>` | Home Manager config | `home-manager --flake .#user` |
| `templates.default` | Project template | `nix flake init -t` |
| `checks.<system>.<name>` | CI checks | `nix flake check` |
| `formatter.<system>` | Code formatter | `nix fmt` |

## Input Types

```nix
inputs = {
  # GitHub repo (most common)
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Specific commit
  nixpkgs.url = "github:NixOS/nixpkgs/abc123";

  # Git repo
  mylib.url = "git+https://example.com/repo.git?ref=main";

  # Local path (for development)
  mylib.url = "path:../mylib";

  # Flake in subdirectory
  mylib.url = "github:org/monorepo?dir=libs/mylib";

  # Non-flake input
  src = {
    url = "github:owner/repo";
    flake = false;
  };
};
```

## follows

Avoid duplicate nixpkgs instances by making inputs share the same nixpkgs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

## Common Patterns

### Development Shell

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [ nodejs pnpm typescript ];

  shellHook = ''
    echo "Dev environment ready"
  '';

  env = {
    DATABASE_URL = "postgresql://localhost/dev";
  };
};
```

### Package + Dev Shell

```nix
let
  myapp = pkgs.callPackage ./default.nix { };
in {
  packages.default = myapp;

  devShells.default = pkgs.mkShell {
    inputsFrom = [ myapp ];  # Inherit build dependencies
    packages = [ pkgs.nixd ];  # Add dev-only tools
  };
}
```

### NixOS Configuration

```nix
nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./hosts/myhost/configuration.nix
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.me = import ./home.nix;
    }
  ];
};
```

## CLI Commands

```bash
# Development
nix develop              # Enter dev shell
nix develop -c bash      # Run command in dev shell

# Building
nix build                # Build default package
nix build .#myapp        # Build specific package
nix log                  # Show build log of last build

# Running
nix run                  # Build and run default app
nix run .#myapp          # Run specific app
nix run nixpkgs#ripgrep  # Run from nixpkgs

# Flake management
nix flake update         # Update all inputs
nix flake update nixpkgs               # Update single input
nix flake show           # Show flake outputs
nix flake check          # Run checks
nix flake metadata       # Show input versions

# Formatting
nix fmt                  # Run configured formatter
```

## Lock File

`flake.lock` pins exact versions of all inputs. Commit it to version control. Update with `nix flake update`.

## flake-utils vs flake-parts

- **flake-utils**: Simple helper, `eachDefaultSystem` iterates over systems
- **flake-parts**: More powerful module system for flakes, better for complex setups

```nix
# flake-parts example
{
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    perSystem = { pkgs, ... }: {
      packages.default = pkgs.hello;
    };
  };
}
```
