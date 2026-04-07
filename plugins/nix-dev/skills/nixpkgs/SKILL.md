---
name: nixpkgs
description: "Use for nixpkgs package management patterns including mkDerivation, callPackage, overlays, override, overrideAttrs, buildPythonPackage, buildRustPackage, buildNpmPackage, buildGoModule, packageOverrides, derivations, fetchFromGitHub, fetchers, stdenv, build phases, nativeBuildInputs, buildInputs, cross-platform packaging, or wrapProgram."
user-invocable: false
---

# Nixpkgs

## Finding Packages

```bash
nix search nixpkgs#<query>
```

If the mcp-nixos MCP server is available, use it for richer search with version history and metadata.

## callPackage Pattern

The standard way packages are defined in nixpkgs. A package file is a function taking its dependencies, and `callPackage` auto-supplies them from the package set:

```nix
# pkgs/tools/misc/hello/default.nix
{ lib, stdenv, fetchurl }:

stdenv.mkDerivation {
  pname = "hello";
  version = "2.12";
  src = fetchurl {
    url = "mirror://gnu/hello/hello-2.12.tar.gz";
    hash = "sha256-abc123...";
  };
  meta = with lib; {
    description = "A program that produces a familiar, friendly greeting";
    license = licenses.gpl3Plus;
    platforms = platforms.all;
  };
}

# Called via:
hello = callPackage ./pkgs/tools/misc/hello { };
```

## stdenv.mkDerivation

The main builder. Key phases in order:

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

  nativeBuildInputs = [ cmake pkg-config ];  # Build-time only (not propagated)
  buildInputs = [ openssl zlib ];             # Link-time dependencies
  propagatedBuildInputs = [ ];                # Also available to dependents

  patches = [ ./fix-build.patch ];
  env.NIX_CFLAGS_COMPILE = "-O2";

  meta = { /* ... */ };
}
```

## Fetchers

| Fetcher | Use case |
|---------|----------|
| `fetchurl { url; hash; }` | Simple URL download |
| `fetchFromGitHub { owner; repo; rev; hash; }` | GitHub repos |
| `fetchFromGitLab { owner; repo; rev; hash; }` | GitLab repos |
| `fetchgit { url; rev; hash; }` | Generic git |
| `fetchzip { url; hash; }` | ZIP/tarball with auto-extract |

Get the hash: use `nix-prefetch-url`, `nix-prefetch-github`, or set `hash = "";` and let Nix tell you the correct one in the error.

## Language-Specific Builders

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

### overrideAttrs — modify a derivation

```nix
pkgs.hello.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./my-patch.patch ];
  version = "2.13";
})
```

### override — change callPackage arguments

```nix
pkgs.hello.override {
  stdenv = pkgs.clangStdenv;  # Build with clang instead of gcc
}
```

## Overlays

An overlay is a function `final: prev:` that modifies the package set:

```nix
# In flake.nix or ~/.config/nixpkgs/overlays/
final: prev: {
  # Add a new package
  myapp = final.callPackage ./myapp.nix { };

  # Modify existing package
  hello = prev.hello.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./fix.patch ];
  });
}
```

- `final` (also called `self`) — the fixed-point result (use for dependencies)
- `prev` (also called `super`) — the previous package set (use for the thing you're modifying)

Rule: use `prev.foo` for the package you're overriding, `final.bar` for its dependencies.

## Cross-Platform

```nix
buildInputs = [ openssl ]
  ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.Security ]
  ++ lib.optionals stdenv.isLinux [ systemd ];
```

## Common Patterns

- **Wrapping binaries**: `wrapProgram $out/bin/foo --prefix PATH : ${lib.makeBinPath [ git ]}`
- **Shell completions**: install to `$out/share/bash-completion/completions/`, etc.
- **Desktop entries**: use `makeDesktopItem`
- **Stripping**: controlled by `dontStrip = true;`
- **Patching shebangs**: automatic in fixupPhase, disable with `dontPatchShebangs`
