---
name: nix-linting
description: "Use for Nix static analysis and linting tools including statix, deadnix, nixfmt, statix check, statix fix, statix.toml, deadnix --fail, deadnix --exclude, nixfmt --check, nixfmt-rfc-style, nix flake check warnings, nix-instantiate --eval, CI lint pipeline for Nix code, nix code quality, Nix anti-pattern detection, treefmt-nix, nom nix-output-monitor, or CI/CD pipeline configuration."
user-invocable: false
---

# Nix Linting and Static Analysis

## Tool Overview

| Tool              | Purpose                        | Fix mode          |
| ----------------- | ------------------------------ | ----------------- |
| statix            | Anti-pattern / lint warnings   | `statix fix`      |
| deadnix           | Dead code detection            | `deadnix --edit`  |
| nixfmt            | Canonical formatter            | `nixfmt`          |
| treefmt           | Multi-formatter orchestration  | `treefmt`         |
| nom               | Build progress display         | wraps nix commands|
| nix-instantiate   | Eval-time error checking       | N/A (read-only)   |
| nix flake check   | Flake-level evaluation + tests | N/A (read-only)   |

## statix

### Basic Usage

```bash
# Check for anti-patterns (exits 1 if findings)
statix check .

# Auto-fix what it can
statix fix .

# Check a specific file
statix check path/to/file.nix

# Explain a specific warning
statix single -w W04 file.nix
```

### Ignore Paths

**Critical:** `--ignore` takes a SINGLE flag with multiple glob
arguments. Do NOT use multiple `--ignore` flags.

```bash
# Correct — single --ignore with multiple globs
statix check . --ignore '.devenv/*' 'result/*'

# WRONG — multiple --ignore flags (only the last one takes effect)
statix check . --ignore '.devenv/*' --ignore 'result/*'
```

### statix.toml Configuration

Place `statix.toml` at the repo root to configure project-wide settings:

```toml
[disabled]
# W20 (repeated_keys) fires on idiomatic flat-attribute module style:
#   nixpkgs.config.allowUnfree = true;
#   nixpkgs.hostPlatform = "...";
# This is intentional NixOS module syntax, not a bug.
repeated_keys = true

[nix_file_blacklist]
# Add generated, vendored, or doc-only files:
# "generated/hardware-configuration.nix"
```

### Severity

statix treats all findings (warnings and errors) equally — any finding
causes exit code 1. There is no severity filtering or warning-only mode.

Common lint names: `manual_inherit`, `legacy_let`, `empty_pattern`, `redundant_pattern_bind`, `unquoted_uri`, `deprecated_to_path`, `empty_let_in`, `deprecated_is_null`, `useless_parens`, `empty_inherit`, `repeated_keys`. Use `statix list` to see the current set, and `statix explain <name>` for a single lint's docs.

## deadnix

### Basic Usage

```bash
# Report dead code (exits 0 even with findings by default)
deadnix .

# Exit 1 on any findings (use for CI)
deadnix --fail .

# Auto-fix (remove dead code)
deadnix --edit .

# Check a specific file
deadnix path/to/file.nix
```

### Exclude Directories

**Critical:** `--exclude` takes multiple directory arguments in a single
flag. Directories are names, not glob patterns.

```bash
# Correct — single --exclude with multiple directories
deadnix --exclude .devenv result .

# WRONG — multiple --exclude flags
deadnix --exclude .devenv --exclude result .
```

### Options

| Flag                         | Effect                              |
| ---------------------------- | ----------------------------------- |
| `--fail`                     | Non-zero exit on findings (CI mode) |
| `--edit`                     | Remove dead code in-place           |
| `--exclude PATH...`          | Skip files or directories           |
| `--no-lambda-arg`            | Ignore unused lambda arguments      |
| `--no-lambda-pattern-names`  | Ignore unused pattern names         |
| `--no-underscore`            | Report `_`-prefixed names too       |
| `--quiet`                    | Suppress output, exit code only     |

## nixfmt

The canonical Nix formatter implementing RFC 166. As of nixpkgs 25.05, `pkgs.nixfmt` IS this formatter — `pkgs.nixfmt-rfc-style` is now a deprecated alias kept for backwards compatibility, and the old formatter lives on as `pkgs.nixfmt-classic`. Use `pkgs.nixfmt` in new code.

