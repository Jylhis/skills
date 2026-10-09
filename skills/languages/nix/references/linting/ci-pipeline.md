# CI/CD Pipeline Patterns for Nix Projects

## Table of Contents

- [GitHub Actions with Nix](#github-actions-with-nix)
- [Faster flake CI (nix-fast-build)](#faster-flake-ci-nix-fast-build)
- [Garnix CI](#garnix-ci)
- [Binary Cache Setup](#binary-cache-setup)
- [CI Workflow Template](#ci-workflow-template)

---

## GitHub Actions with Nix

### Nix Installer

Use DeterminateSystems/nix-installer-action for reliable Nix setup in CI:

```yaml
- uses: DeterminateSystems/nix-installer-action@main
```

Configures Nix with flakes enabled, sets up `/nix/store`, and handles platform differences automatically. It installs **Determinate Nix** by default (Linux x86_64/aarch64, macOS aarch64). Upstream Nix needs `with: { determinate: false }`, which Determinate Systems calls unsupported and may remove. The action always uses the newest installer even when pinned; to pin a Determinate Nix version use `DeterminateSystems/determinate-nix-action@v3` (or an exact tag such as `@v3.23.1`).

For upstream Nix, use `cachix/install-nix-action@v31` (supports `extra_nix_config`, `nix_path`, `install_url`, `github_access_token`):

```yaml
- uses: cachix/install-nix-action@v31
  with:
    github_access_token: ${{ secrets.GITHUB_TOKEN }}
```

### Caching

**magic-nix-cache-action** -- zero-config, free binary caching for GitHub Actions:

```yaml
- uses: DeterminateSystems/magic-nix-cache-action@main
```

Automatically caches `/nix/store` paths using GitHub Actions cache backend. No Cachix account or signing keys needed. Still maintained (v15, 2026). The cache is CI-only and subject to GitHub Actions cache rate limits (HTTP 429 shows up in logs but does not fail the job). For a cache shared with developer machines, Determinate's paid option is `DeterminateSystems/flakehub-cache-action@v3` (needs `permissions: id-token: write`, used with `determinate-nix-action`).

### cache-nix-action

A GitHub Action for caching Nix store paths using GitHub Actions cache backend. More configurable than magic-nix-cache:

```yaml
- uses: nix-community/cache-nix-action@v7
  with:
    primary-key: nix-${{ runner.os }}-${{ hashFiles('**/*.nix', '**/flake.lock') }}
    restore-prefixes-first-match: nix-${{ runner.os }}-
    gc-max-store-size-linux: 1G  # suffixes K, M, G accepted
    # Also supports purge, merge caches across jobs, and custom cache URLs
```

Compatible with `nixbuild/nix-quick-install-action`, `cachix/install-nix-action`, and `DeterminateSystems/determinate-nix-action` (not listed: `nix-installer-action`). v7 caches only `/nix` by default and adds `ca-derivations` support.

---

## nix-github-actions (CI Matrix Generator)

A library to turn Nix flake attribute sets into GitHub Actions matrices — generates per-system build jobs from your `packages` or `checks` outputs.

### Integration

```nix
{
  inputs.nix-github-actions.url = "github:nix-community/nix-github-actions";
  inputs.nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, nix-github-actions }: {
    # Generate a matrix from your checks (or `checks = self.packages;`)
    githubActions = nix-github-actions.lib.mkGithubMatrix {
      inherit (self) checks;
    };

    packages.x86_64-linux.default = /* ... */;
    checks.x86_64-linux.default = /* ... */;
  };
}
```

### Restricting Systems

The default runner map is `x86_64-linux` to `ubuntu-24.04`, `aarch64-linux` to `ubuntu-24.04-arm`, `aarch64-darwin` to `macos-14`, and `x86_64-darwin` to `macos-13`. GitHub retired the `macos-13` image on 2025-12-04 and Nixpkgs 26.05 is the last release supporting x86_64-darwin, so drop that system (or override `platforms`, e.g. with `macos-15-intel`):

```nix
githubActions = nix-github-actions.lib.mkGithubMatrix {
  checks = nixpkgs.lib.getAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] self.checks;
};
```

Each matrix entry has `name`, `system`, `os` (a list) and `attr` (prefixed `githubActions.checks.`).

### CI Workflow Template

Combine nix-github-actions with the Nix installer for a full CI setup:

```yaml
name: Nix CI
on: [push, pull_request]

jobs:
  matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v6
      - uses: cachix/install-nix-action@v31
      - name: Generate matrix
        id: set-matrix
        run: |
          echo "matrix=$(nix eval --json .#githubActions.matrix)" >> "$GITHUB_OUTPUT"

  build:
    name: ${{ matrix.name }} (${{ matrix.system }})
    needs: matrix
    strategy:
      matrix: ${{ fromJson(needs.matrix.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v6
      - uses: cachix/install-nix-action@v31
      - uses: nix-community/cache-nix-action@v7
        with:
          primary-key: nix-${{ matrix.system }}-${{ hashFiles('**/*.nix', '**/flake.lock') }}
          restore-prefixes-first-match: nix-${{ matrix.system }}-
      - run: nix build -L '.#${{ matrix.attr }}'
```

### Complete basic workflow

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Format check
        run: nix fmt -- --ci   # treefmt-based formatter (nixfmt-tree / treefmt-nix)

      - name: Lint
        run: |
          nix develop --command statix check .
          nix develop --command deadnix --fail .

      - name: Build
        run: nix build

      - name: Test
        run: nix flake check
```

### Faster flake CI (nix-fast-build)

`nix-fast-build` (Mic92, 2.x) evaluates with `nix-eval-jobs` in parallel and starts each build as soon as its attribute is evaluated. By default it evaluates `.#checks` for all systems and builds `.#checks.<current system>`. It renders logs itself (no nom dependency) and writes a GitHub Actions job summary.

```yaml
- run: nix run nixpkgs#nix-fast-build -- --skip-cached
```

- `--skip-cached`: skip attributes already in a binary cache (avoids downloading unchanged outputs on ephemeral runners)
- `--systems "aarch64-linux x86_64-linux"`: build more than the current system (needs matching builders)
- `--flake .#checks.x86_64-linux`: pick another attribute root (full path required)
- `--remote user@host`: upload the flake and evaluate/build on a remote machine
- `--file ./release.nix -A attr`: non-flake mode

`nix-eval-jobs` (now `NixOS/nix-eval-jobs`, versioned with Nix, e.g. v2.35.x) is the underlying parallel evaluator with streaming JSON output, also used by Hydra-style setups.

---

## Garnix CI

### What it is

Garnix is a Nix-native CI service. It evaluates your flake outputs and builds them on Garnix infrastructure. Faster than GitHub Actions for Nix workloads because builds run on dedicated Nix-optimized runners with persistent caches.

### garnix.yaml configuration

Place at repo root:

```yaml
builds:
  include:
    - "packages.*.*"
    - "checks.*.*"
    - "devShells.*.*"
  exclude:
    - "packages.aarch64-darwin.*"   # skip if no ARM runners needed
```

Without a `garnix.yaml`, Garnix builds `*.x86_64-linux.*`, `defaultPackage.x86_64-linux`, `devShell.x86_64-linux`, and all `homeConfigurations`, `darwinConfigurations` and `nixosConfigurations`.

Branch filtering uses a `branch` key next to `include`/`exclude`. `builds` may also be a list; Garnix builds the union of all entries:

```yaml
builds:
  - include:
      - "packages.*.*"
    branch: main
  - include:
      - "checks.*.*"
```

No runner configuration needed -- Garnix provides the infrastructure.

### Cache setup

Add Garnix as a trusted substituter in your flake.nix or NixOS config:

```nix
nix.settings = {
  substituters = [ "https://cache.garnix.io" ];
  trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
};
```

On developer machines, add to `~/.config/nix/nix.conf`:

```
extra-substituters = https://cache.garnix.io
extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=
```

---

## Binary Cache Setup

### Cachix

Hosted binary cache service. Push build results to share with CI and team:

```bash
# Push a build result
cachix push mycache ./result

# Push all current store paths (useful after CI build)
nix path-info --all | cachix push mycache

# Configure a machine to use the cache
cachix use mycache
```

`cachix use` adds the substituter and public key to your Nix config automatically.

### Self-hosted Attic

Multi-tenant binary cache with S3 backend. Suitable for orgs that need private caches:

```bash
# Push to an Attic cache
attic push myserver:mycache ./result

# Watch and push store paths as they are built
attic watch-store myserver:mycache
```

Attic supports S3-compatible storage (AWS S3, MinIO, R2) as its backend and handles garbage collection, access control, and deduplication.

### NixOS configuration for trusted substituters

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://mycache.cachix.org"
    "https://attic.example.com/mycache"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "mycache.cachix.org-1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  ];
};
```

---

## CI Workflow Template

Complete GitHub Actions workflow with format check, lint, build, and test across multiple systems.

```yaml
name: Nix CI
on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Format check (treefmt / nixfmt)
        run: nix fmt -- --ci

      - name: statix
        run: nix develop --command statix check .

      - name: deadnix
        run: nix develop --command deadnix --fail .

  build:
    needs: lint
    strategy:
      matrix:
        system:
          - runs-on: ubuntu-latest
            nix-system: x86_64-linux
          - runs-on: ubuntu-24.04-arm
            nix-system: aarch64-linux
      fail-fast: false
    runs-on: ${{ matrix.system.runs-on }}
    steps:
      - uses: actions/checkout@v6
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Build
        run: nix build .#packages.${{ matrix.system.nix-system }}.default

      - name: Flake check
        run: nix flake check

  test:
    needs: build
    strategy:
      matrix:
        system:
          - runs-on: ubuntu-latest
            nix-system: x86_64-linux
          - runs-on: ubuntu-24.04-arm
            nix-system: aarch64-linux
      fail-fast: false
    runs-on: ${{ matrix.system.runs-on }}
    steps:
      - uses: actions/checkout@v6
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Run checks
        run: nix build .#checks.${{ matrix.system.nix-system }} --no-link

      - name: Integration tests
        run: nix develop --command just test
```
