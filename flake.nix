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

      # Resolve bundled-sources.nix entries to concrete source paths by
      # looking each key up in this flake's inputs. Passed to modules/
      # via _module.args so the module evaluates purely without having
      # to re-enter flake-compat.
      bundledSources = nixpkgs.lib.mapAttrs (
        name: cfg:
        cfg
        // {
          src = inputs.${name};
        }
      ) (import ./bundled-sources.nix);

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
