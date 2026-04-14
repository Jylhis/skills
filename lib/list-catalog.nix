# Convenience expression for listing all discovered skills.
# Usage: nix eval --impure --json --expr 'import ./lib/list-catalog.nix' | jq .
let
  flakeSources = import ../_sources.nix;
  pkgs = import flakeSources.nixpkgs { };
  discoverSkills = import ./discover.nix;

  # Discover local plugin skills
  pluginsDir = ../plugins;
  entries = builtins.readDir pluginsDir;
  pluginNames = builtins.filter (
    n: entries.${n} == "directory" && builtins.pathExists (pluginsDir + "/${n}/plugin.nix")
  ) (builtins.attrNames entries);

  localCatalogs = map (
    name:
    discoverSkills {
      path = pluginsDir + "/${name}/skills";
      namespace = name;
    }
  ) pluginNames;

  # Discover third-party skills from flake inputs
  thirdPartySources = import ../sources.nix;
  thirdPartyCatalogs = pkgs.lib.mapAttrsToList (
    pinName: opts:
    discoverSkills {
      path = flakeSources.${pinName} + "/${opts.skillsRoot or "."}";
      namespace = opts.namespace;
      maxDepth = opts.maxDepth or 5;
    }
  ) thirdPartySources;

  allCatalogs = localCatalogs ++ thirdPartyCatalogs;
  merged = builtins.foldl' (a: b: a // b) { } allCatalogs;
in
builtins.mapAttrs (_: s: {
  inherit (s) name namespace relativePath;
}) merged
