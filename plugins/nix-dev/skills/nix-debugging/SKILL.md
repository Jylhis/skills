---
name: nix-debugging
description: "Use for Nix debugging and troubleshooting including infinite recursion, hash mismatch, IFD import from derivation, build failures, nix log, nix why-depends, evaluation errors, attribute missing, unfree package errors, collision errors, builtins.trace, nix repl, nix eval, nix path-info, store paths, garbage collection, closure size analysis, slow evaluation diagnosis, --show-trace, nix-tree, nix-diff, or nom nix-output-monitor."
user-invocable: false
---

# Nix Debugging

## Debugging Methodology

Follow this sequence when something breaks:

1. **Read the error message** — Nix errors are verbose but informative
2. **Add `--show-trace`** — reveals the full evaluation call stack
3. **Use `builtins.trace`** — insert print statements in Nix expressions
4. **Enter `nix repl`** — interactively evaluate subexpressions
5. **Use `nix develop`** — for build failures, run phases manually
6. **Check `nix log`** — read build output for compilation/test failures

## The `--show-trace` Flag

The most important debugging tool. Without it, Nix shows only the final error. With it, you see the full call stack through all module evaluations and function calls.

```bash
# Add --show-trace to ANY nix command
nix build --show-trace .#myPackage
nix eval --show-trace .#myPackage.version
nix flake check --show-trace

# Legacy commands
nix-build --show-trace
nixos-rebuild switch --show-trace
```

**Reading `--show-trace` output:** Scan from bottom (the error) upward. The first frame you recognize from your own code is usually where the bug is. Ignore framework/nixpkgs frames unless the error points to a type mismatch or missing option.

## Common Errors and Fixes

### Infinite Recursion

```
error: infinite recursion encountered
```

**Causes:**
- Using `rec { }` where an attribute references itself circularly
- Overlay using `final` where `prev` is needed (or vice versa)
- NixOS module that sets an option it also reads without `mkIf`

**Debug:** Add `builtins.trace` calls to narrow down which attribute triggers it. In overlays, ensure you use `prev.pkg` for the package being modified and `final.dep` for dependencies.

### Hash Mismatch

```
error: hash mismatch in fixed-output derivation
  specified: sha256-AAAA...
  got:       sha256-BBBB...
```

**Fix:** Replace the hash with the correct one from the error. Or use `lib.fakeHash` / `""` during development to get the correct hash from the error.

### Attribute Not Found

```
error: attribute 'foo' missing
```

**Debug:**
```bash
nix eval nixpkgs#foo --apply 'x: builtins.typeOf x'
nix eval nixpkgs#lib --apply builtins.attrNames
```

Common cause: typo, package renamed/removed, wrong nixpkgs version. Use `mcp-nixos` MCP tools to search for the correct package name.

### Collision Between Packages

```
error: collision between '/nix/store/...-foo/bin/bar' and '/nix/store/...-baz/bin/bar'
```

**Fix:**
```nix
home.packages = [
  (lib.hiPrio pkgs.foo)  # This one wins
  pkgs.baz
];
```

### IFD (Import From Derivation)

```
error: cannot build during evaluation (import from derivation)
```

IFD happens when evaluation requires building something first (`import someDrv`, `readFile "${someDrv}/..."`). The evaluator blocks all other evaluation while the build runs. Fix by:
- Pre-generating the Nix file and committing it
- Using `builtins.fetchurl` instead of derivation-based fetchers during eval
- Allowing IFD with `--allow-import-from-derivation` (not recommended for CI)

See the nix-performance skill for IFD alternatives and consolidation strategies.

### Unfree Package

```
error: Package 'foo' has an unfree license ('unfree')
```

```nix
# In flake or configuration
nixpkgs.config.allowUnfree = true;

# Per-package
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [ "foo" ];

# CLI one-off
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
```

### File Not Tracked by Git

```
error: getting status of '/path/to/file': No such file or directory
```

Flakes only see files tracked by git. Fix: `git add <file>` (staging is enough, no need to commit).

### Pure Evaluation Restriction

```
error: access to absolute path '/...' is forbidden in pure eval mode
```

Flake evaluation is pure by default — no access to paths outside the flake, no environment variables, no `<nixpkgs>`. Fix: pass data through flake inputs or `--impure`.

### Experimental Feature Disabled

```
error: experimental Nix feature 'flakes' is disabled
```

Fix: add to `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

Read `references/error-catalog.md` for the full error reference.

## Debugging Tools

### builtins.trace

Print during evaluation:

```nix
let
  x = builtins.trace "evaluating x" (1 + 1);
  y = builtins.trace "x is ${toString x}" (x + 1);
