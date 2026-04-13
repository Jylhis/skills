---
name: flakes
description: "Use for Nix flakes structure and workflows including flake.nix, flake.lock, nix flake commands, nix develop, nix build, nix run, nix shell, nix fmt, inputs, outputs, devShells, packages, nixosConfigurations, follows, flake-utils, flake-parts, flake templates, eachDefaultSystem, flake checks, pure evaluation constraints, nix flake check evaluation depth, impure inputs, flake output safety, flake limitations, non-flake CLI equivalences, follows with null, flake-compat, or registry management."
user-invocable: false
---

# Nix Flakes

## Flake Structure

A flake is a directory containing `flake.nix` with an attribute set containing `inputs` and `outputs`. The lock file `flake.lock` pins every input to an exact revision.

```nix
{
  description = "Example flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # see outputs table below
  };
}
```

## Outputs Table

| Attribute | Purpose |
|---|---|
| `packages.<system>.<name>` | Buildable packages (`nix build .#name`) |
| `packages.<system>.default` | Default package (`nix build`) |
| `devShells.<system>.default` | Dev shell (`nix develop`) |
| `apps.<system>.<name>` | Runnable apps (`nix run .#name`) |
| `overlays.<name>` | Nixpkgs overlays |
| `nixosModules.<name>` | NixOS modules |
| `nixosConfigurations.<host>` | Full NixOS system configs |
| `lib` | Shared library functions |
| `templates.<name>` | Flake templates (`nix flake init -t`) |
| `checks.<system>.<name>` | CI checks (`nix flake check`) |
| `formatter.<system>` | Default formatter (`nix fmt`) |
| `homeConfigurations.<user>` | Home Manager configs (convention) |
| `darwinConfigurations.<host>` | nix-darwin configs (convention) |

## Input Types

```nix
inputs = {
  # GitHub repository (most common)
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Specific commit
  nixpkgs.url = "github:NixOS/nixpkgs/abc123";

  # Git repository
  mylib.url = "git+https://example.com/repo.git?ref=main";

  # Local path (useful during development)
  mylib.url = "path:./lib";

  # Flake in subdirectory
  mylib.url = "github:org/monorepo?dir=libs/mylib";

  # Tarball
  archive.url = "https://example.com/archive.tar.gz";

  # Non-flake input (raw source)
  vim-plugin = {
    url = "github:author/plugin";
    flake = false;
  };

  # Indirect (from registry)
  nixpkgs.url = "nixpkgs";
};
```

## Input Follows

Use `follows` to deduplicate shared transitive inputs and avoid multiple versions of the same dependency:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### Follows with Null

Disable unused transitive inputs entirely by following to the empty string. This prevents fetching dependencies you never use:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  some-flake = {
    url = "github:owner/some-flake";
    inputs.nixpkgs.follows = "nixpkgs";
    # This flake pulls in flake-utils but we never reference it.
    # Setting to "" avoids fetching it at all.
    inputs.flake-utils.follows = "";
  };
};
```

The empty string `""` means "this input does not exist." The downstream flake must tolerate the missing input (most do when it is only used in `outputs` argument destructuring with a default).

## Flake Limitations

Understand these before adopting flakes for a project:

- **No configuration support.** Flake outputs are fixed at eval time. You cannot parameterise a flake the way you parameterise a NixOS module. If consumers need variants, the flake must anticipate them (e.g. expose multiple packages or accept overlay-based customisation).
- **Cross-compilation and `packages.${system}`.** The system-indexed output schema (`packages.x86_64-linux`) conflates build platform and target platform. Cross-compiled derivations do not fit neatly; you end up with `packages.x86_64-linux.aarch64-linux-hello` or use `legacyPackages` with `pkgsCross`.
- **Serial fetcher blocks evaluation.** Nix fetches each input one at a time during evaluation. Flakes with many inputs pay a latency tax on every `nix` invocation until everything is cached.
- **Entire directory copied to store.** The flake source is copied to `/nix/store` as a whole. Large repos with build artifacts or data files bloat the store unless `.gitignore` excludes them (Nix respects `.gitignore` for git flakes).
- **Git staging requirement.** Only files tracked by git (at least staged with `git add`) are visible inside the flake. New untracked files silently disappear, causing confusing "file not found" errors.

## Non-Flake CLI Equivalences

When working outside flakes or converting legacy commands:

| Classic CLI | Flake-era equivalent |
|---|---|
| `nix-build -A hello` | `nix build -f . hello` |
| `nix-build '<nixpkgs>' -A hello` | `nix build nixpkgs#hello` |
| `nix-shell -A blah` | `nix develop -f . blah` |
| `nix-shell -p curl jq` | `nix shell nixpkgs#curl nixpkgs#jq` |
| `nix-build -E 'with import <nixpkgs> {}; ...'` | `nix build --impure --expr 'with import <nixpkgs> {}; ...'` |
| `nix-env -iA nixpkgs.hello` | `nix profile install nixpkgs#hello` |
| `nix-instantiate --eval -E '1+1'` | `nix eval --expr '1+1'` |

