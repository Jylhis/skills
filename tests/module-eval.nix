# Synthetic eval driver for ../module.nix.
#
# Loads the module four times under stub option contexts that mimic
# Home Manager, NixOS, and nix-darwin, plus a negative case (system
# context with no `programs.jstack.user` set). Throws on the first
# failure; evaluates to the string "OK" when every check passes.
#
# Run via:  nix eval --impure --raw --file tests/module-eval.nix
#           nix eval --raw --apply 'f: f { system = "x86_64-linux"; }' --file tests/module-eval.nix
#
# Also executed by `nix flake check` (pure mode) and `just check`.

{
  system ? builtins.currentSystem,
  # Flake-check calls this module in pure-eval mode and passes `pkgs`
  # explicitly (flake.nix). Standalone impure invocations fall back to
  # bootstrapping nixpkgs from `_sources.nix` (flake-compat).
  pkgs ? import (import ../_sources.nix).nixpkgs { inherit system; },
}:

let
  jstackRepo = ../.;

  basePkgs = pkgs;
  lib = basePkgs.lib;

  jstack = import (jstackRepo + "/module.nix");

  # ── Force-darwin / force-linux pkgs ──────────────────────────────
  # `module.nix` only reads `pkgs.stdenv.hostPlatform.isDarwin`, so
  # overriding that one boolean is enough to drive context detection.
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

  # ── Loose option helpers (catch any value the module sets) ──────
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

  # `assertions` exists in NixOS, nix-darwin AND home-manager.
  assertionsStub = {
    options.assertions = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
    };
  };

  # ── Stub option declarations per target context ─────────────────
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

  # ── Eval driver ─────────────────────────────────────────────────
  evalCtx =
    {
      contextModules,
      pkgs',
      extraConfig ? { },
    }:
    lib.evalModules {
      modules = contextModules ++ [
        assertionsStub
        jstack
        ({
          config = lib.mkMerge [
            {
              programs.jstack.enable = true;
              programs.jstack.repoPath = toString jstackRepo;
              programs.jstack.targets.codex.enable = true;
              programs.jstack.targets.gemini.enable = true;
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

  # Pure-eval regression: repoPath must NOT be used for eval-time imports.
  # Setting it to a non-existent path proves the module resolves everything
  # from its own source tree (relative paths) rather than cfg.repoPath.
  pureEval = evalCtx {
    contextModules = [ hmStubModule ];
    pkgs' = linuxPkgs;
    extraConfig = {
      programs.jstack.repoPath = lib.mkForce "/DOES-NOT-EXIST/jstack";
    };
  };

  # ── Assertions over each context ────────────────────────────────
  assertionsPass = ctx: lib.all (a: a.assertion) ctx.config.assertions;
  assertionsFail = ctx: !(assertionsPass ctx);
  hasInfix = needle: haystack: lib.any (r: lib.hasInfix needle r) haystack;

  check = name: cond: if cond then null else throw "module-eval: FAIL [${name}]";

  results = [
    # ── Home Manager ──
    (check "hm.assertions.pass" (assertionsPass hmEval))
    (check "hm.runtime.installed" (builtins.length hmEval.config.home.packages == 1))
    (check "hm.session.JSTACK_RUNTIME" (hmEval.config.home.sessionVariables ? JSTACK_RUNTIME))
    (check "hm.claude.skills.linked" (hmEval.config.home.file ? ".claude/skills"))
    (check "hm.claude.agents.linked" (hmEval.config.home.file ? ".claude/agents"))
    (check "hm.codex.skills.linked" (hmEval.config.home.file ? ".codex/skills"))
    (check "hm.gemini.skills.linked" (hmEval.config.home.file ? ".gemini/skills"))
    (check "hm.claude.settings.imported" (hmEval.config.programs.claude-code.settings ? model))

    # ── NixOS ──
    (check "nixos.assertions.pass" (assertionsPass nixosEval))
    (check "nixos.runtime.installed" (builtins.length nixosEval.config.environment.systemPackages == 1))
    (check "nixos.env.JSTACK_RUNTIME" (nixosEval.config.environment.variables ? JSTACK_RUNTIME))
    (check "nixos.tmpfiles.has-claude" (
      hasInfix ".claude/skills" nixosEval.config.systemd.tmpfiles.rules
    ))
    (check "nixos.tmpfiles.has-codex" (
      hasInfix ".codex/skills" nixosEval.config.systemd.tmpfiles.rules
    ))
    (check "nixos.tmpfiles.has-gemini" (
      hasInfix ".gemini/skills" nixosEval.config.systemd.tmpfiles.rules
    ))
    (check "nixos.tmpfiles.points-at-linux-home" (
      hasInfix "/home/alice/" nixosEval.config.systemd.tmpfiles.rules
    ))

    # ── nix-darwin ──
    (check "darwin.assertions.pass" (assertionsPass darwinEval))
    (check "darwin.runtime.installed" (
      builtins.length darwinEval.config.environment.systemPackages == 1
    ))
    (check "darwin.env.JSTACK_RUNTIME" (darwinEval.config.environment.variables ? JSTACK_RUNTIME))
    (check "darwin.activation.has-claude" (
      lib.hasInfix ".claude/skills" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.has-codex" (
      lib.hasInfix ".codex/skills" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.has-gemini" (
      lib.hasInfix ".gemini/skills" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.points-at-darwin-home" (
      lib.hasInfix "/Users/alice/" darwinEval.config.system.activationScripts.postActivation.text
    ))
    (check "darwin.activation.chowns-symlinks" (
      lib.hasInfix "chown -h alice:staff" darwinEval.config.system.activationScripts.postActivation.text
    ))

    # ── Negative case: system context, no user → assertion fires ──
    (check "nixosNoUser.assertion.fires" (assertionsFail nixosNoUserEval))

    # ── Pure-eval regression: eval must not depend on repoPath ──
    (check "pure.eval.assertions.pass" (assertionsPass pureEval))
    (check "pure.eval.runtime.installed" (builtins.length pureEval.config.home.packages == 1))
    (check "pure.eval.session.JSTACK_RUNTIME" (pureEval.config.home.sessionVariables ? JSTACK_RUNTIME))
    (check "pure.eval.claude.skills.linked" (pureEval.config.home.file ? ".claude/skills"))
    (check "pure.eval.claude.settings.imported" (pureEval.config.programs.claude-code.settings ? model))
  ];
in
builtins.deepSeq results "OK"
