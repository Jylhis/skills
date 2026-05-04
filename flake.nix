{
  description = "skills - curated agent skill catalogue and multi-tool deployment module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    cc-skills-golang = {
      url = "github:samber/cc-skills-golang";
      flake = false;
    };
    obsidian-skills = {
      url = "github:kepano/obsidian-skills";
      flake = false;
    };
    rust-skills = {
      url = "github:actionbook/rust-skills";
      flake = false;
    };
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    hashicorp-agent-skills = {
      url = "github:hashicorp/agent-skills";
      flake = false;
    };
    openai-skills = {
      url = "github:openai/skills";
      flake = false;
    };
    microsoft-skills = {
      url = "github:microsoft/skills";
      flake = false;
    };
    cloudflare-skills = {
      url = "github:cloudflare/skills";
      flake = false;
    };
    trailofbits-skills = {
      url = "github:trailofbits/skills";
      flake = false;
    };
    trailofbits-skills-curated = {
      url = "github:trailofbits/skills-curated";
      flake = false;
    };
    addyosmani-agent-skills = {
      url = "github:addyosmani/agent-skills";
      flake = false;
    };
    minimax-skills = {
      url = "github:MiniMax-AI/skills";
      flake = false;
    };
    taste-skill = {
      url = "github:Leonxlnx/taste-skill";
      flake = false;
    };
    ai-research-skills = {
      url = "github:Orchestra-Research/AI-Research-SKILLs";
      flake = false;
    };
    github-awesome-copilot = {
      url = "github:github/awesome-copilot";
      flake = false;
    };
    grafana-skills = {
      url = "github:grafana/skills";
      flake = false;
    };
    composio-awesome-codex-skills = {
      url = "github:ComposioHQ/awesome-codex-skills";
      flake = false;
    };
    superpowers-zh = {
      url = "github:jnMetaCode/superpowers-zh";
      flake = false;
    };
    prat011-awesome-llm-skills = {
      url = "github:Prat011/awesome-llm-skills";
      flake = false;
    };
    aboutsecurity = {
      url = "github:wgpsec/AboutSecurity";
      flake = false;
    };
    finance-skills = {
      url = "github:himself65/finance-skills";
      flake = false;
    };
    claude-workflow-v2 = {
      url = "github:CloudAI-X/claude-workflow-v2";
      flake = false;
    };
    awesome-claude-code-toolkit = {
      url = "github:rohitg00/awesome-claude-code-toolkit";
      flake = false;
    };
    vibe-skills = {
      url = "github:foryourhealth111-pixel/Vibe-Skills";
      flake = false;
    };
    tech-leads-agent-skills = {
      url = "github:tech-leads-club/agent-skills";
      flake = false;
    };
    gitagent = {
      url = "github:open-gitagent/gitagent";
      flake = false;
    };
    waza = {
      url = "github:tw93/Waza";
      flake = false;
    };
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Each bundled-sources.nix entry already has `src` wired to a
      # concrete flake input (the file is a function of `inputs`).
      # Pass the result to modules/ via _module.args so the module
      # evaluates purely without having to re-enter flake-compat.
      bundledSources = import ./bundled-sources.nix inputs;

      moduleWithBundled = {
        imports = [ ./modules ];
        _module.args.jstackBundledSources = bundledSources;
      };
    in
    {
      overlays.default = import ./overlay.nix;

      nixosModules.default = moduleWithBundled;
      darwinModules.default = moduleWithBundled;
      homeModules.default = moduleWithBundled;

      # Lib exports for consumers
      lib = {
        defaultSkills = import ./lib/default-skills.nix;
        toolDefs = import ./lib/tool-defs.nix;
        toolMappings = import ./lib/tool-mappings.nix;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend (import ./overlay.nix);
        in
        {
          default = pkgs.jstack-runtime;
          options-doc = import ./docs/options {
            inherit pkgs;
            inherit (pkgs) lib;
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          moduleEval = import ./tests/module-eval.nix { inherit system pkgs; };
        in
        {
          module-eval = pkgs.runCommand "jstack-module-eval" { } ''
            echo ${moduleEval} > $out
          '';
        }
      );
    };
}
