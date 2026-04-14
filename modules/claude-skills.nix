# Devenv module extending claude.code with third-party skill support.
#
# Adds `claude.code.skills` — an attrset of pinned sources that are
# scanned for SKILL.md files via lib/discover.nix and symlinked into
# .claude/skills/ on shell entry.
#
# Usage in devenv.nix:
#   claude.code.skills.promptfoo = {
#     source = (import ./_sources.nix).promptfoo;
#     skillsRoot = ".claude/skills";
#     namespace = "promptfoo";
#   };
{
  config,
  lib,
  ...
}:
let
  cfg = config.claude.code.skills;
  discoverSkills = import ../lib/discover.nix;

  # Run discovery on each configured source.
  catalogs = lib.mapAttrsToList (
    _: opts:
    discoverSkills {
      path = opts.source + "/${opts.skillsRoot}";
      inherit (opts) namespace maxDepth;
    }
  ) cfg;

  allSkills = builtins.foldl' (a: b: a // b) { } catalogs;

  # Shell snippet that symlinks every discovered skill.
  skillLinks = lib.concatStringsSep "\n" (
    map (skill: ''ln -sfn "${skill.path}" "$DEVENV_ROOT/.claude/skills/${skill.name}"'') (
      builtins.attrValues allSkills
    )
  );
in
{
  options.claude.code.skills = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.path;
            description = "Path to the pinned source (e.g. from flake inputs via _sources.nix).";
          };
          skillsRoot = lib.mkOption {
            type = lib.types.str;
            default = ".";
            description = "Subdirectory within the source that contains skill directories.";
          };
          namespace = lib.mkOption {
            type = lib.types.str;
            description = "Namespace prefix for discovered skills (e.g. 'promptfoo').";
          };
          maxDepth = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "Maximum directory depth for skill discovery.";
          };
        };
      }
    );
    default = { };
    description = ''
      Third-party skill sources to discover and symlink into .claude/skills/.
      Each key names a pinned source; skills are auto-discovered via
      lib/discover.nix and symlinked on shell entry.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    enterShell = lib.mkAfter ''
      # Third-party skills (claude.code.skills)
      mkdir -p "$DEVENV_ROOT/.claude/skills"
      ${skillLinks}
    '';
  };
}
