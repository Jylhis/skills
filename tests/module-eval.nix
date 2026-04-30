# Synthetic eval driver for ../modules/.
#
# Loads the module under stub option contexts that mimic Home Manager,
# NixOS, and nix-darwin. Tests all user-level tools (Claude Code, Codex,
# Gemini, Pi, Windsurf MCP) across all three contexts, plus negative cases.
#
# Run via:  nix eval --impure --raw --file tests/module-eval.nix
#           nix eval --raw --apply 'f: f { system = "x86_64-linux"; }' --file tests/module-eval.nix

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
  inherit (basePkgs) lib;

  jstackModule = import (jstackRepo + "/modules");
  devenvModule = import (jstackRepo + "/modules/devenv.nix");
  mcpFormat = import (jstackRepo + "/lib/mcp-format.nix") { inherit lib; };

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
      # HM upstream AI-CLI module stubs. Our tool modules default their
      # `tools.<name>.enable` to these when the upstream module is loaded,
      # so they need to exist in the option tree for the default to fire.
      programs.claude-code.enable = lib.mkEnableOption "upstream claude-code";
      programs.claude-code.settings = looseAny;
      programs.claude-code.plugins = looseList;
      programs.codex.enable = lib.mkEnableOption "upstream codex";
      programs.codex.settings = looseAny;
      programs.codex.custom-instructions = looseStr;
      programs.codex.skills = looseAny;
      programs.gemini-cli.enable = lib.mkEnableOption "upstream gemini-cli";
      programs.aider-chat.enable = lib.mkEnableOption "upstream aider-chat";
      programs.opencode.enable = lib.mkEnableOption "upstream opencode";
      lib = lib.mkOption {
        type = lib.types.unspecified;
        default = {
          file.mkOutOfStoreSymlink = path: { _outOfStoreSymlink = path; };
        };
      };
    };
  };

  hmNoCodexStubModule = {
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
      programs.claude-code.enable = lib.mkEnableOption "upstream claude-code";
      programs.claude-code.settings = looseAny;
      programs.claude-code.plugins = looseList;
      programs.gemini-cli.enable = lib.mkEnableOption "upstream gemini-cli";
      programs.aider-chat.enable = lib.mkEnableOption "upstream aider-chat";
      programs.opencode.enable = lib.mkEnableOption "upstream opencode";
      lib = lib.mkOption {
        type = lib.types.unspecified;
        default = {
          file.mkOutOfStoreSymlink = path: { _outOfStoreSymlink = path; };
        };
      };
    };
  };

  devenvStubModule = {
    options = {
      packages = looseList;
      enterShell = looseStr;
      claude.code = loose;
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
      bundledSources ? { },
    }:
    lib.evalModules {
      modules = contextModules ++ [
        assertionsStub
        jstackModule
        { config._module.args.jstackBundledSources = bundledSources; }
        {
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
        }
      ];
      specialArgs = {
        pkgs = pkgs';
      };
    };

  hmEval = evalCtx {
    contextModules = [ hmStubModule ];
    pkgs' = linuxPkgs;
  };

  hmCodexDirectEval = evalCtx {
    contextModules = [ hmNoCodexStubModule ];
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

  # HM upstream-wiring test: enabling `programs.<tool>.enable` on the
  # upstream HM module should cause our matching `tools.<tool>.enable`
  # to default to true without explicit configuration.
  hmUpstreamWiredEval = lib.evalModules {
    modules = [
      hmStubModule
      assertionsStub
      jstackModule
      { config._module.args.jstackBundledSources = { }; }
      {
        config = {
          programs.jstack.enable = true;
          # Upstream enable flags only — no explicit tools.*.enable.
          programs.claude-code.enable = true;
          programs.codex.enable = true;
          programs.gemini-cli.enable = true;
          programs.aider-chat.enable = true;
          programs.opencode.enable = true;
        };
      }
    ];
    specialArgs = {
      pkgs = linuxPkgs;
    };
  };

  # livePath test: skills should use mkOutOfStoreSymlink
  hmLivePathEval = evalCtx {
    contextModules = [ hmStubModule ];
    pkgs' = linuxPkgs;
    extraConfig = {
      programs.jstack.livePath = "/home/alice/Developer/jstack";
    };
  };

  # Bundled-sources injection test: skillSources, agentSources and
  # commandSources should each populate when jstackBundledSources is
  # non-empty. Uses the repo's own skills/agents/commands as stand-in
  # inputs so the test doesn't depend on network-fetched flake inputs.
  hmBundledEval = evalCtx {
    contextModules = [ hmStubModule ];
    pkgs' = linuxPkgs;
    bundledSources = {
      example = {
        src = jstackRepo;
        skills = {
          namespace = "example";
          paths = {
            devenv = "skills/devenv";
          };
        };
        agents = {
          paths = {
            debugger = "agents/debugger.md";
          };
        };
        commands = {
          subdir = "commands";
        };
      };
    };
  };

  devenvCodexEval = lib.evalModules {
    modules = [
      devenvStubModule
      devenvModule
      {
        config = {
          jstack = {
            enable = true;
            instructions = "Project instructions";
            tools.codex = {
              enable = true;
              approvalPolicy = "on-request";
              extraInstructions = "Codex project instructions";
            };
            skills.test-skill.src = jstackRepo + "/skills/devenv";
            mcpServers.http-server = {
              type = "http";
              url = "https://example.test/mcp";
              bearer_token_env_var = "MCP_TOKEN";
              enabled_tools = [ "search" ];
            };
          };
        };
      }
    ];
    specialArgs = {
      pkgs = linuxPkgs;
    };
  };

  codexReadOnlyEval = evalCtx {
    contextModules = [ hmStubModule ];
    pkgs' = linuxPkgs;
    extraConfig = {
      programs.jstack.tools.codex.sandboxMode = "read-only";
    };
  };

  codexInvalidSandbox = builtins.tryEval (
    builtins.deepSeq
      (evalCtx {
        contextModules = [ hmStubModule ];
        pkgs' = linuxPkgs;
        extraConfig = {
          programs.jstack.tools.codex.sandboxMode = "full-auto";
        };
      }).config.programs.jstack.tools.codex.sandboxMode
      true
  );

  codexMcpAttrs = mcpFormat.formatCodexMcpAttrs {
    stdio-server = {
      command = "stdio-mcp";
      args = [ "--stdio" ];
      env.TOKEN = "value";
      env_vars = [ "LOCAL_TOKEN" ];
      cwd = "/tmp/project";
    };
    http-server = {
      type = "http";
      url = "https://example.test/mcp";
      bearer_token_env_var = "MCP_TOKEN";
      http_headers.Region = "test";
      env_http_headers.Authorization = "AUTH_HEADER";
      startup_timeout_sec = 20;
      tool_timeout_sec = 45;
      enabled = false;
      required = true;
      enabled_tools = [ "open" ];
      disabled_tools = [ "screenshot" ];
    };
  };

  # ── Assertion helpers ──────────────────────────────────────────
  assertionsPass = ctx: lib.all (a: a.assertion) ctx.config.assertions;
  assertionsFail = ctx: !(assertionsPass ctx);
  hasInfix = needle: haystack: lib.any (r: lib.hasInfix needle r) haystack;

  check = name: cond: if cond then null else throw "module-eval: FAIL [${name}]";

  results = [
    # ── Home Manager ──────────────────────────────────────────────
    (check "hm.assertions.pass" (assertionsPass hmEval))

    # Claude Code: delegates to programs.claude-code in HM
    (check "hm.claude.settings.delegated" (hmEval.config.programs.claude-code.settings ? "$schema"))
    (check "hm.claude.skills.linked" (hmEval.config.home.file ? ".claude/skills"))
    (check "hm.claude.mcp.linked" (hmEval.config.home.file ? ".mcp.json"))

    # Codex: delegates to programs.codex in HM when upstream exists
    (check "hm.codex.settings.delegated" (
      hmEval.config.programs.codex.settings.sandbox_mode == "workspace-write"
    ))
    (check "hm.codex.mcp.delegated" (
      hmEval.config.programs.codex.settings.mcp_servers."test-server".command == "test-mcp"
    ))
    (check "hm.codex.instructions.delegated" (
      lib.hasInfix "Test instructions" hmEval.config.programs.codex."custom-instructions"
    ))
    (check "hm.codex.skills.delegated" (hmEval.config.programs.codex.skills != { }))

    # Codex: direct fallback writes files when upstream is absent
    (check "hm.codex.fallback.skills.linked" (hmCodexDirectEval.config.home.file ? ".agents/skills"))
    (check "hm.codex.fallback.agents.linked" (hmCodexDirectEval.config.home.file ? ".codex/AGENTS.md"))
    (check "hm.codex.fallback.config.linked" (
      hmCodexDirectEval.config.home.file ? ".codex/config.toml"
    ))

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
      hasInfix ".agents/skills" nixosEval.config.systemd.tmpfiles.rules
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
      lib.hasInfix ".agents/skills" darwinEval.config.system.activationScripts.postActivation.text
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

    # ── Upstream HM wiring: enable defaults follow programs.* ────
    (check "hm.upstream.claude-code.defaults-true" hmUpstreamWiredEval.config.programs.jstack.tools.claude-code.enable)
    (check "hm.upstream.codex.defaults-true" hmUpstreamWiredEval.config.programs.jstack.tools.codex.enable)
    (check "hm.upstream.gemini.defaults-true" hmUpstreamWiredEval.config.programs.jstack.tools.gemini.enable)
    (check "hm.upstream.aider.defaults-true" hmUpstreamWiredEval.config.programs.jstack.tools.aider.enable)
    (check "hm.upstream.opencode.defaults-true" hmUpstreamWiredEval.config.programs.jstack.tools.opencode.enable)
    # Tools without upstream HM modules stay at their explicit `false`
    # default when the user did not opt-in.
    (check "hm.upstream.cursor.stays-false" (
      !hmUpstreamWiredEval.config.programs.jstack.tools.cursor.enable
    ))
    (check "hm.upstream.windsurf.stays-false" (
      !hmUpstreamWiredEval.config.programs.jstack.tools.windsurf.enable
    ))

    # ── Bundled-sources injection ────────────────────────────────
    (check "hm.bundled.skill.resolved" (
      hmBundledEval.config.programs.jstack._resolvedSkills ? "devenv"
    ))
    (check "hm.bundled.agent.resolved" (hmBundledEval.config.programs.jstack.agents ? "debugger"))
    (check "hm.bundled.skillSources.wired" (
      hmBundledEval.config.programs.jstack.skillSources ? "example"
    ))
    (check "hm.bundled.agentSources.wired" (
      hmBundledEval.config.programs.jstack.agentSources ? "example"
    ))

    # ── Codex option and MCP formatting coverage ─────────────────
    (check "codex.sandbox.read-only.accepted" (
      codexReadOnlyEval.config.programs.jstack.tools.codex.sandboxMode == "read-only"
    ))
    (check "codex.sandbox.full-auto.rejected" (!codexInvalidSandbox.success))
    (check "codex.mcp.stdio.shape" (
      codexMcpAttrs."stdio-server".command == "stdio-mcp"
      && codexMcpAttrs."stdio-server".env_vars == [ "LOCAL_TOKEN" ]
      && codexMcpAttrs."stdio-server".cwd == "/tmp/project"
    ))
    (check "codex.mcp.http.shape" (
      codexMcpAttrs."http-server".url == "https://example.test/mcp"
      && codexMcpAttrs."http-server".bearer_token_env_var == "MCP_TOKEN"
      && codexMcpAttrs."http-server".http_headers.Region == "test"
      && codexMcpAttrs."http-server".env_http_headers.Authorization == "AUTH_HEADER"
      && !codexMcpAttrs."http-server".enabled
      && codexMcpAttrs."http-server".required
      && codexMcpAttrs."http-server".startup_timeout_sec == 20
      && codexMcpAttrs."http-server".tool_timeout_sec == 45
      && codexMcpAttrs."http-server".enabled_tools == [ "open" ]
      && codexMcpAttrs."http-server".disabled_tools == [ "screenshot" ]
    ))
    (check "devenv.codex.config.emitted" (
      lib.hasInfix "$DEVENV_ROOT/.codex/config.toml" devenvCodexEval.config.enterShell
    ))
    (check "devenv.codex.agents.emitted" (
      lib.hasInfix "$DEVENV_ROOT/AGENTS.md" devenvCodexEval.config.enterShell
    ))
    (check "devenv.codex.skills.linked" (
      lib.hasInfix "$DEVENV_ROOT/.agents/skills/test-skill" devenvCodexEval.config.enterShell
    ))
  ];
in
builtins.deepSeq results "OK"
