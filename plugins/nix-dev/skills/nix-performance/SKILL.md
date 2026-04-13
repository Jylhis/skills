---
name: nix-performance
description: "Use for Nix performance optimization including evaluation speed, IFD import from derivation avoidance, dynamic derivations, content-addressed derivations, closure size analysis, nix-tree, nix-diff, nix why-depends, nix path-info, Docker image optimization, binary cache configuration, distributed builds, remote builders, store maintenance, garbage collection, nix store gc, nix store optimise, or build parallelism."
user-invocable: false
---

# Nix Performance

## Evaluation Performance

### Import From Derivation (IFD)

IFD occurs when the Nix evaluator encounters `import someDrv` or `readFile "${someDrv}/..."` where the argument is a derivation output rather than a static path. When this happens, ALL evaluation stops and waits for that derivation to build. The evaluator has no concurrency or parallelism -- it is single-threaded during evaluation.

This is the single biggest evaluation performance killer in Nix. One IFD blocks everything.

### IFD Consolidation Strategy

Instead of triggering IFD once per package (N blocking points), restructure so that one comprehensive derivation collects all needed data, then import that single derivation once. The dependency graph before the IFD enables parallel builds, and there is only one blocking point instead of N.

Pattern:
```nix
# BAD: N separate IFDs, each blocks evaluation
let
  metaA = import (runCommand "get-meta-a" { } ''...'');
  metaB = import (runCommand "get-meta-b" { } ''...'');
in ...

# GOOD: one IFD, all data collected in parallel before the single import
let
  allMeta = import (runCommand "get-all-meta" { } ''
    # builds dependencies in parallel, then collects results
    mkdir -p $out
    cp ${metaDrvA} $out/a.nix
    cp ${metaDrvB} $out/b.nix
  '');
in ...
```

Reference: jade.fyi on IFD consolidation.

### Other Evaluation Bottlenecks

- Avoid `builtins.readDir` on large directories -- it is O(n) entries and returns them all at once.
- Use `lib.fileset` over `cleanSource` for source filtering. fileset is more precise and avoids re-evaluating on irrelevant file changes.
- `builtins.fetchurl`, `builtins.fetchGit`, and `builtins.fetchTarball` block evaluation because they run during eval. Prefer `pkgs.fetchurl` and friends, which are fixed-output derivations that build in parallel with other derivations.
- Use `--trace-function-calls` for evaluation profiling:
  ```bash
  nix eval --trace-function-calls '.#something' 2>trace.log
  ```
  Outputs function entry/exit timestamps to stderr. Analyze with flamegraph tools to find hot paths.

## Dynamic Derivations (Experimental)

Dynamic derivations are an alternative to IFD. Instead of importing a derivation output during evaluation, a derivation's output can itself BE a derivation (.drv file), which Nix then resolves and builds at build time.

Key advantages over IFD:
- Evaluation is not blocked -- the entire build graph is resolved before any building starts
- The dependency chain is handled by the build scheduler, which has parallelism
- No eval/build/eval/build ping-pong

Tools like Drowse simplify working with dynamic derivations.

Status: still experimental in CppNix. Removed from Lix. Not yet widely adopted.

Enable with:
```nix
nix.settings.experimental-features = [ "dynamic-derivations" ];
```

## Content-Addressed Derivations (Experimental)

Nix has three derivation addressing modes:

| Mode | Hash Based On | Network Access | Deduplication |
|------|--------------|----------------|---------------|
| Input-addressed | All inputs (sources, deps, build script) | No | None -- same code change always rebuilds downstream |
| Content-addressed | Output content | No | Identical outputs deduplicated even from different inputs |
| Fixed-output | Expected output hash (specified upfront) | Yes | By output hash |

Input-addressed (the default) means that if you change a comment in a low-level library, everything downstream rebuilds even though the output is bit-identical. Content-addressed derivations fix this by hashing the output itself.

Fixed-output derivations are the special case used by fetchers (`fetchurl`, `fetchFromGitHub`, etc.) -- you specify the expected hash, and the builder gets network access.

Enable content-addressed derivations:
```nix
nix.settings.experimental-features = [ "ca-derivations" ];
```

## Closure Size Optimization

### Analysis Tools

Show closure size with human-readable sizes:
```bash
nix path-info -rsSh .#package
```

Trace why package A depends on package B:
```bash
nix why-depends .#package nixpkgs#gcc
```

Interactive terminal browser for the dependency tree with sizes:
```bash
nix-tree .#package
```

### Common Bloat Sources

