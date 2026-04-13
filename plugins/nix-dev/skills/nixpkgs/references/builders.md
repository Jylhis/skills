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
python3Packages.buildPythonPackage {
  pname = "mylib";
  version = "1.0";
  src = ./.;
  format = "pyproject";                              # or "setuptools", "flit", "wheel"
  build-system = [ python3Packages.setuptools ];     # PEP 517 build backend
  dependencies = [ python3Packages.requests ];       # Runtime deps
  optional-dependencies.dev = [ python3Packages.pytest ];
  nativeCheckInputs = [ python3Packages.pytest ];    # Test-only deps
  checkPhase = ''pytest'';
  pythonImportsCheck = [ "mylib" ];                  # Quick import test
}
```

**Key patterns:**
- `format = "pyproject"` for modern projects with pyproject.toml
- `dependencies` replaces the old `propagatedBuildInputs` for Python deps
- `build-system` replaces old `nativeBuildInputs` for build backends
- `pythonImportsCheck` verifies the package imports correctly

### buildPythonApplication

Same as `buildPythonPackage` but does not propagate Python dependencies. Use for CLI tools that should not be importable as libraries.

---

## Rust

### buildRustPackage (nixpkgs built-in)

```nix
rustPlatform.buildRustPackage {
  pname = "mytool";
  version = "1.0";
  src = ./.;
  cargoHash = "sha256-...";                     # Hash of Cargo.lock dependencies
  # or: cargoLock.lockFile = ./Cargo.lock;      # Auto-compute hash

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ]
    ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.Security ];

  checkFlags = [
    "--skip=test_that_needs_network"             # Skip flaky tests
  ];
}
```

**Getting `cargoHash`:** Set to `lib.fakeHash`, build, copy the correct hash from the error.

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

### buildYarnPackage

For Yarn v1 (classic) projects — uses `yarn.lock`:

```nix
mkYarnPackage {
  pname = "myapp";
  version = "1.0";
  src = ./.;
  packageJSON = ./package.json;
  yarnLock = ./yarn.lock;
}
```

---

## Go

### buildGoModule

```nix
buildGoModule {
  pname = "mytool";
  version = "1.0";
  src = ./.;
  vendorHash = "sha256-...";      # Hash of go.sum dependencies
  # or: vendorHash = null;         # If vendor/ is checked into repo

  # Specify which packages to build (default: ./...)
  subPackages = [ "cmd/mytool" ];

  ldflags = [
    "-s" "-w"                       # Strip debug info
    "-X main.version=${version}"    # Inject version at build time
  ];

  # Go tests
  checkFlags = [ "-timeout" "30s" ];
}
```

**`vendorHash`:** Set to `lib.fakeHash`, build, copy the correct hash. Use `null` if the project vendors its dependencies in-tree.

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
