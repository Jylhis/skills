---
name: npins
description: "Use for npins dependency pinning including npins/sources.json, npins add, npins remove, npins update, npins init, pinning GitHub repos, pinning NixOS channels, importing npins in Nix expressions, npins revision tracking, Channel vs GitHub pin types, npins default.nix, non-flake dependency management, or migrating from channels to GitHub pins."
user-invocable: false
---

# npins

[npins](https://github.com/andir/npins) pins external Nix dependencies
(nixpkgs, third-party repos) without requiring flakes or experimental
features. It is the non-flake equivalent of `flake.lock`.

## File Structure

```
project/
├── npins/
│   ├── default.nix     # Auto-generated import helper
│   └── sources.json    # Pin definitions and locked revisions
```

Initialize with `npins init`. The `npins/` directory is committed to
version control.

## Pin Types

npins supports two pin types with different data shapes:

### GitHub Pin

Tracks a specific branch of a GitHub repository. Has a `.revision` field
containing the locked commit hash.

```json
{
  "pins": {
    "nixpkgs": {
      "type": "GitHub",
      "repository": {
        "type": "GitHub",
        "owner": "NixOS",
        "repo": "nixpkgs"
      },
      "branch": "nixos-unstable",
      "revision": "abc123def456...",
      "url": "https://github.com/NixOS/nixpkgs/archive/abc123def456.tar.gz",
      "hash": "sha256-..."
    }
  }
}
```

### Channel Pin

Tracks a NixOS channel URL. Has NO `.revision` field — only `url` and
`hash`. This means revision-based synchronization workflows (syncing
with `flake.lock` or `devenv.lock`) cannot work with Channel pins.

```json
{
  "pins": {
    "nixpkgs": {
      "type": "Channel",
      "channel": "nixos-unstable",
      "url": "https://releases.nixos.org/...",
      "hash": "sha256-..."
    }
  }
}
```

**Critical:** If you need to extract a nixpkgs revision (e.g., for pin
synchronization), the pin MUST be a GitHub type. Migrate Channel pins
first — see "Migrating Channel to GitHub" below.

## CLI Commands

```bash
# Initialize npins in a project
npins init

# Add a GitHub repository pin
npins add github NixOS nixpkgs --branch nixos-unstable
npins add github nix-community home-manager --branch master

# Add a NixOS channel pin
npins add channel nixos-unstable

# Remove a pin
npins remove nixpkgs

# Update all pins to latest
npins update

# Update a single pin
npins update nixpkgs

# Show current pins
npins show
```

## Importing in Nix Expressions

The generated `npins/default.nix` returns an attrset of fetched sources:

```nix
# Basic import
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };
in
pkgs.hello
```

### With Overlays

```nix
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {
    overlays = [ (import ./overlay.nix) ];
  };
in
pkgs.mypackage
```

### As a Default Argument (Package Flake Pattern)

Use npins as the default pkgs source so the file works standalone but
callers can override:

```nix
{
  pkgs ? import (import ./npins).nixpkgs {
    overlays = [ (import ./overlay.nix) ];
  },
  lib ? pkgs.lib,
}:

{
  inherit (pkgs) mypackage;
  overlays.default = import ./overlay.nix;
}
```

### Accessing a Pinned Dependency

```nix
let
  sources = import ./npins;
  mylib = import sources.mylib;  # Import the pinned source
in
# use mylib
```

## Migrating Channel to GitHub

Channel pins lack `.revision`, which breaks revision-based workflows.
Migrate to a GitHub pin:

```bash
npins remove nixpkgs
npins add github NixOS nixpkgs --branch nixos-unstable
```

After migration, `sources.json` will have a `"type": "GitHub"` entry
with a `.revision` field. The resolved nixpkgs content is identical —
only the pin metadata changes.

## Extracting the Pinned Revision

```bash
jq -r '.pins.nixpkgs.revision' npins/sources.json
```

This only works with GitHub-type pins. Use the revision to synchronize
other lock files (devenv.lock, flake.lock) — see the `nix-hybrid` skill.

## Limitations

- **Flake-only projects cannot be pinned usefully.** Projects like
  home-manager, stylix, and nix-darwin have no `default.nix` — only
  `flake.nix`. While npins can fetch their source, you cannot `import`
  them without flake-compat (which adds complexity). For these deps, use
  flake inputs instead and pass them via `{ inputs }:`.

- **npins is an impure operation.** `import ./npins` calls
  `builtins.fetchTarball` at evaluation time, which requires network
  access and fails under `nix flake check`'s pure evaluation. Do not
  expose npins-derived outputs as `packages.<system>.*` in a flake.

## npins vs Flake Inputs

| Aspect | npins | Flake inputs |
|--------|-------|-------------|
| Experimental features | None required | `nix-command`, `flakes` |
| Lock file | `npins/sources.json` | `flake.lock` |
| Pin granularity | Per-source | Per-input |
| Pure evaluation | No (uses `builtins.fetchTarball`) | Yes |
| Works with non-flake projects | Yes | Via `flake = false` |
| Works with flake-only projects | Fetch only (cannot import) | Full support |

In hybrid setups, npins pins nixpkgs (for dev and as the source of
truth), while flake inputs handle flake-only upstream dependencies.
