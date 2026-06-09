{
  description = "OpenViking `ov` CLI, packaged for local install with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAll = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAll (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          openviking = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.openviking;
        }
      );

      apps = forAll (system: rec {
        ov = {
          type = "app";
          program = "${self.packages.${system}.openviking}/bin/ov";
        };
        default = ov;
      });
    };
}
