# Cross-Compilation Reference

## Table of Contents

- [Platform Concepts](#platform-concepts)
- [Build Inputs Rules](#build-inputs-rules)
- [Using pkgsCross](#using-pkgscross)
- [Splicing Internals](#splicing-internals)
- [Practical Examples](#practical-examples)

---

## Platform Concepts

Cross-compilation involves three platforms:

| Platform | Definition | Example |
|----------|-----------|---------|
| **Build** | Where compilation happens | Your laptop (x86_64-linux) |
| **Host** | Where the compiled binary runs | Raspberry Pi (aarch64-linux) |
| **Target** | What the compiled binary targets (compilers only) | The architecture a cross-compiler generates code for |

Native compilation is the special case where build = host. Target only matters when building compilers.

Platform configs follow `<cpu>-<vendor>-<os>-<abi>`:
- `aarch64-unknown-linux-gnu`
- `x86_64-w64-mingw32` (Windows)
- `aarch64-apple-darwin` (macOS ARM)

## Build Inputs Rules

| Attribute | Runs On | Links Against | Use For |
|-----------|---------|---------------|---------|
| `depsBuildBuild` | Build | Build | Build tools that produce build tools |
| `nativeBuildInputs` | Build | Host | Compilers, code generators, pkg-config, cmake |
| `buildInputs` | Host | Host | Libraries to link against (openssl, zlib) |
| `propagatedBuildInputs` | Host | Host | Libraries that downstream packages also need |
| `depsBuildTarget` | Build | Target | Tools targeting the target platform |
| `depsHostHost` | Host | Host | Rare: libs needed at build time on host |
| `depsTargetTarget` | Target | Target | Rare: runtime deps of the target |

**Simple rule:** If it's a tool/binary you run during build → `nativeBuildInputs`. If it's a library you link against → `buildInputs`.

## Using pkgsCross

Nixpkgs provides pre-configured cross-compilation environments:

```nix
# Cross-compile hello for ARM
pkgs.pkgsCross.aarch64-multiplatform.hello

# Cross-compile for static musl
pkgs.pkgsCross.musl64.hello

# Cross-compile for Windows
pkgs.pkgsCross.mingwW64.hello

# Cross-compile for Raspberry Pi
pkgs.pkgsCross.raspberryPi.hello
```

Available targets (partial list):
- `aarch64-multiplatform` — ARM 64-bit Linux
- `armv7l-hf-multiplatform` — ARM 32-bit Linux (hard float)
- `raspberryPi` — Raspberry Pi (ARMv6)
- `musl64` — x86_64 Linux with musl (static)
- `musl32` — i686 Linux with musl
- `aarch64-multiplatform-musl` — ARM 64-bit with musl
- `mingwW64` — Windows 64-bit
- `mingw32` — Windows 32-bit
- `riscv64` — RISC-V 64-bit Linux

## Splicing Internals

When you use `callPackage` with a cross-compilation package set, Nix automatically resolves dependencies to the correct platform through "splicing":

- Arguments listed in `nativeBuildInputs` are resolved from `pkgs.buildPackages` (the build platform)
- Arguments listed in `buildInputs` are resolved from `pkgs` (the host platform)

This happens transparently through `callPackage`. Each package attribute is a "spliced" object that contains both the build and host variants:

```nix
# In a cross environment, openssl is actually a spliced package:
# openssl.__spliced.buildBuild  — built for build, runs on build
# openssl.__spliced.buildHost   — built for build, targets host (native build tools)
# openssl.__spliced.hostTarget  — built for host (library to link against)
```

`callPackage` inspects which input list a package appears in and selects the appropriate spliced variant.

## Practical Examples

### Cross-compile a C package

```nix
let
  pkgs = import nixpkgs {};
  crossPkgs = pkgs.pkgsCross.aarch64-multiplatform;
in crossPkgs.callPackage ({ stdenv, openssl, pkg-config }:
  stdenv.mkDerivation {
    pname = "myapp";
    version = "1.0";
    src = ./.;
    nativeBuildInputs = [ pkg-config ];  # Runs on build machine
    buildInputs = [ openssl ];           # Links against ARM openssl
  }
) {}
```

### Cross-compile with emulator verification

```nix
let
  pkgs = import nixpkgs {};
  crossPkgs = pkgs.pkgsCross.aarch64-multiplatform;
  emulator = crossPkgs.stdenv.hostPlatform.emulator crossPkgs.buildPackages;
in crossPkgs.runCommandCC "test-cross" {} ''
  $CC -o hello ${./hello.c}
  ${emulator} hello > $out
''
```

### Static compilation

```nix
pkgs.pkgsCross.musl64.callPackage ./package.nix {}
# or for the current platform:
pkgs.pkgsStatic.callPackage ./package.nix {}
```

### Platform-conditional dependencies

```nix
{ lib, stdenv, openssl, darwin }:
stdenv.mkDerivation {
  buildInputs = [ openssl ]
    ++ lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.Security
      darwin.apple_sdk.frameworks.SystemConfiguration
    ];
}
```
