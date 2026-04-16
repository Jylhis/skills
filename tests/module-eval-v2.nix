# Synthetic eval driver for ../modules/ (v2).
#
# Loads the v2 module under stub option contexts that mimic Home Manager,
# NixOS, and nix-darwin. Tests all user-level tools (Claude Code, Codex,
# Gemini, Pi, Windsurf MCP) across all three contexts, plus negative cases.
#
# Run via:  nix eval --impure --raw --file tests/module-eval-v2.nix
#           nix eval --raw --apply 'f: f { system = "x86_64-linux"; }' --file tests/module-eval-v2.nix

{
  system ? builtins.currentSystem,
}:

let
  jstackRepo = ../.;

  pkgsPath = (import (jstackRepo + "/_sources.nix")).nixpkgs;
  basePkgs = import pkgsPath { inherit system; };
  lib = basePkgs.lib;

  jstackModule = import (jstackRepo + "/modules");

  # ── Force-darwin / force-linux pkgs ──────────────────────────────
  withDarwin =
    isDarwin:
    basePkgs
    // {
      stdenv = basePkgs.stdenv // {
        hostPlatform = basePkgs.stdenv.hostPlatform // {
          inherit isDarwin;
        };
      };
    };
  darwinPkgs = withDarwin true;
  linuxPkgs = withDarwin false;

  # ── Loose option helpers ───────────────────────────────────────
  loose = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = { };
  };
  looseList = lib.mkOption {
    type = lib.types.listOf lib.types.unspecified;
    default = [ ];
  };
  looseStr = lib.mkOption {
    type = lib.types.lines;
    default = "";
  };
  looseAny = lib.mkOption {
    type = lib.types.unspecified;
    default = null;
  };

  assertionsStub = {
    options.assertions = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
    };
  };

  # ── Stub option declarations per context ───────────────────────
  hmStubModule = {
    options = {
      home.username = lib.mkOption {
        type = lib.types.str;
        default = "alice";
      };
      home.homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/alice";
      };
      home.packages = looseList;
      home.sessionVariables = loose;
      home.file = loose;
      # HM claude-code module stubs
      programs.claude-code.settings = looseAny;
      programs.claude-code.plugins = looseList;
      lib = lib.mkOption {
        type = lib.types.unspecified;
        default = {
          file.mkOutOfStoreSymlink = path: { _outOfStoreSymlink = path; };
        };
      };
    };
  };

  nixosStubModule = {
    options = {
      environment.systemPackages = looseList;
      environment.variables = loose;
      systemd.tmpfiles.rules = looseList;
    };
  };

  darwinStubModule = {
    options = {
      environment.systemPackages = looseList;
      environment.variables = loose;
      system.primaryUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      system.activationScripts.postActivation.text = looseStr;
    };
  };

  # ── Eval driver ────────────────────────────────────────────────
  evalCtx =
    {
      contextModules,
      pkgs',
      extraConfig ? { },
    }:
    lib.evalModules {
      modules = contextModules ++ [
        assertionsStub
        jstackModule
        ({
          config = lib.mkMerge [
            {
              programs.jstack = {
                enable = true;
                instructions = "Test instructions";
                tools.claude-code.enable = true;
                tools.codex.enable = true;
                tools.gemini.enable = true;
                tools.pi.enable = true;
                tools.windsurf.enable = true;
                skills.test-skill.src = jstackRepo + "/skills/devenv";
                mcpServers.test-server = {
                  command = "test-mcp";
                  args = [ "--stdio" ];
                };
              };
            }
            extraConfig
          ];
        })
      ];
      specialArgs = {
        pkgs = pkgs';
      };
    };

  hmEval = evalCtx {
    contextModules = [ hmStubModule ];
    pkgs' = linuxPkgs;
  };

  nixosEval = evalCtx {
    contextModules = [ nixosStubModule ];
    pkgs' = linuxPkgs;
    extraConfig = {
      programs.jstack.user = "alice";
    };
  };

  darwinEval = evalCtx {
    contextModules = [ darwinStubModule ];
    pkgs' = darwinPkgs;
    extraConfig = {
      programs.jstack.user = "alice";
    };
  };

  # Negative case: NixOS context with no user — assertion should fire.
  nixosNoUserEval = evalCtx {
    contextModules = [ nixosStubModule ];
    pkgs' = linuxPkgs;
  };

  # livePath test: skills should use mkOutOfStoreSymlink
  hmLivePathEval = evalCtx {
    contextModules = [ hmStubModule ];
    pkgs' = linuxPkgs;
    extraConfig = {
      programs.jstack.livePath = "/home/alice/Developer/jstack";
    };
  };

  # ── Assertion helpers ──────────────────────────────────────────
  assertionsPass = ctx: lib.all (a: a.assertion) ctx.config.assertions;
  assertionsFail = ctx: !(assertionsPass ctx);
  hasInfix = needle: haystack: lib.any (r: lib.hasInfix needle r) haystack;

  check = name: cond: if cond then null else throw "module-eval-v2: FAIL [${name}]";

  results = [
    # ── Home Manager ──────────────────────────────────────────────
    (check "hm.assertions.pass" (assertionsPass hmEval))

    # Claude Code: delegates to programs.claude-code in HM
    (check "hm.claude.settings.delegated" (hmEval.config.programs.claude-code.settings ? "$schema"))
    (check "hm.claude.skills.linked" (hmEval.config.home.file ? ".claude/skills"))
    (check "hm.claude.mcp.linked" (hmEval.config.home.file ? ".mcp.json"))

    # Codex: home.file entries
    (check "hm.codex.skills.linked" (hmEval.config.home.file ? ".codex/skills"))
    (check "hm.codex.agents.linked" (hmEval.config.home.file ? ".codex/AGENTS.md"))

    # Gemini: home.file entries
    (check "hm.gemini.skills.linked" (hmEval.config.home.file ? ".gemini/skills"))
    (check "hm.gemini.settings.linked" (hmEval.config.home.file ? ".gemini/settings.json"))

    # Pi: home.file entries
    (check "hm.pi.skills.linked" (hmEval.config.home.file ? ".pi/skills"))
    (check "hm.pi.mcp.linked" (hmEval.config.home.file ? ".pi/mcp.json"))

    # Windsurf: MCP config in user dir
    (check "hm.windsurf.mcp.linked" (hmEval.config.home.file ? ".codeium/windsurf/mcp_config.json"))

    # Skills resolved
    (check "hm.skills.resolved" (hmEval.config.programs.jstack._resolvedSkills ? "test-skill"))

    # ── NixOS ────────────────────────────────────────────────────
    (check "nixos.assertions.pass" (assertionsPass nixosEval))
    (check "nixos.tmpfiles.has-claude" (
      hasInfix ".claude/settings.json" nixosEval.config.systemd.tmpfiles.rules
    ))
    (check "nixos.tmpfiles.has-codex" (
      hasInfix ".codex/skills" nixosEval.config.systemd.tmpfiles.rules
    ))
    (check "nixos.tmpfiles.has-gemini" (
      hasInfix ".gemini/settings.json" nixosEval.config.systemd.tmpfiles.rules
    ))
    (check "nixos.tmpfiles.has-pi" (hasInfix ".pi/mcp.json" nixosEval.config.systemd.tmpfiles.rules))
    (check "nixos.tmpfiles.has-windsurf" (
      hasInfix "mcp_config.json" nixosEval.config.systemd.tmpfiles.rules
    ))
    (check "nixos.tmpfiles.points-at-linux-home" (
      hasInfix "/home/alice/" nixosEval.config.systemd.tmpfiles.rules
    ))

    # ── nix-darwin ───────────────────────────────────────────────
    (check "darwin.assertions.pass" (assertionsPass darwinEval))
    (check "darwin.activation.has-claude" (
      lib.hasInfix ".claude/settings.json" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.has-codex" (
      lib.hasInfix ".codex/skills" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.has-gemini" (
      lib.hasInfix ".gemini/settings.json" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.points-at-darwin-home" (
      lib.hasInfix "/Users/alice/" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.chowns-symlinks" (
      lib.hasInfix "chown -h alice:staff" darwinEval.config.system.activationScripts.postActivation.text
    ))

    # ── Negative case: no user → assertion fires ─────────────────
    (check "nixosNoUser.assertion.fires" (assertionsFail nixosNoUserEval))

    # ── livePath test ────────────────────────────────────────────
    # Note: livePath for skill bundles in HM context requires further design.
    # Skill bundles are store derivations (tool-name substitution happens at build time),
    # so mkOutOfStoreSymlink can't be applied to them directly.
    # livePath is effective for _generated files in NixOS/nix-darwin contexts.
    (check "hm.livePath.eval.succeeds" (assertionsPass hmLivePathEval))
  ];
in
builtins.deepSeq results "OK"
