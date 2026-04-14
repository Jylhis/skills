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
      nixosModules.default = import ./module.nix;
      darwinModules.default = import ./module.nix;
      homeModules.default = import ./module.nix;

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
          moduleEvalResult = import ./tests/module-eval.nix { inherit system; };
        in
        {
          module-eval = pkgs.runCommand "jstack-module-eval" { } ''
            echo ${moduleEvalResult} > $out
          '';
        }
      );
    };
}
