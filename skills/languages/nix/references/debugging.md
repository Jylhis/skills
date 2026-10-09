# Nix Debugging

## Debugging Methodology

Follow this sequence when something breaks:

1. **Read the error message** — Nix errors are verbose but informative
2. **Add `--show-trace`** — reveals the full evaluation call stack
3. **Use `builtins.trace`** — insert print statements in Nix expressions
4. **Enter `nix repl`** — interactively evaluate subexpressions, or add `--debugger` to drop into a REPL at the failure point
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

```text
error: infinite recursion encountered
```

**Causes:**

- Using `rec { }` where an attribute references itself circularly
- Overlay using `final` where `prev` is needed (or vice versa)
- NixOS module that sets an option it also reads without `mkIf`

**Debug:** Add `builtins.trace` calls to narrow down which attribute triggers it. In overlays, ensure you use `prev.pkg` for the package being modified and `final.dep` for dependencies.

### Hash Mismatch

```text
error: hash mismatch in fixed-output derivation
  specified: sha256-AAAA...
  got:       sha256-BBBB...
```

**Fix:** Replace the hash with the correct one from the error. Or use `lib.fakeHash` / `""` during development to get the correct hash from the error.

### Attribute Not Found

```text
error: attribute 'foo' missing
```

**Debug:**

```bash
nix eval nixpkgs#foo --apply 'x: builtins.typeOf x'
nix eval nixpkgs#lib --apply builtins.attrNames
```

Common cause: typo, package renamed/removed, wrong nixpkgs version. Use `mcp-nixos` MCP tools to search for the correct package name.

### Collision Between Packages

```text
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

```text
error: cannot build '/nix/store/...-foo.drv^out' during evaluation because the option 'allow-import-from-derivation' is disabled
```

IFD happens when evaluation requires building something first (`import someDrv`, `readFile "${someDrv}/..."`). The evaluator blocks all other evaluation while the build runs. Fix by:

- Pre-generating the Nix file and committing it
- Using `builtins.fetchurl` instead of derivation-based fetchers during eval
- Allowing IFD with `--allow-import-from-derivation` (not recommended for CI)

To find IFD without breaking the build, set `trace-import-from-derivation = true` (Nix 2.30+): every IFD is logged as a warning.

See the nix-performance skill for IFD alternatives and consolidation strategies.

### Unfree Package

```text
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

```text
error: Path 'foo.nix' in the repository "/path/to/repo" is not tracked by Git.
```

Flakes only see files tracked by git. Nix 2.28+ prints the message above together with the fix; older versions say `getting status of '/path/to/file': No such file or directory`. Fix: `git add <file>`, or `git add -N <file>` (intent-to-add) to make it visible without staging content. No need to commit.

### Pure Evaluation Restriction

```text
error: access to absolute path '/...' is forbidden in pure evaluation mode (use '--impure' to override)
```

Flake evaluation is pure by default — no access to paths outside the flake, no environment variables, no `<nixpkgs>`. `<nixpkgs>` fails with `cannot look up '<nixpkgs>' in pure evaluation mode`, while `builtins.getEnv` silently returns `""`. Fix: pass data through flake inputs or `--impure`.

### Experimental Feature Disabled

```text
error: experimental Nix feature 'flakes' is disabled; add '--extra-experimental-features flakes' to enable it
```

Fix: add to `~/.config/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
```

Still required on upstream Nix 2.35 and Lix. Determinate Nix treats `flakes` and `nix-command` as stable and never shows this error; other features (for example `pipe-operators`, `ca-derivations`) still need the flag there.

Read `debugging/error-catalog.md` for the full error reference.

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

### Finding where a warning comes from

`builtins.warn` (Nix 2.23+, which `lib.warn` uses when available) prints `evaluation warning: ...` without a location. Make warnings fatal to get a stack trace:

```bash
NIX_ABORT_ON_WARN=1 nix eval --show-trace .#nixosConfigurations.host.config.system.build.toplevel
# or: nix eval --option abort-on-warn true --show-trace ...
```

### Interactive debugger (`--debugger`)

Add `--debugger` to a new-CLI command (`nix eval`, `nix build`, ...) to open a REPL with the local variables in scope when evaluation throws:

```bash
nix eval --debugger .#packages.x86_64-linux.default
```

