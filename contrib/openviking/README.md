# OpenViking `ov` CLI — Nix package

[OpenViking](https://openviking.ai) (`volcengine/OpenViking`) is a context
filesystem for AI agents. Its command-line client is the Rust binary **`ov`**
(crate `crates/ov_cli`). OpenViking is **not in nixpkgs**, and the upstream
`openviking.ai/#connect` install script has been deprecated (it now points at
`npm i -g @openviking/cli`). This directory packages `ov` for Nix instead.

## Install locally

With [Nix](https://nixos.org) and flakes enabled:

```bash
# from a checkout of this repo
./contrib/openviking/install.sh
# or, equivalently
nix profile install ./contrib/openviking#openviking
```

Run it without installing:

```bash
nix run ./contrib/openviking#ov -- --help
```

Verify:

```bash
ov --version   # -> 0.3.24
```

## What it builds

`package.nix` builds the `ov_cli` crate from source with
`rustPlatform.buildRustPackage`, pinned to the upstream tag `cli@0.3.24`:

- Workspace-aware: `buildAndTestSubdir = "crates/ov_cli"`, so the pyo3
  `ragfs-python` member is never built.
- `env.OPENVIKING_VERSION` is set so `ov --version` reports the real version
  (the crate's `build.rs` reads it; the default would be `0.0.0`).
- `reqwest` uses `rustls-tls` (no OpenSSL); `cmake` is the only extra native
  build input (for the aws-lc-rs backend).
- Tests are skipped (`doCheck = false`) — they expect a running OpenViking
  server.

Requires nixpkgs with Rust ≥ 1.91.1 (the crate is edition 2024); current
`nixpkgs-unstable` ships 1.95, so no toolchain overlay is needed.

## Upstreaming to nixpkgs

`package.nix` is a pure `{ lib, rustPlatform, fetchFromGitHub, cmake }`
function written to nixpkgs conventions. To submit it upstream, drop it into
`pkgs/by-name/op/openviking/package.nix` unchanged. Note the binary name `ov`
collides with the existing `ov` pager (`noborus/ov`) in nixpkgs — the package
is named `openviking` with `meta.mainProgram = "ov"`.

## Updating the version

Bump `version` in `package.nix`, then refresh both hashes (set each to
`lib.fakeHash`, run `nix build ./contrib/openviking#openviking`, and paste the
`got:` hash from the error):

1. `src.hash` — the `fetchFromGitHub` tarball.
2. `cargoHash` — the vendored crate dependencies.
