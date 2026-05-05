# Nix Performance Tools Reference

## Table of Contents

- [nix-tree](#nix-tree)
- [nix-diff](#nix-diff)
- [nix-du](#nix-du)
- [nom (nix-output-monitor)](#nom-nix-output-monitor)
- [nvd](#nvd)
- [nix path-info](#nix-path-info)
- [nix why-depends](#nix-why-depends)
- [--trace-function-calls](#--trace-function-calls)

## nix-tree

Interactive terminal browser for Nix dependency trees. Shows the closure of a package with sizes for each dependency. Essential for finding bloat.

### Usage

Browse the closure of a flake output:
```bash
nix-tree .#package
```

Browse the derivation tree (build-time deps) instead of runtime closure:
```bash
nix-tree --derivation .#package
```

Browse a store path directly:
```bash
nix-tree /nix/store/...-some-package
```

### Navigation

- Arrow keys to navigate the tree
- Enter to expand/collapse nodes
- `s` to sort by size (largest first) -- use this to find bloat quickly
- `w` to show why a path is in the closure (which parent references it)
- `q` to quit

### Tips

- Start by sorting by size to find the largest dependencies
- Check if any compilers, development headers, or documentation appear in the runtime closure
- Use the "why" view to trace how an unexpected dependency got pulled in

## nix-diff

Compare two .drv files to see exactly what changed between two versions of a derivation. Useful for understanding why something rebuilt.

### Usage

Compare two derivations:
```bash
nix-diff /nix/store/aaaa-foo.drv /nix/store/bbbb-foo.drv
```

Get derivation paths from flake outputs:
```bash
nix-diff \
  $(nix path-info --derivation .#package) \
  $(nix path-info --derivation github:owner/repo#package)
```

### Output

Shows a structured diff including:
- Changed inputs (which dependencies changed)
- Changed build script or arguments
- Changed environment variables
- Changed source hashes

This helps answer "why did this rebuild?" by pinpointing the exact input that changed.

## nix-du

Visualize GC roots and their sizes. Generates reports showing what store paths are alive and why.

### Usage

Generate a report of store usage by GC root:
```bash
nix-du -s
```

Output as a chart (requires chart rendering):
```bash
nix-du -s | sort -rn | head -20
```

### Use Cases

- Find which GC roots are consuming the most space
- Identify old profiles or result symlinks holding large closures alive
- Decide what to clean up before running garbage collection

## nom (nix-output-monitor)

Wraps `nix build`, `nix shell`, `nix develop`, and other commands with a rich progress display. Shows the build graph, download progress, and timing information.

### Usage

Build with progress monitoring:
```bash
nom build .#package
```

Develop shell with monitoring:
```bash
nom develop .#package
```

Pipe nix output through nom:
```bash
nix build .#package 2>&1 | nom
```

### What It Shows

- Which derivations are building, downloading, or waiting
- Progress bars for downloads
- Build times for each derivation
- Total elapsed time
- Build graph showing parallel and sequential builds

## nvd

Compare NixOS or Home Manager generations to see what changed between activations.

### Usage

Compare two NixOS generations:
```bash
nvd diff /nix/var/nix/profiles/system-{41,42}-link
```

Compare two Home Manager generations:
```bash
nvd diff /nix/var/nix/profiles/per-user/$USER/home-manager-{41,42}-link
```

### Output

Shows for each package:
- Added packages (new in the target generation)
- Removed packages (gone from the target generation)
- Upgraded packages (version changed)
- Closure size change

Useful for reviewing what a `nixos-rebuild switch` or `home-manager switch` actually changed.

## nix path-info

Query information about store paths. The primary tool for closure size analysis.

### Usage Patterns

Closure with human-readable sizes:
```bash
nix path-info -rsSh .#package
```
Columns: store path, NAR size (own), closure size (total).

Closure as JSON for scripting:
```bash
nix path-info -r --json .#package
```
Pipe to `jq` for custom analysis.

Tree view of dependencies:
```bash
nix path-info --tree .#package
```

Show only the closure size (total):
```bash
nix path-info -Sh .#package
```

### Flags Reference

| Flag | Meaning |
|------|---------|
| `-r` | Show full closure (recursive) |
| `-s` | Show NAR size (own size of each path) |
| `-S` | Show closure size (total size including deps) |
| `-h` | Human-readable sizes |
| `--json` | JSON output |
| `--tree` | Tree view |
| `--derivation` | Show derivation path instead of output path |

## nix why-depends

Trace why one store path depends on another. Essential for understanding and breaking unwanted dependency chains.

### Usage Patterns

Basic dependency trace:
```bash
nix why-depends .#package nixpkgs#gcc
```

With path details (shows which string references create the dependency):
```bash
nix why-depends --all .#package nixpkgs#gcc
```

Between store paths:
```bash
nix why-depends /nix/store/...-my-app /nix/store/...-gcc
```

### Interpreting Output

The output shows the shortest chain of references from package A to package B. Each step shows which file in the store path contains a reference (string match) to the next store path in the chain.

This is how you find:
- Why a compiler is in the runtime closure (often a path string embedded in a binary or script)
- Why a large dependency is being pulled in transitively
- Where to apply `removeReferencesTo` to break the chain

## --trace-function-calls

Built-in Nix evaluation profiler. Records entry and exit timestamps for every Nix function call during evaluation.

### Usage

Capture a trace:
```bash
nix eval --trace-function-calls '.#something' 2>trace.log
```

The trace is written to stderr. Each line contains:
```
function-entry <timestamp_us> <function_name> <file>:<line>:<col>
function-exit  <timestamp_us> <function_name> <file>:<line>:<col>
```

### Generating Flamegraphs

Convert the trace to a flamegraph for visual analysis:
```bash
nix eval --trace-function-calls '.#something' 2>trace.log
# Use nix-trace-flamegraph or similar tool to convert
# trace.log into a flamegraph SVG
```

### What to Look For

- Functions with high cumulative time (wide bars in flamegraph)
- Repeated evaluation of the same function (many thin bars)
- IFD blocking points (long gaps in the trace)
- Deep recursion in `lib.fix` or overlay chains
