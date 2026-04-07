---
name: nix-debugging
description: "Use for Nix debugging and troubleshooting including infinite recursion, hash mismatch, IFD import from derivation, build failures, nix log, nix why-depends, evaluation errors, attribute missing, unfree package errors, collision errors, builtins.trace, nix repl, nix eval, nix path-info, store paths, garbage collection, closure size analysis, or slow evaluation diagnosis."
user-invocable: false
---

# Nix Debugging

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
# Check if it exists
nix eval nixpkgs#foo --apply 'x: builtins.typeOf x'

# List available attributes
nix eval nixpkgs#lib --apply builtins.attrNames
```

Common cause: typo in package name, or the package was renamed/removed in a nixpkgs update.

### Collision Between Packages

```
error: collision between '/nix/store/...-foo/bin/bar' and '/nix/store/...-baz/bin/bar'
```

**Fix:** One of the packages provides the same file. Use `lib.hiPrio` to prefer one, or remove the conflicting package:

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

IFD happens when evaluation requires building something first. Common with generated Nix expressions. Fix by:
- Pre-generating the Nix file and committing it
- Using `builtins.fetchurl` instead of derivation-based fetchers during eval
- Allowing IFD with `--allow-import-from-derivation` (not recommended for CI)

### Unfree Package

```
error: Package 'foo' has an unfree license ('unfree')
```

**Fix:**
```nix
# In flake or configuration
nixpkgs.config.allowUnfree = true;

# Or per-package
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [ "foo" ];

# CLI
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
```

## Debugging Tools

### builtins.trace

Print during evaluation:

```nix
let
  x = builtins.trace "evaluating x" (1 + 1);
  y = builtins.trace "x is ${toString x}" (x + 1);
in y
```

`lib.traceVal x` prints and returns `x`. `lib.traceValSeq x` forces deep evaluation before printing.

### nix log

Show build logs for failed (or successful) builds:

```bash
nix log nixpkgs#hello          # Log from last build
nix log /nix/store/...-hello   # Log for specific store path
```

### nix why-depends

Trace why one package depends on another:

```bash
nix why-depends nixpkgs#myapp nixpkgs#gcc
```

Useful for understanding closure size and unexpected dependencies.

### nix path-info

Inspect store paths:

```bash
nix path-info -rsSh nixpkgs#hello   # Show closure size
nix path-info --json nixpkgs#hello  # JSON output
```

### nix eval

Evaluate expressions without building:

```bash
nix eval nixpkgs#hello.version                    # "2.12.1"
nix eval nixpkgs#hello.meta.license.shortName     # "gpl3Plus"
nix eval --expr 'builtins.attrNames (import <nixpkgs> {})'  # List all packages
```

### nix repl

Interactive evaluation:

```bash
nix repl -f '<nixpkgs>'
# or
nix repl --expr 'import <nixpkgs> {}'

nix-repl> hello.version
"2.12.1"
nix-repl> lib.attrNames (lib.filterAttrs (n: v: lib.isDerivation v) python3Packages)
```

`:lf .` loads the current flake in the repl.

## Build Debugging

```bash
# Build with verbose output
nix build -L nixpkgs#hello

# Keep failed build directory for inspection
nix build --keep-failed nixpkgs#hello
# Failed build dir is printed: /tmp/nix-build-hello-xxx

# Override a phase interactively
nix develop nixpkgs#hello
# Then run phases manually:
unpackPhase
configurePhase
buildPhase
```

## Garbage Collection

```bash
nix-collect-garbage         # Remove unreferenced store paths
nix-collect-garbage -d      # Also delete old profiles/generations
nix store gc                # New CLI equivalent
nix store optimise          # Deduplicate store (hardlinks)

# Check store integrity
nix store verify --all

# Show what would be deleted
nix-collect-garbage --print-dead
```

## Performance

- **Evaluation slow?** Check for IFD, large `builtins.readDir` on big directories, or deep recursive imports
- **Build slow?** Check if substitutes (binary cache) are configured: `nix config show | grep substituters`
- **Large closures?** Use `nix path-info -rsSh` and `nix why-depends` to find unexpected runtime dependencies