The `-f` / `--file` flag makes the new CLI operate on a plain Nix file instead of a flake, which is useful for gradual migration.

## Flake-Compat

Use `flake-compat` to provide `default.nix` and `shell.nix` wrappers so that users without flakes enabled can still build and develop.

Add `flake-compat` as an input in `flake.nix`:

```nix
inputs.flake-compat = {
  url = "github:edolstra/flake-compat";
  flake = false;
};
```

### default.nix

```nix
# default.nix
(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    nodeSrc = lock.nodes.flake-compat.locked;
  in
    fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${nodeSrc.rev}.tar.gz";
      sha256 = nodeSrc.narHash;
    }
) { src = ./.; })
.defaultNix
```

### shell.nix

```nix
# shell.nix
(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    nodeSrc = lock.nodes.flake-compat.locked;
  in
    fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${nodeSrc.rev}.tar.gz";
      sha256 = nodeSrc.narHash;
    }
) { src = ./.; })
.shellNix
```

## Registry Management

The flake registry maps short names (e.g. `nixpkgs`) to full flake URLs.

### Commands

```bash
# List all registries (global + system + user)
nix registry list

# Pin a registry entry to a specific revision
nix registry pin nixpkgs

# Add a custom entry to the user registry
nix registry add my-lib github:owner/my-lib

# Remove an entry
nix registry remove my-lib
```

### Registry Locations

| Scope | File |
|---|---|
| User | `~/.config/nix/registry.json` |
| System | `/etc/nix/registry.json` |
| Global | Fetched from `https://channels.nixos.org/flake-registry.json` |

User entries override system entries, which override global entries. Use `--registry` flag to point to a custom registry file. Pin registries in CI to ensure reproducibility.

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

### Multi-system with forEachSystem

```nix
outputs = { self, nixpkgs }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f {
      pkgs = nixpkgs.legacyPackages.${system};
    });
  in {
    packages = forEachSystem ({ pkgs }: {
      default = pkgs.callPackage ./. {};
    });
    devShells = forEachSystem ({ pkgs }: {
      default = pkgs.mkShell {
        packages = [ pkgs.nixfmt-rfc-style ];
      };
    });
  };
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

### Overlay Pattern

```nix
outputs = { self, nixpkgs }: {
  overlays.default = final: prev: {
    mypackage = final.callPackage ./package.nix {};
  };
};
```

## CLI Commands

```bash
nix flake init              # Create flake.nix from template
nix flake init -t templates#name  # From a specific template
nix flake update            # Update all inputs
nix flake update nixpkgs    # Update single input
nix flake lock --update-input nixpkgs  # Same (older syntax)
nix flake show              # Show outputs
nix flake metadata          # Show inputs and metadata
nix flake check             # Run checks and validate structure
nix flake archive           # Copy flake and inputs to store
nix build .#package         # Build a specific package
nix build                   # Build default package
nix develop                 # Enter dev shell
nix develop -c bash         # Run command in dev shell
nix run .#app               # Run an app
nix run nixpkgs#ripgrep     # Run from nixpkgs
nix fmt                     # Run configured formatter
nix log                     # Show build log of last build
```

## Pure Evaluation Constraints

Flakes evaluate in pure mode by default:

- No access to environment variables (`builtins.getEnv` returns `""`)
- No unrestricted filesystem access outside the flake source
- No `<nixpkgs>` angle-bracket paths (NIX_PATH ignored)
- `builtins.currentSystem` unavailable (must thread `system` explicitly)
- `--impure` flag lifts all restrictions when needed

`nix flake check` evaluates different outputs to different depths:

| Output | Evaluation depth | Impure safe? |
|--------|-----------------|-------------|
| `packages.<system>.*` | **Full** -- derivation is evaluated | No |
| `checks.<system>.*` | **Full** -- evaluated and built | No |
| `overlays.default` | Arity check only (body not forced) | Yes |
| `darwinConfigurations` | Shallow (attrset structure) | Yes |
| `nixosConfigurations` | Shallow (attrset structure) | Yes |
| `homeManagerModules` | Non-standard -- warns, does NOT fail | Yes |

**Formatter caveat:** If the flake's `systems` list doesn't include the current dev platform (e.g., linux-only flake on macOS), `nix fmt` fails with `does not provide attribute 'formatter.x86_64-darwin'`. Use `nixfmt .` directly or add all dev platforms to the systems list.

## flake-utils vs flake-parts

**flake-utils** is a thin helper that provides `eachDefaultSystem` and a handful of utility functions. It reduces boilerplate but offers no type checking or module composition.

```nix
# flake-utils example
{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        packages.default = pkgs.hello;
      }
    );
}
```

**flake-parts** uses the NixOS module system to structure flake outputs. It provides type-checked options, composable modules, and a `perSystem` pattern that cleanly separates per-system and flake-level attributes.

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

See `references/flake-parts.md` for detailed flake-parts patterns including the dendritic module pattern, perSystem API, and ecosystem module list.

For hybrid flake/non-flake project architectures, see the **nix-hybrid** skill.
