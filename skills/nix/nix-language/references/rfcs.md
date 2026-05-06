# NixOS RFCs — Reference

RFCs are the mechanism for substantial changes to Nix, Nixpkgs, NixOS, and their ecosystem. Source: <https://github.com/NixOS/rfcs>.

This file is cross-referenced from **nix-language**, **nixpkgs**, **flakes**, **nixos-modules**, **nix-testing**, **nix-containers**, **nix-linting**, **nix-debugging**, and **nix-performance**. Only technical takeaways relevant to writing Nix today are summarized here; governance-only RFCs are listed at the bottom for completeness.

## Language and Tooling

### RFC 4 — Replace Unicode Quotes
Nix error output quotes paths and strings with ASCII `'...'` and `"..."` (not curly `‘ ’`). Match on ASCII quotes when scripting against Nix diagnostic output. Implemented.

### RFC 45 — Deprecate Unquoted URL Literals
`url = https://example.com;` is deprecated; always write `url = "https://example.com";`. statix flags unquoted URLs via the `unquoted_uri` lint. Accepted; Nix 2.x emits deprecation warnings, removal pending.

### RFC 134 — Nix Store Layer
Nix is architecturally layered: store → fetchers → expression language → flakes. Use these terms precisely — "Nix store" (paths, daemon, substituters) is independent of "Nix language". Accepted; implementation in progress (`libnixstore` as separable component).

### RFC 136 — Stabilize Incrementally
The new `nix` CLI stabilizes layer-by-layer, separately from flakes. `nix build`/`nix run`/`nix develop` remain under `experimental-features = nix-command flakes` and may still change. Use `nix-build`/`nix-shell` in portable scripts that must work without experimental features enabled.

### RFC 145 — Doc Comments
Document Nix functions with `/** ... */` (double-asterisk opening) containing CommonMark; reserve `#` and `/* */` for implementation comments. This syntax is parsed by `nixdoc` and LSP tooling for hover tooltips. Accepted.

```nix
/**
  Compute the sum of two numbers.

  # Example
  ```
  add 1 2
  => 3
  ```

  # Type
  ```
  add :: Number -> Number -> Number
  ```
*/
add = a: b: a + b;
```

### RFC 166 — Standard Nix Format
`nixfmt` (the RFC-166 variant, packaged as `pkgs.nixfmt` since nixpkgs 25.05; `pkgs.nixfmt-rfc-style` is a deprecated alias; the old formatter is `pkgs.nixfmt-classic`) is the canonical Nix formatter. All of Nixpkgs is reformatted with it. Do not recommend `nixpkgs-fmt` or `alejandra` for new code. Implemented.

## Nix CLI and Store Internals

### RFC 62 — Content-Addressed Paths
Opt-in content-addressed store paths via `__contentAddressed = true` plus `experimental-features = ca-derivations`. Downstream rebuilds are skipped when a derivation's output is byte-identical to the previous build (early cutoff). Experimental.

### RFC 92 — Plan Dynamism (Dynamic Derivations)
`builtins.outputOf` plus dynamic derivations (whose output is itself a `.drv`) replace `import-from-derivation` hacks for 2nix / generated-expression workflows. Guarded by `experimental-features = dynamic-derivations`. Experimental but the intended direction.

### RFC 97 — No Read-Store-Dir Permissions Enforcement
Default `/nix/store` mode is `1735`: the `nixbld` group cannot list the store. Scripts must not assume read access. NixOS exposes the store permissions as a configurable module option. Implemented.

### RFC 106 — Nix Release Schedule
Nix (the tool) releases every 6 weeks with a green `master` policy. Expect new experimental features to appear frequently. Pin Nix via `nix.package` or flake inputs when determinism matters. Implemented.

### RFC 132 — Meson Builds Nix
Nix itself is built with Meson + Ninja since Nix 2.22. When bisecting or building Nix from source, use `meson setup build && ninja -C build`, not `./configure && make`. Implemented.

### RFC 133 — Git Hashing
Native git blob/tree hashing as a Nix content-addressing scheme, enabling interop with Software Heritage and Git-native fetching without tarball canonicalization issues. Accepted; partially implemented behind experimental flag.

## Nixpkgs Contribution Workflow

### RFC 23 — Musl libc
`pkgsMusl` and `*-unknown-linux-musl` targets exist alongside glibc. Best-effort, not parity — many packages need patches to cross-compile to musl. Implemented.

### RFC 26 — Staging Workflow
Three-branch Nixpkgs workflow: `master` (small changes), `staging-next` (stabilization), `staging` (mass rebuilds). When writing or reviewing a Nixpkgs PR, pick the base branch by rebuild count, not habit. Implemented.

### RFC 32 — Phase Hooks in `nix-shell`
Stdenv phase functions work when invoked directly inside `nix-shell` (`buildPhase`, `configurePhase`, etc. — no `eval "$buildPhase"` needed). Pre/post hooks still run even when a phase is overridden, so `overrideAttrs` appending to `postBuild` is reliable. Implemented.

### RFC 46 — Platform Support Tiers
Nixpkgs platforms are organized into tiers (Tier 1 = x86_64-linux, aarch64-linux with full CI and binary cache; lower tiers = best-effort). Don't assume binary substitutes exist for non-Tier-1 platforms. Implemented.

### RFC 80 — NixOS Release Schedule
NixOS releases are YY.05 (May) and YY.11 (November), aligned with GNOME/KDE cycles. Each release is supported roughly one cycle after its successor ships. Implemented since 21.05.

### RFC 85 — Release Stabilization (ZHF)
Around release branch-off, breaking changes to Release Critical Packages (kernel, systemd, glibc, desktop envs) are restricted during Zero Hydra Failures. Land risky work earlier in the cycle. Most stabilization happens on `master`, not via backporting. Implemented.