Inside: `:bt` (backtrace), `:st <n>` (inspect frame n), `:env` (show variables), `:s` (step), `:c` (continue to the next error or `builtins.break`), `:q` (quit). Place `builtins.break value` in code to stop at a chosen point; set `debugger-on-trace = true` or `debugger-on-warn = true` to also stop at every `builtins.trace` or `builtins.warn`.

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

Useful repl commands: `:lf` (load flake), `:l` (load file), `:r` (reload; also reloads `:lf` flakes since Nix 2.29), `:t` (show type), `:p` (pretty print), `:doc` (show documentation; since Nix 2.24 also renders RFC 145 `/** */` doc comments, e.g. `:doc lib.toFunction`). Since Nix 2.34 the repl also accepts `inherit (a) x y` and several bindings per line (`p = 1; q = 2;`).

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

Since Nix 2.29, `--json` output is pretty-printed when stdout is a terminal and stays single-line in pipes; force it with `--pretty` or disable it with `--no-pretty`.

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
nix path-info --json --json-format 2 nixpkgs#hello   # Detailed JSON output
nix path-info -r nixpkgs#hello       # List all closure paths
```

Since Nix 2.33, `nix path-info --json` without `--json-format` is deprecated (it warns and falls back to the legacy format 1). Format 2 nests results under `info` and keys them by store path base name; format 3 (Nix 2.35) adds structured signatures.

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
# Nix prints the kept build directory. Since Nix 2.30 it lives under the
# build-dir setting (default /nix/var/nix/builds), no longer under $TMPDIR or /tmp.

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

## Building Nix From Source (RFC 132)

Nix itself has moved from autotools to Meson; Nix 2.26 removed the Make-based build. To build from source for bisection or debugging (inside the Nix dev shell):

```bash
meson setup build
ninja -C build
```

Old `./configure && make` instructions are obsolete. Per RFC 134, `libnixstore` (the store layer) is separable from the evaluator — future Nix builds may ship layered packages.

## ASCII Diagnostic Output (RFC 4)

Nix CLI error output uses plain ASCII `'...'` and `"..."` quotes, not curly `‘ ’`. Parsers and tests matching on Nix output should assume ASCII.

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
nix-store --gc --print-dead
nix store gc --dry-run         # Nix 2.34+ also reports how many paths would be freed

# Show GC roots
nix-store --gc --print-roots
```

## vulnix (Vulnerability Scanner)

vulnix scans the Nix store for packages with known CVEs from the NVD (National Vulnerability Database). It matches package names and versions against CVE entries and reports active advisories.

### Usage

```bash
# Scan the current system configuration
vulnix --system

# Scan a build result and its transitive closure
vulnix result/

# Scan specific derivations without determining requisites
vulnix -R /nix/store/*-some-package.drv

# Whitelist specific packages (suppress known false positives)
vulnix --whitelist whitelist.nix
```

### Whitelist Format

```nix
# whitelist.nix
[
  {
    name = "libssh2";
    version = "1.9.0";
    # Skip specific CVEs for this package version
    cves = [ "CVE-2019-17498" ];
    until = "2025-01-01";  # expiry date
  }
]
```

### Requirements

- Must run as the same user that owns the Nix store database, or with `nix-daemon` active
- Parses `.drv` files directly (tested with Nix >= 1.10 and 2.x)
- Set `LANG=C.UTF-8` if you see encoding errors

### CI Integration

Run as a periodic check on NixOS systems to catch known-vulnerable packages in the active configuration.

## Performance Diagnosis

- **Evaluation slow?** Check for IFD, large `builtins.readDir` on big directories, deep recursive imports, or `builtins.readFile` on big files. Use `--eval-profiler flamegraph` (Nix 2.30+, writes `nix.profile` for `flamegraph.pl` or speedscope; see `--eval-profile-file`) to profile evaluation; `--trace-function-calls` is the older, noisier option. `trace-import-from-derivation = true` lists hidden IFD.
- **Build slow?** Check if substituters (binary cache) are configured: `nix config show | grep substituters`. Use `nom` to see what is building vs downloading.
- **Large closures?** Use `nix path-info -rsSh` and `nix why-depends` to find unexpected runtime dependencies. Use `nix-tree` for interactive exploration.
- **Unnecessary rebuilds?** Use `nix-diff` to compare old and new derivations. Check if `src = ./.` is picking up untracked files (use `lib.fileset`).

See the nix-performance skill for deep optimization techniques.