- Compiler or development headers ending up in the runtime closure
- Unused stdenv references (build tools referenced by output paths)
- Documentation, tests, or source files embedded in the output
- Transitive dependencies pulled in by a single string reference to a store path

### Removing Unwanted Dependencies

Use `disallowedReferences` to make the build fail if specified packages appear in the closure:
```nix
stdenv.mkDerivation {
  # ...
  disallowedReferences = [ stdenv.cc ];
};
```

Use `removeReferencesTo` to strip store path references from binaries:
```nix
stdenv.mkDerivation {
  # ...
  nativeBuildInputs = [ removeReferencesTo ];
  postInstall = ''
    remove-references-to -t ${stdenv.cc} $out/bin/*
  '';
};
```

Use `lib.fileset` to include only needed source files, avoiding embedding docs and tests in the derivation:
```nix
src = lib.fileset.toSource {
  root = ./.;
  fileset = lib.fileset.unions [
    ./src
    ./Cargo.toml
    ./Cargo.lock
  ];
};
```

## Docker/OCI Image Optimization

### streamLayeredImage

`pkgs.dockerTools.streamLayeredImage` generates Docker layers without materializing the full image in the Nix store. It streams the image directly to `docker load` or a registry.

```nix
pkgs.dockerTools.streamLayeredImage {
  name = "my-app";
  tag = "latest";
  contents = [ myApp ];
  config.Cmd = [ "${myApp}/bin/my-app" ];
};
```

### Layer Optimization

Separate frequently-changed store paths from stable ones using the `layers` parameter so Docker can cache stable layers:

```nix
pkgs.dockerTools.streamLayeredImage {
  name = "my-app";
  tag = "latest";
  layers = [
    # Stable base layer -- cached across rebuilds
    (pkgs.dockerTools.buildLayer {
      name = "base";
      contents = [ pkgs.cacert pkgs.tzdata ];
    })
  ];
  # Application code goes in the top layer
  contents = [ myApp ];
  config.Cmd = [ "${myApp}/bin/my-app" ];
};
```

### Reducing Image Size

- Use `nix why-depends` to find unexpected runtime dependencies
- Use `removeReferencesTo` to strip build-time references from binaries
- Avoid including shells, coreutils, or compilers unless the application needs them at runtime
- Cross-reference the nix-containers skill for detailed Docker/OCI patterns

## Build Performance

### Binary Cache Configuration

Configure substituters (binary caches) to avoid building from source:
```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://my-cache.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "my-cache.cachix.org-1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  ];
};
```

### Parallelism Settings

- `--max-jobs N` (or `nix.settings.max-jobs`): number of derivations to build in parallel. Default auto-detects cores.
- `--cores N` (or `nix.settings.cores`): cores allocated per individual build (passed as `NIX_BUILD_CORES` to builders). Set to 0 for "use all available."
- These interact: max-jobs=4 with cores=4 on a 16-core machine means 4 builds each using 4 cores.

### Distributed Builds

Offload builds to remote machines via SSH:

```nix
nix.buildMachines = [{
  hostName = "builder";
  sshUser = "nix";
  sshKey = "/etc/nix/builder-key";
  system = "x86_64-linux";
  maxJobs = 8;
  supportedFeatures = [ "big-parallel" "kvm" ];
}];
nix.distributedBuilds = true;
nix.settings.builders-use-substitutes = true;
```

Key settings:
- `builders-use-substitutes = true`: lets remote builders pull from binary caches instead of uploading everything from the local machine
- `supportedFeatures`: advertise capabilities like `big-parallel` (for builds that benefit from many cores) and `kvm` (for VM-based tests)
- Multiple builders can be listed for load distribution

### Native Linux Builder on macOS

Determinate Nix provides a native Linux builder for macOS, enabling Linux derivation builds on macOS without Docker. This is significantly faster than the traditional QEMU-based linux-builder.

## Store Maintenance

### Garbage Collection

Remove old generations and all unreferenced store paths:
```bash
nix-collect-garbage -d
```

New CLI equivalent:
```bash
nix store gc
```

Show what GC roots are preventing collection:
```bash
nix-store --gc --print-roots
```

### Profile Cleanup

Remove old profile history entries:
```bash
nix profile wipe-history --older-than 30d
```

### Store Deduplication

Deduplicate identical files in the store via hardlinks:
```bash
nix store optimise
```

This is safe to run at any time and can reclaim significant space when multiple packages share identical files.

### Store Integrity Verification

Check store integrity (all paths, all signatures):
```bash
nix store verify --all
```

## Reference

See references/tools.md for tool-specific usage patterns and examples.
