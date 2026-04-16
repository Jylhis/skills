{
  description = "jstack - multi-agent AI developer workflow configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    promptfoo = {
      url = "github:promptfoo/promptfoo/0.121.3";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      overlays.default = import ./overlay.nix;

      # v2 modules (multi-tool, per-tool config generation)
      nixosModules.default = import ./modules;
      darwinModules.default = import ./modules;
      homeModules.default = import ./modules;

      # v1 legacy modules (plugin-based, repoPath symlinks)
      nixosModules.legacy = import ./module.nix;
      darwinModules.legacy = import ./module.nix;
      homeModules.legacy = import ./module.nix;

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
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          moduleEvalV1 = import ./tests/module-eval.nix { inherit system pkgs; };
          moduleEvalV2 = import ./tests/module-eval-v2.nix { inherit system pkgs; };
        in
        {
          module-eval = pkgs.runCommand "jstack-module-eval" { } ''
            echo ${moduleEvalV1} > $out
          '';
          module-eval-v2 = pkgs.runCommand "jstack-module-eval-v2" { } ''
            echo ${moduleEvalV2} > $out
          '';
        }
      );
    };
}
