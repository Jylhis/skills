# Non-flake entry point — evaluates flake.nix via flake-compat so that
# `nix-build` and older non-flake tooling see the same outputs produced
# by `nix build` / `nix flake check`.
{
  system ? builtins.currentSystem,
}:
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  fc = lock.nodes.flake-compat.locked;
  flake-compat = builtins.fetchTarball {
    url = "https://github.com/${fc.owner}/${fc.repo}/archive/${fc.rev}.tar.gz";
    sha256 = fc.narHash;
  };
  flake = (import flake-compat { src = ./.; }).defaultNix;
in
{
  packages.default = flake.packages.${system}.default;
  inherit (flake)
    nixosModules
    darwinModules
    homeModules
    ;
}
