# Core module — top-level options, context detection, and deployment from _generated.
#
# This module declares the shared programs.jstack options (enable, user, livePath,
# packages, instructions) and the internal _generated option that tool modules
# populate. It handles deploying generated files to the correct locations based
# on the detected context (Home Manager, NixOS, or nix-darwin).
{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.programs.jstack;

  # ── Context detection ────────────────────────────────────────────────
  isHomeManager = options ? home.homeDirectory;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  isSystem = !isHomeManager;
  isNixOS = isSystem && !isDarwin;
  isNixDarwin = isSystem && isDarwin;

  # ── Resolve target user / home dir ──────────────────────────────────
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
      "/INVALID-jstack-user-not-set"
    else if isDarwin then
      "/Users/${effectiveUser}"
    else
      "/home/${effectiveUser}";

  # ── Collect all generated files from tool modules ───────────────────
  allFiles = lib.concatMapAttrs (_tool: gen: gen.files) cfg._generated;
  allDirs = lib.concatMapAttrs (_tool: gen: gen.dirs) cfg._generated;
  allPaths = allFiles // allDirs;

  # ── Check for path collisions across tools ──────────────────────────
  pathsByTool = lib.concatMapAttrs (
    tool: gen: lib.mapAttrs (_path: _: tool) (gen.files // gen.dirs)
  ) cfg._generated;

  # ── Runtime package from shared packages ────────────────────────────
  runtimeEnv =
    if cfg.packages != [ ] then
      pkgs.buildEnv {
        name = "jstack-runtime";
        paths = cfg.packages;
      }
    else
      null;

  # ── Home Manager symlink helper ─────────────────────────────────────
  mkHmSource =
    relPath: storePath:
    if cfg.livePath != null then
      config.lib.file.mkOutOfStoreSymlink (cfg.livePath + "/" + relPath)
    else
      storePath;

  # ── NixOS tmpfiles helper ───────────────────────────────────────────
  mkTmpfilesRules =
    paths:
    lib.mapAttrsToList (
      relPath: storePath:
      "L+ ${effectiveHome}/${relPath} - ${effectiveUser} ${effectiveUser} - ${storePath}"
    ) paths;

  # ── nix-darwin activation helper ────────────────────────────────────
  mkDarwinActivationLines =
    paths:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (relPath: storePath: ''
        mkdir -p "$(dirname "${effectiveHome}/${relPath}")"
        ln -sfn "${storePath}" "${effectiveHome}/${relPath}"
        chown -h ${effectiveUser}:staff "${effectiveHome}/${relPath}" 2>/dev/null || true
      '') paths
    );
in
{
  options.programs.jstack = {
    enable = lib.mkEnableOption "jstack multi-agent AI configuration";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Target user for installing per-user dotfiles.

        Required when this module is imported into a NixOS or nix-darwin
        configuration. In Home Manager context the value is taken from
        `home.username` and this option is ignored. On nix-darwin it
        defaults to `system.primaryUser` when set.
      '';
      example = "alice";
    };

    livePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Absolute path to the jstack repo checkout for live editing.
        When set, skills and instructions are symlinked to the repo
        instead of copied to the Nix store. Breaks purity but enables
        editing without rebuild. Only effective in Home Manager context.
      '';
      example = "/home/alice/Developer/jstack";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages added to PATH for all enabled tools.";
    };

    instructions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Tool-agnostic instructions included in every tool's instruction file
        (CLAUDE.md, AGENTS.md, GEMINI.md, etc.).
      '';
    };

    agents = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            src = lib.mkOption {
              type = lib.types.path;
              description = "Path to a markdown file defining this subagent.";
            };
            tools = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
              description = "Tool names to deploy this agent to, or null for all enabled tools.";
            };
          };
        }
      );
      default = { };
      description = ''
        Subagent definitions. Merged additively with repo-shipped agents so
        downstream consumers can append without overriding.
      '';
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            src = lib.mkOption {
              type = lib.types.path;
              description = "Path to the slash command markdown file.";
            };
            tools = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
              description = "Tool names to deploy this command to, or null for all enabled tools.";
            };
          };
        }
      );
      default = { };
      description = ''
        Slash command definitions. Merged additively with repo-shipped
        commands so downstream consumers can append without overriding.
      '';
    };

    # Internal option for tool modules to register files for deployment.
    # Each tool module sets _generated.<toolName>.{files,dirs}.
    # This module reads all entries and deploys them per context.
    _generated = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            files = lib.mkOption {
              type = lib.types.attrsOf lib.types.path;
              default = { };
              description = "Map of relative path -> store path for files.";
            };
            dirs = lib.mkOption {
              type = lib.types.attrsOf lib.types.path;
              default = { };
              description = "Map of relative path -> store path for directories.";
            };
          };
        }
      );
      default = { };
      internal = true;
      description = "Generated config files per tool. Set by tool modules, consumed by deployment.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge (
      [
        # ── Assertions ──
        {
          assertions = [
            {
              assertion = isHomeManager || effectiveUser != null;
              message =
                "programs.jstack: when used as a NixOS or nix-darwin module, set"
                + " `programs.jstack.user` (or `system.primaryUser` on nix-darwin).";
            }
          ];
        }
      ]
      ++ lib.optionals isHomeManager [
        # ── Runtime package (Home Manager) ──
        (lib.mkIf (runtimeEnv != null) {
          home.packages = [ runtimeEnv ];
          home.sessionVariables.JSTACK_RUNTIME = "${runtimeEnv}";
        })

        # ── Deploy generated files via home.file ──
        {
          home.file = lib.mapAttrs (relPath: storePath: { source = mkHmSource relPath storePath; }) allPaths;
        }
      ]
      ++ lib.optionals isSystem [
        # ── Runtime package (NixOS / nix-darwin) ──
        (lib.mkIf (runtimeEnv != null) {
          environment.systemPackages = [ runtimeEnv ];
          environment.variables.JSTACK_RUNTIME = "${runtimeEnv}";
        })
      ]
      ++ lib.optionals isNixOS [
        # ── Deploy generated files via systemd-tmpfiles ──
        {
          systemd.tmpfiles.rules = mkTmpfilesRules allPaths;
        }
      ]
      ++ lib.optionals isNixDarwin [
        # ── Deploy generated files via activation script ──
        {
          system.activationScripts.postActivation.text = mkDarwinActivationLines allPaths;
        }
      ]
    )
  );
}
