{
  pkgs ? import (import ../_sources.nix).nixpkgs { },
}:
let
  pluginsDir = ../plugins;
  entries = builtins.readDir pluginsDir;
  pluginNames = builtins.filter (
    n: entries.${n} == "directory" && builtins.pathExists (pluginsDir + "/${n}/plugin.nix")
  ) (builtins.attrNames entries);

  loadPackages =
    name:
    let
      pluginDef = import (pluginsDir + "/${name}/plugin.nix") { inherit pkgs; };
    in
    pluginDef.packages or [ ];

  pluginPackages = builtins.concatLists (map loadPackages pluginNames);

  basePackages = with pkgs; [
    pyright
    typescript-language-server
  ];
in
pkgs.buildEnv {
  name = "claude-runtime";
  paths = basePackages ++ pluginPackages;
}
