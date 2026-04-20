# devenv integration module for jstack v2.
#
# Handles two responsibilities:
# 1. Project-level tool config (Cursor, OpenCode, Cline, Aider, Windsurf rules)
# 2. Live-editing skill deployment for development
#
# Delegates to devenv's built-in claude.code integration for Claude Code
# rather than duplicating its file generation.
#
# Usage in devenv.nix:
#   imports = [ ./modules/devenv.nix ];
#   jstack = {
#     enable = true;
#     tools.claude-code.enable = true;
#     tools.cursor.enable = true;
#     skills = jstack.lib.defaultSkills.all;
#     mcpServers.github = { command = "github-mcp-server"; args = ["--stdio"]; };
#   };
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jstack;
  instructionGen = import ../lib/instruction-gen.nix { inherit lib; };
  mcpFormat = import ../lib/mcp-format.nix { inherit lib; };

  # Generate instruction file content for project-level tools
  mkInstr =
    extra:
    instructionGen.mkInstructionFile {
      shared = cfg.instructions;
      inherit extra;
    };

  # Cursor MCP config file
  cursorMcpFile =
    if cfg.mcpServers != { } then
      pkgs.writeText "cursor-mcp.json" (mcpFormat.formatMcpJson cfg.mcpServers)
    else
      null;

  # OpenCode config with embedded MCP
  openCodeConfig =
    let
      base = cfg.tools.opencode.settings or { };
      withMcp =
        if cfg.mcpServers != { } then base // { mcp = mcpFormat.formatMcpAttrs cfg.mcpServers; } else base;
    in
    if withMcp != { } then pkgs.writeText "opencode.json" (builtins.toJSON withMcp) else null;

  # Skill symlink script: creates per-skill symlinks for live editing
  skillLinkScript =
    let
      skillEntries = lib.mapAttrsToList (name: skill: {
        inherit name;
        inherit (skill) src;
      }) (cfg.skills or { });
    in
    lib.concatMapStringsSep "\n" (
      entry: ''ln -sfn "${entry.src}" "$DEVENV_ROOT/.agents/skills/${entry.name}"''
    ) skillEntries;
in
{
  options.jstack = {
    enable = lib.mkEnableOption "jstack project configuration";

    instructions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Tool-agnostic instructions shared across all enabled tools.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            src = lib.mkOption {
              type = lib.types.path;
              description = "Path to a directory containing SKILL.md.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };
            transform = lib.mkOption {
              type = lib.types.nullOr (lib.types.functionTo lib.types.str);
              default = null;
            };
            tools = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
            };
          };
        }
      );
      default = { };
      description = "Skills deployed to the project for all enabled tools.";
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption { type = lib.types.str; };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            env = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
            type = lib.mkOption {
              type = lib.types.enum [
                "stdio"
                "sse"
                "http"
              ];
              default = "stdio";
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        }
      );
      default = { };
      description = "MCP servers shared across all enabled tools.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages added to PATH.";
    };

    tools = {
      claude-code = {
        enable = lib.mkEnableOption "Claude Code (delegates to devenv claude.code)";
        model = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.unspecified;
          default = { };
        };
        extraInstructions = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
      cursor = {
        enable = lib.mkEnableOption "Cursor project config";
        extraInstructions = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
      windsurf = {
        enable = lib.mkEnableOption "Windsurf project config";
        extraInstructions = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
      opencode = {
        enable = lib.mkEnableOption "OpenCode project config";
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.unspecified;
          default = { };
        };
        extraInstructions = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
      cline = {
        enable = lib.mkEnableOption "Cline project config";
        extraInstructions = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
      aider = {
        enable = lib.mkEnableOption "Aider project config";
        extraInstructions = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    inherit (cfg) packages;

    # Delegate Claude Code to devenv's built-in integration
    claude.code = lib.mkIf cfg.tools.claude-code.enable {
      enable = true;
      mcpServers = lib.mapAttrs (
        _: srv:
        {
          inherit (srv) command type;
        }
        // lib.optionalAttrs (srv.args != [ ]) { inherit (srv) args; }
        // lib.optionalAttrs (srv.env != { }) { inherit (srv) env; }
      ) cfg.mcpServers;
    };

    enterShell = lib.mkAfter ''
      # ── jstack: skill deployment (live symlinks) ──
      mkdir -p "$DEVENV_ROOT/.agents/skills"
      ${skillLinkScript}

      ${lib.optionalString cfg.tools.cursor.enable ''
        # ── jstack: Cursor project config ──
        mkdir -p "$DEVENV_ROOT/.cursor/rules"
        ${
          let
            content = mkInstr cfg.tools.cursor.extraInstructions;
          in
          lib.optionalString (content != "") ''
            cat > "$DEVENV_ROOT/.cursor/rules/jstack.md" <<'JSTACK_EOF'
            ${content}
            JSTACK_EOF
          ''
        }
        ${lib.optionalString (cursorMcpFile != null) ''
          ln -sfn "${cursorMcpFile}" "$DEVENV_ROOT/.cursor/mcp.json"
        ''}
      ''}

      ${lib.optionalString cfg.tools.windsurf.enable ''
        # ── jstack: Windsurf project config ──
        mkdir -p "$DEVENV_ROOT/.windsurf"
        ${
          let
            content = mkInstr cfg.tools.windsurf.extraInstructions;
          in
          lib.optionalString (content != "") ''
            cat > "$DEVENV_ROOT/.windsurfrules" <<'JSTACK_EOF'
            ${content}
            JSTACK_EOF
          ''
        }
      ''}

      ${lib.optionalString cfg.tools.opencode.enable ''
        # ── jstack: OpenCode project config ──
        ${
          let
            content = mkInstr cfg.tools.opencode.extraInstructions;
          in
          lib.optionalString (content != "") ''
            cat > "$DEVENV_ROOT/AGENTS.md" <<'JSTACK_EOF'
            ${content}
            JSTACK_EOF
          ''
        }
        ${lib.optionalString (openCodeConfig != null) ''
          ln -sfn "${openCodeConfig}" "$DEVENV_ROOT/opencode.json"
        ''}
      ''}

      ${lib.optionalString cfg.tools.cline.enable ''
        # ── jstack: Cline project config ──
        mkdir -p "$DEVENV_ROOT/.clinerules"
        ${
          let
            content = mkInstr cfg.tools.cline.extraInstructions;
          in
          lib.optionalString (content != "") ''
            cat > "$DEVENV_ROOT/.clinerules/jstack.md" <<'JSTACK_EOF'
            ${content}
            JSTACK_EOF
          ''
        }
      ''}

      ${lib.optionalString cfg.tools.aider.enable ''
        # ── jstack: Aider project config ──
        ${
          let
            content = mkInstr cfg.tools.aider.extraInstructions;
          in
          lib.optionalString (content != "") ''
            cat > "$DEVENV_ROOT/CONVENTIONS.md" <<'JSTACK_EOF'
            ${content}
            JSTACK_EOF
          ''
        }
      ''}
    '';
  };
}