in y
```

`lib.traceVal x` prints and returns `x`. `lib.traceValSeq x` forces deep evaluation before printing. `lib.traceSeq x y` deeply evaluates and prints `x`, returns `y`.

### nix repl

Interactive evaluation:

```bash
nix repl -f '<nixpkgs>'
# or for flakes:
nix repl --expr 'import <nixpkgs> {}'

nix-repl> hello.version
"2.12.1"
nix-repl> :lf .           # Load current flake
nix-repl> outputs.packages.x86_64-linux.default
```

Useful repl commands: `:lf` (load flake), `:l` (load file), `:t` (show type), `:p` (pretty print), `:doc` (show documentation).

### nix log

Show build logs for failed (or successful) builds:

```bash
nix log nixpkgs#hello          # Log from last build
nix log /nix/store/...-hello   # Log for specific store path
```

### nix eval

Evaluate expressions without building:

```bash
nix eval nixpkgs#hello.version                    # "2.12.1"
nix eval nixpkgs#hello.meta.license.shortName     # "gpl3Plus"
nix eval --expr 'builtins.attrNames (import <nixpkgs> {})'
nix eval --json .#packages.x86_64-linux           # JSON output
```

### nix why-depends

Find why one package depends on another:

```bash
nix why-depends nixpkgs#myapp nixpkgs#gcc
# Shows the reference chain through the closure
```

### nix path-info

Inspect store paths and closures:

```bash
nix path-info -rsSh nixpkgs#hello   # Show closure: all paths, sizes, total
nix path-info --json nixpkgs#hello   # Detailed JSON output
nix path-info -r nixpkgs#hello       # List all closure paths
```

### nix-tree (interactive closure browser)

Browse the dependency tree interactively in the terminal:

```bash
nix-tree nixpkgs#hello              # Browse closure
nix-tree --derivation nixpkgs#hello # Browse build-time deps
```

Navigate with arrow keys. Shows size contribution of each dependency. Use this to find unexpected large dependencies.

### nix-diff (derivation comparator)

Compare two derivations to see exactly what changed:

```bash
nix-diff /nix/store/...-foo.drv /nix/store/...-bar.drv
```

Useful for understanding why a rebuild was triggered — shows which inputs, build commands, or environment variables differ.

### nom (nix-output-monitor)

Wraps nix commands with a progress display showing build graphs and statistics:

```bash
nom build .#myPackage              # Replaces nix build
nom shell nixpkgs#hello            # Replaces nix shell
nom develop                        # Replaces nix develop
```

Shows which derivations are building, downloading, or waiting. Much more informative than default nix output.

## Build Debugging

```bash
# Build with verbose streaming output
nix build -L nixpkgs#hello

# Keep failed build directory for inspection
nix build --keep-failed nixpkgs#hello
# Failed build dir printed: /tmp/nix-build-hello-xxx

# Override a phase interactively
nix develop nixpkgs#hello
# Then run phases manually:
unpackPhase
patchPhase
configurePhase
buildPhase
checkPhase
installPhase
```

## Store Path Internals

Nix uses three store path naming strategies:

| Type | Hash Based On | Network Access | Use Case |
|------|--------------|----------------|----------|
| **Input-addressed** | Derivation contents (inputs) | No (sandboxed) | Normal software builds |
| **Fixed-output** | Expected output hash | Yes (relaxed sandbox) | Fetchers (fetchurl, fetchFromGitHub) |
| **Content-addressed** | Actual output content | No (sandboxed) | Deduplication (experimental) |

Input-addressed paths change when any input changes, even if the output is identical. Content-addressed derivations (ca-derivations) solve this but remain experimental.

## Garbage Collection

```bash
nix-collect-garbage         # Remove unreferenced store paths
nix-collect-garbage -d      # Also delete old profiles/generations
nix store gc                # New CLI equivalent
nix store optimise          # Deduplicate store (hardlinks identical files)

# Check store integrity
nix store verify --all

# Show what would be deleted
nix-collect-garbage --print-dead

# Show GC roots
nix-store --gc --print-roots
```

## Performance Diagnosis

- **Evaluation slow?** Check for IFD, large `builtins.readDir` on big directories, deep recursive imports, or `builtins.readFile` on big files. Use `--trace-function-calls` to profile evaluation.
- **Build slow?** Check if substituters (binary cache) are configured: `nix config show | grep substituters`. Use `nom` to see what is building vs downloading.
- **Large closures?** Use `nix path-info -rsSh` and `nix why-depends` to find unexpected runtime dependencies. Use `nix-tree` for interactive exploration.
- **Unnecessary rebuilds?** Use `nix-diff` to compare old and new derivations. Check if `src = ./.` is picking up untracked files (use `lib.fileset`).

See the nix-performance skill for deep optimization techniques.
