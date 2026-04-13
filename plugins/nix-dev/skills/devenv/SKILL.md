---
name: devenv
description: "Use for devenv.sh developer environment patterns including devenv.nix, devenv.yaml, devenv shell, devenv up, devenv init, devenv test, devenv languages, devenv processes, devenv services, pre-commit hooks in devenv, cachix caching, devenv.lock, direnv integration, ad-hoc nix environments, enterShell configuration, nixpkgs pin override, exact nixpkgs commit in devenv.yaml, cachix devenv-nixpkgs rolling, devenv container, devenv tasks, devenv mcp, devenv lsp, overlay integration, or MCP tool integration with mcp__devenv__search_options and mcp__devenv__search_packages."
user-invocable: false
---

# devenv

## File Structure

```
project/
  devenv.nix          # Main environment configuration
  devenv.yaml         # Input sources (nixpkgs pin, imports)
  devenv.lock         # Lock file (auto-generated, commit this)
  .devenv/            # Generated (gitignore this)
  .envrc              # direnv integration (optional)
```

## devenv.nix Basics

Every devenv.nix is a function that receives module arguments:

```nix
{ pkgs, lib, config, ... }: {
  # Environment configuration here
}
```

### Packages

```nix
{ pkgs, ... }: {
  packages = [
    pkgs.git
    pkgs.curl
    pkgs.jq
    pkgs.ripgrep
  ];
}
```

### Languages

devenv has first-class language support with toolchain management:

```nix
{ pkgs, ... }: {
  languages.python = {
    enable = true;
    version = "3.12";
    venv.enable = true;
    venv.requirements = ./requirements.txt;
  };

  languages.rust = {
    enable = true;
    channel = "stable";  # or "nightly", "beta"
  };

  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    npm.install.enable = true;
  };

  languages.go.enable = true;
  languages.java.enable = true;
  languages.elixir.enable = true;
  languages.typescript.enable = true;
  languages.nix.enable = true;
}
```

### Environment Variables

```nix
{ ... }: {
  env.DATABASE_URL = "postgres://localhost:5432/mydb";
  env.APP_ENV = "development";
  env.RUST_LOG = "debug";
}
```

### Shell Hooks

```nix
{ ... }: {
  enterShell = ''
    echo "Welcome to the dev environment"
    export PATH="$PWD/bin:$PATH"
  '';
}
```

## Services

devenv can run background services (databases, caches, etc.) via process-compose. See **references/services.md** for a complete service configuration reference.

```nix
{ pkgs, ... }: {
  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
    port = 5432;
    initialDatabases = [{ name = "myapp_dev"; }];
  };

  services.redis.enable = true;

  services.minio = {
    enable = true;
    buckets = [ "uploads" ];
  };
}
```

Start services with `devenv up` alongside processes.

## Processes

Define custom long-running processes:

```nix
{ pkgs, ... }: {
  processes.server.exec = "cargo run -- serve";
  processes.worker.exec = "cargo run -- worker";
  processes.frontend.exec = "cd frontend && npm run dev";
}
```

Process-compose options for ordering and dependencies:

```nix
{ ... }: {
  processes.api = {
    exec = "./run-api.sh";
    process-compose = {
      depends_on.postgres.condition = "process_healthy";
      readiness_probe = {
        http_get = {
          host = "127.0.0.1";
          port = 8080;
          path = "/health";
        };
        initial_delay_seconds = 2;
      };
    };
  };
}
```

Run with `devenv up` alongside services.

## Pre-commit Hooks

```nix
{ ... }: {
  pre-commit.hooks = {
    nixfmt-rfc-style.enable = true;
    rustfmt.enable = true;
    clippy.enable = true;
    shellcheck.enable = true;
    actionlint.enable = true;
    prettier = {
      enable = true;
      excludes = [ "pnpm-lock.yaml" ];
    };
  };
}
```

## Testing

```nix
{ pkgs, ... }: {
  enterTest = ''
    echo "Running tests..."
    cargo test
  '';
}
```

Run with `devenv test`.

## Tasks

devenv tasks define custom build/test pipelines with dependency ordering:

```nix
{ pkgs, ... }: {
  tasks = {
    "myapp:build" = {
      exec = "cargo build --release";
    };
    "myapp:test" = {
      exec = "cargo test";
      after = [ "myapp:build" ];
    };
    "myapp:lint" = {
      exec = "cargo clippy -- -D warnings";
    };
    "myapp:ci" = {
      exec = "echo 'All checks passed'";
      after = [ "myapp:test" "myapp:lint" ];
    };
  };
}
```

Run a task and all its dependencies:

```
devenv tasks run myapp:ci
```

This executes the full dependency graph: build, then test and lint in parallel, then ci.

## MCP Integration

devenv exposes MCP tools for discovering options and packages:

- `mcp__devenv__search_options` - Search devenv configuration options by keyword. Use this to discover available settings (e.g., search "postgres" to find all PostgreSQL-related options).
- `mcp__devenv__search_packages` - Search nixpkgs packages by name or description. Use this to find the correct package name before adding it to `packages` in devenv.nix.

Use these MCP tools when you need to:
- Find what options a language or service supports
- Discover the correct package name in nixpkgs
- Explore available configuration for a specific devenv module

## devenv mcp and lsp

devenv includes built-in MCP server and language server support:

- `devenv mcp` - Launches an MCP server that exposes the environment's tools and options. Connect this to editors or AI assistants that support MCP.
- `devenv lsp` - Starts the nixd language server configured for the project. Provides completions, diagnostics, and hover information for devenv.nix files. Useful for editor integration.

## Container Builds

devenv can build OCI container images directly from the environment:

```nix
{ pkgs, ... }: {
  containers.app = {
    name = "myapp";
    tag = "latest";
    copyToRoot = ./dist;
    startupCommand = "${pkgs.python3}/bin/python -m myapp";
  };

  containers.worker = {
    name = "myapp-worker";
    tag = "latest";
    copyToRoot = ./dist;
    startupCommand = "${pkgs.python3}/bin/celery -A myapp worker";
  };
}
```

Build a container:

```
devenv container app         # builds the "app" container
devenv container worker      # builds the "worker" container
```

This produces OCI images without Docker, using Nix for reproducible layer generation. Cross-reference the **nix-containers** skill for advanced container patterns and multi-stage builds.

## Overlay Integration

Use overlays within devenv.nix to customize or add packages:

```nix
{ pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      myapp = final.callPackage ./package.nix {};
    })
  ];

  packages = [ pkgs.myapp ];
}
```

Overlays let you:
- Override existing package versions or build flags
- Add custom packages built from local source
- Apply patches to upstream packages
- Compose multiple overlays for layered customization

```nix
{ pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      nodejs = prev.nodejs_22;
    })
    (final: prev: {
      myTool = prev.writeShellScriptBin "my-tool" ''
        echo "custom tool"
      '';
    })
  ];
}
```

## devenv.yaml

Controls inputs, imports, and nixpkgs pinning:

```yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixos-unstable
```

### Pinning Exact nixpkgs Commit

Override the default nixpkgs input with a specific commit from `NixOS/nixpkgs`:

```yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/abc123def456789...
```

After `devenv update`, `devenv.lock` will have `nodes.nixpkgs.locked.rev` pointing directly at `NixOS/nixpkgs` -- no indirection.

**Do NOT use `cachix/devenv-nixpkgs/rolling`** as the nixpkgs input. It adds a `nixpkgs-src` indirection node in `devenv.lock`, which causes the locked revision to diverge from `cache.nixos.org` hashes. This breaks binary cache hits and makes pin synchronization with npins and flake.lock impossible.

Use an exact `github:NixOS/nixpkgs/<commit>` URL to keep all three lock files in sync. See the **nix-hybrid** skill for the full sync recipe.

### Multiple Environments

Use imports in devenv.yaml to compose environments from multiple files:

```yaml
# devenv.yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixpkgs-unstable
imports:
  - ./devenv-base.nix
  - ./devenv-services.nix
```

```nix
# devenv-base.nix
{ pkgs, ... }: {
  packages = [ pkgs.git pkgs.curl ];
  languages.python.enable = true;
}
```

```nix
# devenv-services.nix
{ pkgs, ... }: {
  services.postgres.enable = true;
  services.redis.enable = true;
}
```

You can also split backend and frontend into separate devenv configurations:

```yaml
# backend/devenv.yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixpkgs-unstable
```

```nix
# backend/devenv.nix
{ pkgs, ... }: {
  languages.rust.enable = true;
  services.postgres.enable = true;
}
```

```yaml
# frontend/devenv.yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixpkgs-unstable
```

```nix
# frontend/devenv.nix
{ pkgs, ... }: {
  languages.javascript.enable = true;
  packages = [ pkgs.nodejs_22 ];
}
```

Use conditional configuration for CI vs local by checking environment variables in `enterShell` or using `lib.mkIf`.

Cross-reference the **nix-hybrid** skill for managing three-lock-file sync (devenv.lock, flake.lock, npins sources) in polyglot projects.

## CLI Commands

```bash
devenv init              # Initialize new devenv project
devenv shell             # Enter the dev shell
devenv shell -- <cmd>    # Run command in dev shell
devenv up                # Start services and processes
devenv test              # Run enterTest
devenv update            # Update inputs
devenv info              # Show environment info
devenv gc                # Garbage collect old generations
devenv search <pkg>      # Search for packages
devenv tasks run <name>  # Run a task and its dependencies
devenv container <name>  # Build an OCI container
devenv mcp               # Launch MCP server
devenv lsp               # Start nixd language server
```

## Ad-hoc Environments

For quick one-off environments without creating files:

```bash
devenv -O languages.rust.enable:bool true shell -- cargo --version
devenv -O packages:pkgs "ripgrep fd" shell -- rg --version
```

Use ad-hoc environments when:
- You need a quick tool that is not in the project environment
- Testing a language or package before adding it to devenv.nix
- Running a one-off command in an isolated environment

## direnv Integration

Create `.envrc` for automatic environment activation:

```bash
# .envrc
source_url "https://raw.githubusercontent.com/cachix/devenv/main/direnv-support.sh" ""
use devenv
```

Then run `direnv allow`. The environment activates automatically when you enter the directory and deactivates when you leave.

## Caching with Cachix

Speed up builds by pushing/pulling from a binary cache:

```nix
{
  cachix.push = "mycache";
  cachix.pull = [ "mycache" "nix-community" ];
}
```

Or configure in devenv.yaml:

```yaml
cachix:
  pull:
    - devenv
    - myorg
  push: myorg
```

Configure the Cachix auth token:

```
cachix authtoken <token>
```

This avoids rebuilding packages that have already been built and cached by your team or CI.
