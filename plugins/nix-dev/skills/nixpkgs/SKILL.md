---
name: nixpkgs
description: "Use for nixpkgs package management patterns including mkDerivation, callPackage, overlays, override, overrideAttrs, buildPythonPackage, buildRustPackage, buildNpmPackage, buildGoModule, packageOverrides, derivations, fetchFromGitHub, fetchers, stdenv, build phases, nativeBuildInputs, buildInputs, cross-compilation, cross-platform packaging, wrapProgram, lib.fileset source filtering, overlay composition, or meta-attributes."
user-invocable: false
---

# Nixpkgs

## Finding Packages

```bash
nix search nixpkgs#<query>
```

If the mcp-nixos MCP server is available, use it for richer search with version history and metadata.

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
stdenv.mkDerivation {
  pname = "myapp";
  version = "1.0.0";
  src = fetchFromGitHub { owner = "..."; repo = "..."; rev = "..."; hash = "..."; };

  nativeBuildInputs = [ cmake pkg-config ];  # Tools that run on the BUILD machine
  buildInputs = [ openssl zlib ];             # Libraries for the HOST machine
  propagatedBuildInputs = [ ];                # Also available to downstream dependents

  patches = [ ./fix-build.patch ];
  env.NIX_CFLAGS_COMPILE = "-O2";

  meta = { /* ... */ };
}
```

**`nativeBuildInputs` vs `buildInputs`:** For native builds they are equivalent. For cross-compilation, `nativeBuildInputs` are built for the build machine (compilers, code generators, pkg-config) while `buildInputs` are built for the host machine (libraries to link against). See `references/cross-compilation.md`.

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
| `fetchFromGitHub` | GitHub repos | `owner`, `repo`, `rev`, `hash` |
| `fetchFromGitLab` | GitLab repos | `owner`, `repo`, `rev`, `hash` |
| `fetchgit` | Generic git | `url`, `rev`, `hash` |
| `fetchzip` | ZIP/tarball with auto-extract | `url`, `hash` |
| `fetchpatch` | Fetch a patch from URL | `url`, `hash`, `excludes?` |

**Getting the hash:** Use `nurl` (generates full fetcher calls from URLs), `nix-prefetch-url`, `nix-prefetch-github`, or set `hash = "";` and Nix reports the correct hash in the error.

**Fetchers vs builtins:** `pkgs.fetchurl` is a fixed-output derivation (builds in parallel, cached). `builtins.fetchurl` runs during evaluation and blocks the evaluator. Prefer `pkgs.fetch*` for build-time downloads.

## Language-Specific Builders

See `references/builders.md` for detailed patterns per language.

### Python

```nix
python3Packages.buildPythonPackage {
  pname = "mylib";
  version = "1.0";
  src = ./.;
  format = "pyproject";
  build-system = [ python3Packages.setuptools ];
  dependencies = [ python3Packages.requests ];
  nativeCheckInputs = [ python3Packages.pytest ];
}
```

### Rust

```nix
rustPlatform.buildRustPackage {
  pname = "mytool";
  version = "1.0";
  src = ./.;
  cargoHash = "sha256-...";
  buildInputs = lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.Security ];
}
```

### Node.js

```nix
buildNpmPackage {
  pname = "myapp";
  version = "1.0";
  src = ./.;
  npmDepsHash = "sha256-...";
}
```

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

```nix
final: prev:
(upstream.overlays.default final prev) // {
  my-extra = final.callPackage ./my-extra.nix { };
}
```

## Meta-Attributes

```nix
meta = with lib; {
  description = "One-line description";
  homepage = "https://example.com";
  license = licenses.mit;              # or licenses.gpl3Plus, etc.
  maintainers = with maintainers; [ alice bob ];
  platforms = platforms.all;            # or platforms.linux, platforms.darwin
  mainProgram = "mytool";              # which binary `nix run` executes
  broken = stdenv.isDarwin;            # mark as broken on specific platforms
  changelog = "https://example.com/changelog";
};
```

`mainProgram` is important for `nix run` — without it, Nix guesses from `pname`.

## Cross-Platform

```nix
buildInputs = [ openssl ]
  ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ]
  ++ lib.optionals stdenv.isLinux [ systemd ];
```

See `references/cross-compilation.md` for cross-compilation patterns (building for a different architecture).

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
