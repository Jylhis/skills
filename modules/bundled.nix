# Auto-populates programs.jstack.skillSources (and repo-shipped agents /
# commands) from the jstack repo itself. Imported by modules/default.nix
# so every consumer receives the bundled content automatically; consumer
# config merges additively via attrset mkMerge.
#
# `jstackBundledSources` is injected via _module.args from flake.nix (or
# from tests/module-eval.nix for standalone evaluation). It maps each
# bundled-sources.nix key to a resolved source path + config block.
{
  config,
  lib,
  jstackBundledSources ? { },
  ...
}:

let
  cfg = config.programs.jstack;

  agentsDir = ../agents;
  agentFiles = lib.filterAttrs (_: t: t == "regular") (builtins.readDir agentsDir);
  repoAgents = lib.mapAttrs' (
    filename: _:
    let
      name = lib.removeSuffix ".md" filename;
    in
    lib.nameValuePair name {
      src = agentsDir + "/${filename}";
    }
  ) (lib.filterAttrs (n: _: lib.hasSuffix ".md" n) agentFiles);

  commandsDir = ../commands;
  commandFiles =
    if builtins.pathExists commandsDir then
      lib.filterAttrs (_: t: t == "regular") (builtins.readDir commandsDir)
    else
      { };
  repoCommands = lib.mapAttrs' (
    filename: _:
    let
      name = lib.removeSuffix ".md" filename;
    in
    lib.nameValuePair name {
      src = commandsDir + "/${filename}";
    }
  ) (lib.filterAttrs (n: _: lib.hasSuffix ".md" n) commandFiles);
in
{
  config = lib.mkIf cfg.enable {
    programs.jstack.skillSources = lib.mapAttrs (_: src: {
      inherit (src) src;
      subdir = src.subdir or ".";
      namespace = src.namespace or "";
      include = src.include or [ ];
      exclude = src.exclude or [ ];
      maxDepth = src.maxDepth or 5;
    }) jstackBundledSources;

    programs.jstack.agents = repoAgents;
    programs.jstack.commands = repoCommands;
  };
}
