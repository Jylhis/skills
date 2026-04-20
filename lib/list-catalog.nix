# Convenience expression for listing all discovered skills.
# Usage: nix eval --impure --json --expr 'import ./lib/list-catalog.nix' | jq .
let
  flakeSources = import ../_sources.nix;
  pkgs = import flakeSources.nixpkgs { };
  inherit (pkgs) lib;
  discoverSkills = import ./discover.nix;

  # Discover skills from flat skills/ directory
  localCatalog = discoverSkills {
    path = ../skills;
    namespace = "jstack";
  };

  # Discover bundled upstream skills from bundled-sources.nix. Each
  # entry has `src` (a resolved flake input path) and optionally a
  # `skills` sub-attr declaring either `subdir` or `paths`.
  bundledSources = import ../bundled-sources.nix flakeSources;

  bundledCatalogs = lib.flatten (
    lib.mapAttrsToList (
      sourceName: src:
      if !(src ? skills) then
        [ ]
      else
        let
          skillsCfg = src.skills;
          root = src.src;
          namespace = skillsCfg.namespace or sourceName;
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
          let
            raw = discoverSkills {
              path = root + "/${skillsCfg.subdir or "."}";
              inherit namespace;
              maxDepth = skillsCfg.maxDepth or 5;
            };
            include = skillsCfg.include or [ ];
            exclude = skillsCfg.exclude or [ ];
            filtered =
              if include != [ ] then
                lib.filterAttrs (_: s: builtins.elem s.name include) raw
              else if exclude != [ ] then
                lib.filterAttrs (_: s: !(builtins.elem s.name exclude)) raw
              else
                raw;
          in
          [ filtered ]
    ) bundledSources
  );

  allCatalogs = [ localCatalog ] ++ bundledCatalogs;
  merged = builtins.foldl' (a: b: a // b) { } allCatalogs;
in
builtins.mapAttrs (_: s: {
  inherit (s) name namespace relativePath;
}) merged
