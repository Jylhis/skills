# Claude Code tool module.
#
# User-level tool: config lives in ~/.claude/.
#
# In Home Manager context, delegates to HM's programs.claude-code module
# to avoid collision (both would generate ~/.claude/settings.json).
# In NixOS/nix-darwin context, uses _generated for deployment.
{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.programs.jstack;
  toolCfg = cfg.tools.claude-code;

  isHomeManager = options ? home.homeDirectory;
  isSystem = !isHomeManager;

  mcpFormat = import ../../lib/mcp-format.nix { inherit lib; };
  instructionGen = import ../../lib/instruction-gen.nix { inherit lib; };
  skillBundle = import ../../lib/skill-bundle.nix { inherit pkgs lib; };
  fileBundle = import ../../lib/file-bundle.nix { inherit pkgs lib; };

  # Filter skills to those targeting this tool (or all tools)
  toolSkills = lib.filterAttrs (
    _: skill: skill.tools == null || builtins.elem "claude-code" skill.tools
  ) cfg._resolvedSkills;

  # Build skill bundle for Claude Code
  skills =
    if toolSkills != { } then
      skillBundle.mkSkillBundle {
        skills = toolSkills;
        toolName = "claude-code";
      }
    else
      null;

  agentsDir = fileBundle.mkFileBundle {
    entries = cfg.agents;
    toolName = "claude-code";
    kind = "agents";
  };

  commandsDir = fileBundle.mkFileBundle {
    entries = cfg.commands;
    toolName = "claude-code";
    kind = "commands";
  };

  # Merge settings
  mergedSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
  }
  // lib.optionalAttrs (toolCfg.model != null) { model = toolCfg.model; }
  // lib.optionalAttrs (toolCfg.permissions.allow != [ ] || toolCfg.permissions.deny != [ ]) {
    permissions =
      { }
      // lib.optionalAttrs (toolCfg.permissions.allow != [ ]) { allow = toolCfg.permissions.allow; }
      // lib.optionalAttrs (toolCfg.permissions.deny != [ ]) { deny = toolCfg.permissions.deny; };
  }
  // lib.optionalAttrs (toolCfg.hooks != { }) { hooks = toolCfg.hooks; }
  // toolCfg.settings;

  # Instruction file content
  instructionContent = instructionGen.mkInstructionFile {
    shared = cfg.instructions;
    extra = toolCfg.extraInstructions;
  };

  # MCP config
  mcpJson =
    if cfg.mcpServers != { } then
      pkgs.writeText "jstack-mcp.json" (mcpFormat.formatMcpJson cfg.mcpServers)
    else
      null;

  # LSP config
  lspJson =
    if cfg.lspServers != { } then
      pkgs.writeText "jstack-lsp.json" (
        builtins.toJSON {
          lspServers = lib.mapAttrs (
            _: srv:
            {
              inherit (srv) command;
            }
            // lib.optionalAttrs (srv.args != [ ]) { inherit (srv) args; }
            // lib.optionalAttrs (srv.extensionToLanguage != { }) {
              inherit (srv) extensionToLanguage;
            }
          ) cfg.lspServers;
        }
      )
    else
      null;

  # Settings file
  settingsFile = pkgs.writeText "jstack-claude-settings.json" (builtins.toJSON mergedSettings);

  # Instruction file
  instructionFile =
    if instructionContent != "" then pkgs.writeText "CLAUDE.md" instructionContent else null;
in
{
  options.programs.jstack.tools.claude-code = {
    enable = lib.mkEnableOption "Claude Code configuration";

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default model for Claude Code.";
      example = "claude-sonnet-4-6";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
      description = "Extra fields merged into settings.json.";
    };

    permissions = {
      allow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tool permissions to allow.";
        example = [
          "Read"
          "Glob"
          "Grep"
        ];
      };
      deny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tool permissions to deny.";
        example = [ "Bash(rm -rf *)" ];
      };
    };

    hooks = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
      description = "Claude Code hooks configuration.";
    };

    extraInstructions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional text appended to CLAUDE.md.";
    };
  };

  config = lib.mkIf (cfg.enable && toolCfg.enable) (
    lib.mkMerge (
      # ── Home Manager context: delegate to HM's claude-code module ──
      lib.optionals isHomeManager [
        {
          programs.claude-code.settings = mergedSettings;
        }

        (lib.mkIf (instructionFile != null) {
          home.file.".claude/CLAUDE.md".source = instructionFile;
        })

        (lib.mkIf (skills != null) {
          home.file.".claude/skills".source = skills;
        })

        (lib.mkIf (agentsDir != null) {
          home.file.".claude/agents".source = agentsDir;
        })

        (lib.mkIf (commandsDir != null) {
          home.file.".claude/commands".source = commandsDir;
        })

        (lib.mkIf (mcpJson != null) {
          home.file.".mcp.json".source = mcpJson;
        })

        (lib.mkIf (lspJson != null) {
          home.file.".lsp.json".source = lspJson;
        })
      ]

      # ── System context: use _generated ──
      ++ lib.optionals isSystem [
        {
          programs.jstack._generated.claude-code.files = {
            ".claude/settings.json" = settingsFile;
          }
          // lib.optionalAttrs (instructionFile != null) {
            ".claude/CLAUDE.md" = instructionFile;
          }
          // lib.optionalAttrs (mcpJson != null) { ".mcp.json" = mcpJson; }
          // lib.optionalAttrs (lspJson != null) { ".lsp.json" = lspJson; };
        }

        (lib.mkIf (skills != null) {
          programs.jstack._generated.claude-code.dirs = {
            ".claude/skills" = skills;
          };
        })

        (lib.mkIf (agentsDir != null) {
          programs.jstack._generated.claude-code.dirs = {
            ".claude/agents" = agentsDir;
          };
        })

        (lib.mkIf (commandsDir != null) {
          programs.jstack._generated.claude-code.dirs = {
            ".claude/commands" = commandsDir;
          };
        })
      ]
    )
  );
}
