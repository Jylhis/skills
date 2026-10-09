# Nix Ecosystem Tools

Community tools from nix-community and related orgs that extend the Nix
development experience — search, documentation, language servers,
library aggregation, platform-specific packaging, and more.

## Search and Documentation

### noogle (Nix API Search)

A web-based search engine for Nix functions. Indexes `builtins`, `nixpkgs.lib`,
and related function documentation. Always reflects the latest nixpkgs main
branch.

- URL: <https://noogle.dev>
- Search by function name, type signature, or description
- Detects aliases of `lib` and `builtins` functions
- Shows type signatures parsed and interpreted from source

Use when you need to find a `lib.*` function by behavior but can't recall
the exact name. Faster than grepping nixpkgs source.

### manix (CLI Documentation Searcher)

A fast CLI tool that searches across multiple Nix documentation sources
simultaneously: Nixpkgs documentation, Nixpkgs comments, the Nixpkgs
tree (pkgs, pkgs.lib), NixOS options, nix-darwin options, and Home
Manager options.

```bash
# Basic search
manix mergeattr

# Strict matching
manix --strict mergeattr

# Update the search cache
manix --update-cache mergeattr

# Use with fzf for interactive search
manix "" | sed -n 's/^# \(.*\) \?.*/\1/p' | fzf --preview="manix '{}'" | xargs manix
```

Still maintained (nix-community, v0.9.0 in 2026, new maintainers). Install
via nixpkgs: `nix profile add nixpkgs#manix` (`nix profile install` is the
pre-2.30 name, kept as an alias) or add to `environment.systemPackages`.

### nixdoc (Library Documentation Generator)

A tool that generates reference documentation for Nix library functions
defined in Nixpkgs' `lib`. It parses Nix source files using `rnix-parser`
and transforms them into CommonMark documentation.

It implements the doc-comment standard from RFC 145 — only `/** ... */`
(double-asterisk) comments are parsed as documentation. Single-star
`/* */` and `#` are implementation comments.

```bash
# Generate documentation for a lib file
nixdoc --file lib.nix --category "strings" --description "String utilities" > strings.md

# Export mode for external consumers
nixdoc --manifest manifest.json --root /path/to/nixpkgs --output functions-export.json
```

Export mode (`--manifest`, new in v3.2.0) emits one JSON file of RFC 145
doc-comments that is independent of the Nixpkgs manual pipeline.

Use nixdoc when contributing to nixpkgs `lib` — it verifies your doc
comments render correctly.

## Language Server (nixd)

### nixd — Feature-Rich Nix Language Server

A language server for Nix that interoperates with the C++ Nix evaluator
(nix-community, 2.9.x in 2026). Notable features:

- Nixpkgs option support (NixOS, home-manager, flake-parts)
- Nixpkgs package completion (lazily evaluated)
- Shared eval caches with your system's Nix (flake, file)
- Cross-file analysis (goto definition into nixpkgs locations)

### Configuration

nixd 2.x is configured through the LSP `workspace/configuration` request,
under a `nixd` key in your editor's LSP settings. The v1 `.nixd.json` file is
no longer read; delete it. Without configuration, packages come from
`import <nixpkgs> { }` and NixOS options from `<nixpkgs>`, so flake users
should either set `nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];` or give
explicit expressions:

```json
{
  "nixd": {
    "nixpkgs": {
      "expr": "import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }"
    },
    "formatting": {
      "command": ["nixfmt"]
    },
    "options": {
      "nixos": {
        "expr": "(builtins.getFlake (toString ./.)).nixosConfigurations.myhost.options"
      },
      "home_manager": {
        "expr": "(builtins.getFlake (toString ./.)).homeConfigurations.\"me@myhost\".options"
      }
    }
  }
}
```

In VS Code this object goes under `nix.serverSettings`; in Neovim under
`settings` of `vim.lsp.config("nixd", ...)`; with Eglot via
`eglot-workspace-configuration` in `.dir-locals.el`.

### Integration

- **devenv**: `devenv lsp` launches nixd configured for the project
- **Neovim**: use nvim-lspconfig with `nixd` server
- **VS Code**: use nixd extension
- **Emacs**: use lsp-mode or eglot with `nixd`

### Comparison with nil and nix-language-server

nixd links against the C++ Nix library, giving it access to the real
evaluator for completions and option lookups; its own parser and static
analysis live in `libnixf` (also exposed as `nixf-tidy`, wrapped by the
`nixf-diagnose` git hook). nil (oxalica, still actively released) uses its
own rowan-based parser and does incremental static analysis; it shells out
to the `nix` binary only for flake work (`nix flake archive`, optional
evaluation of inputs and NixOS options). The old rnix-lsp is archived.
nixd is the current reference LSP for Nix; nil is the lighter option.

## Parser (rnix-parser)

### rnix-parser — Rust Nix Parser

A parser for the Nix language written in Rust. Uses the `rowan` crate
for lossless AST representation — all span information (whitespace,
comments) is preserved, and the AST can be printed back to 100%
identical source.

Used by: statix, deadnix, nixdoc, and other Nix tooling (and the archived
nixpkgs-fmt). nil and nixd have their own parsers. Current release: v0.14.0
(2026).

```bash
# Parse from stdin
echo "[hello nix]" | nix run github:nix-community/rnix-parser --example from-stdin
```

Not typically used directly — it's a library that other tools build on.
Understanding it helps when a tool reports a parse error: the error
message format comes from rnix-parser.

