# Language-Specific Builders Reference

## Table of Contents

- [Python](#python)
- [Rust](#rust)
- [Node.js](#nodejs)
- [Go](#go)
- [Trivial Builders](#trivial-builders)

---

## Python

### buildPythonPackage

```nix
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "mylib";
  version = "1.0";
  src = ./.;
  pyproject = true;                                  # PEP 517 build via pypaBuildHook
  build-system = [ python3Packages.setuptools ];     # PEP 517 build backend
  dependencies = [ python3Packages.requests ];       # Runtime deps
  optional-dependencies.dev = [ python3Packages.rich ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];  # Runs pytest in checkPhase
  disabledTests = [ "test_needs_network" ];
  pythonImportsCheck = [ "mylib" ];                  # Quick import test
})
```

**Key patterns:**
- `pyproject = true` for every new package. Since 25.11 an explicit `pyproject` (or legacy `format`) is required; the old implicit `setup.py` default is gone. `pyproject = true` falls back to setuptools, so it also works for `setup.py`-only projects.
- `dependencies` replaces the old `propagatedBuildInputs` for Python deps
- `build-system` replaces old `nativeBuildInputs` for build backends
- `pytestCheckHook` in `nativeCheckInputs` instead of a hand-written `checkPhase`; tune it with `pytestFlags`, `disabledTests`, `disabledTestPaths`, `disabledTestMarks`. `pytestFlagsArray` is an error as of 26.05.
- `pythonImportsCheck` verifies the package imports correctly
- `finalAttrs:` (fixed-point arguments) is supported, as with `mkDerivation`
- To change the stdenv, override the builder (`buildPythonPackage.override { stdenv = ...; }`); passing `stdenv` as an argument is deprecated since 25.11

### buildPythonApplication

Same as `buildPythonPackage` but does not propagate Python dependencies. Use for CLI tools that should not be importable as libraries.

---

## Rust

### buildRustPackage (nixpkgs built-in)

```nix
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mytool";
  version = "1.0";
  src = ./.;
  cargoHash = "sha256-...";                     # Hash of the vendored crates
  # or: cargoLock.lockFile = ./Cargo.lock;      # No hash; git deps need cargoLock.outputHashes

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];                    # No darwin.apple_sdk.frameworks.*; default SDK is in stdenv

  checkFlags = [
    "--skip=test_that_needs_network"             # Skip flaky tests
  ];
})
```

**Getting `cargoHash`:** Set to `lib.fakeHash`, build, copy the correct hash from the error.

**25.05 vendoring change:** `cargoHash` is now produced by `rustPlatform.fetchCargoVendor` (Cargo 1.84 changed the `cargo vendor` output format, which invalidated all `fetchCargoTarball` hashes), so pre-25.05 hashes must be regenerated. `cargoSha256` is an error; `useFetchCargoVendor` is non-optional and should be removed.

### Crane (alternative)

Crane provides incremental Rust compilation — dependency crate builds are cached separately from your source code:

```nix
let
  craneLib = crane.mkLib pkgs;
in craneLib.buildPackage {
  src = craneLib.cleanCargoSource ./.;
  buildInputs = [ openssl ];
  nativeBuildInputs = [ pkg-config ];
}
```

### Naersk (alternative)

Builds directly from `Cargo.lock` without separate vendor step:

```nix
naersk.buildPackage {
  src = ./.;
}
```

---

## Node.js

### buildNpmPackage

```nix
buildNpmPackage {
  pname = "myapp";
  version = "1.0";
  src = ./.;
  npmDepsHash = "sha256-...";

  # For packages with native addons:
  nativeBuildInputs = [ python3 pkg-config ];
  buildInputs = [ vips ];  # e.g., for sharp

  # Build script from package.json
  npmBuild = "npm run build";

  installPhase = ''
    mkdir -p $out/lib/node_modules/myapp
    cp -r dist node_modules package.json $out/lib/node_modules/myapp/
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/myapp \
      --add-flags $out/lib/node_modules/myapp/dist/index.js
  '';
}
```

`buildNpmPackage` takes `finalAttrs:` and runs the `build` script from `package.json` by default (`npmBuildScript` changes it; `dontNpmBuild = true` skips it). Since 26.05, `npmDepsFetcherVersion = 2` enables packument caching, which fixes npm-workspace projects (regenerate `npmDepsHash`).

The `nodePackages` set and `node2nix` were removed in 26.05; package Node CLIs as top-level packages with `buildNpmPackage` (or the pnpm/Yarn helpers below).

### Yarn v1 (hooks)

`mkYarnPackage`, `mkYarnModules`, `fixup_yarn_lock` and yarn2nix were removed in 26.05. Use `fetchYarnDeps` plus the Yarn hooks on a plain `mkDerivation`:

```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "myapp";
  version = "1.0";
  src = ./.;

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = finalAttrs.src + "/yarn.lock";
    hash = "sha256-...";
  };

  nativeBuildInputs = [
    yarnConfigHook   # installs node_modules from the offline cache
    yarnBuildHook    # runs `yarn --offline build` (yarnBuildScript to change)
    yarnInstallHook  # prunes devDependencies and installs into $out
    nodejs
  ];
})
```

For Yarn Berry (v3/v4) lockfiles, use `yarn-berry_4.fetchYarnBerryDeps` for `offlineCache` and `yarn-berry_4.yarnBerryConfigHook` in `nativeBuildInputs`.

### pnpm

```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "myapp";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm_10            # pin a major; pass the same one to fetchPnpmDeps
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;  # value the 26.05 manual uses for new packages
    hash = "sha256-...";
  };
})
```

`fetchPnpmDeps` and `pnpmConfigHook` are top-level since 26.05; `pnpm.fetchDeps`/`pnpm.configHook` are deprecated. `fetcherVersion` 1 and 2 are deprecated in 26.05 and already removed on unstable (3 is the minimum there). Bumping `fetcherVersion` changes the hash.

---

## Go

### buildGoModule

```nix
buildGoModule (finalAttrs: {
  pname = "mytool";
  version = "1.0";
  src = ./.;
  vendorHash = "sha256-...";      # Hash of go.sum dependencies
  # or: vendorHash = null;         # If vendor/ is checked into repo

  # Specify which packages to build (default: ./...)
  subPackages = [ "cmd/mytool" ];

  ldflags = [
    "-s" "-w"                                   # Strip debug info
    "-X main.version=${finalAttrs.version}"     # Inject version at build time
  ];

  env.CGO_ENABLED = 0;            # Go env vars go through `env`

  # Go tests: -skip / -run take regexes
  checkFlags = [ "-skip=^TestNetwork$" ];
})
```

**`vendorHash`:** Set to `lib.fakeHash`, build, copy the correct hash. Use `null` if the project vendors its dependencies in-tree.

**Recent changes:** `buildGoModule` accepts `finalAttrs:` since 25.05. `CGO_ENABLED` must be set as `env.CGO_ENABLED` (the top-level compatibility shim was removed in 25.11), and setting Go variables such as `GOOS`/`GOARCH` directly is an error. `goSum = ./go.sum;` makes rebuilds track `go.sum`. `buildGoPackage` (GOPATH mode) was removed in 25.05. `buildGoLatestModule`/`go_latest` follow the newest toolchain.

---

## Trivial Builders

### writeText / writeTextFile

Create a file in the store:

```nix
pkgs.writeText "my-config" ''
  key = value
''

pkgs.writeTextFile {
  name = "my-script";
  text = "#!/bin/sh\necho hello";
  executable = true;
  destination = "/bin/my-script";
}
```

### writeShellApplication

Creates a bash script with runtime dependencies on PATH, `set -euo pipefail`, and shellcheck validation:

```nix
pkgs.writeShellApplication {
  name = "deploy";
  runtimeInputs = [ pkgs.kubectl pkgs.jq ];
  text = ''
    kubectl get pods -o json | jq '.items[].metadata.name'
  '';
}
```

### writeShellScript / writeShellScriptBin

Simpler version without shellcheck or runtimeInputs:

```nix
pkgs.writeShellScriptBin "greet" ''echo "Hello, $1"''
```

### runCommand / runCommandLocal

Execute a command and capture the output as a derivation:

```nix
pkgs.runCommand "generated-config" { nativeBuildInputs = [ pkgs.jq ]; } ''
  echo '{"key": "value"}' | jq . > $out
''
```

`runCommandLocal` prevents substitution — always builds locally.

### symlinkJoin

Merge multiple packages into one by symlinking their contents:

```nix
pkgs.symlinkJoin {
  name = "combined-tools";
  paths = [ pkgs.git pkgs.curl pkgs.jq ];
}
```

### makeWrapper / wrapProgram

Set environment variables and PATH for a binary:

```nix
postInstall = ''
  wrapProgram $out/bin/mytool \
    --prefix PATH : ${lib.makeBinPath [ pkgs.git pkgs.ssh ]} \
    --set MY_CONFIG "/etc/mytool.conf"
'';
```
