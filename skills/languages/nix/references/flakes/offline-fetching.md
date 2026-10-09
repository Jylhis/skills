# Flake Input Fetching, Offline Evaluation, and Restricted Networks

Why flake evaluation contacts GitHub while channels never do, what the
local caches actually short-circuit, and the supported workflows for
air-gapped or egress-filtered environments (CI sandboxes, agent
sessions behind an allowlisting proxy).

## Why Flakes Fetch From GitHub

A flake input names its own origin host. `github:NixOS/nixpkgs` is an
instruction to fetch that exact revision from github.com; there is no
central distribution point to fall back to. Unless an input is already
in the store or a substituter has it (see below), stock Nix
materializes it from its origin at evaluation time (the eager, serial
fetcher noted under Flake Limitations in `flakes.md`).

The `github:` input type downloads the pinned revision as a tarball
archive from GitHub's endpoints rather than cloning, as a deliberate
optimization (faster, no history). So resolving a `github:` input
means contacting github.com, api.github.com, or codeload.github.com,
never NixOS channel infrastructure.

Channels are the opposite model: a channel is a single URL to a
pre-packed `nixexprs` tarball, and the official channels resolve
entirely through NixOS-run infrastructure (`nixos.org/channels` →
`channels.nixos.org` → `releases.nixos.org`, a CDN over project S3).
GitHub never appears in that path. Two nuances:

- This holds for *official* channels only; a user-defined channel URL
  can point anywhere.
- Flakes were not "designed to replace channels" as a stated goal.
  The contrast is an architectural difference (decentralized
  origin-named inputs vs. centralized tarball distribution), not
  documented intent. Do not frame it as intent.

## narHash and Substitution

`flake.lock` stores a `narHash` per input (SRI SHA-256 of the NAR
serialization of the source tree). Per RFC 0049 and the Nix manual,
its purpose is to let flake inputs be substituted from a binary cache:
narHash determines the store path, the other locked attributes carry
what the store path cannot.