## Library Aggregation

### lib-aggregate

A flake that aggregates pure Nix libraries which do not depend on
nixpkgs. Its `lib` output is `nixpkgs.lib` (via nixpkgs.lib, the cheap
fork) with flake-utils merged in as `lib.flake-utils`.

```nix
{
  inputs.lib-aggregate.url = "github:nix-community/lib-aggregate";
  # lib-aggregate inputs.nixpkgs-lib follows nixpkgs.lib
  outputs = { lib-aggregate, ... }: {
    # Access aggregated lib
    lib = lib-aggregate.lib;
  };
}
```

Use when your flake provides a library (not packages) and wants to
extend `nixpkgs.lib` with additional pure functions.

### nixpkgs.lib

A cheap, continuously rebased fork of `nixpkgs.lib` — the `lib`
attribute of nixpkgs without the rest of nixpkgs. This allows consuming
`lib` without evaluating the entire package set.

```nix
{
  inputs.nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
  outputs = { nixpkgs-lib, ... }: {
    lib = nixpkgs-lib.lib;
  };
}
```

Use `nixpkgs.lib` as a lightweight dependency when you only need `lib`
functions (lists, attrsets, strings) but not the full nixpkgs package
set. Faster to fetch and evaluate than full nixpkgs.

## Platform-Specific Packaging

### nixpkgs-wayland

Automated, pre-built packages for Wayland (sway/wlroots) tools on
nixos-unstable. Packages are auto-updated to the latest upstream commits
— often containing unreleased versions.

```nix
# flake.nix
{
  inputs.nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";
}
```

```nix
# NixOS module (inputs passed via specialArgs)
{ inputs, pkgs, ... }:
{
  # use it as an overlay ...
  nixpkgs.overlays = [ inputs.nixpkgs-wayland.overlay ];
  # ... or pull single packages, built against nixos-unstable
  environment.systemPackages = [
    inputs.nixpkgs-wayland.packages.${pkgs.stdenv.hostPlatform.system}.wev
  ];
}
```

Use the Cachix binary cache to avoid building from source:

```bash
cachix use nixpkgs-wayland
```

Or in NixOS config:

```nix
nix.settings = {
  substituters = [ "https://nixpkgs-wayland.cachix.org" ];
  trusted-public-keys = [ "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA=" ];
};
```

Packages include: wlroots, sway-unwrapped, swaybg, swaylock, swayidle,
foot, mako, wob, wev, wayvnc, wl-clipboard, xdg-desktop-portal-wlr, and
other Wayland utilities (see the README's package table), often at
versions ahead of nixpkgs unstable.

### nixos-generators (deprecated)

`nix-community/nixos-generators` is archived. Since NixOS 25.05 its image
formats are upstream in nixpkgs as `system.build.images.<variant>`, built
with `nixos-rebuild build-image` (which replaces `nixos-generate`):

```bash
nixos-rebuild build-image --image-variant iso --flake .#myhost
```

```nix
packages.x86_64-linux.myhost-iso =
  self.nixosConfigurations.myhost.config.system.build.images.iso;
```

Most formats map one to one (amazon, azure, gce, hyperv, iso, kexec,
proxmox, qcow, raw-efi, virtualbox, ...). Renamed or folded: `install-iso`
is `iso-installer`; `sd-aarch64*` and `sd-x86_64` become `sd-card` with the
matching `system`; `vm`/`vm-bootloader` are `nixos-rebuild build-vm` /
`build-vm-with-bootloader`. The `docker` format has no upstream variant.

### nix-on-droid

Nix on Android — provides a Nix package manager environment and module
system for Android devices. See `ecosystem/nix-on-droid.md` for the
full reference.

## awesome-nix

A curated list of the best Nix community resources, tools, modules, and
projects. Not a tool itself — use it for discovery.

- URL: <https://github.com/nix-community/awesome-nix>
- Categories: Learning, Discovery, Deployment, Virtualization,
  Command-Line Tools, Development, DevOps, Programming Languages,
  NixOS Modules, Overlays, Distributions

When starting a new Nix project, check awesome-nix for existing
solutions before building from scratch.

## Tool Selection Guide

| Need | Tool |
|------|------|
| Search `lib.*` functions by behavior | noogle (web) or manix (CLI) |
| Search NixOS/home-manager/nix-darwin options | manix |
| Generate `lib` documentation from doc-comments | nixdoc |
| Language server for editor integration | nixd |
| Parse Nix source (for tooling) | rnix-parser (library) |
| Aggregate pure Nix libs | lib-aggregate |
| Lightweight `lib` without full nixpkgs | nixpkgs.lib |
| Latest Wayland packages (ahead of nixpkgs) | nixpkgs-wayland |
| Build NixOS images (ISO, cloud, VM, SD card) | `nixos-rebuild build-image` (nixos-generators is archived) |
| Nix on Android | nix-on-droid |
| Discover Nix ecosystem projects | awesome-nix |

## Related Skills

- **nix-language** — language fundamentals, builtins, lib, doc comments (RFC 145)
- **nix-flakes** — flake structure, inputs, outputs, flake-parts
- **nix-linting** — statix, deadnix, nixfmt, CI pipeline
- **nix-testing** — nixosTest, namaka, nix-unit, nixt
- **nix-debugging** — --show-trace, nix-tree, nix-diff, vulnix
