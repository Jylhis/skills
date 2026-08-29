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

Install via nixpkgs: `nix profile install nixpkgs#manix` or add to
`environment.systemPackages`.

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

Use nixdoc when contributing to nixpkgs `lib` — it verifies your doc
comments render correctly.

## Language Server (nixd)

### nixd — Feature-Rich Nix Language Server

A language server for Nix that interoperates with the C++ Nix evaluator.
Notable features:

- Nixpkgs option support (NixOS, home-manager, flake-parts)
- Nixpkgs package completion (lazily evaluated)
- Shared eval caches with your system's Nix (flake, file)
- Cross-file analysis (goto definition into nixpkgs locations)

### Configuration

nixd reads `.nixd.json` or `nixd.json` in the project root:

```json
{
  "eval": {
    "target": {
      "installable": ".#default",
      "args": ["--extra-experimental-features", "nix-command flakes"]
    }
  },
  "formatting": {
    "command": ["nixfmt"]
  },
  "options": {
    "enable": true,
    "target": {
      "installable": ".#nixosConfigurations.myhost"
    }
  }
}
```

### Integration

- **devenv**: `devenv lsp` launches nixd configured for the project
- **Neovim**: use nvim-lspconfig with `nixd` server
- **VS Code**: use nixd extension
- **Emacs**: use lsp-mode or eglot with `nixd`

### Comparison with nil and nix-language-server

nixd links against the C++ Nix library, giving it access to the real
evaluator for completions and option lookups. Other servers (nil,
nix-language-server) use rnix-parser for AST-only analysis without
evaluation. nixd is the current reference LSP for Nix.

## Parser (rnix-parser)

### rnix-parser — Rust Nix Parser

A parser for the Nix language written in Rust. Uses the `rowan` crate
for lossless AST representation — all span information (whitespace,
comments) is preserved, and the AST can be printed back to 100%
identical source.

Used by: nixpkgs-fmt, statix, deadnix, nixdoc, nil, and other Nix
tooling.

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
nixpkgs. It combines `nixpkgs.lib` (via nixpkgs.lib, the cheap fork)
with `flake-utils` and other pure libs into a single `lib` attribute.

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
{
  inputs.nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";
  # nixpkgs-wayland provides an overlay
  nixpkgs.overlays = [ nixpkgs-wayland.overlay ];
}
```

Use the Cachix binary cache to avoid building from source:

```bash
cachix use nixpkgs-wayland
# Or in NixOS config:
nix.settings = {
  substituters = [ "https://nixpkgs-wayland.cachix.org" ];
  trusted-public-keys = [ "nixpkgs-wayland.cachix.org-1:7nasTI/N7N9SIloJ6Sw5G6CgzS4fdS6rUZ6wx8C4P64=" ];
};
```

Packages include: wlroots, sway, swaybg, waybar, wob, flashrom,
wev, and other Wayland utilities — often at versions ahead of
nixpkgs unstable.

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
| Nix on Android | nix-on-droid |
| Discover Nix ecosystem projects | awesome-nix |

## Related Skills

- **nix-language** — language fundamentals, builtins, lib, doc comments (RFC 145)
- **nix-flakes** — flake structure, inputs, outputs, flake-parts
- **nix-linting** — statix, deadnix, nixfmt, CI pipeline
- **nix-testing** — nixosTest, namaka, nix-unit, nixt
- **nix-debugging** — --show-trace, nix-tree, nix-diff, vulnix
