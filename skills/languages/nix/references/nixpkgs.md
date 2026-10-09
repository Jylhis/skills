# Nixpkgs

## Finding Packages

```bash
nix search nixpkgs#<query>
```

If the mcp-nixos MCP server is available, use it for richer search with version history and metadata.

For the authoritative RFC index governing Nixpkgs contribution conventions (staging workflow, `pkgs/by-name`, `passthru.tests`, `meta.sourceProvenance`, platform tiers, breaking-change policy), see `language/rfcs.md`.

## The `callPackage` Pattern

`callPackage` is the core composition mechanism of nixpkgs. It takes a function (usually from a file) and auto-fills its arguments from the package set:

```nix
# package.nix — a function accepting its dependencies
{ lib, stdenv, fetchurl, openssl }:
stdenv.mkDerivation {
  pname = "hello";
  version = "2.12";
  src = fetchurl {
    url = "mirror://gnu/hello/hello-2.12.tar.gz";
    hash = "sha256-abc123...";
  };
  buildInputs = [ openssl ];
  meta.license = lib.licenses.gpl3Plus;
}

# Called via:
hello = callPackage ./package.nix {};
# callPackage reads the function's argument names via builtins.functionArgs
# and supplies lib, stdenv, fetchurl, openssl from pkgs automatically.
# The second arg {} provides manual overrides.
```

**Why `callPackage` matters:**

- **Overridable:** `hello.override { openssl = openssl_1_1; }` swaps one dependency
- **Cross-compilation:** `callPackage` resolves `nativeBuildInputs` from `buildPackages` through "splicing" — the same `package.nix` works for native and cross builds
- **Upstreamable:** Packages in `callPackage` form are directly submittable to nixpkgs

Always write packages as functions in separate files and use `callPackage` to instantiate them.

## File Layout: `pkgs/by-name` (RFC 140)

New leaf packages in Nixpkgs go in `pkgs/by-name/<two-letter-shard>/<pname>/package.nix` with a plain `callPackage` signature. They are auto-wired into `all-packages.nix` by sharded discovery — do not edit `all-packages.nix` for new additions, and do not place new packages in ad-hoc category directories.

```text
pkgs/by-name/
├── he/
│   └── hello/
│       └── package.nix   # { lib, stdenv, fetchurl, ... }: stdenv.mkDerivation {...}
└── ri/
    └── ripgrep/
        └── package.nix
```

Only top-level packages instantiated with plain `pkgs.callPackage` qualify; packages built with another `callPackage` (e.g. `python3Packages.callPackage`, `libsForQt5.callPackage`) and members of nested package sets still use the category hierarchy. A package that needs non-default `callPackage` arguments may move into `by-name`, but its `callPackage ... { custom = ...; }` line stays in `all-packages.nix` so the `.override` interface does not change.

