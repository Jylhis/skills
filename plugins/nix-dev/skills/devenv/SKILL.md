---
name: devenv
description: "Use for devenv.sh developer environment patterns including devenv.nix, devenv.yaml, devenv shell, devenv up, devenv init, devenv test, devenv languages, devenv processes, devenv services, pre-commit hooks in devenv, cachix caching, devenv.lock, direnv integration, ad-hoc nix environments, or enterShell configuration."
user-invocable: false
---

# devenv

[devenv](https://devenv.sh) provides declarative developer environments using Nix without requiring deep Nix knowledge.

## File Structure

```
project/
├── devenv.nix          # Main configuration
├── devenv.yaml         # Inputs (nixpkgs, etc.)
├── devenv.lock         # Pinned versions (commit this)
├── .devenv/            # Generated (gitignore this)
└── .envrc              # direnv integration (optional)
```

## devenv.nix Basics

```nix
{ pkgs, lib, config, ... }:

{
  # Packages available in the shell
  packages = with pkgs; [
    git
    curl
    jq
  ];

  # Environment variables
  env = {
    DATABASE_URL = "postgresql://localhost/dev";
    RUST_LOG = "debug";
  };

  # Shell startup hook
  enterShell = ''
    echo "Welcome to the dev environment"
    git status
  '';
}
```

## Languages

devenv has built-in support for many languages:

```nix
{
  languages.rust = {
    enable = true;
    channel = "stable";  # or "nightly", "beta"
  };

  languages.python = {
    enable = true;
    version = "3.12";
    venv.enable = true;
    venv.requirements = ./requirements.txt;
  };

  languages.go.enable = true;

  languages.javascript = {
    enable = true;
    npm.enable = true;
  };

  languages.typescript.enable = true;

  languages.nix.enable = true;  # Adds nil LSP, nixfmt, statix
}
```

## Services

Run infrastructure locally:

```nix
{
  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "myapp"; }];
    listen_addresses = "127.0.0.1";
  };

  services.redis.enable = true;

  services.minio = {
    enable = true;
    buckets = [ "uploads" ];
  };
}
```

Start services with `devenv up`.

## Processes

Define custom long-running processes:

```nix
{
  processes = {
    server.exec = "cargo run -- serve";
    worker.exec = "cargo run -- worker";
    frontend.exec = "cd frontend && npm run dev";
  };
}
```

Run with `devenv up` alongside services.

## Pre-commit Hooks

```nix
{
  pre-commit.hooks = {
    nixfmt-rfc-style.enable = true;
    rustfmt.enable = true;
    clippy.enable = true;
    shellcheck.enable = true;
    actionlint.enable = true;
  };
}
```

## Testing

```nix
{
  enterTest = ''
    echo "Running tests"
    cargo test
  '';
}
```

Run with `devenv test`.

## devenv.yaml

Controls inputs and imports:

```yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixos-unstable

imports:
  - ./backend/devenv.nix
  - ./frontend/devenv.nix
```

## CLI Commands

```bash
devenv init             # Initialize new devenv project
devenv shell            # Enter the dev shell
devenv shell -- <cmd>   # Run command in dev shell
devenv up               # Start services and processes
devenv test             # Run enterTest
devenv update            # Update inputs
devenv info             # Show environment info
devenv gc               # Garbage collect old generations
devenv search <pkg>     # Search for packages
```

## Ad-hoc Environments

For quick one-off environments without creating files:

```bash
devenv -O languages.rust.enable:bool true shell -- cargo --version
devenv -O packages:pkgs "ripgrep fd" shell -- rg --version
```

## direnv Integration

Add `.envrc` for automatic shell activation:

```bash
# .envrc
source_url "https://raw.githubusercontent.com/cachix/devenv/main/direnv-support.sh" ""
use devenv
```

Then `direnv allow`.

## Caching with Cachix

```nix
{
  cachix.push = "mycache";  # Push builds to Cachix
  cachix.pull = [ "mycache" "nix-community" ];  # Pull from caches
}
```

## Multiple Environments

Use `devenv.yaml` imports or conditional configuration for different setups (e.g., CI vs local).
