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
  # Home Manager exposes `home.homeDirectory`; NixOS / nix-darwin do not.
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

  # ── Build artifacts (shared across all contexts) ────────────────────
  runtimePkg = import ./runtime { inherit pkgs; };

  pluginsDir = ./plugins;
  pluginBundles = lib.pipe (builtins.readDir pluginsDir) [
    (lib.filterAttrs (_: type: type == "directory"))
    (lib.filterAttrs (name: _: builtins.pathExists (pluginsDir + "/${name}/plugin.nix")))
    (lib.mapAttrsToList (name: _: pluginsDir + "/${name}"))
  ];

  # Discovery library
  discoverSkills = import ./lib/discover.nix;

  # Discover local plugin skills
  localPluginNames = lib.pipe (builtins.readDir pluginsDir) [
    (lib.filterAttrs (_: type: type == "directory"))
    (lib.filterAttrs (name: _: builtins.pathExists (pluginsDir + "/${name}/plugin.nix")))
    builtins.attrNames
  ];

  localCatalogs = map (
    name:
    discoverSkills {
      path = pluginsDir + "/${name}/skills";
      namespace = name;
    }
  ) localPluginNames;

  localCatalog = builtins.foldl' (a: b: a // b) { } localCatalogs;

  # Discover third-party skills from flake inputs
  thirdPartySources = import ./sources.nix;
  sources = import ./_sources.nix;
  thirdPartyCatalogs = lib.mapAttrsToList (
    pinName: opts:
    discoverSkills {
      path = sources.${pinName} + "/${opts.skillsRoot or "."}";
      namespace = opts.namespace;
      maxDepth = opts.maxDepth or 5;
    }
  ) thirdPartySources;

  thirdPartyCatalog =
    if cfg.thirdParty.enable then builtins.foldl' (a: b: a // b) { } thirdPartyCatalogs else { };

  fullCatalog = localCatalog // thirdPartyCatalog;

  catalogInfo = {
    totalSkills = builtins.length (builtins.attrNames fullCatalog);
    localSkills = builtins.length (builtins.attrNames localCatalog);
    thirdPartySkills = builtins.length (builtins.attrNames thirdPartyCatalog);
  };

  # ── Home Manager symlink helper ─────────────────────────────────────
  mkHmLink = path: config.lib.file.mkOutOfStoreSymlink (cfg.repoPath + "/" + path);

  # ── Per-target link maps (paths relative to user $HOME) ─────────────
  # Used to drive both NixOS (systemd-tmpfiles) and nix-darwin
  # (activation script) symlink creation in non-HM contexts.
  claudeLinks = {
    ".claude/skills" = "skills";
    ".claude/agents" = "agents";
    ".claude/commands" = "commands";
    ".claude/hooks" = "hooks";
    ".claude/plugins" = "plugins";
    ".claude/CLAUDE.md" = "CLAUDE.md";
    ".claude/settings.json" = "settings.json";
  };
  codexLinks = {
    ".codex/skills" = "skills";
  };
  geminiLinks = {
    ".gemini/skills" = "skills";
  };

  # ── System-context symlink helpers ──────────────────────────────────
  # NixOS: declarative systemd-tmpfiles `L+` rules with explicit owner.
  mkTmpfilesRules =
    links:
    lib.mapAttrsToList (
      relPath: source:
      "L+ ${effectiveHome}/${relPath} - ${effectiveUser} ${effectiveUser} - ${cfg.repoPath}/${source}"
    ) links;

  # nix-darwin: shell snippet appended to `system.activationScripts.postActivation`
  # (runs as root, so chown the symlink to the target user afterwards).
  mkDarwinActivationLines =
    links:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (relPath: source: ''
        mkdir -p "$(dirname "${effectiveHome}/${relPath}")"
        ln -sfn "${cfg.repoPath}/${source}" "${effectiveHome}/${relPath}"
        chown -h ${effectiveUser}:staff "${effectiveHome}/${relPath}" 2>/dev/null || true
      '') links
    );
