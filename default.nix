# Non-flake entry point — resolves inputs from flake.lock.
# Usage: nix-build -A packages.default
{
  system ? builtins.currentSystem,
  pkgs ? import (import ./_sources.nix).nixpkgs {
    inherit system;
    overlays = [ (import ./overlay.nix) ];
  },
}:
{
  packages.default = pkgs.jstack-runtime;
  overlays.default = import ./overlay.nix;
  nixosModules.default = import ./module.nix;
  darwinModules.default = import ./module.nix;
  homeModules.default = import ./module.nix;
  lib = import ./lib { inherit pkgs; };
}