What upstream Nix does (current `Input::getAccessor` in
`src/libfetchers/fetchers.cc`): for a *final* input that has a
narHash, Nix computes the store path and calls `ensurePath` on it,
which succeeds if the path is already in the local store or can be
fetched from a configured substituter. Only if that fails does it go
to the origin. Lock file entries are implicitly final, so locked flake
inputs (evaluated through the internal `fetchFinalTree`) take this
path. This dates back to NixOS/nix#3253 ("Substitute flake inputs",
closed by Dolstra in February 2020); the top-level flake itself is not
substituted. Nix 2.32 fixed substituted inputs being re-copied on
every evaluation (#14041, a regression since 2.25).

The catch in practice:

- Substitution needs a cache that actually holds that `source` store
  path. cache.nixos.org has nixpkgs source trees; most other GitHub
  inputs are in no public cache, so a cold machine still contacts the
  origin.
- A failed substitution is only logged at `--debug` ("substitution of
  input '...' failed"), then Nix silently falls back to the origin.
  When an egress-restricted run unexpectedly hits GitHub, rerun with
  `--debug` and grep for that message.
- User-facing `builtins.fetchTree` calls are *not* final and skip this
  step (see below).

### Pre-Seeding the Store by narHash

Because the store path is computable from narHash, a machine with
binary-cache access (but no GitHub access) can pre-seed locked inputs
from its configured substituters:

```bash
# For each input in flake.lock with narHash "sha256-...":
nix-store --realise "$(nix-store --print-fixed-path --recursive sha256 <narHash> source)"
```

nixpkgs source trees are substitutable from cache.nixos.org, and
nix-community flake inputs (e.g. emacs-overlay, flake-compat) from
nix-community.cachix.org. With the store pre-seeded this way, the
flake CLI (`nix build`, `nix flake check` builds) evaluates fully
offline via the short-circuit.

### fetchTarball vs. fetchTree Asymmetry

The short-circuit is not uniform across fetchers:

- `builtins.fetchTarball` with a `sha256` short-circuits on a
  pre-seeded store path and never touches the network. Since Nix 2.32
  (#14138) it, `builtins.fetchurl`, and `fetchTree { type = "tarball"; }`
  with a narHash are also substituted from binary caches before
  downloading.
- A user-facing `builtins.fetchTree` call with the `github` type is
  not final, so it does **not** short-circuit on store contents alone;
  it re-downloads by URL unless its own fetcher cache is warm. The
  draft NixOS/nix#14634 would expose `builtins.fetchFinalTree` to fix
  this.
- Locked inputs evaluated by the flake CLI are final and do
  short-circuit (previous section).

Practical consequence for flake-compat: the bootstrap
`fetchTarball { sha256 = narHash; }` in `default.nix` works offline
once pre-seeded. flake-compat then fetches the remaining inputs with
`builtins.fetchTree` *if it exists* (that is, when `flakes` or
`fetch-tree` is enabled) and otherwise falls back to `fetchTarball`
with `sha256 = narHash`. So the non-flake path with flakes disabled is
the offline-friendly one; with flakes enabled, flake-compat's
`fetchTree` calls may still need GitHub egress on a cold cache.
NixOS/flake-compat#79 (open) switches it to `fetchFinalTree` once Nix
ships that builtin.

### Fetcher Cache Anatomy

A successful `github:` fetch records rows (`gitRevToTreeHash`,
`gitRevToLastModified`, `sourcePathToHash`) in
`~/.cache/nix/fetcher-cache-v4.sqlite` plus the tree in the bare-git
`~/.cache/nix/tarball-cache-v2`. A warm fetcher cache short-circuits
`github:` inputs without network access, but it is per-user,
TTL-influenced (`tarball-ttl`), and not a supported offline mechanism.
Treat it as an optimization, not a strategy.

## Supported Workflow: nix flake archive

The documented restricted-network workflow is `nix flake archive`: it
copies a flake and all its locked inputs into a store or binary cache,
so a connected machine pre-fetches and ships them to the restricted
one.

```bash
# On a machine with GitHub access:
nix flake archive --to file:///mnt/usb/nix-store   # or ssh://host, s3://..., https://cache...

# On the restricted machine, once inputs are in the store,
# evaluation proceeds without contacting origins.
```

For proxy-restricted CI/agent environments, `nix flake archive --to
<your-cachix-or-substituter>` run from CI covers inputs missing from
public caches, and is often cleaner long-term than allowlisting
GitHub hosts or maintaining a per-input narHash prefetch script.

## In-Flight Changes

Eager eval-time fetching is a known pain point (slow for flakes with
many inputs). What has landed upstream:

- **`nix flake prefetch-inputs`** (Nix 2.31+) fetches all inputs in
  parallel; useful as a warm-up step in CI before an egress window
  closes.
- **Lazier copying** (Nix 2.35): flake inputs and `fetchTarball`
  results are NAR-hashed without being copied to the store first; the
  copy happens only if `outPath` reaches a derivation. The whole tree
  is still read and hashed, so this saves disk and time, not network.

Not stock defaults:

- **Determinate Nix build-time inputs** (3.9.0+, experimental):
  `build-time-fetch-tree` + `buildTime = true` per input defers the
  origin fetch until a dependent derivation builds. Per-input opt-in;
  it is *not* an eval-offline guarantee. Determinate's lazy trees are
  likewise Determinate-specific.
- **`builtins.fetchFinalTree`** (draft PR NixOS/nix#14634): exposes
  the final-input fetch to user code, so `fetchTree`-style calls with
  a narHash (flake-compat, hand-written pins) can be substituted.

Non-flake pinners that use Nixpkgs fetchers at build time (npins with
`{ inherit pkgs; }`, Nixtamal `fetch-time build`) produce fixed-output
derivations, which substitute like any other build output; see
`../pinning.md`.

This landscape is moving; re-verify current behavior before relying
on any of it.

## Decision Table for Restricted Networks

| Situation | Approach |
|---|---|
| One-off build, cache-reachable inputs | Pre-seed by narHash from substituters |
| Recurring CI/agent sessions | `nix flake archive --to <substituter>` from a connected pipeline |
| Fully air-gapped | `nix flake archive --to file:///...` and physically transfer |
| Non-flake entry point (flake-compat) | Bootstrap with `fetchTarball` + narHash; run without `flakes`/`fetch-tree` enabled so flake-compat also falls back to `fetchTarball`; `fetchTree` paths may not short-circuit |
| Unexpected origin egress despite cached inputs | Rerun with `--debug`, look for "substitution of input ... failed" |
| "Just allowlist the proxy" | Needs github.com, api.github.com, and codeload.github.com |

## Sources

- Nix manual, `nix3-flake` and `nix3-flake-archive` pages
- RFC 0049 (flakes), <https://github.com/tweag/rfcs/blob/flakes/rfcs/0049-flakes.md>
- NixOS/nix#3253 (input substitution, closed 2020 by commit
  94a94da), NixOS/nix#14634 (fetchFinalTree, draft),
  NixOS/nix#9570 (eager fetch cost), NixOS/nix#14041 and #14138
  (Nix 2.32 release notes)
- Nix source, `src/libfetchers/fetchers.cc` (`Input::getAccessor`)
  and `src/libflake/lockfile.cc` (lock entries implicitly final)
- Nix 2.31 and 2.35 release notes (`prefetch-inputs`, lazier copying)
- NixOS/flake-compat `default.nix` and PR #79
- Determinate Systems changelog (Determinate Nix 3.9.0)
