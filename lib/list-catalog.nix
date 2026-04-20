# Convenience expression for listing all discovered skills.
# Usage: nix eval --impure --json --expr 'import ./lib/list-catalog.nix' | jq .
let
  flakeSources = import ../_sources.nix;
  pkgs = import flakeSources.nixpkgs { };
  discoverSkills = import ./discover.nix;

  # Discover skills from flat skills/ directory
  localCatalog = discoverSkills {
    path = ../skills;
    namespace = "jstack";
  };

  # Discover bundled upstream skills (flake inputs declared in bundled-sources.nix).
  bundledSources = import ../bundled-sources.nix;
  bundledCatalogs = pkgs.lib.mapAttrsToList (
    pinName: opts:
    discoverSkills {
      path = flakeSources.${pinName} + "/${opts.subdir or "."}";
      namespace = opts.namespace or pinName;
      maxDepth = opts.maxDepth or 5;
    }
  ) bundledSources;

  allCatalogs = [ localCatalog ] ++ bundledCatalogs;
  merged = builtins.foldl' (a: b: a // b) { } allCatalogs;
in
builtins.mapAttrs (_: s: {
  inherit (s) name namespace relativePath;
}) merged
