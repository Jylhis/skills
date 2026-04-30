# Codex CLI tool module.
#
# User-level tool: config lives in ~/.codex/.
# Config is TOML format (~/.codex/config.toml).
{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.programs.jstack;
  toolCfg = cfg.tools.codex;

  isHomeManager = options ? home.homeDirectory;
  isSystem = !isHomeManager;

  hasUpstream = lib.hasAttrByPath [ "programs" "codex" "enable" ] options;
  upstreamHasSettings = lib.hasAttrByPath [ "programs" "codex" "settings" ] options;
  upstreamHasCustomInstructions = lib.hasAttrByPath [
    "programs"
    "codex"
    "custom-instructions"
  ] options;
  upstreamHasContext = lib.hasAttrByPath [ "programs" "codex" "context" ] options;
  upstreamHasSkills = lib.hasAttrByPath [ "programs" "codex" "skills" ] options;

  mcpFormat = import ../../lib/mcp-format.nix { inherit lib; };
  instructionGen = import ../../lib/instruction-gen.nix { inherit lib; };
  skillBundle = import ../../lib/skill-bundle.nix { inherit pkgs lib; };

  takeUntil =
    pred: list:
    if list == [ ] then
      [ ]
    else
      let
        head = builtins.head list;
        tail = builtins.tail list;
      in
      if pred head then [ ] else [ head ] ++ takeUntil pred tail;

  hasFrontmatterDescription =
    skill:
    let
      raw = builtins.readFile (skill.src + "/SKILL.md");
      content = if skill.transform or null != null then skill.transform raw else raw;
      lines = lib.splitString "\n" content;
      frontmatter =
        if lines != [ ] && builtins.head lines == "---" then
          takeUntil (line: line == "---") (builtins.tail lines)
        else
          [ ];
    in
    builtins.any (
      line: builtins.match "[[:space:]]*description[[:space:]]*:.*" line != null
    ) frontmatter;

  toolSkills = lib.filterAttrs (
    _: skill:
    (skill.tools == null || builtins.elem "codex" skill.tools)
    # Codex rejects skills without a description. Some upstream Claude-oriented
    # bundles intentionally omit it for command-only/internal support skills.
    && hasFrontmatterDescription skill
  ) cfg._resolvedSkills;

  skills =
    if toolSkills != { } then
      skillBundle.mkSkillBundle {
        skills = toolSkills;
        toolName = "codex";
      }
    else
      null;

  instructionContent = instructionGen.mkInstructionFile {
    shared = cfg.instructions;
    extra = toolCfg.extraInstructions;
  };

  instructionFile =
    if instructionContent != "" then pkgs.writeText "AGENTS.md" instructionContent else null;

  settingsWithoutNested = lib.removeAttrs toolCfg.settings [
    "features"
    "mcp_servers"
  ];

  mergedFeatures = toolCfg.features // (toolCfg.settings.features or { });
  mergedMcpServers =
    mcpFormat.formatCodexMcpAttrs cfg.mcpServers // (toolCfg.settings.mcp_servers or { });

  mergedSettings = {
    sandbox_mode = toolCfg.sandboxMode;
  }
  // lib.optionalAttrs (toolCfg.model != null) { inherit (toolCfg) model; }
  // lib.optionalAttrs (toolCfg.approvalPolicy != null) {
    approval_policy = toolCfg.approvalPolicy;
  }
  // lib.optionalAttrs (toolCfg.profile != null) { inherit (toolCfg) profile; }
  // settingsWithoutNested
  // lib.optionalAttrs (mergedFeatures != { }) { features = mergedFeatures; }
  // lib.optionalAttrs (mergedMcpServers != { }) { mcp_servers = mergedMcpServers; };

  configToml =
    if mergedSettings != { } then
      mcpFormat.formatToml pkgs "codex-config.toml" mergedSettings
    else
      null;

  skillsPath = if toolCfg.skillsTarget == "agents" then ".agents/skills" else ".codex/skills";

  generatedFiles =
    { }
    // lib.optionalAttrs (instructionFile != null) {
      ".codex/AGENTS.md" = instructionFile;
    }
    // lib.optionalAttrs (configToml != null) {
      ".codex/config.toml" = configToml;
    };
in
{
  options.programs.jstack.tools.codex = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = if hasUpstream then config.programs.codex.enable else false;
      defaultText = lib.literalExpression ''
        if the upstream Home Manager `programs.codex` module is loaded,
        its `enable` value; otherwise `false`.
      '';
      example = true;
      description = ''
        Whether to enable Codex CLI configuration.

        In Home Manager context, this defaults to the upstream
        `programs.codex.enable` value when the upstream module is loaded.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
      description = "Extra TOML-compatible fields merged into config.toml.";
    };

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default model for Codex.";
      example = "gpt-5.5";
    };

    approvalPolicy = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "untrusted"
          "on-request"
          "never"
        ]
      );
      default = null;
      description = "Codex approval policy.";
    };

    sandboxMode = lib.mkOption {
      type = lib.types.enum [
        "read-only"
        "workspace-write"
        "danger-full-access"
      ];
      default = "workspace-write";
      description = "Codex sandbox mode.";
    };

    profile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default Codex profile.";
    };

    features = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Feature flags written under the Codex [features] table.";
    };

    skillsTarget = lib.mkOption {
      type = lib.types.enum [
        "agents"
        "codex"
      ];
      default = "agents";
      description = "Skill directory target: .agents/skills for modern Codex or .codex/skills for compatibility.";
    };

    extraInstructions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional text appended to AGENTS.md.";
    };
  };

  config = lib.mkIf (cfg.enable && toolCfg.enable) (
    lib.mkMerge (
      lib.optionals isHomeManager [
        (lib.mkIf hasUpstream (
          lib.mkMerge (
            lib.optionals upstreamHasSettings [
              {
                programs.codex.settings = mergedSettings;
              }
            ]
            ++ lib.optionals upstreamHasCustomInstructions [
              (lib.mkIf (instructionContent != "") {
                programs.codex.custom-instructions = instructionContent;
              })
            ]
            ++ lib.optionals (!upstreamHasCustomInstructions && upstreamHasContext) [
              (lib.mkIf (instructionContent != "") {
                programs.codex.context = instructionContent;
              })
            ]
            ++ lib.optionals (!upstreamHasCustomInstructions && !upstreamHasContext) [
              (lib.mkIf (instructionContent != "") {
                home.file.".codex/AGENTS.md".source = instructionFile;
              })
            ]
            ++ lib.optionals upstreamHasSkills [
              (lib.mkIf (skills != null) {
                programs.codex.skills = skills;
              })
            ]
            ++ lib.optionals (!upstreamHasSettings) [
              (lib.mkIf (configToml != null) {
                home.file.".codex/config.toml".source = configToml;
              })
            ]
            ++ lib.optionals (!upstreamHasSkills) [
              (lib.mkIf (skills != null) {
                home.file = {
                  ${skillsPath} = {
                    source = skills;
                  };
                };
              })
            ]
          )
        ))
        (lib.mkIf (!hasUpstream) (
          lib.mkMerge [
            {
              home.file = lib.mapAttrs (_: source: { inherit source; }) generatedFiles;
            }
            (lib.mkIf (skills != null) {
              home.file = {
                ${skillsPath} = {
                  source = skills;
                };
              };
            })
          ]
        ))
      ]
      ++ lib.optionals isSystem [
        {
          programs.jstack._generated.codex.files = generatedFiles;
        }
        (lib.mkIf (skills != null) {
          programs.jstack._generated.codex.dirs = {
            ${skillsPath} = skills;
          };
        })
      ]
    )
  );
}
