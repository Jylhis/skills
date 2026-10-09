# devenv

## devenv 2.x Migration Notes

Current release line: devenv 2.4 (2026-09-24). devenv 2.0 (2026-03-05) rewrote the CLI on top of the Nix C API (no more spawning `nix` per command, per-attribute evaluation cache) and made a built-in native process manager the default. The 2.0 release deprecated devenv 0.x; support is dropped entirely in devenv 3.

Breaking changes when moving a 1.x project to 2.x:

- **git-hooks input is opt-in.** `git-hooks` is no longer an implicit input; add it to `devenv.yaml` if you use `git-hooks.hooks`. The `pre-commit-hooks` input alias was removed (add `pre-commit-hooks: { follows: git-hooks }` only if you switch between 1.x and 2.x). The `pre-commit.*` option path still works as a rename of `git-hooks.*`, but use `git-hooks.hooks.*`.
- **`pre-commit` command replaced by `prek`** (Rust rewrite): scripts that run `pre-commit run --all-files` must call `prek run --all-files`.
- **Native process manager is the default.** `processes.<name>.process-compose.*` settings only apply with `process.manager.implementation = "process-compose"`; translate them to native options (see Processes below).
- **`devenv build` emits JSON** mapping attributes to store paths: `devenv build languages.rust.package | jq -r '.["languages.rust.package"]'`.
- **`devenv container --copy <name>` removed**; use `devenv container copy <name>`.

Later 2.x breaking changes:

- 2.1: `devenv tasks run` defaults to `--mode before` (runs the task's dependencies too); use `--mode single` for the old behaviour. Bare `devenv` prints help, not the version.
- 2.2: `x86_64-darwin` (Intel macOS) is no longer built or released; pin an older CLI there. The shell hook and `devenv allow` detect projects by `devenv.nix`, so a directory with only `devenv.yaml` no longer auto-activates. `devenv init` no longer writes `.envrc` unless given `--include-envrc`.

Pin the CLI version a project expects with `require_version` in `devenv.yaml` (`true` = match the modules version, or a constraint such as `">=2.2"`).

## File Structure

```text
project/
  devenv.nix          # Main environment configuration
  devenv.yaml         # Input sources (nixpkgs pin, imports)
  devenv.lock         # Lock file (auto-generated, commit this)
  .devenv/            # Generated (gitignore this)
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

devenv can run background services (databases, caches, etc.) under its native process manager. See **devenv/services.md** for a complete service configuration reference.

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

Start services with `devenv up` alongside processes (`devenv up -d` to run them in the background, `devenv down` to stop).

## Processes

Define custom long-running processes:

```nix
{ pkgs, ... }: {
  processes.server.exec = "cargo run -- serve";
  processes.worker.exec = "cargo run -- worker";
  processes.frontend.exec = "cd frontend && npm run dev";
}
```

Native process manager options for ordering, readiness and restarts:

```nix
{ ... }: {
  processes.api = {
    exec = "./run-api.sh";
    after = [ "devenv:processes:postgres" ];  # waits for postgres readiness (@ready is the default)
    ready = {
      http.get = { port = 8080; path = "/health"; };
      initial_delay = 2;
    };
    restart.on = "on_failure";                # "never" | "always" | "on_failure"
    env.PORT = "8080";
    cwd = "./backend";
  };
}
```

Dependency suffixes: `@started`, `@ready` (default for processes), `@completed`; for tasks `@succeeded` (default). The manager also supports exec and `notify` (sd_notify) probes, `watch` file watching, socket activation, `watchdog`, `shutdown.signal`/`grace`, and automatic port allocation via `ports.<name>.allocate` (resolved value in `config.processes.<name>.ports.<name>.value`).

Run with `devenv up`. With processes already running, a second `devenv up` attaches to them; `devenv processes attach|list|logs|restart|stop|wait` control a running native manager. Other managers (`process-compose`, `overmind`, `honcho`, `hivemind`, `mprocs`) are available through `process.manager.implementation`, with fewer control features.

## Git Hooks

Requires the `git-hooks` input (not implicit since 2.0):

```yaml
# devenv.yaml
inputs:
  git-hooks:
    url: github:cachix/git-hooks.nix
```

```nix
{ ... }: {
  git-hooks.hooks = {
    nixfmt.enable = true;          # the nixfmt-rfc-style hook was removed

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

Run with `devenv test` (also runs the git hooks against all files). Hooks run through `prek`.

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

```bash
devenv tasks run myapp:ci
```

This executes the full dependency graph: build, then test and lint in parallel, then ci. The default `--mode before` runs the task plus its upstream dependencies; `--mode single` runs only the named task, `--mode all` also runs dependents. `wantedBy = [ "devenv:processes:db" ];` (2.4+) makes a task run whenever the listed task or process starts; pair it with `after` for ordering. Processes are tasks too (`devenv:processes:<name>`), so a task can `after` a process.

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
    version = "latest";
    copyToRoot = ./dist;
    startupCommand = "${pkgs.python3}/bin/python -m myapp";
  };

  containers.worker = {
    name = "myapp-worker";
    version = "latest";
    copyToRoot = ./dist;
    startupCommand = "${pkgs.python3}/bin/celery -A myapp worker";
  };
}
```

Build a container:

```bash
devenv container build app   # builds the "app" container
devenv container run app     # builds and runs it with Docker
devenv container --registry docker://ghcr.io/ copy app  # push to a registry
```

Built-in container names: `shell` (equivalent of `devenv shell`) and `processes` (equivalent of `devenv up`).

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

**Do NOT use `cachix/devenv-nixpkgs/rolling`** as the nixpkgs input. It adds a `nixpkgs-src` indirection node in `devenv.lock`, which causes the locked revision to diverge from `cache.nixos.org` hashes. This breaks binary cache hits and makes pin synchronization with flake.lock impossible.

Use an exact `github:NixOS/nixpkgs/<commit>` URL to keep both lock files in sync. See the **nix-hybrid** skill for the full sync recipe.

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

Cross-reference the **nix-hybrid** skill for managing two-lock-file sync (devenv.lock, flake.lock) in polyglot projects.

## CLI Commands

```bash
devenv init              # Initialize new devenv project (--include-envrc for direnv)
devenv shell             # Enter the dev shell (auto-reloads when watched files change)
devenv shell -- <cmd>    # Run command in dev shell
devenv up                # Start services and processes (attaches if already running)
devenv up -d             # Start them in the background
devenv down              # Stop background processes (= devenv processes down)
devenv processes logs <name>  # Inspect a running native-managed process
devenv test              # Run enterTest
devenv update            # Update inputs
devenv inputs add <name> <url>  # Add an input to devenv.yaml
devenv info              # Show environment info
devenv gc                # Garbage collect old generations
devenv search <pkg>      # Search for packages
devenv tasks run <name>  # Run a task and its dependencies
devenv tasks list --json # Machine-readable task graph
devenv container build <name>  # Build an OCI container
devenv build <attr>      # Build attributes, prints JSON {attr: store path}
devenv repl              # REPL with devenv, pkgs and inputs
devenv hook <shell>      # Native auto-activation hook (bash, zsh, fish, nu)
devenv allow / revoke    # Trust or untrust a directory for the hook
devenv mcp               # Launch MCP server
devenv lsp               # Start nixd language server
```

devenv 2.4 also adds an experimental `devenv machines` command for building and deploying NixOS, nix-darwin and home-manager machines next to the environment.

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

## Automatic Activation

devenv 2.x ships a native shell hook, so direnv is optional:

```bash
# ~/.bashrc (zsh: `devenv hook zsh`; fish and nushell load it automatically)
eval "$(devenv hook bash)"
```

Then run `devenv allow` once in the project. The hook activates when you `cd` into a directory containing `devenv.nix` and deactivates when you leave. `devenv --from <source> allow` binds a directory to an out-of-tree configuration (for example `github:myorg/devenv-configs?dir=rust-web`) that has no local `devenv.nix`.

### direnv Integration

direnv still works if you prefer in-place environment changes without a subshell. Create `.envrc` (or use `devenv init --include-envrc`):

```bash
# .envrc
eval "$(devenv direnvrc)"
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

`devenv` is added to `cachix.pull` automatically. Cache configuration lives in `devenv.nix` only; `devenv.yaml` has no `cachix` key.

Configure the Cachix auth token, either through SecretSpec (2.2+, nothing exported into the environment):

```yaml
# devenv.yaml
secretspec:
  enable: true
  provider: keyring
  cachix_auth_token: true
```

or with the Cachix CLI, which devenv falls back to:

```bash
cachix authtoken <token>
```

This avoids rebuilding packages that have already been built and cached by your team or CI.
