# Auto-populates programs.jstack.{skillSources, agentSources,
# commandSources, agents, commands} from the jstack repo itself.
#
# Imported by modules/default.nix so every consumer receives the
# bundled content automatically. Consumer config merges additively.
#
# `jstackBundledSources` is injected via _module.args from flake.nix (or
# from tests/module-eval.nix for standalone evaluation). It maps each
# bundled-sources.nix key to the resolved source path plus per-kind
# selection under `.skills`, `.agents`, `.commands` sub-attrs.
{
  config,
  lib,
  jstackBundledSources ? { },
  ...
}:

let
  cfg = config.programs.jstack;

  # Split the bundled config into three flat per-kind attrsets keyed on
  # `<source-name>-<kind>` so each source can contribute to any subset
  # of skills / agents / commands without name collisions.
  perKindSources =
    kind:
    lib.concatMapAttrs (
      name: src:
      if src ? ${kind} then
        {
          "${name}" = {
            inherit (src) src;
          }
          // src.${kind};
        }
      else
        { }
    ) jstackBundledSources;

  bundledSkillSources = perKindSources "skills";
  bundledAgentSources = perKindSources "agents";
  bundledCommandSources = perKindSources "commands";

  # Repo-shipped agents: every .md file under agents/ becomes an entry.
  agentsDir = ../agents;
  agentFiles =
    if builtins.pathExists agentsDir then
      lib.filterAttrs (_: t: t == "regular") (builtins.readDir agentsDir)
    else
      { };
  repoAgents = lib.mapAttrs' (
    filename: _:
    let
      name = lib.removeSuffix ".md" filename;
    in
    lib.nameValuePair name {
      src = agentsDir + "/${filename}";
    }
  ) (lib.filterAttrs (n: _: lib.hasSuffix ".md" n) agentFiles);

  # Repo-shipped slash commands (commands/*.md). Directory may be empty.
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
    programs.jstack.skillSources = lib.mapAttrs (_: entry: {
      inherit (entry) src;
      subdir = entry.subdir or ".";
      namespace = entry.namespace or "";
      include = entry.include or [ ];
      exclude = entry.exclude or [ ];
      paths = entry.paths or { };
      maxDepth = entry.maxDepth or 5;
    }) bundledSkillSources;

    programs.jstack.agentSources = lib.mapAttrs (_: entry: {
      inherit (entry) src;
      subdir = entry.subdir or ".";
      include = entry.include or [ ];
      exclude = entry.exclude or [ ];
      paths = entry.paths or { };
    }) bundledAgentSources;

    programs.jstack.commandSources = lib.mapAttrs (_: entry: {
      inherit (entry) src;
      subdir = entry.subdir or ".";
      include = entry.include or [ ];
      exclude = entry.exclude or [ ];
      paths = entry.paths or { };
    }) bundledCommandSources;

    programs.jstack.agents = repoAgents;
    programs.jstack.commands = repoCommands;
  };
}
