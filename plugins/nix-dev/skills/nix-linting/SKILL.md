---
name: nix-linting
description: "Use for Nix static analysis and linting tools including statix, deadnix, nixfmt, statix check, statix fix, statix.toml, deadnix --fail, deadnix --exclude, nixfmt --check, nixfmt-rfc-style, nix flake check warnings, nix-instantiate --eval, CI lint pipeline for Nix code, nix code quality, or Nix anti-pattern detection."
user-invocable: false
---

# Nix Linting and Static Analysis

## Tool Overview

| Tool | Purpose | What it detects |
|------|---------|----------------|
| **statix** | Anti-pattern linter | Unused let bindings, eta-reducible functions, legacy `let { }`, manual `inherit`, repeated keys |
| **deadnix** | Dead code finder | Unused function arguments, unused let bindings, unused `with` imports |
| **nixfmt** | Code formatter | Style inconsistencies (nixfmt-rfc-style is the standard) |

## statix

### Basic Usage

```bash
# Check for anti-patterns (exits 1 if findings)
statix check .

# Auto-fix what it can
statix fix .

# Check a specific file
statix check path/to/file.nix
```

### Ignore Paths

**Critical:** `--ignore` takes a SINGLE flag with multiple glob
arguments. Do NOT use multiple `--ignore` flags.

```bash
# Correct — single --ignore with multiple globs
statix check . --ignore 'npins/*' '.devenv/*' 'result/*'

# WRONG — multiple --ignore flags (only the last one takes effect)
statix check . --ignore 'npins/*' --ignore '.devenv/*'
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

## deadnix

### Basic Usage

```bash
# Report dead code (exits 0 even with findings by default)
deadnix .

# Exit 1 on any findings (use for CI)
deadnix --fail .

# Auto-fix (remove dead code)
deadnix --edit .
```

### Exclude Directories

**Critical:** `--exclude` takes multiple directory arguments in a single
flag. Directories are names, not glob patterns.

```bash
# Correct — single --exclude with multiple directories
deadnix --exclude npins .devenv result .

# Check a specific file
deadnix path/to/file.nix
```

### Options

```bash
deadnix --no-lambda-arg      # Don't report unused lambda args
deadnix --no-lambda-pattern-names  # Don't report unused pattern names
deadnix --no-underscore       # Don't report unused _-prefixed names
```

## nixfmt

The standard Nix formatter. Uses `nixfmt-rfc-style` conventions.

```bash
# Format all Nix files in place
nixfmt .

# Check formatting without modifying (exits 1 if changes needed)
nixfmt --check .

# Format specific files
nixfmt flake.nix default.nix
```

### Formatting Before Migration

When doing large refactors, run `nixfmt .` and commit separately
(message: `style: nixfmt`) to keep cosmetic changes out of the
functional commit.

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

### Evaluation Behavior

`nix flake check` evaluates different outputs to different depths:

| Output | Evaluation | Notes |
|--------|-----------|-------|
| `packages.<system>.*` | **Full** evaluation | Fails if impure |
| `checks.<system>.*` | **Full** evaluation + build | Runs tests |
| `overlays.default` | Arity check only | Body not evaluated |
| `darwinConfigurations` | Shallow (attrset structure) | Safe with impure deps |
| `nixosConfigurations` | Shallow (attrset structure) | Safe with impure deps |
| `homeManagerModules` | **Non-standard output** | Warns but does NOT fail |

### Common Gotchas

**Non-standard output warnings:** Outputs like `homeManagerModules` are
not in the flake schema. `nix flake check` warns about them but does NOT
fail. The warnings are expected and harmless — do not suppress them.

**`--no-build` false failures:** `nix flake check --no-build` can fail
if a dependency's `.drv` file was garbage collected. Prefer running
without `--no-build` — it will fetch from binary cache if available.

**Formatter system mismatch:** If the flake's `systems` list doesn't
include the current dev platform (e.g., a linux-only flake on macOS),
`nix fmt` fails with:

```
error: flake does not provide attribute 'formatter.x86_64-darwin'
```

Fix by either adding all dev platforms to the systems list, or using
`nixfmt .` directly instead of `nix fmt`.

## CI Integration

Combine all linting tools in a single recipe:

```bash
# Full lint pipeline
nixfmt --check .
statix check . --ignore 'npins/*' '.devenv/*' 'result/*'
deadnix --fail --exclude npins .devenv result .
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
    statix check . --ignore 'npins/*' '.devenv/*' 'result/*'
    deadnix --fail --exclude npins .devenv result .
```