```bash
# Format all Nix files in place
nixfmt .

# Check formatting without modifying (exits 1 if changes needed)
nixfmt --check .

# Format specific files
nixfmt flake.nix default.nix
```

In nixpkgs and flake-parts projects, `nix fmt` delegates to the formatter defined in `flake.nix`:

```nix
formatter.x86_64-linux = pkgs.nixfmt;
```

## nom (nix-output-monitor)

Wraps Nix build commands with a progress display showing build graphs and download statistics.

### Basic Usage

```bash
nom build .#mypackage        # build with progress display
nom shell .#devShell          # enter shell with progress
nom develop                   # develop with progress
nix build 2>&1 | nom          # pipe mode for any nix command
```

### Features

- Real-time build graph visualization
- Download progress with speed and ETA
- Build failure summary with log paths
- Color-coded status indicators
- Shows total build/download statistics at completion

Useful for both CI (readable build logs) and local development (understanding what is building).

## treefmt-nix

Multi-formatter framework that runs multiple formatters in one pass. Configure nixfmt, rustfmt, prettier, shfmt, and others in a single config.

### With flake-parts

```nix
# flake.nix
{
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.treefmt-nix.flakeModule ];
    perSystem = { ... }: {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.rustfmt.enable = true;
        programs.prettier.enable = true;
        programs.shfmt.enable = true;
      };
    };
  };
}
```

### Running

```bash
nix fmt                       # format everything (delegates to treefmt)
treefmt                       # run directly
treefmt --fail-on-change      # CI mode — exit 1 if changes needed
```

### Standalone treefmt.toml

```toml
[formatter.nix]
command = "nixfmt"
includes = ["*.nix"]

[formatter.rust]
command = "rustfmt"
options = ["--edition", "2021"]
includes = ["*.rs"]

[formatter.shell]
command = "shfmt"
options = ["-i", "2"]
includes = ["*.sh"]
```

## nix-instantiate

### Evaluating Nix Files

```bash
# Evaluate a Nix expression
nix-instantiate --eval default.nix

# With strict evaluation (force thunks)
nix-instantiate --eval --strict default.nix

# Parse only (syntax check)
nix-instantiate --parse default.nix
```

**Important:** When `default.nix` is a function (e.g.,
`{ pkgs ? ... }: ...`), `--eval` returns `<LAMBDA>` and exits 0. This
is expected behavior — it confirms the file parses and evaluates to a
valid function. It is sufficient as a CI syntax check.

## nix flake check

Use as the flake-level lint pass — it evaluates all outputs (at depths that vary per output type) and runs every derivation under `checks.<system>.*`.

For the per-output evaluation depth table and pure-eval caveats (non-standard output warnings, `--no-build` false failures, formatter system mismatch, IFD slowness), see the **flakes** skill.

## devenv pre-commit hooks

As an alternative to standalone lint setup, devenv integrates pre-commit hooks directly:

```nix
# devenv.nix
{ pkgs, ... }: {
  pre-commit.hooks = {
    nixfmt-rfc-style.enable = true;
    statix.enable = true;
    deadnix.enable = true;
  };
}
```

This runs linters automatically on `git commit`. Cross-reference the devenv skill for full configuration.

## CI Integration

Combine all linting tools in a single recipe:

```bash
# Full lint pipeline
nixfmt --check .
statix check . --ignore '.devenv/*' 'result/*'
deadnix --fail --exclude .devenv result .
nix-instantiate --parse default.nix
```

For flake projects, add:

```bash
nix flake check
```

### Justfile Recipe

```just
lint:
    nixfmt --check .
    statix check . --ignore '.devenv/*' 'result/*'
    deadnix --fail --exclude .devenv result .

lint-fix:
    statix fix .
    deadnix --edit .
    nixfmt .

check:
    nix flake check
```

### Quick GitHub Actions step

```yaml
- uses: DeterminateSystems/nix-installer-action@main
- uses: DeterminateSystems/magic-nix-cache-action@main
- run: nix develop --command just lint
```

See references/ci-pipeline.md for CI/CD workflow templates.
