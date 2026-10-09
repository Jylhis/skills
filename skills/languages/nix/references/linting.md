# Nix Linting and Static Analysis

## Tool Overview

| Tool              | Purpose                        | Fix mode          |
| ----------------- | ------------------------------ | ----------------- |
| statix            | Anti-pattern / lint warnings   | `statix fix`      |
| deadnix           | Dead code detection            | `deadnix --edit`  |
| nixfmt            | Canonical formatter (one file) | `nixfmt`          |
| treefmt           | Multi-formatter orchestration  | `treefmt`         |
| nixfmt-tree       | treefmt preconfigured for nixfmt | `treefmt`       |
| nom               | Build progress display         | wraps nix commands|
| nix-instantiate   | Eval-time error checking       | N/A (read-only)   |
| nix flake check   | Flake-level evaluation + tests | N/A (read-only)   |

## statix

The original `oppiliappan/statix` repo now carries a caution banner and has
had no release since v0.5.8 (2023). The Nixpkgs `statix` package builds the
Molybdenum Software fork (`github:molybdenumsoftware/statix`) from HEAD
(version `0.5.8-unstable-*`); that fork does not plan further tagged releases.
CLI and lint names are unchanged.

### Basic Usage

```bash
# Check for anti-patterns (exits 1 if findings)
statix check .

# Auto-fix what it can
statix fix .

# Check a specific file
statix check path/to/file.nix

# Explain a warning by code (codes come from `statix list`)
statix explain W04

# Fix exactly one finding at a line,column position
statix single -p 12,5 file.nix
```

### Ignore Paths

**Critical:** current statix (clap 4) takes ONE glob per `--ignore`/`-i`.
Repeat the flag for multiple globs. statix also respects `.gitignore` by
default (`-u` disables that), so gitignored `.devenv/` and `result` are
already skipped.

```bash
# Correct: one --ignore per glob
statix check . --ignore '.devenv/*' --ignore 'result/*'

# WRONG: the second glob is parsed as an extra positional and errors out
# ("unexpected argument 'result/*' found")
statix check . --ignore '.devenv/*' 'result/*'
```

Older statix READMEs show `-i a.nix b.nix`; that form fails with the
statix shipped in nixpkgs 26.05 and unstable.

### statix.toml Configuration

Place `statix.toml` at the repo root (statix searches parent directories,
or pass `--config`). The file has two top-level lists, `disabled` (lint
names) and `ignore` (path globs). `statix dump > statix.toml` writes a
starter file.

```toml
# W20 (repeated_keys) fires on idiomatic flat-attribute module style:
#   nixpkgs.config.allowUnfree = true;
#   nixpkgs.hostPlatform = "...";
# This is intentional NixOS module syntax, not a bug.
disabled = ["repeated_keys"]

# Generated, vendored, or doc-only files:
ignore = [".direnv", "generated/hardware-configuration.nix"]
```

### Severity

statix treats all findings (warnings and errors) equally — any finding
causes exit code 1. There is no severity filtering or warning-only mode.

Common lint names: `manual_inherit`, `manual_inherit_from`, `legacy_let_syntax`, `empty_pattern`, `redundant_pattern_bind`, `unquoted_uri`, `deprecated_to_path`, `empty_let_in`, `useless_parens`, `empty_inherit`, `repeated_keys`, `empty_list_concat`. Use `statix list` to see the current set with their `W`-codes, and `statix explain <code>` (for example `statix explain W20`) for a single lint's docs. `statix.toml` uses the names; `explain` takes the codes.

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

**Critical:** `--exclude` takes multiple paths in a single flag, and it is
greedy: it swallows every following argument, including the target
directory. Put the target first or end the list with `--`. Paths are
literal, not glob patterns. deadnix skips hidden directories such as
`.devenv` unless `--hidden` is given.

```bash
# Correct: target first, then one --exclude with several paths
deadnix --fail . --exclude result vendor

# Correct: terminate the exclude list explicitly
deadnix --fail --exclude result vendor -- .

# WRONG: "." becomes an exclude, nothing is scanned, exit code 0
deadnix --fail --exclude result vendor .

# WRONG: repeated --exclude flags are rejected
deadnix --exclude result --exclude vendor .
```

### Options

| Flag                         | Effect                              |
| ---------------------------- | ----------------------------------- |
| `--fail`                     | Non-zero exit on findings (CI mode) |
| `--edit`                     | Remove dead code in-place           |
| `--exclude PATH...`          | Skip files or directories           |
| `--no-lambda-arg`            | Ignore unused lambda arguments      |
| `--no-lambda-pattern-names`  | Ignore unused pattern names         |
| `--no-underscore`            | Skip all bindings starting with `_` |
| `--hidden`                   | Recurse into hidden directories     |
| `--output-format json`       | Machine-readable output             |
| `--quiet`                    | Suppress output, exit code only     |

## nixfmt

