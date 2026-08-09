{
  description = "Jylhis AI tooling marketplace — skills, agents, slash commands, MCP servers, LSP servers, and plugins as structured flake outputs.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/15f4ee454b1dce334612fa6843b3e05cf546efab";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      mkCatalogue =
        system: pkgs:
        import ./nix/catalogue.nix {
          inherit pkgs;
          inherit (nixpkgs) lib;
          repoRoot = self;
        };
    in
    {
      lib = import ./nix/lib.nix { inherit (nixpkgs) lib; };

      # Custom output namespace. Not consumed by `nix flake check`'s default
      # checks; downstreams read it directly. See README / docs/install.md.
      aiTooling = forAllSystems mkCatalogue;

      packages = forAllSystems (
        system: pkgs:
        import ./nix/packages {
          inherit pkgs;
          catalogue = mkCatalogue system pkgs;
          repoRoot = self;
        }
      );

      apps = forAllSystems (
        system: _pkgs:
        let
          packages = self.packages.${system};
          mk = name: {
            type = "app";
            program = "${packages.${name}}/bin/${name}";
          };
        in
        {
          list = mk "skills-list";
          show = mk "skills-show";
          install = mk "skills-install";
          default = mk "skills-list";
        }
      );

      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = with pkgs; [
              git
              just
              jq
              yq-go
              shellcheck
              (python3.withPackages (ps: [
                ps.pyyaml
                ps.jsonschema
              ]))
            ];
          };
        }
      );

      # Explicit `nix flake check` target — proves the whole catalogue
      # evaluates and serialises to JSON. Custom `aiTooling` outputs are
      # skipped by the default check runner.
      checks = forAllSystems (
        system: pkgs: {
          catalogue = pkgs.runCommand "catalogue-check" { } ''
            cp ${self.packages.${system}.skills-catalogue-json} $out
          '';
        }
      );

      formatter = forAllSystems (_system: pkgs: pkgs.nixpkgs-fmt);
    };
}