in
{
  options.programs.jstack = {
    enable = lib.mkEnableOption "jstack multi-agent AI configuration";

    repoPath = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the jstack repository checkout.";
      example = "/home/user/Developer/jstack";
    };

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

    targets = {
      claude = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deploy skills and plugins to Claude Code (~/.claude/).";
        };
      };
      codex = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Deploy skills to Codex CLI (~/.codex/).";
        };
      };
      gemini = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Deploy skills to Gemini CLI (~/.gemini/).";
        };
      };
    };

    thirdParty = {
      enable = lib.mkEnableOption "third-party skill sources";
      selectedSkills = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          List of skill IDs to enable from third-party sources.
          Use "namespace:skill-name" format (e.g. "anthropic:frontend-design").
          Leave empty to enable all discovered third-party skills.
        '';
      };
    };
  };

  # Branches that depend on the surrounding module system (Home Manager
  # vs NixOS vs nix-darwin) are gated *eagerly* with `lib.optionals` so
  # the module system never sees option paths that don't exist in the
  # current context. `mkIf` is reserved for in-config conditions
  # (`cfg.enable`, `cfg.targets.<x>.enable`), where laziness matters.
  config = lib.mkIf cfg.enable (
    lib.mkMerge (
      [
        # ── Universal: assertion that a user is resolvable in system mode ──
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
        # ── Runtime package + JSTACK_RUNTIME (Home Manager) ──
        {
          home.packages = [ runtimePkg ];
          home.sessionVariables.JSTACK_RUNTIME = "${runtimePkg}";
        }

        # ── Claude Code target ──
        (lib.mkIf cfg.targets.claude.enable {
          programs.claude-code.settings = import ./settings.nix;
          programs.claude-code.plugins = pluginBundles;

          home.file = {
            ".claude/skills".source = mkHmLink "skills";
            ".claude/agents".source = mkHmLink "agents";
            ".claude/commands".source = mkHmLink "commands";
            ".claude/hooks".source = mkHmLink "hooks";
            ".claude/plugins".source = mkHmLink "plugins";
            ".claude/CLAUDE.md".source = mkHmLink "CLAUDE.md";
          };
        })

        # ── Codex CLI target ──
        (lib.mkIf cfg.targets.codex.enable {
          home.file.".codex/skills".source = mkHmLink "skills";
        })

        # ── Gemini CLI target ──
        (lib.mkIf cfg.targets.gemini.enable {
          home.file.".gemini/skills".source = mkHmLink "skills";
        })
      ]
      ++ lib.optionals isSystem [
        # ── Runtime package + JSTACK_RUNTIME (NixOS / nix-darwin) ──
        {
          environment.systemPackages = [ runtimePkg ];
          environment.variables.JSTACK_RUNTIME = "${runtimePkg}";
        }
      ]
      ++ lib.optionals isNixOS [
        # ── Claude Code target — NixOS (systemd-tmpfiles) ──
        (lib.mkIf cfg.targets.claude.enable {
          systemd.tmpfiles.rules = mkTmpfilesRules claudeLinks;
        })
        (lib.mkIf cfg.targets.codex.enable {
          systemd.tmpfiles.rules = mkTmpfilesRules codexLinks;
        })
        (lib.mkIf cfg.targets.gemini.enable {
          systemd.tmpfiles.rules = mkTmpfilesRules geminiLinks;
        })
      ]
      ++ lib.optionals isNixDarwin [
        # ── Claude Code target — nix-darwin (postActivation script) ──
        (lib.mkIf cfg.targets.claude.enable {
          system.activationScripts.postActivation.text = mkDarwinActivationLines claudeLinks;
        })
        (lib.mkIf cfg.targets.codex.enable {
          system.activationScripts.postActivation.text = mkDarwinActivationLines codexLinks;
        })
        (lib.mkIf cfg.targets.gemini.enable {
          system.activationScripts.postActivation.text = mkDarwinActivationLines geminiLinks;
        })
      ]
    )
  );
}
