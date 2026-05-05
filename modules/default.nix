# Single module: deploy a skills directory to ~/.claude/.
#
# Detects context at eval time and uses the right primitive:
#   Home Manager → home.file (optionally mkOutOfStoreSymlink)
#   NixOS        → systemd.tmpfiles.rules (L+)
#   nix-darwin   → system.activationScripts.postActivation
{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.programs.skills;

  isHomeManager = options ? home.homeDirectory;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  isSystem = !isHomeManager;
  isNixOS = isSystem && !isDarwin;
  isNixDarwin = isSystem && isDarwin;

  effectiveUser =
    if isHomeManager then
      config.home.username
    else if cfg.user != null then
      cfg.user
    else if isNixDarwin && (config.system.primaryUser or null) != null then
      config.system.primaryUser
    else
      null;

  effectiveHome =
    if isHomeManager then
      config.home.homeDirectory
    else if effectiveUser == null then
      "/INVALID-skills-user-not-set"
    else if isDarwin then
      "/Users/${effectiveUser}"
    else
      "/home/${effectiveUser}";

  skillsStorePath = pkgs.runCommand "skills" { } ''
    mkdir -p $out
    cp -r ${cfg.src}/. $out/
  '';

  paths = {
    ".claude/skills" = skillsStorePath;
  } // lib.optionalAttrs (cfg.claudeMd != null) {
    ".claude/CLAUDE.md" = cfg.claudeMd;
  };

  hmSource =
    relPath: storePath:
    if cfg.livePath != null then
      let
        liveSub = if relPath == ".claude/skills" then "skills" else "CLAUDE.md";
      in
      config.lib.file.mkOutOfStoreSymlink (cfg.livePath + "/" + liveSub)
    else
      storePath;
in
{
  options.programs.skills = {
    enable = lib.mkEnableOption "skills catalogue deployment to ~/.claude/";

    src = lib.mkOption {
      type = lib.types.path;
      default = ../skills;
      description = "Path to a directory containing one subdirectory per skill (each with SKILL.md).";
    };

    claudeMd = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ../CLAUDE.md;
      description = "Path to the repo CLAUDE.md to symlink to ~/.claude/CLAUDE.md, or null to skip.";
    };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Target user for installing per-user files. Required for NixOS or
        nix-darwin; ignored under Home Manager (taken from home.username).
        On nix-darwin defaults to system.primaryUser.
      '';
    };

    livePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Absolute path to a live repo checkout. When set under Home Manager,
        ~/.claude/skills and ~/.claude/CLAUDE.md become out-of-store symlinks
        so edits in the checkout take effect without a rebuild.
      '';
      example = "/home/alice/src/skills";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = isHomeManager || effectiveUser != null;
          message = "programs.skills: set `user` (or `system.primaryUser` on nix-darwin) when using outside Home Manager.";
        }
      ];
    }

    (lib.mkIf isHomeManager {
      home.file = lib.mapAttrs (relPath: storePath: { source = hmSource relPath storePath; }) paths;
    })

    (lib.mkIf isNixOS {
      systemd.tmpfiles.rules = lib.mapAttrsToList (
        relPath: storePath: "L+ ${effectiveHome}/${relPath} - ${effectiveUser} ${effectiveUser} - ${storePath}"
      ) paths;
    })

    (lib.mkIf isNixDarwin {
      system.activationScripts.postActivation.text = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (relPath: storePath: ''
          mkdir -p "$(dirname "${effectiveHome}/${relPath}")"
          ln -sfn "${storePath}" "${effectiveHome}/${relPath}"
          chown -h ${effectiveUser}:staff "${effectiveHome}/${relPath}" 2>/dev/null || true
        '') paths
      );
    })
  ]);
}