CI enforces the layout with [`nixpkgs-vet`](https://github.com/NixOS/nixpkgs-vet): new top-level `callPackage` packages must live in `by-name`, and a `by-name` package may not reference files outside its own directory. Run `./ci/nixpkgs-vet.sh master` locally. The nixpkgs-merge-bot (`@NixOS/nixpkgs-merge-bot merge`, invoked by a package maintainer) only merges PRs touching packages in `pkgs/by-name`.

RFC 146 (decoupling categories from the filesystem) is accepted, but `meta.categories` is not implemented: it is not a recognized key in `pkgs/stdenv/generic/check-meta.nix`, so `checkMeta` rejects it. Don't set it.

## stdenv.mkDerivation

Phases in order:

1. **unpackPhase** — extracts `src`
2. **patchPhase** — applies `patches` list
3. **configurePhase** — runs `./configure` (autotools) or cmake
4. **buildPhase** — runs `make`
5. **checkPhase** — runs tests (set `doCheck = true`)
6. **installPhase** — installs to `$out`
7. **fixupPhase** — patches ELF binaries, wraps scripts

Key attributes:

```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "myapp";
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "...";
    repo = "...";
    tag = "v${finalAttrs.version}";
    hash = "...";
  };

  __structuredAttrs = true;                   # Required for new top-level packages
  strictDeps = true;                          # Enforce the build/host input split

  nativeBuildInputs = [ cmake pkg-config ];  # Tools that run on the BUILD machine
  buildInputs = [ openssl zlib ];             # Libraries for the HOST machine
  propagatedBuildInputs = [ ];                # Also available to downstream dependents

  patches = [ ./fix-build.patch ];
  env.NIX_CFLAGS_COMPILE = "-O2";             # Exported variables go in `env`

  meta = { /* ... */ };
})
```

**`finalAttrs` over `rec`:** Pass a function to `mkDerivation` instead of using `rec { ... }`. `rec` binds at the syntax level and ignores `overrideAttrs`; `finalAttrs` is the final, overridden attribute set (plus `finalAttrs.finalPackage`). `buildGoModule` (25.05+), `buildRustPackage`, `buildPythonPackage`/`buildPythonApplication`, `buildNpmPackage`, `buildEnv` (25.11+) and the Emacs builders accept the same `finalAttrs:` form.

**`__structuredAttrs` and `env`:** The Nixpkgs 26.05 manual says all new top-level packages must enable `__structuredAttrs`. With it on, attributes are passed to the builder as JSON/Bash arrays instead of flat environment strings. Only attributes under `env` are exported as environment variables; everything else stays a shell variable local to the build script. `passAsFile` is disabled under structured attrs.

**`strictDeps`:** Without it, stdenv tolerates inputs in the wrong list for native builds, which then breaks cross-compilation. The language builders for dlang, emacs, go, nim, ocaml, python and rust turn it on by default; set it explicitly on plain `mkDerivation` packages.

**`nativeBuildInputs` vs `buildInputs`:** For native builds they are equivalent (unless `strictDeps = true`). For cross-compilation, `nativeBuildInputs` are built for the build machine (compilers, code generators, pkg-config) while `buildInputs` are built for the host machine (libraries to link against). See `nixpkgs/cross-compilation.md`. Nested lists in these inputs are deprecated as of 26.05; flatten them.

**Toolchain defaults:** Nixpkgs 25.05 moved to GCC 14 and LLVM 19, 25.11 to LLVM 21 and CMake 4, and 26.05 to GCC 15 (LLVM stays at 21; glibc 2.42). CMake 4 rejects `cmake_minimum_required(VERSION <3.5)`; the usual fix for unmaintained upstreams is `cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];`. glibc 2.42 no longer makes the stack executable on behalf of a shared library; for a library you build, `env.NIX_LDFLAGS = "-z,noexecstack";` (per the 26.05 release notes) or `patchelf --clear-execstack` on a prebuilt one.

## Source Filtering with `lib.fileset`

Replace `src = ./.;` with precise source filtering to avoid unnecessary rebuilds:

```nix
let
  fs = lib.fileset;
in stdenv.mkDerivation {
  pname = "myapp";
  version = "1.0";
  src = fs.toSource {
    root = ./.;
    fileset = fs.unions [
      ./src
      ./Cargo.toml
      ./Cargo.lock
    ];
  };
}
```

Only files in the fileset enter the store. Changes to README, CI configs, etc. won't trigger rebuilds. Use `fs.fileFilter` for pattern-based filtering and `fs.difference` to exclude files.

## Fetchers

| Fetcher | Use Case | Key Attrs |
|---------|----------|-----------|
| `fetchurl` | Direct URL download | `url`, `hash` |
| `fetchFromGitHub` | GitHub repos | `owner`, `repo`, `tag` or `rev`, `hash` |
| `fetchFromGitLab` | GitLab repos | `owner`, `repo`, `tag` or `rev`, `hash` |
| `fetchgit` | Generic git | `url`, `tag` or `rev`, `hash`, `rootDir?` |
| `fetchzip` | ZIP/tarball with auto-extract | `url`, `hash` |
| `fetchpatch2` | Fetch a patch from URL (preferred for new patches) | `url`, `hash`, `excludes?` |

**`tag` vs `rev`:** For releases use `tag = "v${finalAttrs.version}";` rather than `rev = "v..."`. `tag` is equivalent to `rev = "refs/tags/..."` and avoids branch/tag name clashes. Use `rev` only for full 40-character commit hashes (GitHub returns 404 for ambiguous short hashes). Write `tag = finalAttrs.version;`, not `tag = "${finalAttrs.version}";`.

**`hash` vs `sha256`:** Always use `hash` with an SRI string (`"sha256-..."`). Per-algorithm attributes such as `sha256 = "<nix32>"` are still accepted, but the fetcher docs prefer `hash`. `rustPlatform.buildRustPackage` errors on `cargoSha256` (since 25.05); use `cargoHash`.

**Recent fetcher changes:** `fetchgit` gained `rootDir` (fetch only one subdirectory) and `gitConfigFile` in 25.11. `fetchFromSavannah` is deprecated as of 26.05 (use `fetchgit` or a mirror). On unstable (26.11), `fetchurl` always enables `strictDeps`.

**Getting the hash:** Use `nurl` (generates full fetcher calls from URLs), `nix-init` (generates complete package definitions from URLs), `nix-prefetch-url`, `nix-prefetch-github`, or set `hash = lib.fakeHash;` (or `""`) and Nix reports the correct hash in the error.

### nurl — Generate Fetcher Calls from URLs

`nurl` generates Nix fetcher expressions from repository URLs. It infers the correct fetcher (fetchFromGitHub, fetchFromGitLab, etc.) and computes the hash:

```bash
$ nurl https://github.com/nix-community/patsh v0.2.0
fetchFromGitHub {
  owner = "nix-community";
  repo = "patsh";
  tag = "v0.2.0";
  hash = "sha256-7HXJspebluQeejKYmVA7sy/F3dtU1gc4eAbKiPexMMA=";
}
```

Supported fetchers: `fetchFromGitHub`, `fetchFromGitLab`, `fetchFromGitea`, `fetchFromGitiles`, `fetchFromBitbucket`, `fetchFromRepoOrCz`, `fetchFromSourcehut`, `fetchCrate`, `fetchPypi`, `fetchHex`, `fetchgit`, `fetchhg`, `fetchsvn`, `fetchurl`, `fetchzip`, `fetchpatch`, `fetchpatch2`, `builtins.fetchGit`.

```bash
# Specify a custom fetcher
nurl -f fetchCrate https://crates.io/crates/serde 1.0

# Output only the hash
nurl -H https://github.com/owner/repo v1.0

# JSON output for scripting
nurl -j https://github.com/owner/repo v1.0

# Fetch submodules (optional value must use `=`: -S=false)
nurl -S https://github.com/owner/repo v1.0
```

### nix-init — Generate Package Definitions from URLs

`nix-init` builds on top of `nurl` to generate complete Nix package definitions (not just fetcher calls) from URLs. It handles hash prefetching, dependency inference for Rust/Go/Python, license detection, and interactive prompts with fuzzy completions.

```bash
# Generate a package definition interactively
nix-init https://github.com/owner/repo

# Headless mode (requires --url)
nix-init --url https://github.com/owner/repo --headless

# Specify builder and output path
nix-init --builder rustPlatform.buildRustPackage -u https://github.com/owner/repo

# Output path is positional; -C commits when the path is by-name (RFC 140)
nix-init -C -u https://github.com/owner/repo pkgs/by-name/re/repo/
```

Generated output typically needs review — double-check the license, description, and build flags.

### nixpkgs-update — Automated Package Updates

A tool and bot for automatically updating nixpkgs packages (now under the NixOS org, `github:NixOS/nixpkgs-update`). The bot runs on the `r-ryantm` account and submits PRs to nixpkgs. For manual use, run it from a clean nixpkgs checkout with an `upstream` remote and a `GITHUB_TOKEN`:

```bash
# Update one package from an old to a new version, build it, and commit
nix run github:NixOS/nixpkgs-update -- update "postman 7.20.0 7.21.2"
# --nixpkgs-review also builds reverse dependencies; --cve adds a CVE report
# Docs: https://nixos.github.io/nixpkgs-update/
```

The bot creates PRs titled like "foobar: 1.0.0 -> 1.0.1" with build results. PRs from `r-ryantm` on `pkgs/by-name` packages can be merged by a listed maintainer via the merge bot.

### nix-update and nixpkgs-review

For hand-driven bumps, `nix-update` (Mic92) edits `version`, `hash` and vendor hashes in place; `buildPythonPackage`/`buildPythonApplication` default `passthru.updateScript` to `nix-update-script` since 25.11, and other packages can opt in with `passthru.updateScript = nix-update-script { };`.

```bash
nix-update hello                    # latest release
nix-update --version=branch hello   # latest commit on the default branch
nix-update --build --commit hello   # build, then commit
nix-update --flake mypkg            # package defined in a flake

nixpkgs-review pr 12345                     # build everything a PR touches
nixpkgs-review pr --post-result 12345       # comment the report on the PR
nixpkgs-review wip                          # uncommitted local changes
nixpkgs-review rev HEAD                     # a local commit
nixpkgs-review pr --systems all 12345       # every platform you have builders for
```

**Fetchers vs builtins:** `pkgs.fetchurl` is a fixed-output derivation (builds in parallel, cached). `builtins.fetchurl` runs during evaluation and blocks the evaluator. Prefer `pkgs.fetch*` for build-time downloads.

## Language-Specific Builders

See `nixpkgs/builders.md` for detailed patterns per language.

### Python

```nix
python3Packages.buildPythonPackage {
  pname = "mylib";
  version = "1.0";
  src = ./.;
  pyproject = true;
  build-system = [ python3Packages.setuptools ];
  dependencies = [ python3Packages.requests ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];
}
```

Since 25.11 `buildPythonPackage`/`buildPythonApplication` require an explicit `pyproject = true` (or a legacy `format`); `pyproject = true` with `build-system = [ setuptools ]` also covers `setup.py`-only projects. 26.05 errors on `pytestFlagsArray`; use `pytestFlags`, `disabledTests`, `disabledTestPaths`.

### Rust

```nix
rustPlatform.buildRustPackage {
  pname = "mytool";
  version = "1.0";
  src = ./.;
  cargoHash = "sha256-...";
  # No darwin.apple_sdk.frameworks.*: the default Darwin SDK is in stdenv
}
```

Since 25.05 `cargoHash` is computed by `rustPlatform.fetchCargoVendor` (Cargo 1.84 changed the `cargo vendor` format, so every older `cargoHash` had to be regenerated). Drop any `useFetchCargoVendor` attribute: on 26.05 it is non-optional and setting it triggers a warning (`false` fails an assertion).

### Node.js

```nix
buildNpmPackage {
  pname = "myapp";
  version = "1.0";
  src = ./.;
  npmDepsHash = "sha256-...";
}
```

As of 26.05 the `nodePackages` set, `node2nix`, and `yarn2nix`/`mkYarnPackage`/`mkYarnModules` are gone. Use `buildNpmPackage` for npm, `fetchYarnDeps` + `yarnConfigHook`/`yarnBuildHook`/`yarnInstallHook` for Yarn v1, `yarn-berry_4.fetchYarnBerryDeps` + `yarnBerryConfigHook` for Yarn 3/4, and top-level `fetchPnpmDeps` + `pnpmConfigHook` for pnpm (the `pnpm.fetchDeps`/`pnpm.configHook` spellings are deprecated). The default Node.js is 24 LTS in 26.05. See `nixpkgs/builders.md`.

### Go

```nix
buildGoModule {
  pname = "mytool";
  version = "1.0";
  src = ./.;
  vendorHash = "sha256-...";
}
```

## Overrides

### overrideAttrs — modify derivation attributes

```nix
pkgs.hello.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./my-patch.patch ];
  version = "2.13";
})
```

`overrideAttrs` re-runs mkDerivation with the modified attributes. The function receives the previous attributes.

### override — change callPackage arguments

```nix
pkgs.hello.override {
  stdenv = pkgs.clangStdenv;  # Build with clang instead of gcc
}
```

`override` re-calls the `callPackage` function with different arguments. Only works on packages built with `callPackage`.

## Overlays

An overlay is a function `final: prev: { ... }` that extends or modifies the package set:

```nix
final: prev: {
  # Add a new package
  myapp = final.callPackage ./myapp.nix { };

  # Modify existing package
  hello = prev.hello.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./fix.patch ];
  });
}
```

### `final` vs `prev`

- **`prev`** — the package set before this overlay. Use for the package you are modifying: `prev.hello`
- **`final`** — the fully resolved package set after ALL overlays. Use for dependencies: `final.openssl`

**Default rule:** Use `prev` by default. Switch to `final` only when you need a package that another overlay provides or when you need the version of a dependency that other overlays may have modified.

Using `final.foo` where `foo` is the attribute you're defining causes infinite recursion.

### Multiple Overlay Composition

Overlays are applied in order. Each overlay's `prev` is the result of all previous overlays. `final` is always the same for every overlay — the fully composed result.

```nix
import nixpkgs {
  overlays = [
    overlay1  # prev = bare nixpkgs
    overlay2  # prev = nixpkgs + overlay1
    overlay3  # prev = nixpkgs + overlay1 + overlay2
  ];
  # final = nixpkgs + overlay1 + overlay2 + overlay3 (same for all three)
}
```

### Composing Upstream Overlays

To layer custom additions on top of an upstream overlay, merge the applied results:

```nix
final: prev:
(upstream.overlays.default final prev) // {
  my-extra = final.callPackage ./my-extra.nix { };
}
```

To compose several overlay *functions* into one (without applying them yet), use `lib.composeManyExtensions` — it threads `final`/`prev` through each overlay correctly, which `//` cannot do on the functions themselves:

```nix
overlays.default = lib.composeManyExtensions [
  upstream.overlays.default
  (import ./overlay.nix)
  (final: prev: { my-extra = final.callPackage ./my-extra.nix { }; })
];
```

Reach for the applied `//` form when you have the resolved attrsets in hand; use `composeManyExtensions` when the result itself needs to remain a single overlay function (e.g., a flake output).

## Meta-Attributes

```nix
meta = {
  description = "One-line description";
  homepage = "https://example.com";
  license = lib.licenses.mit;                   # or lib.licenses.gpl3Plus, etc.
  maintainers = with lib.maintainers; [ alice bob ];
  teams = [ lib.teams.someteam ];               # optional, from maintainers/team-list.nix
  platforms = lib.platforms.all;                # or lib.platforms.linux, lib.platforms.darwin
  mainProgram = "mytool";                       # which binary `nix run` executes
  broken = stdenv.hostPlatform.isDarwin;        # mark as broken on specific platforms
  changelog = "https://example.com/changelog";

  # RFC 89 — required when the package ships prebuilt binaries
  sourceProvenance = [ lib.sourceTypes.fromSource ];
  # Use [ binaryNativeCode ], [ binaryBytecode ], or [ binaryFirmware ]
  # for non-source packages. Fully source packages can omit this field.
};
```

Prefer explicit `lib.` prefixes over a blanket `meta = with lib; { ... }`, matching the Nixpkgs manual examples.

`mainProgram` is important for `nix run`: without it, Nix guesses from `pname`. Since 25.11 it also sets `NIX_MAIN_PROGRAM` in the build environment, so changing it causes a rebuild.

**`broken = true` auto-removes (RFC 180).** A package broken on all platforms is removed one NixOS release cycle after being marked (broken in 25.11 → removed after 26.05). Fix or remove, don't just unmark. The same applies to packages with empty `meta.maintainers` and no reverse dependents.

**`meta.problems` (RFC 127) has landed.** `meta.broken = true;` is now shorthand for `meta.problems.broken.message = "This package is broken.";`; set the long form to customize the message. On unstable (26.11), `config.allowBrokenPredicate` is deprecated in favor of `config.problems.handlers.<pname>.broken = "warn"` (or `"ignore"`), and Python's `disabled` maps to `meta.problems.unsupportedPython`. `knownVulnerabilities` and license checks still use their existing fields.

## Tests: `passthru.tests` (RFC 119)

Package tests live in two places with distinct purposes:

| Mechanism | When it runs | Use for |
|-----------|-------------|---------|
| `doCheck = true` + `checkPhase` | During package build | Fast in-tree tests (unit tests, `cargo test`, `pytest`) |
| `passthru.tests = { ... }` | Separate derivations, picked up by `nixpkgs-review` and CI | Slow / integration / VM / cross-package smoke tests |

```nix
stdenv.mkDerivation {
  pname = "myapp";
  # ...
  doCheck = true;
  checkPhase = ''
    ./run-unit-tests
  '';

  passthru.tests = {
    vm-smoke = nixosTests.myapp;               # NixOS VM integration test
    cli-help = runCommand "myapp-cli-help" { } ''
      ${placeholder "out"}/bin/myapp --help > $out
    '';
  };
}
```

See the **nix-testing** skill for writing `nixosTests.*` entries.

## Platform Tiers (RFC 46)

Nixpkgs platforms are tiered. Only Tier 1 (x86_64-linux, aarch64-linux) has full CI and binary cache coverage. Don't assume substitutes exist for macOS/BSD/less-common architectures, and don't assume a package builds on non-Tier-1 platforms just because `platforms.all` is set. Use `meta.platforms` deliberately and `meta.broken = <predicate>` when a platform is known to break.

**x86_64-darwin is going away.** Nixpkgs 26.05 is the last release that builds or supports Intel macOS (binaries until 26.05 goes out of support at the end of 2026); 26.11 drops it and errors with instructions to switch to 26.05. 26.05 prints a warning that `config.allowDeprecatedx86_64Darwin = true` silences (flake users: `import nixpkgs { system = "x86_64-darwin"; config.allowDeprecatedx86_64Darwin = true; }`). Since 25.11, Nixpkgs needs macOS 14 (Sonoma) or newer; the default SDK is 14.4.

## Contribution Workflow

### Staging Branches (RFC 26)

Nixpkgs branch workflow based on rebuild count (same names with a `-YY.MM` suffix on stable branches):

| Base branch | Use for |
|-------------|---------|
| `master` | Normal changes. CI adds `rebuild` labels; at 500+ rebuilds consider `staging` |
| `staging-next` | Stabilization of staging changes before they hit master (only fixes for Hydra failures) |
| `staging` | Mass-rebuilds, 1000+ rebuilds (stdenv, glibc, openssl, common libs) |
| `staging-nixos` | Linux kernel changes and PRs labeled `10.rebuild-nixos-tests` (rebuild all NixOS tests) |

Pick base branch based on rebuild blast radius. `nixpkgs-review` helps estimate this.

CI enforces formatting with the official `nixfmt` (RFC 166) through treefmt; run `nix develop --command treefmt` or `nix-shell --run treefmt` in the Nixpkgs checkout before pushing.

### Breaking Changes (RFC 88)

When changing a library with dependents: either fix all dependents in the same PR, or land on `staging` and give downstream maintainers a window. Never knowingly merge a change to `master` that would stall the channel.

### Release Freeze (RFC 85)

Around NixOS release branch-offs (YY.05 and YY.11 per RFC 80), changes to Release Critical Packages (kernel, systemd, glibc, desktop envs) are restricted during the "Zero Hydra Failures" push. Land risky work earlier in the cycle.

## Cross-Platform

```nix
buildInputs = [ openssl ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ systemd ];
# Darwin: the default SDK (frameworks included) is already in stdenv.
# Only add a newer one when needed, e.g. `lib.optionals stdenv.hostPlatform.isDarwin [ apple-sdk_15 ]`,
# and raise the deployment target with `(darwinMinVersionHook "13.3")`.
```

- **`darwin.apple_sdk.*` is gone.** `darwin.apple_sdk`, `apple_sdk_11_0` and `apple_sdk_12_3` became throwing stubs in 25.11. Delete `darwin.apple_sdk.frameworks.*` inputs; replace hard-coded framework paths with `$SDKROOT/System/Library/Frameworks/...` in `preConfigure`. Use `apple-sdk_14`, `apple-sdk_15`, `apple-sdk_26`, ... for a non-default SDK.
- **Use `stdenv.hostPlatform.isDarwin`, not `stdenv.isDarwin`.** The short `stdenv.is*` forms (`isDarwin`, `isLinux`, `isx86_64`, `isAarch64`, ...) are deprecated aliases on unstable (since 2026-05) and warn. They already refer to the host platform, so the rename is mechanical.
- **`xorg.*` is deprecated (26.05).** Packages moved to the top level with lowercase names, e.g. `xorg.libX11` → `libx11`; the old paths still evaluate with a warning.

See `nixpkgs/cross-compilation.md` for cross-compilation patterns (building for a different architecture).

## Common Patterns

- **Wrapping binaries**: `wrapProgram $out/bin/foo --prefix PATH : ${lib.makeBinPath [ git ]}`
- **writeShellApplication**: Creates a script with runtime deps on PATH and shellcheck validation:

  ```nix
  pkgs.writeShellApplication {
    name = "my-script";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = ''curl -s "$1" | jq .'';
  }
  ```

- **Shell completions**: install to `$out/share/bash-completion/completions/`, `$out/share/zsh/site-functions/`, `$out/share/fish/vendor_completions.d/`
- **Desktop entries**: use `makeDesktopItem`
- **Stripping**: controlled by `dontStrip = true;`
- **Patching shebangs**: automatic in fixupPhase, disable with `dontPatchShebangs`
- **Removing references**: `removeReferencesTo` strips store path references from binaries to reduce closure size
