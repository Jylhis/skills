{ config, lib, ... }:

let
  cfg = config.programs.jstack;
  runtimePkg = import (/. + cfg.repoPath + "/runtime");
  mkLink = path: config.lib.file.mkOutOfStoreSymlink (cfg.repoPath + "/" + path);

  pluginsDir = /. + cfg.repoPath + "/plugins";
  pluginBundles = lib.pipe (builtins.readDir pluginsDir) [
    (lib.filterAttrs (_: type: type == "directory"))
    (lib.filterAttrs (
      name: _: builtins.pathExists (pluginsDir + "/${name}/.claude-plugin/plugin.json")
    ))
    (lib.mapAttrsToList (name: _: pluginsDir + "/${name}"))
  ];
in
{
  options.programs.jstack = {
    enable = lib.mkEnableOption "jstack Claude Code configuration";

    repoPath = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the jstack repository checkout.";
      example = "/home/user/Developer/jstack";
    };
  };

  config = lib.mkIf cfg.enable {
    # Delegate settings and memory to upstream programs.claude-code
    programs.claude-code.settings = import ((/. + cfg.repoPath) + "/settings.nix");
    programs.claude-code.memory.source = mkLink "CLAUDE.md";
    programs.claude-code.plugins = pluginBundles;

    # Live-editable directory symlinks (not using upstream Dir options
    # which copy to the Nix store and lose live editing)
    home.file = {
      ".claude/skills".source = mkLink "skills";
      ".claude/agents".source = mkLink "agents";
      ".claude/commands".source = mkLink "commands";
      ".claude/hooks".source = mkLink "hooks";
      ".claude/plugins".source = mkLink "plugins";
    };

    home.packages = [ runtimePkg ];

    home.sessionVariables = {
      JSTACK_RUNTIME = "${runtimePkg}";
    };
  };
}
