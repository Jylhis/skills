# Skills module — declares skill and skillSources options.
#
# Individual skills are declared with `programs.jstack.skills.<name>.src`.
# Bulk imports from flake inputs use `programs.jstack.skillSources.<name>.src`.
#
# Skill bundling happens in tool modules (they call lib/skill-bundle.nix
# with the resolved skill set and their tool name for substitution).
# This module only exposes the options and a resolved `_resolvedSkills`
# internal option that tool modules consume.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.jstack;
  discoverSkills = import ../lib/discover.nix;

  # Resolve skillSources into individual skill entries.
  # Two modes:
  #   paths non-empty  → explicit selection; each entry (name → relPath) becomes a skill dir
  #   paths empty      → walk src + subdir with discover.nix; include/exclude filters apply
  discoveredSkills = lib.concatMapAttrs (
    _sourceName: sourceCfg:
    if sourceCfg.paths != { } then
      lib.mapAttrs (_: relPath: {
        src = sourceCfg.src + "/${relPath}";
        packages = sourceCfg.packages;
        transform = sourceCfg.transform;
        tools = null;
      }) sourceCfg.paths
    else
      let
        catalog = discoverSkills {
          path = sourceCfg.src + "/${sourceCfg.subdir}";
          namespace = sourceCfg.namespace;
          maxDepth = sourceCfg.maxDepth;
        };

        filtered =
          if sourceCfg.include != [ ] then
            lib.filterAttrs (_: s: builtins.elem s.name sourceCfg.include) catalog
          else if sourceCfg.exclude != [ ] then
            lib.filterAttrs (_: s: !(builtins.elem s.name sourceCfg.exclude)) catalog
          else
            catalog;
      in
      lib.mapAttrs' (
        _id: skill:
        lib.nameValuePair skill.name {
          src = skill.path;
          packages = sourceCfg.packages;
          transform = sourceCfg.transform;
          tools = null;
        }
      ) filtered
  ) cfg.skillSources;

  # Merge individual skills with discovered skills (individual takes precedence)
  resolvedSkills =
    discoveredSkills
    // (lib.mapAttrs (_name: skill: {
      inherit (skill)
        src
        packages
        transform
        tools
        ;
    }) cfg.skills);
in
{
  options.programs.jstack = {
    skills = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              src = lib.mkOption {
                type = lib.types.path;
                description = "Path to a directory containing SKILL.md.";
              };

              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Packages whose binaries are symlinked into the skill's bin/ dir.";
              };

              transform = lib.mkOption {
                type = lib.types.nullOr (lib.types.functionTo lib.types.str);
                default = null;
                description = ''
                  Function (string -> string) applied to SKILL.md content before deployment.
                  Receives the raw file content and returns the modified content.
                  Applied at eval time via builtins.readFile — use sparingly.
                '';
              };

              tools = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                description = ''
                  List of tool names to deploy this skill to, or null for all enabled tools.
                  Tool names: claude-code, codex, gemini, pi, cursor, windsurf, opencode, cline, aider.
                '';
              };
            };
          }
        )
      );
      default = { };
      description = "Individual skill definitions.";
    };

    skillSources = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              src = lib.mkOption {
                type = lib.types.path;
                description = "Path to a directory tree containing skill subdirectories.";
              };

              subdir = lib.mkOption {
                type = lib.types.str;
                default = ".";
                description = "Subdirectory within src that contains skill directories.";
              };

              namespace = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Namespace prefix for discovered skill IDs.";
              };

              include = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Skill names to include (empty = all).";
              };

              exclude = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Skill names to exclude.";
              };

              transform = lib.mkOption {
                type = lib.types.nullOr (lib.types.functionTo lib.types.str);
                default = null;
                description = "Function (string -> string) applied to each SKILL.md content.";
              };

              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Packages bundled with every skill from this source.";
              };

              maxDepth = lib.mkOption {
                type = lib.types.int;
                default = 5;
                description = "Maximum directory depth for skill discovery.";
              };

              paths = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = ''
                  Explicit skill selection as `{ <name> = <relative-path>; }`.
                  Each value is a path (relative to `src`) that contains a
                  SKILL.md. When set, `subdir`/`include`/`exclude` are ignored
                  and no directory scan is performed — each entry is mounted
                  as a skill under its key name.
                '';
                example = {
                  claude-md-improver = "plugins/claude-md-management/skills/claude-md-improver";
                };
              };
            };
          }
        )
      );
      default = { };
      description = "Bulk skill sources for importing from flake inputs or external repos.";
    };

    # Internal: resolved skills (individual + discovered, merged)
    _resolvedSkills = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
      internal = true;
      description = "Merged skill set consumed by tool modules for bundling.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.jstack._resolvedSkills = resolvedSkills;
  };
}
