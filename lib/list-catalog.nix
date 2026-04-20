# Convenience expression for listing all discovered skills.
# Usage: nix eval --impure --json --expr 'import ./lib/list-catalog.nix' | jq .
let
  flakeSources = import ../_sources.nix;
  pkgs = import flakeSources.nixpkgs { };
  lib = pkgs.lib;
  discoverSkills = import ./discover.nix;

  # Discover skills from flat skills/ directory
  localCatalog = discoverSkills {
    path = ../skills;
    namespace = "jstack";
  };

  # Discover bundled upstream skills from bundled-sources.nix. Each
  # source can declare skills via either `subdir` (auto-discovery) or
  # `paths` (explicit map of name -> relative path).
  bundledSources = import ../bundled-sources.nix;

  bundledCatalogs = lib.flatten (
    lib.mapAttrsToList (
      pinName: src:
      if !(src ? skills) then
        [ ]
      else
        let
          skillsCfg = src.skills;
          root = flakeSources.${pinName};
          namespace = skillsCfg.namespace or pinName;
        in
        if (skillsCfg.paths or { }) != { } then
          [
            (lib.mapAttrs' (
              name: relPath:
              lib.nameValuePair "${namespace}:${name}" {
                inherit name namespace;
                path = root + "/${relPath}";
                relativePath = relPath;
              }
            ) skillsCfg.paths)
          ]
        else
          [
            (discoverSkills {
              path = root + "/${skillsCfg.subdir or "."}";
              inherit namespace;
              maxDepth = skillsCfg.maxDepth or 5;
            })
          ]
    ) bundledSources
  );

  allCatalogs = [ localCatalog ] ++ bundledCatalogs;
  merged = builtins.foldl' (a: b: a // b) { } allCatalogs;
in
builtins.mapAttrs (_: s: {
  inherit (s) name namespace relativePath;
}) merged
