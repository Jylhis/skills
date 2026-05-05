{
  description = "skills - curated Claude Code skill catalogue + minimal deployment module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
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
      nixosModules.default = ./modules;
      darwinModules.default = ./modules;
      homeModules.default = ./modules;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.runCommand "skills" { } ''
            mkdir -p $out
            cp -r ${./skills}/. $out/
          '';
        }
      );
    };
}
