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

  # Look up the user record from `users.users.<name>` if the consuming
  # configuration declares one. Returns null when the user isn't declared
  # there (e.g. on machines where the interactive user is created outside
  # the NixOS module system, or on nix-darwin setups that skip it).
  declaredUser =
    if effectiveUser == null then
      null
    else
      config.users.users.${effectiveUser} or null;

  effectiveHome =
    if isHomeManager then
      config.home.homeDirectory
    else if effectiveUser == null then
      "/INVALID-skills-user-not-set"
    else if declaredUser != null && (declaredUser.home or null) != null then
      declaredUser.home
    else if isDarwin then
      "/Users/${effectiveUser}"
    else
      "/home/${effectiveUser}";

  effectiveGroup =
    if declaredUser != null && (declaredUser.group or "") != "" then
      declaredUser.group
    else if isDarwin then
      "staff"
    else
      effectiveUser;

  skillsStorePath = pkgs.runCommand "skills" { } ''
    mkdir -p $out
    cp -r ${cfg.src}/. $out/
  '';

  paths =
    { ".claude/skills" = skillsStorePath; }
    // lib.optionalAttrs (cfg.claudeMd != null) {
      ".claude/CLAUDE.md" = cfg.claudeMd;
    }
    // lib.optionalAttrs (cfg.agentsMd != null) {
      ".claude/AGENTS.md" = cfg.agentsMd;
    };

  hmSource =
    relPath: storePath:
    if cfg.livePath != null then
      let
        liveSub =
          if relPath == ".claude/skills" then
            "skills"
          else if relPath == ".claude/CLAUDE.md" then
            "CLAUDE.md"
          else if relPath == ".claude/AGENTS.md" then
            "AGENTS.md"
          else
            throw "programs.skills: unknown live path mapping for ${relPath}";
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
      description = "Path to symlink as ~/.claude/CLAUDE.md, or null to skip.";
    };

    agentsMd = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ../AGENTS.md;
      description = ''
        Path to symlink as ~/.claude/AGENTS.md, or null to skip. Deployed
        alongside CLAUDE.md so Claude Code's `@AGENTS.md` import resolves.
      '';
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
      # `L+` tmpfiles entries auto-create parent dirs as root:root, which
      # leaves ~/.claude unwritable for the user on first install. Emit
      # an explicit `d` rule for ~/.claude so it's owned by the user
      # before the symlink rules run.
      systemd.tmpfiles.rules =
        [ "d ${effectiveHome}/.claude 0755 ${effectiveUser} ${effectiveGroup} - -" ]
        ++ lib.mapAttrsToList (
          relPath: storePath:
          "L+ ${effectiveHome}/${relPath} - ${effectiveUser} ${effectiveGroup} - ${storePath}"
        ) paths;
    })

    (lib.mkIf isNixDarwin {
      # `ln -sfn DST` won't replace a pre-existing real directory at DST
      # (a common case for ~/.claude/skills), so `darwin-rebuild switch`
      # would fail. Back up real files/dirs first; replace symlinks
      # in-place. Activation runs as root, so chown the result to the
      # target user.
      system.activationScripts.postActivation.text = lib.concatStringsSep "\n" (
        [
          ''
            mkdir -p "${effectiveHome}/.claude"
            chown ${effectiveUser}:${effectiveGroup} "${effectiveHome}/.claude" 2>/dev/null || true
          ''
        ]
        ++ lib.mapAttrsToList (relPath: storePath: ''
          dst="${effectiveHome}/${relPath}"
          mkdir -p "$(dirname "$dst")"
          if [ -L "$dst" ]; then
            rm -f "$dst"
          elif [ -e "$dst" ]; then
            mv "$dst" "$dst.before-skills-$(date -u +%Y%m%dT%H%M%SZ)"
          fi
          ln -s "${storePath}" "$dst"
          chown -h ${effectiveUser}:${effectiveGroup} "$dst" 2>/dev/null || true
        '') paths
      );
    })
  ]);
}