The official Nix formatter implementing RFC 166, maintained by the Nix
formatting team (1.0.0 in July 2025, 1.5.x current). Since nixpkgs 25.11,
`pkgs.nixfmt` IS this formatter. `pkgs.nixfmt-rfc-style` is a deprecated
alias that emits a warning. `pkgs.nixfmt-classic` (the pre-RFC formatter)
warns on 26.05 and throws on unstable. Use `pkgs.nixfmt` in new code. All of
Nixpkgs was reformatted with it and Nixpkgs CI enforces the format.

`nixfmt` formats files, not trees: passing a directory (`nixfmt .`) is
deprecated and prints a warning. Use `nixfmt-tree` or treefmt-nix for a
whole project.

```bash
# Format specific files in place
nixfmt flake.nix default.nix

# Check formatting without modifying (exits 1 if changes needed)
nixfmt --check flake.nix default.nix

# Whole project (treefmt preconfigured for nixfmt)
nix run nixpkgs#nixfmt-tree
```

Other useful flags: `--indent N`, `--width N`, `--mergetool` (resolves
formatting-only merge conflicts via `git mergetool -t nixfmt`), and
`--follow-symlinks` (1.5+). Since 1.4, `/*nixfmt:disable*/` and
`/*nixfmt:enable*/` comments exclude a region from formatting.

For `nix fmt`, point the flake `formatter` at `nixfmt-tree` (or a treefmt-nix
wrapper), not at bare `nixfmt`. Since Nix 2.25, `nix fmt` with no arguments
no longer passes `.` to the formatter, so bare `nixfmt` would just wait on
stdin.

```nix
formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
```

## nom (nix-output-monitor)

Wraps Nix build commands with a progress display showing build graphs and download statistics.

### Basic Usage

```bash
nom build .#mypackage        # build with progress display
nom shell .#devShell          # enter shell with progress
nom develop                   # develop with progress (evaluates twice)
nix build --log-format internal-json -v .#mypackage |& nom --json  # pipe mode
nixos-rebuild build |& nom    # human-log parsing for wrappers without JSON
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
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
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

The flake module sets `formatter` (`treefmt.flakeFormatter`, default on) and
adds a `checks.<system>.treefmt` check (`treefmt.flakeCheck`, default on), so
`nix flake check` fails on unformatted files. Without flake-parts, use
`treefmt-nix.lib.evalModule pkgs ./treefmt.nix` and expose
`config.build.wrapper` as `formatter` and `config.build.check self` as a check.

### Running

```bash
nix fmt                       # format everything (delegates to treefmt)
treefmt                       # run directly
treefmt --ci                  # CI mode: --no-cache + --fail-on-change
treefmt --fail-on-change      # exit 1 if any file changed
```

treefmt 2.x has no `--check` flag. `--ci` still rewrites files before
failing, so run it on a throwaway checkout.

### Standalone treefmt.toml

```toml
[formatter.nixfmt]
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

### Parsing Nix Files Safely

```bash
# Parse only (syntax check)
nix-instantiate --parse default.nix
```

Use `--parse` for CI syntax checks on repository-controlled Nix files.
Avoid `nix-instantiate --eval` for untrusted code because evaluation can
execute builtins that read local files, inspect environment variables,
or trigger fetches.

## nix flake check

Use as the flake-level lint pass — it evaluates all outputs (at depths that vary per output type) and runs every derivation under `checks.<system>.*`.

For the per-output evaluation depth table and pure-eval caveats (non-standard output warnings, `--no-build` false failures, formatter system mismatch, IFD slowness), see the **flakes** skill.

## Git hooks (git-hooks.nix / devenv)

`cachix/git-hooks.nix` (formerly `pre-commit-hooks.nix`) ships `nixfmt`,
`statix`, `deadnix`, `nil` and `nixf-diagnose` hooks. Use `hooks.nixfmt`:
the `nixfmt-rfc-style` and `nixfmt-classic` hooks were removed and now fail
with an assertion pointing to `hooks.nixfmt`.

devenv integrates it directly. The option is `git-hooks` (the old
`pre-commit` name is a renamed alias), and since devenv 2.0 the `git-hooks`
input must be listed in `devenv.yaml`. The default hook runner is now `prek`.

```nix
# devenv.nix
{ pkgs, ... }: {
  git-hooks.hooks = {
    nixfmt.enable = true;
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
treefmt --ci                      # or: nixfmt --check $(git ls-files '*.nix')
statix check .
deadnix --fail .
nix-instantiate --parse default.nix
```

For flake projects, add:

```bash
nix flake check
```

### Justfile Recipe

```just
lint:
    treefmt --fail-on-change
    statix check . --ignore 'vendor/*' --ignore 'generated/*'
    deadnix --fail . --exclude vendor generated

lint-fix:
    statix fix .
    deadnix --edit .
    treefmt

check:
    nix flake check
```

### Quick GitHub Actions step

```yaml
- uses: DeterminateSystems/nix-installer-action@main   # installs Determinate Nix
- uses: DeterminateSystems/magic-nix-cache-action@main
- run: nix develop --command just lint
```

See linting/ci-pipeline.md for CI/CD workflow templates.
