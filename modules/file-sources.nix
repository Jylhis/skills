# Bulk import of agents and slash commands from external repos.
#
# Each source points to a directory in the nix store (typically a flake
# input) and selects `.md` files either from a single `subdir` (with
# optional `include` / `exclude`) or from an explicit `paths` map.
#
# Resolved entries populate the top-level `programs.jstack.agents` and
# `programs.jstack.commands` attrsets, so tool modules deploy them
# through the existing file-bundle pipeline (see lib/file-bundle.nix).
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.jstack;

  resolveSource =
    sourceCfg:
    if sourceCfg.paths != { } then
      lib.mapAttrs (_: relPath: {
        src = sourceCfg.src + "/${relPath}";
        tools = sourceCfg.tools;
      }) sourceCfg.paths
    else
      let
        dirPath = sourceCfg.src + "/${sourceCfg.subdir}";
        entries =
          if builtins.pathExists dirPath then
            lib.filterAttrs (_: t: t == "regular") (builtins.readDir dirPath)
          else
            { };
        mdFiles = lib.filterAttrs (n: _: lib.hasSuffix ".md" n) entries;

        namesToPaths = lib.mapAttrs' (
          filename: _:
          let
            name = lib.removeSuffix ".md" filename;
          in
          lib.nameValuePair name "${sourceCfg.subdir}/${filename}"
        ) mdFiles;

        filtered =
          if sourceCfg.include != [ ] then
            lib.filterAttrs (name: _: builtins.elem name sourceCfg.include) namesToPaths
          else if sourceCfg.exclude != [ ] then
            lib.filterAttrs (name: _: !(builtins.elem name sourceCfg.exclude)) namesToPaths
          else
            namesToPaths;
      in
      lib.mapAttrs (_: relPath: {
        src = sourceCfg.src + "/${relPath}";
        tools = sourceCfg.tools;
      }) filtered;

  sourceOptions =
    kind:
    { name, ... }:
    {
      options = {
        src = lib.mkOption {
          type = lib.types.path;
          description = "Path to a directory tree containing ${kind} markdown files.";
        };
        subdir = lib.mkOption {
          type = lib.types.str;
          default = ".";
          description = "Subdirectory within src containing ${kind} .md files.";
        };
        include = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "${kind} names (without .md) to include. Empty = all.";
        };
        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "${kind} names to exclude.";
        };
        paths = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Explicit ${kind} selection as `{ <name> = <relative-path>; }`.
            Values point at individual .md files relative to `src`. When
            set, `subdir`/`include`/`exclude` are ignored.
          '';
        };
        tools = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "Tool names each resolved entry targets, or null for all.";
        };
      };
    };

  resolvedAgents = lib.concatMapAttrs (_: resolveSource) cfg.agentSources;
  resolvedCommands = lib.concatMapAttrs (_: resolveSource) cfg.commandSources;
in
{
  options.programs.jstack = {
    agentSources = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (sourceOptions "agent"));
      default = { };
      description = "Bulk agent sources. Resolved entries merge into programs.jstack.agents.";
    };

    commandSources = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (sourceOptions "command"));
      default = { };
      description = "Bulk slash-command sources. Resolved entries merge into programs.jstack.commands.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.jstack.agents = resolvedAgents;
    programs.jstack.commands = resolvedCommands;
  };
}
