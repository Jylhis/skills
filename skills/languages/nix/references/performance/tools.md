# Nix Performance Tools Reference

## Table of Contents

- [nix-tree](#nix-tree)
- [nix-diff](#nix-diff)
- [nix-du](#nix-du)
- [nom (nix-output-monitor)](#nom-nix-output-monitor)
- [nvd](#nvd)
- [dix and nh](#dix-and-nh)
- [nix path-info](#nix-path-info)
- [nix why-depends](#nix-why-depends)
- [--eval-profiler](#--eval-profiler)
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

Query a binary cache without downloading the closure:
```bash
nix eval --raw 'nixpkgs#stellarium.outPath' | xargs -o nix-tree --store https://cache.nixos.org
```

With no argument it opens `~/.nix-profile` and `/var/run/current-system`. `--dot` prints the graph in DOT format instead.

### Navigation

- `hjkl` or arrow keys to navigate the tree
- `s` to change the sort order (by name, closure size, added size) -- sort by size to find bloat quickly
- `w` to open the why-depends view (which parents pull a path in)
- `/` to search, `y` to yank the selected path, `?` for help
- `q` or Esc to quit or close a modal

Columns: NAR size (the path itself), closure size, and added size (the path plus its *unique* dependencies, i.e. what removing it would actually free).

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

`nix-du` writes a Graphviz DOT graph (needs `dot` from `graphviz`). Roots are on the left; an edge A to B means B stays alive as long as A does; red nodes are the heaviest.

Only keep nodes of at least 500 MB and render to SVG:
```bash
nix-du -s=500MB | dot -Tsvg > store.svg
```

Only keep the 50 heaviest inner nodes:
```bash
nix-du -n=50 | dot -Tsvg > store.svg
```

Analyze the dependencies of one store path instead of all GC roots:
```bash
nix-du --root /nix/store/...-foo -s=100MB | dot -Tsvg > foo.svg
```

With filters, node sizes are approximations.

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

Pipe nix output through nom (JSON mode gives the full build tree):
```bash
nix build --log-format internal-json -v .#package |& nom --json
```

For wrappers that cannot take `--log-format` (e.g. `nixos-rebuild`, `home-manager`), plain `|& nom` parses the human-readable log. `nom shell`/`nom develop` evaluate twice, so they cost extra eval time.

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

Compare a fresh build against the running system:
```bash
nixos-rebuild build && nvd diff /run/current-system result
```

Compare two Home Manager generations (current Home Manager keeps profiles in `~/.local/state/nix/profiles` when that directory exists, otherwise in `/nix/var/nix/profiles/per-user/$USER`; `home-manager generations` prints the exact paths):
```bash
nvd diff ~/.local/state/nix/profiles/home-manager-{41,42}-link
```

### Output

Shows for each package:
- Added packages (new in the target generation)
- Removed packages (gone from the target generation)
- Upgraded packages (version changed)
- Closure size change (counted in store paths, not bytes)

Useful for reviewing what a `nixos-rebuild switch` or `home-manager switch` actually changed.

## dix and nh

`dix` (2.x) is a Rust rewrite of the nvd idea and much faster. Same two-path interface:
```bash
dix /nix/var/nix/profiles/system-{41,42}-link
dix --output json /run/current-system ./result   # machine-readable
```
In CI pass `--force-correctness`: by default dix may fall back to reading Nix's SQLite DB with `?immutable=1`, which can be inaccurate while the store is being written.

`nh` (nix-community, 4.4.x) wraps `nixos-rebuild`, `darwin-rebuild` and `home-manager` and shows a dix diff before activation (`nh os switch`, `nh home switch`); since 4.4 this also works with `--target-host`. Other performance-relevant pieces:
- `nh clean all --keep-since 7d --keep 3` cleans profiles and GC roots, then runs GC. By default it also removes `result` and direnv GC roots (`--no-gcroots` or `--no-direnv` to keep them). 4.4 adds `--keep-one` (keep active direnv GC roots regardless of age) and `-x/--cross-filesystems`.
- `--option NAME VALUE` and `--override-input INPUT URL` (4.4) pass Nix settings and input overrides through to every underlying `nix` call.
- `nh search` now uses subcommands (4.4 breaking change): `nh search packages`, `nh search options`, plus `prs`, `issues` and `offline`.
- 4.4 dropped x86_64-darwin.

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
nix path-info -r --json --json-format 2 .#package
```
Pipe to `jq` for custom analysis. Since Nix 2.33, `--json` without `--json-format` is deprecated (it still emits format 1 with a warning). Format 2 nests entries under `info`, keyed by store-path basenames, with structured hashes; 2.35 adds format 3 (structured signatures).

`nix path-info` has no tree view. For a tree use `nix-store --query --tree` (`nix-store -q --tree`) or `nix-tree`.

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
| `--json` | JSON output (pair with `--json-format N`) |
| `--sigs` | Show signatures |
| `--derivation` | Show derivation path instead of output path |

## nix why-depends

Trace why one store path depends on another. Essential for understanding and breaking unwanted dependency chains.

### Usage Patterns

Basic dependency trace:
```bash
nix why-depends .#package nixpkgs#gcc
```

Show every edge, not just the shortest path:
```bash
nix why-depends --all .#package nixpkgs#gcc
```

Show which files in each parent contain the reference:
```bash
nix why-depends --precise .#package nixpkgs#gcc
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

## --eval-profiler

Stack-sampling evaluation profiler (Nix 2.30+). Prefer it over `--trace-function-calls`: lower overhead, and the output includes the name of the called function.

```bash
nix eval --eval-profiler flamegraph --eval-profile-file eval.profile '.#something'
nix-instantiate '<nixpkgs>' -A hello --eval-profiler flamegraph   # writes ./nix.profile
flamegraph.pl eval.profile > eval.svg                             # or load into speedscope
```

`--eval-profiler-frequency` sets the sample rate (default 99 Hz). Each line is a folded stack of `file:line:col:function` frames.

## --trace-function-calls

Older built-in tracer. Records entry and exit timestamps for every Nix function call during evaluation.

### Usage

Capture a trace:
```bash
nix eval --trace-function-calls '.#something' 2>trace.log
```

The trace is written to stderr. Each line has a call-site position and a nanosecond timestamp (`undefined position` means a builtin):
```
function-trace entered /nix/store/...-source/lib/attrsets.nix:226:41 at 1565795253249935150
function-trace exited /nix/store/...-source/lib/attrsets.nix:226:41 at 1565795253249941684
```

### Generating Flamegraphs

Convert the trace to a flamegraph for visual analysis:
```bash
nix eval --trace-function-calls '.#something' 2>trace.log
# contrib/stack-collapse.py ships in the Nix source tree
python3 stack-collapse.py trace.log | flamegraph.pl > trace.svg
```

### What to Look For

- Functions with high cumulative time (wide bars in flamegraph)
- Repeated evaluation of the same function (many thin bars)
- IFD blocking points (long gaps in the trace)
- Deep recursion in `lib.fix` or overlay chains
