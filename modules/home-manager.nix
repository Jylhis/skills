{ config, lib, pkgs, ... }:
let
  cfg = config.programs.claude-config;
in
{
  options.programs.claude-config = {
    enable = lib.mkEnableOption "claude config";

    devPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Absolute path to the claude-config working tree. When set, skills
        and plugins are symlinked out-of-store for live editing. When null,
        content is copied into the store from this module's directory.
      '';
      example = "/home/markus/Developer/jylhis/claude-config";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      live = cfg.devPath != null;
      mkLink = sub:
        if live
        then config.lib.file.mkOutOfStoreSymlink "${cfg.devPath}/${sub}"
        else ../${sub};
    in
    {
      home.file.".claude/skills".source  = mkLink "skills";
      home.file.".claude/plugins".source = mkLink "plugins";

      # Always store-managed — these are the stable bits
      home.file.".claude/settings.json".source = ../modules/settings.json;
      home.file.".claude/CLAUDE.md".source     = ../modules/CLAUDE.md;
    }
  );
}