### RFC 88 — Nixpkgs Breaking Change Policy
When changing a library with dependents, either fix all dependents in the same PR or land on `staging` with notice; never knowingly merge a break to `master` that would stall the channel. Implemented.

### RFC 89 — `meta.sourceProvenance`
Any Nixpkgs derivation pulling prebuilt binaries must set `meta.sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];` (or `binaryBytecode`, `binaryFirmware`). Users can opt out of non-source packages via `config.allowNonSource = false`. Fully-source packages can omit the field. Implemented.

### RFC 119 — Testing Conventions (`passthru.tests`)
Package tests live in two places:

- `doCheck = true` + `checkPhase` — fast in-build tests that run during build
- `passthru.tests = { foo = nixosTests.foo; bar = ...; }` — slow / integration / VM / downstream tests that `nixpkgs-review` and CI pick up automatically

Use `passthru.tests` for VM tests (`nixosTests.<name>`) and cross-package smoke tests. Implemented.

### RFC 127 — Unified `meta.problems`
Replaces the patchwork of `meta.broken` / `meta.insecure` / `meta.knownVulnerabilities` / `allowUnfree` flags with a unified problems/handlers/matchers pipeline. New packages should still set the existing fields (migration is gradual) but be aware of the direction. Accepted; implementation in progress.

### RFC 140 — `pkgs/by-name`
New leaf packages go in `pkgs/by-name/<two-letter-shard>/<pname>/package.nix` with a plain `callPackage` signature. Auto-wired into `all-packages.nix` — do not edit `all-packages.nix` for new additions. Only packages needing args beyond defaults still live outside `by-name`. Implemented.

```
pkgs/by-name/
├── he/
│   └── hello/
│       └── package.nix
└── ri/
    └── ripgrep/
        └── package.nix
```

### RFC 146 — `meta.categories`
Package categorization moves from filesystem directory structure to explicit `meta.categories = [ ... ]` tags. Multivalued and decoupled from file layout — with `pkgs/by-name` (RFC 140), directory paths no longer carry category meaning. Accepted.

### RFC 180 — Broken Package Auto-Removal
Packages marked `broken = true` on all platforms, or left with empty `meta.maintainers` and no dependents, are automatically removed one full NixOS release cycle after being flagged (e.g. broken in 23.11 → removed after 24.05). Don't fight this by unmarking without a fix. Accepted.

## NixOS Modules

### RFC 42 — `settings` Over `extraConfig`
Deprecates stringly-typed `extraConfig` options in favor of structured `settings` attrsets generated via `pkgs.formats.<format>.generate`:

```nix
{
  options.services.foo.settings = lib.mkOption {
    type = (pkgs.formats.toml { }).type;
    default = { };
  };
  config = lib.mkIf cfg.enable {
    environment.etc."foo.toml".source =
      (pkgs.formats.toml { }).generate "foo.toml" cfg.settings;
  };
}
```

Also discourages shadowing every upstream key with its own NixOS option — lean on `freeformType` instead. Canonical pattern for all new modules. Implemented.

### RFC 52 — Dynamic IDs
Don't hardcode uid/gid in `ids.nix` for new NixOS services. Use `users.users.<name>.isSystemUser = true` (NixOS auto-assigns a persistent id) or set `serviceConfig.DynamicUser = true` (ephemeral per-invocation id) for services with no persistent on-disk state. Implemented.

### RFC 72 — CommonMark Docs
NixOS option `description` and Nixpkgs doc sources are CommonMark (Markdown), not DocBook. `lib.mdDoc` is historical — CommonMark is now the default; do not add DocBook `<para>`/`<literal>`/`<xref>` markup. Implemented.

### RFC 108 — NixOS Containers (systemd-nspawn rewrite)
The NixOS `containers.<name> = { ... };` subsystem is migrating from the legacy `nixos-container` tooling to `systemd-nspawn` + `systemd-networkd`. This is distinct from `dockerTools` OCI images — they share the word "container" but solve different problems. Partially implemented.

### RFC 125 — Bootspec
Every NixOS generation emits a stable JSON schema at `/nix/store/.../boot.json` describing kernel, initrd, cmdline, and metadata. Bootloader integrations should parse bootspec rather than globbing `/boot`. When writing custom bootloader modules or initrd tooling, consume bootspec. Implemented.

## Governance / Process (no direct code takeaway)

Listed for completeness; these don't affect Nix code you write:

- RFC 1 — RFC Process
- RFC 15 — Release Manager role
- RFC 25 / 44 — Nix Core Team (created, then disbanded)
- RFC 36 — RFC Steering Committee + Shepherd Teams
- RFC 39 — Nixpkgs Maintainers read-only team
- RFC 43 — RFCSC rotation rules
- RFC 51 / 124 — Stale-bot on Nixpkgs and Nix (mark, don't close)
- RFC 55 / 71 — Retired committer policy
- RFC 94 — Official chat on Matrix
- RFC 102 — Moderation Team
- RFC 130 — Stalled / Lacking Interest RFC states

## Notable Open RFCs (as of 2026-04)

Worth tracking because they may land soon:

- RFC 148 — Pipe operator (`|>`) in the Nix language
- RFC 181 — List index syntax
- RFC 190 — Ban `with` expression in Nixpkgs
- RFC 197 — `pkgs/by-name` for package sets
- RFC 194 — Flake Entrypoint
- RFC 193 — TOML Flakes
- RFC 192 — Version pins for `pkgs/by-name`
- RFC 191 — Lockfile Generation

Check <https://github.com/NixOS/rfcs/pulls?q=is%3Apr+%22RFC+%22> for the live set.
