# CI/CD Pipeline Patterns for Nix Projects

## Table of Contents

- [GitHub Actions with Nix](#github-actions-with-nix)
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

Configures Nix with flakes enabled, sets up `/nix/store`, and handles platform differences automatically.

### Caching

**magic-nix-cache-action** -- zero-config, free binary caching for GitHub Actions:

```yaml
- uses: DeterminateSystems/magic-nix-cache-action@main
```

Automatically caches `/nix/store` paths using GitHub Actions cache backend. No Cachix account or signing keys needed.

**cache-nix-action** -- community alternative with more control:

```yaml
- uses: nix-community/cache-nix-action@v6
  with:
    primary-key: nix-${{ runner.os }}-${{ hashFiles('flake.lock') }}
    restore-prefixes-first-match: nix-${{ runner.os }}-
    gc-max-store-size-linux: 2000000000   # 2 GB limit
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
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Format check
        run: nix fmt -- --check .

      - name: Lint
        run: |
          nix develop --command statix check .
          nix develop --command deadnix --fail .

      - name: Build
        run: nix build

      - name: Test
        run: nix flake check
```

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

# Optional: select specific branches
branches:
  include:
    - main
    - "release/*"
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
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Format check (treefmt / nixfmt)
        run: nix fmt -- --check .

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
      - uses: actions/checkout@v4
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
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Run checks
        run: nix build .#checks.${{ matrix.system.nix-system }} --no-link

      - name: Integration tests
        run: nix develop --command just test
```
