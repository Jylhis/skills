# Flake Input Fetching, Offline Evaluation, and Restricted Networks

Why flake evaluation contacts GitHub while channels never do, what the
local caches actually short-circuit, and the supported workflows for
air-gapped or egress-filtered environments (CI sandboxes, agent
sessions behind an allowlisting proxy).

## Why Flakes Fetch From GitHub

A flake input names its own origin host. `github:NixOS/nixpkgs` is an
instruction to fetch that exact revision from github.com; there is no
central distribution point to fall back to. Stock Nix materializes
every input from its origin at evaluation time (the eager, serial
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

## narHash: Designed for Substitution, Not Yet Used for It

`flake.lock` stores a `narHash` per input (SRI SHA-256 of the NAR
serialization of the source tree). Per RFC 0049 and the Nix manual,
its purpose is to let flake inputs be substituted from a binary cache:
narHash determines the store path, the other locked attributes carry
what the store path cannot.

The catch: stock Nix does **not** automatically fall back to remote
substituters for inputs at evaluation time. The feature request
(NixOS/nix#3253, filed by Dolstra in 2019) is still open. What does
exist is a local short-circuit: an input already present in the local
store or fetcher cache by narHash is not re-fetched.

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
  pre-seeded store path and never touches the network.
- `builtins.fetchTree`'s `github` fetcher does **not** short-circuit
  on store contents alone; it re-downloads by URL unless its own
  fetcher cache is warm.

Practical consequence: a flake-compat `default.nix` that fetches
flake-compat via `fetchTarball { sha256 = narHash; }` works offline
once pre-seeded, while the same input resolved through the flake CLI's
`fetchTree` path may still require GitHub egress on a cold cache.

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

## In-Flight Changes (Nothing Stock Yet)

Eager eval-time fetching is a known pain point (slow for flakes with
many inputs). Two mechanisms relax it, neither stock default:

- **Determinate Nix build-time inputs** (3.9.0+, experimental):
  `build-time-fetch-tree` + `buildTime = true` per input defers the
  origin fetch until a dependent derivation builds. Per-input opt-in;
  it is *not* an eval-offline guarantee.
- **`builtins.fetchFinalTree`** (draft PR NixOS/nix#14634): allows
  substitution from binary caches when narHash is in the input
  attributes, the likely path to closing #3253.

This landscape is moving (lazy trees are also opt-in); re-verify
current behavior before relying on any of it.

## Decision Table for Restricted Networks

| Situation | Approach |
|---|---|
| One-off build, cache-reachable inputs | Pre-seed by narHash from substituters |
| Recurring CI/agent sessions | `nix flake archive --to <substituter>` from a connected pipeline |
| Fully air-gapped | `nix flake archive --to file:///...` and physically transfer |
| Non-flake entry point (flake-compat) | Ensure it uses `fetchTarball` + narHash, which short-circuits; `fetchTree` paths may not |
| "Just allowlist the proxy" | Needs github.com, api.github.com, and codeload.github.com |

## Sources

- Nix manual, `nix3-flake` and `nix3-flake-archive` pages
- RFC 0049 (flakes), <https://github.com/tweag/rfcs/blob/flakes/rfcs/0049-flakes.md>
- NixOS/nix#3253 (input substitution, open), NixOS/nix#14634
  (fetchFinalTree, draft), NixOS/nix#9570 (eager fetch cost)
- Determinate Systems changelog (Determinate Nix 3.9.0)
